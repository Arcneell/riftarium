import '../../cards/domain/card.dart';
import 'deck.dart';

/// Règles de construction d'un deck Riftbound.
///
/// Portage Dart de `apps/api/app/validation.py` (contrôles renvoyés par l'API
/// dans `deck.checks`) et de `apps/web/src/composables/useDeckRules.js`
/// (plafonds appliqués en direct dans l'éditeur). L'écran de détail affiche
/// les contrôles de l'API ; l'éditeur utilise ceux-ci tant que rien n'est
/// enregistré.

/// Une zone du deck : légende, champs de bataille, runes, deck principal.
class DeckZone {
  const DeckZone(this.key, this.label, this.target);

  final String key;
  final String label;

  /// Nombre de cartes attendu pour un deck légal (minimum pour `main`).
  final int target;
}

const List<DeckZone> deckZones = [
  DeckZone('Legend', 'Légende', 1),
  DeckZone('Battlefield', 'Champs de bataille', 3),
  DeckZone('Rune', 'Runes', 12),
  DeckZone('main', 'Deck principal', 40),
];

/// Plafond d'exemplaires par carte dans un deck de tournoi.
const Map<String, int> tournamentCaps = {
  'Legend': 1,
  'Battlefield': 1,
  'Rune': 12,
  'main': 3,
};

/// Plafond du format libre (limite du schéma d'encodage historique).
const int freeCap = 12;

const Set<String> _namedZones = {'Legend', 'Battlefield', 'Rune'};

/// Zone d'une carte : son type s'il a une zone dédiée, sinon `main`.
String zoneOf(RiftCard card) =>
    _namedZones.contains(card.type) ? card.type : 'main';

final RegExp _variantId = RegExp(
  r'^([a-z0-9]+)-(\d+)([a-z*]?)-(\d+)$',
  caseSensitive: false,
);
final RegExp _variantSuffix = RegExp(
  r'\s*\((?:alternate art|overnumbered|signature|starter|promo)\)\s*$',
  caseSensitive: false,
);
final RegExp _nameSeparators = RegExp(r'[\s,–—-]+');

/// Famille d'un identifiant : `ogn-037a-298` et `ogn-037*-298` → `ogn-037-298`.
String variantFamily(String? riftboundId) {
  final ident = (riftboundId ?? '').trim().toLowerCase();
  final match = _variantId.firstMatch(ident);
  if (match == null) return ident;
  return '${match.group(1)}-${match.group(2)}-${match.group(4)}';
}

/// Nom de jeu : sans suffixe de variante, tirets et virgules équivalents.
String canonicalName(String? name) {
  final text = (name ?? '').trim().replaceAll(_variantSuffix, '');
  return text.replaceAll(_nameSeparators, ' ').trim().toLowerCase();
}

/// Clé de la règle des 3 exemplaires : reprints et variantes d'un même nom.
String copyFamily(RiftCard card) {
  final name = canonicalName(card.name);
  if (name.isNotEmpty) return '${card.type}:$name';
  final family = variantFamily(card.riftboundId);
  return family.isNotEmpty ? family : card.id;
}

/// Cartes réparties par zone, triées par énergie puis par nom (comme le site).
Map<String, List<DeckCard>> groupDeck(List<DeckCard> cards) {
  final groups = <String, List<DeckCard>>{
    'Legend': [],
    'Battlefield': [],
    'Rune': [],
    'main': [],
  };
  for (final entry in cards) {
    groups[zoneOf(entry.card)]!.add(entry);
  }
  for (final zone in groups.values) {
    zone.sort((a, b) {
      final energyA = a.card.energy ?? -1;
      final energyB = b.card.energy ?? -1;
      if (energyA != energyB) return energyA - energyB;
      return a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase());
    });
  }
  return groups;
}

/// Nombre de cartes d'une zone.
int zoneCount(Map<String, List<DeckCard>> groups, String key) =>
    groups[key]!.fold<int>(0, (total, entry) => total + entry.qty);

/// Légende du deck, si elle a déjà été choisie.
RiftCard? legendOf(List<DeckCard> cards) {
  for (final entry in cards) {
    if (entry.card.type == 'Legend') return entry.card;
  }
  return null;
}

/// Champion élu : l'unité championne partageant un tag avec la légende, sinon
/// la première championne, sinon la première unité taguée. Même choix que
/// `championOf` du site (le code de deck le transporte).
DeckCard? championOf(List<DeckCard> cards) {
  final tags = legendOf(cards)?.tags.toSet() ?? <String>{};
  final units = cards.where((entry) => entry.card.type == 'Unit').toList();
  bool tagged(DeckCard entry) => entry.card.tags.any(tags.contains);

  for (final entry in units) {
    if (entry.card.supertype == 'Champion' && tagged(entry)) return entry;
  }
  for (final entry in units) {
    if (entry.card.supertype == 'Champion') return entry;
  }
  for (final entry in units) {
    if (tagged(entry)) return entry;
  }
  return null;
}

/// Quantité déjà présente pour la famille d'une carte (variantes comprises).
int inDeckQty(List<DeckCard> cards, RiftCard card) {
  final family = copyFamily(card);
  var total = 0;
  for (final entry in cards) {
    if (copyFamily(entry.card) == family) total += entry.qty;
  }
  return total;
}

/// Domaines d'une carte, hors `Colorless`.
Set<String> coloredDomains(RiftCard card) =>
    card.domains.where((domain) => domain != 'Colorless').toSet();

/// Vrai si la carte sort de l'identité de domaines fixée par la légende.
/// Ne concerne ni la légende ni les champs de bataille (libres).
bool offDomain(List<DeckCard> cards, RiftCard card) {
  final legend = legendOf(cards);
  if (legend == null || card.type == 'Legend' || card.type == 'Battlefield') {
    return false;
  }
  final allowed = coloredDomains(legend);
  return coloredDomains(card).any((domain) => !allowed.contains(domain));
}

/// Résultat d'un ajout ou d'un retrait dans l'éditeur.
class DeckMutation {
  const DeckMutation(this.cards, {this.refusal, this.notice});

  /// Nouvelle liste de cartes (inchangée si `refusal` est renseigné).
  final List<DeckCard> cards;

  /// Ajout refusé : message à afficher.
  final String? refusal;

  /// Information sans refus (légende remplacée).
  final String? notice;

  bool get accepted => refusal == null;
}

/// Ajoute un exemplaire d'une carte en appliquant les règles du format.
DeckMutation addCardToDeck(
  List<DeckCard> cards,
  RiftCard card, {
  required String format,
}) {
  var next = List<DeckCard>.from(cards);
  String? notice;

  if (format != 'free') {
    final zone = zoneOf(card);
    final legendEntry = _legendEntry(next);
    if (zone == 'Legend') {
      if (legendEntry != null && legendEntry.card.id == card.id) {
        return DeckMutation(
          cards,
          refusal: 'Cette légende est déjà dans le deck.',
        );
      }
      if (legendEntry != null) {
        next.remove(legendEntry);
        notice = 'Légende remplacée par ${card.name}.';
      }
    } else if (legendEntry == null) {
      return DeckMutation(
        cards,
        refusal: 'Choisis d’abord ta légende : elle fixe les domaines du deck.',
      );
    }
    if (offDomain(next, card)) {
      return DeckMutation(
        cards,
        refusal: '${card.name} est hors des domaines de ta légende.',
      );
    }
    if (zone == 'Battlefield' &&
        zoneCount(groupDeck(next), 'Battlefield') >= 3 &&
        inDeckQty(next, card) == 0) {
      return DeckMutation(cards, refusal: '3 champs de bataille maximum.');
    }
    final cap = tournamentCaps[zone]!;
    if (zone != 'Legend' && inDeckQty(next, card) >= cap) {
      return DeckMutation(
        cards,
        refusal: zone == 'main'
            ? 'Maximum 3 exemplaires de ${card.name}.'
            : 'Maximum $cap exemplaire(s) de ${card.name}.',
      );
    }
  } else if (inDeckQty(next, card) >= freeCap) {
    return DeckMutation(cards, refusal: '$freeCap exemplaires maximum.');
  }

  final index = next.indexWhere((entry) => entry.card.id == card.id);
  if (index >= 0) {
    next[index] = next[index].copyWith(qty: next[index].qty + 1);
  } else {
    next = [...next, DeckCard(card: card, qty: 1)];
  }
  return DeckMutation(next, notice: notice);
}

/// Retire un exemplaire d'une carte (la ligne disparaît à zéro).
List<DeckCard> removeCardFromDeck(List<DeckCard> cards, String cardId) {
  final next = List<DeckCard>.from(cards);
  final index = next.indexWhere((entry) => entry.card.id == cardId);
  if (index < 0) return cards;
  final qty = next[index].qty - 1;
  if (qty <= 0) {
    next.removeAt(index);
  } else {
    next[index] = next[index].copyWith(qty: qty);
  }
  return next;
}

/// Contrôles de construction, identiques à `validate_deck` côté API.
///
/// Utilisés dans l'éditeur avant l'enregistrement ; l'écran de détail affiche
/// ceux que l'API a calculés.
List<DeckCheck> validateDeck(List<DeckCard> entries) {
  List<DeckCard> ofType(String type) =>
      entries.where((entry) => entry.card.type == type).toList();
  int total(List<DeckCard> list) =>
      list.fold<int>(0, (sum, entry) => sum + entry.qty);

  final legends = ofType('Legend');
  final battlefields = ofType('Battlefield');
  final runes = ofType('Rune');
  final main = entries
      .where(
        (entry) => const {'Unit', 'Spell', 'Gear'}.contains(entry.card.type),
      )
      .toList();

  final checks = <DeckCheck>[];
  void add(String rule, bool ok, String message) =>
      checks.add(DeckCheck(rule: rule, ok: ok, message: message));

  final legendCount = total(legends);
  add(
    'legend',
    legendCount == 1,
    'Exactement 1 légende ($legendCount actuellement)',
  );

  final battlefieldCount = total(battlefields);
  final distinct =
      battlefields.map((entry) => entry.card.id).toSet().length ==
      battlefields.length;
  add(
    'battlefields',
    battlefieldCount == 3 &&
        battlefields.every((entry) => entry.qty == 1) &&
        distinct,
    '3 champs de bataille distincts ($battlefieldCount actuellement)',
  );

  final runeCount = total(runes);
  add('runes', runeCount == 12, '12 runes ($runeCount actuellement)');

  final mainCount = total(main);
  add(
    'main_size',
    mainCount >= 40,
    'Deck principal : 40 cartes minimum ($mainCount actuellement)',
  );

  // Règle 103.2.b : 3 exemplaires max par carte, reprints et variantes compris.
  final over = _familiesOver(main, 3);
  add(
    'copies',
    over.isEmpty,
    over.isEmpty
        ? 'Maximum 3 exemplaires par carte'
        : 'Plus de 3 exemplaires : ${over.take(5).join(', ')}',
  );

  // Mot-clé [Unique] : un seul exemplaire dans tout le deck (règle 800).
  final uniques = entries
      .where((entry) => entry.card.text.toLowerCase().contains('[unique]'))
      .toList();
  final uniqueOver = _familiesOver(uniques, 1);
  add(
    'unique',
    uniqueOver.isEmpty,
    uniqueOver.isEmpty
        ? 'Cartes [Unique] en un seul exemplaire'
        : '[Unique] en plusieurs exemplaires : ${uniqueOver.take(5).join(', ')}',
  );

  if (legendCount == 1) {
    final legend = legends.first.card;
    final allowed = coloredDomains(legend);
    final illegal = <String>{};
    for (final entry in [...main, ...runes]) {
      if (coloredDomains(entry.card).any((d) => !allowed.contains(d))) {
        illegal.add(entry.card.name);
      }
    }
    final sortedIllegal = illegal.toList()..sort();
    add(
      'domains',
      illegal.isEmpty,
      illegal.isEmpty
          ? 'Domaines conformes à la légende'
          : 'Hors domaines de la légende : ${sortedIllegal.take(5).join(', ')}',
    );

    // Règle 103.2.a.2 : le deck principal contient le champion élu.
    final legendTags = legend.tags.toSet();
    if (legendTags.isNotEmpty) {
      final hasChampion = main.any(
        (entry) => entry.card.tags.any(legendTags.contains),
      );
      final label = (legendTags.toList()..sort()).join(' / ');
      add(
        'champion',
        hasChampion,
        hasChampion
            ? 'Champion élu présent ($label)'
            : 'Aucune carte $label dans le deck principal (champion élu requis)',
      );
    }
  } else {
    add('domains', false, 'Domaines non vérifiables sans légende unique');
  }

  return checks;
}

/// Noms des familles dépassant `limit` exemplaires, triés.
List<String> _familiesOver(List<DeckCard> entries, int limit) {
  final totals = <String, int>{};
  final names = <String, String>{};
  for (final entry in entries) {
    final family = copyFamily(entry.card);
    totals[family] = (totals[family] ?? 0) + entry.qty;
    final current = names[family];
    // Nom de base plutôt que « (Alternate Art) » : le plus court gagne.
    if (current == null || entry.card.name.length < current.length) {
      names[family] = entry.card.name;
    }
  }
  final over = <String>{};
  totals.forEach((family, qty) {
    if (qty > limit) over.add(names[family] ?? family);
  });
  return over.toList()..sort();
}

/// Entrée de la légende présente dans la liste, s'il y en a une.
DeckCard? _legendEntry(List<DeckCard> cards) {
  for (final entry in cards) {
    if (entry.card.type == 'Legend') return entry;
  }
  return null;
}
