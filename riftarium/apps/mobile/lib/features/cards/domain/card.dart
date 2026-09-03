import '../../../core/api_exception.dart';

/// Carte telle que renvoyée par `card_out` (`apps/api/app/routers/cards.py`).
///
/// `ownedQty` / `wishedQty` ne sont présents que pour un utilisateur connecté.
class RiftCard {
  const RiftCard({
    required this.id,
    required this.riftboundId,
    required this.name,
    required this.setId,
    required this.type,
    required this.rarity,
    required this.domains,
    required this.tags,
    this.collectorNumber,
    this.supertype,
    this.energy,
    this.might,
    this.power,
    this.text = '',
    this.flavour,
    this.imageUrl,
    this.artist,
    this.orientation,
    this.alternateArt = false,
    this.signature = false,
    this.overnumbered = false,
    this.foil = false,
    this.priceEur,
    this.priceFoilEur,
    this.ownedQty,
    this.wishedQty,
    this.variants = const [],
  });

  factory RiftCard.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      // Une carte sans identifiant n'est pas affichable (ni lien, ni
      // collection) : mieux vaut le dire que propager une coquille vide.
      throw const ApiException('Carte illisible : identifiant absent.');
    }
    return RiftCard(
      id: id,
      riftboundId: (json['riftbound_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      setId: (json['set_id'] as String?) ?? '',
      type: (json['type'] as String?) ?? '',
      rarity: (json['rarity'] as String?) ?? '',
      domains: _strings(json['domains']),
      tags: _strings(json['tags']),
      collectorNumber: (json['collector_number'] as num?)?.toInt(),
      supertype: json['supertype'] as String?,
      energy: (json['energy'] as num?)?.toInt(),
      might: (json['might'] as num?)?.toInt(),
      power: (json['power'] as num?)?.toInt(),
      text: (json['text'] as String?) ?? '',
      flavour: json['flavour'] as String?,
      imageUrl: json['image_url'] as String?,
      artist: json['artist'] as String?,
      orientation: json['orientation'] as String?,
      alternateArt: json['alternate_art'] == true,
      signature: json['signature'] == true,
      overnumbered: json['overnumbered'] == true,
      foil: json['foil'] == true,
      priceEur: (json['price_eur'] as num?)?.toDouble(),
      priceFoilEur: (json['price_foil_eur'] as num?)?.toDouble(),
      ownedQty: (json['owned_qty'] as num?)?.toInt(),
      wishedQty: (json['wished_qty'] as num?)?.toInt(),
      // Seul `GET /cards/{id}` renvoie la famille de variantes ; les items de
      // liste n'ont pas la clé, la récursion s'arrête donc au premier niveau.
      variants: (json['variants'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RiftCard.fromJson)
          .toList(),
    );
  }

  final String id;
  final String riftboundId;
  final String name;
  final String setId;
  final String type;
  final String rarity;
  final List<String> domains;
  final List<String> tags;
  final int? collectorNumber;
  final String? supertype;
  final int? energy;
  final int? might;
  final int? power;
  final String text;
  final String? flavour;
  final String? imageUrl;
  final String? artist;
  final String? orientation;
  final bool alternateArt;
  final bool signature;
  final bool overnumbered;
  final bool foil;
  final double? priceEur;

  /// Prix indicatif de l'impression foil, quand la source le distingue.
  final double? priceFoilEur;
  final int? ownedQty;
  final int? wishedQty;

  /// Autres impressions de la même carte (alt-art, signature, overnumbered),
  /// telles que renvoyées par la fiche. Vide ailleurs.
  final List<RiftCard> variants;

  bool get isLandscape => orientation == 'landscape';
  bool get isOwned => (ownedQty ?? 0) > 0;

  /// Code affiché sous la carte : `OGN 209` (set + numéro collector).
  String get displayCode {
    final number = collectorNumber;
    final set = setId.toUpperCase();
    return number == null ? set : '$set $number';
  }

  RiftCard copyWith({int? ownedQty, int? wishedQty}) => RiftCard(
    id: id,
    riftboundId: riftboundId,
    name: name,
    setId: setId,
    type: type,
    rarity: rarity,
    domains: domains,
    tags: tags,
    collectorNumber: collectorNumber,
    supertype: supertype,
    energy: energy,
    might: might,
    power: power,
    text: text,
    flavour: flavour,
    imageUrl: imageUrl,
    artist: artist,
    orientation: orientation,
    alternateArt: alternateArt,
    signature: signature,
    overnumbered: overnumbered,
    foil: foil,
    priceEur: priceEur,
    priceFoilEur: priceFoilEur,
    ownedQty: ownedQty ?? this.ownedQty,
    wishedQty: wishedQty ?? this.wishedQty,
    variants: variants,
  );

  static List<String> _strings(Object? value) =>
      value is List ? value.map((e) => e.toString()).toList() : const [];
}

/// Page de résultats de `GET /api/cards`.
class CardPage {
  const CardPage({
    required this.total,
    required this.page,
    required this.size,
    required this.items,
  });

  factory CardPage.fromJson(Map<String, dynamic> json) => CardPage(
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    size: (json['size'] as num?)?.toInt() ?? 0,
    items: (json['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RiftCard.fromJson)
        .toList(),
  );

  final int total;
  final int page;
  final int size;
  final List<RiftCard> items;

  /// `size` peut manquer d'une réponse abîmée : on retombe sur la taille de
  /// page demandée, sinon `page * 0 < total` boucle indéfiniment.
  bool get hasMore => page * (size > 0 ? size : items.length) < total;
}
