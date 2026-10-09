import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/cards/domain/card_labels.dart';

RiftCard _card(
  String id,
  String setId, {
  bool alternateArt = false,
  bool overnumbered = false,
}) => RiftCard(
  id: id,
  riftboundId: id,
  name: 'Fury Rune',
  setId: setId,
  type: 'Rune',
  rarity: 'Common',
  domains: const ['Fury'],
  tags: const [],
  alternateArt: alternateArt,
  overnumbered: overnumbered,
);

void main() {
  test('les libellés de variante suivent le site', () {
    expect(variantLabel(_card('a', 'OGN')), 'Normale');
    expect(variantLabel(_card('b', 'OGN', alternateArt: true)), 'Alt-art');
    expect(variantLabel(_card('c', 'OGN', overnumbered: true)), 'Overnumbered');
  });

  test('le set s’ajoute quand les variantes viennent de plusieurs sets', () {
    final runes = [
      _card('ogn', 'OGN'),
      _card('ven', 'VEN'),
      _card('alt', 'OGN', alternateArt: true),
    ];
    expect(runes.map((card) => variantChipLabel(card, runes)), [
      'Normale · OGN',
      'Normale · VEN',
      'Alt-art · OGN',
    ]);
  });

  test('un seul set : le libellé reste court', () {
    final legend = [
      _card('base', 'OGN'),
      _card('on', 'OGN', overnumbered: true),
    ];
    expect(legend.map((card) => variantChipLabel(card, legend)), [
      'Normale',
      'Overnumbered',
    ]);
  });
}
