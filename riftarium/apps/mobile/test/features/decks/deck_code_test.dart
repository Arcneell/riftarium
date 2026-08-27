import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/decks/domain/deck.dart';
import 'package:riftarium_mobile/features/decks/domain/deck_code.dart';
import 'package:riftarium_mobile/features/decks/domain/deck_share.dart';

/// Un jeu d'essai croisé : le code attendu vient de la bibliothèque
/// JavaScript `@piltoverarchive/riftbound-deck-codes` 1.4.0, celle qu'utilise
/// le site (`apps/web/src/deckExport.js`). Si l'encodeur Dart produit la même
/// chaîne, les deux implémentations sont d'accord octet pour octet.
class CodeCase {
  const CodeCase(
    this.label,
    this.main,
    this.code, {
    this.sideboard = const [],
    this.champion,
  });

  final String label;
  final List<DeckCodeCard> main;
  final List<DeckCodeCard> sideboard;
  final String? champion;
  final String code;
}

List<DeckCodeCard> deck(Map<String, int> entries) => entries.entries
    .map((entry) => DeckCodeCard(entry.key, entry.value))
    .toList();

/// Codes triés pour comparer deux listes sans dépendre de l'ordre.
List<String> normalize(List<DeckCodeCard> cards) =>
    (cards.map((card) => '${card.cardCode}=${card.count}').toList())..sort();

final cases = <CodeCase>[
  CodeCase(
    'deck d’exemple du site',
    deck({
      'OGN-247': 1,
      'OGN-119': 1,
      'OGN-275': 1,
      'OGN-007': 6,
      'OGN-009': 6,
      'OGN-004': 3,
    }),
    'CMAAAAAAAAAACAQAAADQSAAAAEAQAAAEAAAQGAAAO73QDEYCAAAAAAIAAB3Q',
    champion: 'OGN-119',
  ),
  CodeCase(
    'sans champion élu',
    deck({'OGN-247': 1, 'OGN-004': 3}),
    'CMAAAAAAAAAAAAAAAEAQAAAEAAAQCAAA64AQAAAAAA',
  ),
  CodeCase(
    'une seule carte',
    deck({'OGN-001': 1}),
    'CMAAAAAAAAAAAAAAAAAACAIAAAAQAAAAAA',
  ),
  CodeCase(
    'runes (format 1.4)',
    deck({'VEN-R04': 12, 'OGN-119': 2}),
    'CQAQCBIAAECAAAAAAAAAAAAAAAAQCAAAAB3QAAAAAAAQAAAAO4',
    champion: 'OGN-119',
  ),
  CodeCase(
    'carte spéciale SP (format 1.5)',
    deck({'VEN-SP4': 1, 'OGN-010': 2}),
    'CUAQEAQBAEAAAAAKAEAQCBIAAICAAAA',
  ),
  CodeCase(
    'plus de 12 exemplaires (format 1.5)',
    deck({'OGN-030': 20, 'OGN-031': 1}),
    'CUAAEFABAEAAAHQBAEAQAAA7AAAA',
  ),
  CodeCase(
    'variantes a / s / b et deux sets',
    deck({'OGN-007a': 3, 'OGN-037s': 1, 'OGN-008b': 2, 'ARC-100': 2}),
    'CMAAAAAAAAAAAAAAAEAQAAIHAIAQAAYIAEBAAZABAEAAEJIAAAAACAACEU',
    champion: 'OGN-037s',
  ),
  CodeCase(
    'tous les sets',
    deck({
      'OGS-005': 1,
      'SFD-012': 1,
      'UNL-200': 1,
      'RAD-099': 1,
      'ARC-002': 1,
    }),
    'CMAAAAAAAAAAAAAAAAAAKAIBAACQCAQAAIAQGAAMAECABSABAEDAAYYAAAAAA',
  ),
  CodeCase(
    'avec réserve',
    deck({'OGN-001': 2}),
    'CMAAAAAAAAAAAAAAAAAQCAAAAEAAAAIBAAABMAIBAAAFQAIAAAAQ',
    sideboard: [DeckCodeCard('OGN-022', 2), DeckCodeCard('OGN-088', 1)],
    champion: 'OGN-001',
  ),
  CodeCase(
    'champion rune',
    deck({'OGN-005': 1, 'OGN-R07': 4}),
    'CQAAAAAAAAAAAAABAEAAAAIHAAAACAIAAAAAKAAAAAAQAAABA4',
    champion: 'OGN-R07',
  ),
  CodeCase(
    'champion spécial signé',
    deck({'VEN-SP1a': 1}),
    'CUAQCAIBAECQCAQBAAAQKAICAE',
    champion: 'VEN-SP1a',
  ),
  CodeCase(
    'préfixes mélangés dans un même groupe',
    deck({'OGN-007': 2, 'OGN-R07': 2, 'OGN-100': 2, 'OGN-R02': 2}),
    'CQAAAAAAAAAAAAAAAAAQIAAAAADQAZABAIAQOAAAAAAAA',
  ),
  CodeCase(
    'numéros normaux, runes et spéciaux mêlés',
    deck({'VEN-SP4': 1, 'VEN-010': 1, 'VEN-R01': 1, 'VEN-SP12': 1}),
    'CUAQCAIBAQCQAAAKAEAQEBACBQAAA',
  ),
];

void main() {
  group('toCardCode', () {
    test('passe les identifiants Riftarium en codes de cartes', () {
      expect(toCardCode('ogn-247-298'), 'OGN-247');
      expect(toCardCode('ogn-007a-298'), 'OGN-007a');
      expect(toCardCode('ogn-037*-298'), 'OGN-037s');
      expect(toCardCode('ven-r04'), 'VEN-R04');
      expect(toCardCode('ven-r4'), 'VEN-R04');
      expect(toCardCode('ven-sp4-006'), 'VEN-SP4');
      expect(toCardCode(''), '');
      expect(toCardCode(null), '');
      expect(toCardCode('promo-quelconque'), 'PROMO-QUELCONQUE');
    });

    test('la requête de recherche retire le suffixe de variante', () {
      expect(cardCodeQuery('OGN-037s'), 'ogn-037');
      expect(cardCodeQuery('OGN-247'), 'ogn-247');
      expect(cardCodeQuery('VEN-R04'), 'ven-r04');
      expect(cardCodeQuery('VEN-SP4'), 'ven-sp4');
    });
  });

  group('codes croisés avec la bibliothèque du site', () {
    for (final item in cases) {
      test('encode « ${item.label} » exactement comme le site', () {
        expect(
          encodeDeckCode(
            item.main,
            sideboard: item.sideboard,
            chosenChampion: item.champion,
          ),
          item.code,
        );
      });

      test('décode « ${item.label} » vers le deck d’origine', () {
        final decoded = decodeDeckCode(item.code);
        expect(normalize(decoded.mainDeck), normalize(item.main));
        expect(normalize(decoded.sideboard), normalize(item.sideboard));
        expect(decoded.chosenChampion, item.champion);
      });
    }

    test('le décodage est l’inverse de l’encodage', () {
      for (final item in cases) {
        final decoded = decodeDeckCode(item.code);
        expect(
          encodeDeckCode(
            decoded.mainDeck,
            sideboard: decoded.sideboard,
            chosenChampion: decoded.chosenChampion,
          ),
          item.code,
          reason: item.label,
        );
      }
    });

    test('lit un code de format 1.2 (README de la bibliothèque)', () {
      const readme =
          'CIAAAAAAAAAQCAAAA4AACAIAABMQAAILAAAAICIMDMOVOX3AM5UHIAIDAAAC'
          'O6XYAEAQKAAABX3QDGACUABKIAQAAEBQAAAWDBOQCAQAABMHE';
      final decoded = decodeDeckCode(readme);
      expect(decoded.mainDeck.length, 21);
      expect(decoded.chosenChampion, isNull);
      expect(decoded.mainDeck, contains(const DeckCodeCard('OGN-007', 7)));
      expect(normalize(decoded.sideboard), [
        'OGN-022=2',
        'OGN-024=2',
        'OGN-088=1',
        'OGN-093=2',
        'OGN-114=1',
      ]);
    });

    test('accepte une autre écriture des signatures', () {
      final decoded = decodeDeckCode(cases[6].code, signedSuffix: '*');
      expect(
        decoded.mainDeck.map((card) => card.cardCode),
        contains('OGN-037*'),
      );
      expect(decoded.chosenChampion, 'OGN-037*');
    });
  });

  group('cas d’erreur', () {
    test('refuse un code vide', () {
      expect(() => decodeDeckCode('   '), throwsA(isA<DeckCodeException>()));
    });

    test('refuse un caractère hors base32', () {
      expect(
        () => decodeDeckCode('CMAA0AAA'),
        throwsA(isA<DeckCodeException>()),
      );
    });

    test('refuse un code tronqué', () {
      expect(() => decodeDeckCode('CMAA'), throwsA(isA<DeckCodeException>()));
    });

    test('refuse un format inconnu', () {
      // Premier octet 0x23 : format 2, version 3.
      expect(
        () => decodeDeckCode('EMAAAAAAAAAAAAAAAAAACAIAAAAQAAAAAA'),
        throwsA(isA<DeckCodeException>()),
      );
    });

    test('refuse une quantité nulle ou négative', () {
      expect(
        () => encodeDeckCode([const DeckCodeCard('OGN-001', 0)]),
        throwsA(isA<DeckCodeException>()),
      );
    });

    test('refuse un set inconnu', () {
      expect(
        () => encodeDeckCode([const DeckCodeCard('ZZZ-001', 1)]),
        throwsA(isA<DeckCodeException>()),
      );
    });

    test('refuse un code de carte malformé', () {
      expect(
        () => encodeDeckCode([const DeckCodeCard('OGN', 1)]),
        throwsA(isA<DeckCodeException>()),
      );
    });
  });

  group('code d’un deck Riftarium', () {
    RiftCard card({
      required String riftboundId,
      required String name,
      String type = 'Unit',
      String? supertype,
      List<String> tags = const [],
    }) => RiftCard(
      id: riftboundId,
      riftboundId: riftboundId,
      name: name,
      setId: 'OGN',
      type: type,
      rarity: 'Rare',
      domains: const ['Fury'],
      tags: tags,
      supertype: supertype,
    );

    final sample = <DeckCard>[
      DeckCard(
        card: card(
          riftboundId: 'ogn-247-298',
          name: 'Daughter of the Void',
          type: 'Legend',
          tags: const ['Ahri'],
        ),
        qty: 1,
      ),
      DeckCard(
        card: card(
          riftboundId: 'ogn-119-298',
          name: 'Ahri, Inquisitive',
          supertype: 'Champion',
          tags: const ['Ahri'],
        ),
        qty: 1,
      ),
      DeckCard(
        card: card(
          riftboundId: 'ogn-275-298',
          name: 'Altar to Unity',
          type: 'Battlefield',
        ),
        qty: 1,
      ),
      DeckCard(
        card: card(riftboundId: 'ogn-007-298', name: 'Fury Rune', type: 'Rune'),
        qty: 6,
      ),
      DeckCard(
        card: card(riftboundId: 'ogn-009-298', name: 'Mind Rune', type: 'Rune'),
        qty: 6,
      ),
      DeckCard(
        card: card(riftboundId: 'ogn-004-298', name: 'Charm'),
        qty: 3,
      ),
    ];

    test('reprend le code du deck d’exemple du site', () {
      expect(deckCodeOf(sample), cases.first.code);
    });

    test('cumule les quantités par code de carte', () {
      expect(normalize(encoderCards(sample)), normalize(cases.first.main));
    });

    test('refuse un deck vide', () {
      expect(() => deckCodeOf(const []), throwsA(isA<DeckCodeException>()));
    });

    test('liste texte : toutes les zones, tous les exemplaires', () {
      final text = nameList(sample);
      expect(text, contains('1x Daughter of the Void'));
      expect(text, contains('6x Fury Rune'));
      expect(text, contains('3x Charm'));
    });
  });
}
