import 'package:riftarium_mobile/features/cards/domain/card.dart';

/// Carte de test, telle que la renverrait `GET /api/cards/{id}`.
///
/// Pas d'`image_url` : les tests de widgets n'ont pas de réseau, `CardImage`
/// affiche alors son substitut.
Map<String, dynamic> scanCardJson({
  String id = 'OGN-209',
  String name = 'Jinx, la fauteuse de troubles',
  int collectorNumber = 209,
  double? priceEur = 12.34,
  int ownedQty = 1,
}) => {
  'id': id,
  'riftbound_id': 'ogn-$collectorNumber-298',
  'name': name,
  'set_id': 'OGN',
  'type': 'Unit',
  'rarity': 'Epic',
  'domains': <String>[],
  'tags': <String>[],
  'collector_number': collectorNumber,
  'image_url': null,
  'price_eur': priceEur,
  'owned_qty': ownedQty,
};

RiftCard scanCard({
  String id = 'OGN-209',
  String name = 'Jinx, la fauteuse de troubles',
  int collectorNumber = 209,
  double? priceEur = 12.34,
  int ownedQty = 1,
}) => RiftCard.fromJson(
  scanCardJson(
    id: id,
    name: name,
    collectorNumber: collectorNumber,
    priceEur: priceEur,
    ownedQty: ownedQty,
  ),
);
