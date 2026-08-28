import '../../cards/domain/card.dart';

/// `RiftCard` sait se lire (`fromJson`) mais pas s'écrire : le compteur encode
/// lui-même les champs dont il a besoin, avec les noms de `card_out`, pour que
/// la relecture repasse par `RiftCard.fromJson` sans conversion.
Map<String, dynamic> cardToJson(RiftCard card) => {
  'id': card.id,
  'riftbound_id': card.riftboundId,
  'name': card.name,
  'set_id': card.setId,
  'type': card.type,
  'rarity': card.rarity,
  'domains': card.domains,
  'tags': card.tags,
  'collector_number': card.collectorNumber,
  'supertype': card.supertype,
  'energy': card.energy,
  'might': card.might,
  'power': card.power,
  'text': card.text,
  'flavour': card.flavour,
  'image_url': card.imageUrl,
  'artist': card.artist,
  'orientation': card.orientation,
  'alternate_art': card.alternateArt,
  'signature': card.signature,
  'overnumbered': card.overnumbered,
  'foil': card.foil,
};

/// Relecture d'une carte encodée par [cardToJson] ; null si le JSON est
/// inexploitable (fichier tronqué, format d'une ancienne version).
RiftCard? cardFromJson(Object? json) {
  if (json is! Map) return null;
  final map = Map<String, dynamic>.from(json);
  if (map['id'] is! String) return null;
  try {
    return RiftCard.fromJson(map);
  } on Object {
    return null;
  }
}
