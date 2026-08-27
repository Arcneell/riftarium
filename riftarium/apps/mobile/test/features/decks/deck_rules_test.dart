import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/decks/domain/deck.dart';
import 'package:riftarium_mobile/features/decks/domain/deck_rules.dart';

RiftCard card({
  required String id,
  String? name,
  String? riftboundId,
  String type = 'Unit',
  String? supertype,
  List<String> domains = const ['Fury'],
  List<String> tags = const [],
  int? energy,
  String text = '',
}) => RiftCard(
  id: id,
  riftboundId: riftboundId ?? id.toLowerCase(),
  name: name ?? id,
  setId: 'OGN',
  type: type,
  rarity: 'Rare',
  domains: domains,
  tags: tags,
  supertype: supertype,
  energy: energy,
  text: text,
);

DeckCard entry(RiftCard value, [int qty = 1]) =>
    DeckCard(card: value, qty: qty);

/// Deck de tournoi complet et légal, servant de base aux variations.
List<DeckCard> legalDeck() {
  final legend = card(
    id: 'legend',
    name: 'Ahri, Légende',
    type: 'Legend',
    tags: const ['Ahri'],
  );
  return [
    entry(legend),
    for (var i = 0; i < 3; i++)
      entry(card(id: 'bf$i', name: 'Champ $i', type: 'Battlefield')),
    entry(card(id: 'rune', name: 'Rune de fureur', type: 'Rune'), 12),
    entry(
      card(
        id: 'champ',
        name: 'Ahri, Unité',
        supertype: 'Champion',
        tags: const ['Ahri'],
      ),
      3,
    ),
    for (var i = 0; i < 13; i++) entry(card(id: 'u$i', name: 'Unité $i'), 3),
  ];
}

Map<String, bool> statusOf(List<DeckCard> cards) => {
  for (final check in validateDeck(cards)) check.rule: check.ok,
};

void main() {
  group('zones et familles', () {
    test('zoneOf range les cartes sans zone dédiée dans le deck principal', () {
      expect(zoneOf(card(id: 'a', type: 'Legend')), 'Legend');
      expect(zoneOf(card(id: 'b', type: 'Battlefield')), 'Battlefield');
      expect(zoneOf(card(id: 'c', type: 'Rune')), 'Rune');
      expect(zoneOf(card(id: 'd', type: 'Spell')), 'main');
      expect(zoneOf(card(id: 'e', type: 'Gear')), 'main');
    });

    test('copyFamily réunit reprints et variantes d’un même nom', () {
      final base = card(id: 'a', name: 'Charm', riftboundId: 'ogn-004-298');
      final alt = card(
        id: 'b',
        name: 'Charm (Alternate Art)',
        riftboundId: 'ogn-004a-298',
      );
      final other = card(id: 'c', name: 'Charme', riftboundId: 'ogn-005-298');
      expect(copyFamily(alt), copyFamily(base));
      expect(copyFamily(other), isNot(copyFamily(base)));
    });

    test('canonicalName ignore tirets, virgules et suffixes', () {
      expect(canonicalName('Ahri, Inquisitive'), 'ahri inquisitive');
      expect(canonicalName('Ahri-Inquisitive'), 'ahri inquisitive');
      expect(canonicalName('Charm (Signature)'), 'charm');
    });

    test('variantFamily neutralise le marqueur de variante', () {
      expect(variantFamily('ogn-037a-298'), 'ogn-037-298');
      expect(variantFamily('ogn-037*-298'), 'ogn-037-298');
      expect(variantFamily('ven-r04'), 'ven-r04');
    });

    test('groupDeck trie par énergie puis par nom', () {
      final cards = [
        entry(card(id: 'b', name: 'Bêta', energy: 3)),
        entry(card(id: 'a', name: 'Alpha', energy: 3)),
        entry(card(id: 'c', name: 'Gamma', energy: 1)),
      ];
      expect(groupDeck(cards)['main']!.map((e) => e.card.name).toList(), [
        'Gamma',
        'Alpha',
        'Bêta',
      ]);
    });

    test('championOf préfère la championne taguée par la légende', () {
      final cards = [
        entry(card(id: 'l', type: 'Legend', tags: const ['Ahri'])),
        entry(card(id: 'other', supertype: 'Champion', tags: const ['Jinx'])),
        entry(card(id: 'ahri', supertype: 'Champion', tags: const ['Ahri'])),
      ];
      expect(championOf(cards)?.card.id, 'ahri');
    });
  });

  group('ajout de cartes (éditeur)', () {
    test('exige la légende avant toute autre carte', () {
      final result = addCardToDeck(
        const [],
        card(id: 'u'),
        format: 'tournament',
      );
      expect(result.accepted, isFalse);
      expect(result.refusal, contains('légende'));
    });

    test('remplace la légende existante et le signale', () {
      final first = card(id: 'l1', name: 'Ahri', type: 'Legend');
      final second = card(id: 'l2', name: 'Jinx', type: 'Legend');
      final deck = addCardToDeck(const [], first, format: 'tournament').cards;
      final result = addCardToDeck(deck, second, format: 'tournament');
      expect(result.accepted, isTrue);
      expect(result.notice, contains('Jinx'));
      expect(result.cards.where((e) => e.card.type == 'Legend').length, 1);
    });

    test('refuse une carte hors des domaines de la légende', () {
      final deck = addCardToDeck(
        const [],
        card(id: 'l', type: 'Legend', domains: const ['Fury']),
        format: 'tournament',
      ).cards;
      final result = addCardToDeck(
        deck,
        card(id: 'u', name: 'Calme', domains: const ['Calm']),
        format: 'tournament',
      );
      expect(result.accepted, isFalse);
      expect(result.refusal, contains('hors des domaines'));
    });

    test('accepte les cartes neutres', () {
      final deck = addCardToDeck(
        const [],
        card(id: 'l', type: 'Legend', domains: const ['Fury']),
        format: 'tournament',
      ).cards;
      final result = addCardToDeck(
        deck,
        card(id: 'u', domains: const ['Colorless']),
        format: 'tournament',
      );
      expect(result.accepted, isTrue);
    });

    test('plafonne le deck principal à 3 exemplaires, variantes comprises', () {
      var cards = addCardToDeck(
        const [],
        card(id: 'l', type: 'Legend'),
        format: 'tournament',
      ).cards;
      final unit = card(id: 'u', name: 'Charm', riftboundId: 'ogn-004-298');
      for (var i = 0; i < 3; i++) {
        cards = addCardToDeck(cards, unit, format: 'tournament').cards;
      }
      final refused = addCardToDeck(cards, unit, format: 'tournament');
      expect(refused.refusal, 'Maximum 3 exemplaires de Charm.');

      final variant = card(
        id: 'u-alt',
        name: 'Charm (Alternate Art)',
        riftboundId: 'ogn-004a-298',
      );
      expect(
        addCardToDeck(cards, variant, format: 'tournament').accepted,
        isFalse,
      );
    });

    test('limite les champs de bataille à trois, distincts', () {
      var cards = addCardToDeck(
        const [],
        card(id: 'l', type: 'Legend'),
        format: 'tournament',
      ).cards;
      for (var i = 0; i < 3; i++) {
        cards = addCardToDeck(
          cards,
          card(id: 'bf$i', type: 'Battlefield'),
          format: 'tournament',
        ).cards;
      }
      expect(
        addCardToDeck(
          cards,
          card(id: 'bf3', type: 'Battlefield'),
          format: 'tournament',
        ).refusal,
        '3 champs de bataille maximum.',
      );
      // Un exemplaire supplémentaire d'un champ déjà présent reste refusé.
      expect(
        addCardToDeck(
          cards,
          card(id: 'bf0', type: 'Battlefield'),
          format: 'tournament',
        ).accepted,
        isFalse,
      );
    });

    test('le format libre ignore la légende et plafonne à 12', () {
      var cards = const <DeckCard>[];
      final unit = card(id: 'u', name: 'Sans loi');
      for (var i = 0; i < 12; i++) {
        final result = addCardToDeck(cards, unit, format: 'free');
        expect(result.accepted, isTrue);
        cards = result.cards;
      }
      expect(
        addCardToDeck(cards, unit, format: 'free').refusal,
        contains('12'),
      );
    });

    test('retirer un exemplaire fait disparaître la ligne à zéro', () {
      final cards = [entry(card(id: 'u'), 2)];
      final once = removeCardFromDeck(cards, 'u');
      expect(once.single.qty, 1);
      expect(removeCardFromDeck(once, 'u'), isEmpty);
      expect(removeCardFromDeck(once, 'absent'), once);
    });
  });

  group('validation de tournoi', () {
    test('un deck complet passe tous les contrôles', () {
      final checks = validateDeck(legalDeck());
      expect(checks.every((check) => check.ok), isTrue, reason: '$checks');
      expect(
        checks.map((check) => check.rule),
        containsAll(<String>[
          'legend',
          'battlefields',
          'runes',
          'main_size',
          'copies',
          'unique',
          'domains',
          'champion',
        ]),
      );
    });

    test('signale une légende manquante et des domaines invérifiables', () {
      final cards = legalDeck()
          .where((entry) => entry.card.type != 'Legend')
          .toList();
      final status = statusOf(cards);
      expect(status['legend'], isFalse);
      expect(status['domains'], isFalse);
      expect(
        validateDeck(
          cards,
        ).firstWhere((check) => check.rule == 'domains').message,
        'Domaines non vérifiables sans légende unique',
      );
    });

    test('compte les runes et les champs de bataille', () {
      final cards = legalDeck()
          .where((entry) => entry.card.type != 'Rune')
          .toList();
      final status = statusOf(cards);
      expect(status['runes'], isFalse);
      expect(
        validateDeck(
          cards,
        ).firstWhere((check) => check.rule == 'runes').message,
        '12 runes (0 actuellement)',
      );
    });

    test('refuse plus de 3 exemplaires, variantes comprises', () {
      final cards = [
        ...legalDeck(),
        entry(
          card(
            id: 'u0-alt',
            name: 'Unité 0 (Alternate Art)',
            riftboundId: 'ogn-100a-298',
          ),
        ),
      ];
      final check = validateDeck(
        cards,
      ).firstWhere((item) => item.rule == 'copies');
      expect(check.ok, isFalse);
      expect(check.message, contains('Unité 0'));
    });

    test('refuse deux exemplaires d’une carte [Unique]', () {
      final cards = [
        ...legalDeck(),
        entry(card(id: 'uni', name: 'Relique', text: 'Objet [Unique] rare'), 2),
      ];
      final check = validateDeck(
        cards,
      ).firstWhere((item) => item.rule == 'unique');
      expect(check.ok, isFalse);
      expect(check.message, contains('Relique'));
    });

    test('refuse une carte hors des domaines de la légende', () {
      final cards = [
        ...legalDeck(),
        entry(card(id: 'off', name: 'Intruse', domains: const ['Calm'])),
      ];
      final check = validateDeck(
        cards,
      ).firstWhere((item) => item.rule == 'domains');
      expect(check.ok, isFalse);
      expect(check.message, contains('Intruse'));
    });

    test('exige le champion élu quand la légende porte un tag', () {
      final cards = legalDeck()
          .where((entry) => entry.card.id != 'champ')
          .toList();
      final check = validateDeck(
        cards,
      ).firstWhere((item) => item.rule == 'champion');
      expect(check.ok, isFalse);
      expect(check.message, contains('Ahri'));
    });

    test('compte 40 cartes minimum dans le deck principal', () {
      final cards = [
        entry(card(id: 'l', type: 'Legend')),
        entry(card(id: 'u'), 3),
      ];
      final check = validateDeck(
        cards,
      ).firstWhere((item) => item.rule == 'main_size');
      expect(check.ok, isFalse);
      expect(check.message, contains('3 actuellement'));
    });
  });
}
