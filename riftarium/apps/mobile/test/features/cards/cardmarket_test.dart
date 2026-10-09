import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/cards/domain/cardmarket.dart';

RiftCard _card(
  String name, {
  bool alternateArt = false,
  bool overnumbered = false,
  bool signature = false,
}) => RiftCard(
  id: 'x',
  riftboundId: 'ogn-251-298',
  name: name,
  setId: 'OGN',
  type: 'Legend',
  rarity: 'Rare',
  domains: const [],
  tags: const [],
  alternateArt: alternateArt,
  overnumbered: overnumbered,
  signature: signature,
);

void main() {
  group('cardmarketSearch', () {
    test('garde le nom seul pour une impression normale', () {
      expect(cardmarketSearch(_card('Jinx - Rebel')), 'Jinx - Rebel');
    });

    test('cherche « showcase » pour un alt-art, un ON ou une signature', () {
      expect(
        cardmarketSearch(
          _card('Jinx - Loose Cannon (Overnumbered)', overnumbered: true),
        ),
        'Jinx - Loose Cannon showcase',
      );
      expect(
        cardmarketSearch(
          _card('Jinx - Loose Cannon (Signature)', signature: true),
        ),
        'Jinx - Loose Cannon showcase',
      );
      expect(
        cardmarketSearch(
          _card('Jinx - Rebel (Alternate Art)', alternateArt: true),
        ),
        'Jinx - Rebel showcase',
      );
    });

    test('l’URL encode la recherche', () {
      expect(
        cardmarketUri(_card('Vi & Jinx')).toString(),
        'https://www.cardmarket.com/fr/Riftbound/Products/Search'
        '?searchString=Vi%20%26%20Jinx',
      );
    });
  });
}
