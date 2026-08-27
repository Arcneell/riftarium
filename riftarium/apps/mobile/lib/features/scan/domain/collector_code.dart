/// Lecture du code collector imprimé au bas des cartes (« OGN 209/298 »).
///
/// Port Dart de `apps/web/src/scanOcr.js` : même parsing, mêmes garde-fous.
/// Pourquoi lire le code plutôt que la ressemblance de l'illustration : le code
/// identifie la carte de façon exacte (set + numéro + total d'impression), là où
/// l'image confond les variantes et les arts alternatifs.
///
/// Ce fichier est du Dart pur (aucun import Flutter) : c'est ce qui le rend
/// entièrement testable sans caméra ni plugin natif.
library;

/// Marge « overnumbered » : certaines cartes portent un numéro supérieur au
/// total imprimé (impressions hors set numéroté). Riot n'a jamais dépassé
/// quelques dizaines au-delà ; 60 laisse de la marge sans accepter n'importe quoi.
const int kOvernumberMargin = 60;

/// Identifiant Riftbound décomposé : « unl-229*-219 ».
class RiftboundId {
  const RiftboundId({
    required this.set,
    required this.number,
    required this.suffix,
    required this.total,
  });

  /// Code du set en majuscules (« UNL », « OGN »).
  final String set;

  /// Numéro de la carte dans le set.
  final int number;

  /// Suffixe éventuel (« * » pour les variantes étoilées, lettres d'impression).
  final String suffix;

  /// Total d'impression du set (219 pour UNL, 298 pour OGN…).
  final int total;

  bool get star => suffix.contains('*');
}

final RegExp _riftboundIdPattern = RegExp(
  r'^([a-z0-9]{2,6})-(\d{1,4})([a-z*]{0,3})-(\d{1,4})$',
  caseSensitive: false,
);

/// « unl-229*-219 » → set UNL, numéro 229, étoile, total 219. Null si la forme
/// n'est pas reconnue (identifiant absent ou exotique).
RiftboundId? parseRiftboundId(String? rid) {
  final match = _riftboundIdPattern.firstMatch((rid ?? '').trim());
  if (match == null) return null;
  return RiftboundId(
    set: match.group(1)!.toUpperCase(),
    number: int.parse(match.group(2)!),
    suffix: match.group(3)!.toLowerCase(),
    total: int.parse(match.group(4)!),
  );
}

/// Code lu sur une carte : « OGN 209/298 ». Le set et l'étoile sont des bonus
/// (jamais exigés, jamais décisifs) — voir [matchByCode].
class CollectorCode {
  const CollectorCode({
    required this.number,
    required this.total,
    this.set,
    this.star = false,
  });

  /// Set à trois lettres quand l'OCR l'a lu, null sinon.
  final String? set;
  final int number;
  final int total;
  final bool star;

  /// Le code tel qu'il est imprimé, numéro complété à la longueur du total
  /// (« OGN 002/298 », jamais « OGN 2/298 »).
  String get label {
    final padded = number.toString().padLeft(total.toString().length, '0');
    return '${set == null ? '' : '$set '}$padded${star ? '*' : ''}/$total';
  }

  @override
  bool operator ==(Object other) =>
      other is CollectorCode &&
      other.set == set &&
      other.number == number &&
      other.total == total &&
      other.star == star;

  @override
  int get hashCode => Object.hash(set, number, total, star);

  @override
  String toString() => 'CollectorCode($label)';
}

/// Entrée de l'index de scan (`GET /api/cards/hashes`) : l'identifiant de la
/// carte et son `riftbound_id`, seuls champs nécessaires à la lecture du code.
class ScanIndexEntry {
  const ScanIndexEntry({required this.id, required this.rid});

  final String id;
  final String rid;
}

/// Totaux d'impression présents dans l'index (219 pour UNL, 298 pour OGN…).
///
/// Ce filtre est ce qui rend l'OCR utilisable : un total inventé par la
/// reconnaissance (« 279 », « 2I9 » relu 219…) est rejeté au lieu de désigner
/// une carte au hasard.
Set<int> collectorTotals(Iterable<ScanIndexEntry> entries) {
  final totals = <int>{};
  for (final entry in entries) {
    final parsed = parseRiftboundId(entry.rid);
    if (parsed != null) totals.add(parsed.total);
  }
  return totals;
}

/// Groupe de chiffres du texte nettoyé, avec ses positions.
class _DigitRun {
  const _DigitRun(this.text, this.start, this.end);

  final String text;
  final int start;
  final int end;
}

final RegExp _noisePattern = RegExp(r'[^A-Z0-9/*]+');
final RegExp _setPattern = RegExp(r'(?:^|[^A-Z])([A-Z]{3})(?![A-Z])');
final RegExp _digitsPattern = RegExp(r'\d+');
final RegExp _hasDigit = RegExp(r'\d');

List<_DigitRun> _digitRuns(String text) => _digitsPattern
    .allMatches(text)
    .map((match) => _DigitRun(match.group(0)!, match.start, match.end))
    .toList();

/// Corrige les confusions de forme dans les blocs numériques : « 2I9 » → 219,
/// « OO2 » → 002. La substitution est limitée aux jetons contenant déjà un
/// chiffre, sinon elle abîmerait le set (« OGN » deviendrait « 0GN »).
///
/// O → 0 et I → 1 conservent la longueur du texte : les positions des groupes
/// de chiffres restent valables pour la détection de l'étoile.
String _normalizeDigits(String cleaned) {
  final tokens = cleaned.split(' ');
  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];
    if (!_hasDigit.hasMatch(token)) continue;
    tokens[i] = token.replaceAll('O', '0').replaceAll('I', '1');
  }
  return tokens.join(' ');
}

/// Texte brut de l'OCR → code lu, ou null si rien de crédible.
///
/// On ne cherche pas à valider la forme « SET • N/T » : l'OCR perd le point
/// médian, colle ou double les espaces et confond « / » avec « 1 » ou « 7 ». On
/// extrait donc tous les groupes de chiffres et on ne retient qu'un couple
/// (numéro, total) dont le TOTAL existe vraiment dans l'index et dont le numéro
/// est plausible.
CollectorCode? parseCollectorCode(String? text, Set<int> knownTotals) {
  if (knownTotals.isEmpty) return null;
  final cleaned = _normalizeDigits(
    (text ?? '').toUpperCase().replaceAll(_noisePattern, ' '),
  );
  final set = _setPattern.firstMatch(cleaned)?.group(1);
  final runs = _digitRuns(cleaned);

  CollectorCode? accept(int number, int total, bool star) =>
      knownTotals.contains(total) &&
          number >= 1 &&
          number <= total + kOvernumberMargin
      ? CollectorCode(set: set, number: number, total: total, star: star)
      : null;

  // Cas normal : deux groupes distincts. Parcours à l'envers, le code est en
  // fin de ligne (un parasite lu au début ne doit pas primer).
  for (var i = runs.length - 2; i >= 0; i--) {
    final between = cleaned.substring(runs[i].end, runs[i + 1].start);
    final hit = accept(
      int.parse(runs[i].text),
      int.parse(runs[i + 1].text),
      between.contains('*'),
    );
    if (hit != null) return hit;
  }

  // Repli : le séparateur a disparu et les deux nombres sont collés
  // (« 229219 ») — les totaux connus donnent le point de coupure. L'étoile est
  // alors indétectable.
  for (var i = runs.length - 1; i >= 0; i--) {
    final digits = runs[i].text;
    for (var cut = 1; cut < digits.length; cut++) {
      final hit = accept(
        int.parse(digits.substring(0, cut)),
        int.parse(digits.substring(cut)),
        false,
      );
      if (hit != null) return hit;
    }
  }
  return null;
}

/// Même parsing, mais ligne par ligne, jamais sur le texte complet.
///
/// ML Kit rend tout le texte de la carte (nom, règles, puissance), là où le web
/// ne lui donnait qu'une bande recadrée. Recoller les lignes fabriquerait des
/// couples qui n'existent pas : « Inflige 3 dégâts » suivi de « Puissance 298 »
/// se lirait « 3/298 ». Chaque ligne est donc jugée seule, dans l'ordre reçu —
/// l'appelant les trie du bas de l'image vers le haut, là où le code est imprimé.
CollectorCode? parseCollectorCodeFromLines(
  List<String> lines,
  Set<int> knownTotals,
) {
  for (final line in lines) {
    final code = parseCollectorCode(line, knownTotals);
    if (code != null) return code;
  }
  return null;
}

/// Cartes de l'index compatibles avec un code lu.
///
/// L'étoile imprimée fait quelques pixels sur la photo : la lire est un coup de
/// dé. Toutes les variantes du même numéro sont donc retournées ensemble, la
/// variante dont l'étoile correspond passant devant (préférence, jamais filtre).
List<ScanIndexEntry> matchByCode(
  CollectorCode? code,
  Iterable<ScanIndexEntry> entries,
) {
  if (code == null) return const [];

  List<ScanIndexEntry> collect({required bool useSet}) {
    final found = <ScanIndexEntry>[];
    for (final entry in entries) {
      final parsed = parseRiftboundId(entry.rid);
      if (parsed == null) continue;
      if (parsed.number != code.number || parsed.total != code.total) continue;
      if (useSet && parsed.set != code.set) continue;
      found.add(entry);
    }
    return found;
  }

  // Le set filtre les collisions entre extensions ; s'il a été mal lu, on
  // retombe sur le numéro seul plutôt que de perdre une lecture valide.
  var items = code.set == null ? <ScanIndexEntry>[] : collect(useSet: true);
  if (items.isEmpty) items = collect(useSet: false);

  // Tri stable : les variantes dont l'étoile correspond d'abord.
  final ranked = List.generate(
    items.length,
    (rank) => (entry: items[rank], rank: rank),
  );
  ranked.sort((a, b) {
    final aStar = parseRiftboundId(a.entry.rid)?.star == code.star;
    final bStar = parseRiftboundId(b.entry.rid)?.star == code.star;
    if (aStar == bStar) return a.rank.compareTo(b.rank);
    return aStar ? -1 : 1;
  });
  return [for (final item in ranked) item.entry];
}

/// Verrouillage d'une lecture : une carte n'est reconnue que lorsque la même
/// lecture revient plusieurs fois.
///
/// Deux critères, l'un ou l'autre suffit :
/// - [streak] lectures identiques d'affilée (la carte est tenue stable) ;
/// - [majority] lectures identiques parmi les [window] dernières (la carte
///   bouge un peu, une lecture sur deux part sur une voisine).
///
/// Après verrouillage, la même carte est ignorée pendant [cooldown] : posée sur
/// la table elle reste dans le champ et serait reconnue — et réajoutée — à
/// chaque tour de boucle.
class ScanStabilizer {
  ScanStabilizer({
    this.streak = 3,
    this.window = 6,
    this.majority = 4,
    this.cooldown = const Duration(seconds: 4),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final int streak;
  final int window;
  final int majority;
  final Duration cooldown;
  final DateTime Function() _clock;

  final List<String> _recent = [];
  final Map<String, DateTime> _lockedAt = {};

  /// Lectures accumulées depuis le dernier verrouillage (0 = rien en cours).
  int get pending => _recent.length;

  /// Soumet une lecture. Renvoie [key] quand elle est confirmée, null sinon.
  String? offer(String key) {
    final now = _clock();
    _lockedAt.removeWhere((_, at) => now.difference(at) >= cooldown);
    if (_lockedAt.containsKey(key)) {
      // Carte encore sous l'objectif juste après son ajout : on repart de zéro
      // pour qu'elle doive être reconfirmée une fois le délai passé.
      _recent.clear();
      return null;
    }

    _recent.add(key);
    if (_recent.length > window) _recent.removeAt(0);

    var trailing = 0;
    for (var i = _recent.length - 1; i >= 0 && _recent[i] == key; i--) {
      trailing++;
    }
    final occurrences = _recent.where((entry) => entry == key).length;
    if (trailing < streak && occurrences < majority) return null;

    _lockedAt[key] = now;
    _recent.clear();
    return key;
  }

  /// Oublie les lectures en cours sans lever les délais d'anti-doublon.
  void clearPending() => _recent.clear();

  /// Remise à zéro complète (nouvelle session de scan).
  void reset() {
    _recent.clear();
    _lockedAt.clear();
  }
}
