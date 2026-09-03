import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';
import '../domain/card_codec.dart';
import 'game_store.dart';
import '../../decks/domain/deck_rules.dart';

/// Fichier de cache des légendes, dans le dossier documents.
const String kLegendsCacheFileName = 'legends.json';

/// Au-delà, on retente le réseau ; en dessous, le cache répond seul.
const Duration kLegendsCacheMaxAge = Duration(days: 7);

/// Une légende et ses variantes (même nom canonique : normale, alt-art,
/// overnumbered, signature).
class LegendGroup {
  LegendGroup({required List<RiftCard> variants})
    : variants = List.unmodifiable(variants);

  /// Version normale d'abord, puis alt-art, overnumbered, signature.
  final List<RiftCard> variants;

  RiftCard get base => variants.first;
  String get name => base.name;
  List<String> get domains => base.domains;

  bool matches(String query) {
    if (query.isEmpty) return true;
    return _fold(name).contains(_fold(query));
  }
}

/// Étiquette d'une variante, ou null pour la version normale.
String? legendVariantLabel(RiftCard card) {
  if (card.signature) return 'Signature';
  if (card.overnumbered) return 'Overnumbered';
  if (card.alternateArt) return 'Alt-art';
  return null;
}

/// Copie locale de la liste des légendes.
abstract class LegendsCacheStore {
  /// Cartes en cache et date de rapatriement, ou null s'il n'y a pas de cache.
  Future<({List<RiftCard> cards, DateTime fetchedAt})?> read();

  Future<bool> write(List<RiftCard> cards, DateTime fetchedAt);
}

class FileLegendsCacheStore implements LegendsCacheStore {
  const FileLegendsCacheStore({GameDirectoryResolver? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  final GameDirectoryResolver _directory;

  Future<File> _file() async {
    final directory = await _directory();
    return File(
      '${directory.path}${Platform.pathSeparator}$kLegendsCacheFileName',
    );
  }

  @override
  Future<({List<RiftCard> cards, DateTime fetchedAt})?> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map) return null;
      final cards = (json['items'] as List? ?? const [])
          .map(cardFromJson)
          .whereType<RiftCard>()
          .toList();
      if (cards.isEmpty) return null;
      final fetchedAt =
          DateTime.tryParse('${json['fetched_at']}') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return (cards: cards, fetchedAt: fetchedAt);
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> write(List<RiftCard> cards, DateTime fetchedAt) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          'fetched_at': fetchedAt.toIso8601String(),
          'items': cards.map(cardToJson).toList(),
        }),
        flush: true,
      );
      return true;
    } on Object {
      return false;
    }
  }
}

/// Liste des légendes, groupées par carte et servies hors ligne.
///
/// Le cache passe avant le réseau tant qu'il est frais : ouvrir le sélecteur
/// est alors instantané, même sans connexion. Quand le réseau ne répond pas,
/// un cache périmé vaut mieux qu'une liste vide.
class LegendsRepository {
  const LegendsRepository({
    required this.api,
    required this.cache,
    this.maxAge = kLegendsCacheMaxAge,
    this.pageSize = 100,
    this.maxPages = 6,
  });

  final CardsApi api;
  final LegendsCacheStore cache;
  final Duration maxAge;
  final int pageSize;

  /// Garde-fou : la liste des légendes tient largement dans ces pages.
  final int maxPages;

  Future<List<LegendGroup>> load({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final cached = await cache.read();
    if (cached != null && today.difference(cached.fetchedAt) < maxAge) {
      return groupLegends(cached.cards);
    }
    try {
      final cards = await _fetch();
      if (cards.isEmpty) throw StateError('aucune légende');
      await cache.write(cards, today);
      return groupLegends(cards);
    } on Object {
      if (cached != null) return groupLegends(cached.cards);
      rethrow;
    }
  }

  Future<List<RiftCard>> _fetch() async {
    final cards = <RiftCard>[];
    for (var page = 1; page <= maxPages; page++) {
      final result = await api.list(
        filters: const CardFilters(type: 'Legend'),
        page: page,
        size: pageSize,
      );
      cards.addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) break;
    }
    return cards;
  }
}

/// Regroupe les cartes par `riftbound_id` et trie les groupes par nom.
List<LegendGroup> groupLegends(List<RiftCard> cards) {
  // Regroupement par nom canonique (sans « (Alternate Art) », « (Overnumbered) »,
  // « (Signature) ») : les overnumbered et signatures portent un riftbound_id
  // différent de la version normale, le nom est le seul lien fiable.
  final byId = <String, List<RiftCard>>{};
  for (final card in cards) {
    final key = canonicalName(card.name).isEmpty
        ? (card.riftboundId.isEmpty ? card.id : card.riftboundId)
        : canonicalName(card.name).toLowerCase();
    byId.putIfAbsent(key, () => []).add(card);
  }
  final groups = <LegendGroup>[];
  for (final entry in byId.entries) {
    final variants = entry.value..sort(_byVariant);
    groups.add(LegendGroup(variants: variants));
  }
  groups.sort((a, b) => _fold(a.name).compareTo(_fold(b.name)));
  return groups;
}

int _byVariant(RiftCard a, RiftCard b) {
  final rank = _variantRank(a).compareTo(_variantRank(b));
  if (rank != 0) return rank;
  return (a.collectorNumber ?? 0).compareTo(b.collectorNumber ?? 0);
}

int _variantRank(RiftCard card) {
  if (card.signature) return 3;
  if (card.overnumbered) return 2;
  if (card.alternateArt) return 1;
  return 0;
}

/// Comparaison insensible à la casse et aux accents (« Jinx » = « jinx »).
String _fold(String value) {
  const accents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿœæ';
  const plain = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = accents.indexOf(char);
    buffer.write(index == -1 ? char : plain[index]);
  }
  return buffer.toString();
}
