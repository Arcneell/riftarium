/// Set de cartes tel que renvoyé par `GET /api/sets`.
///
/// L'API répond par une liste JSON nue d'objets
/// `{set_id, name, card_count, published_on}`, triée par date de sortie.
class CardSet {
  const CardSet({
    required this.setId,
    required this.name,
    this.cardCount,
    this.publishedOn,
  });

  factory CardSet.fromJson(Map<String, dynamic> json) => CardSet(
    setId: (json['set_id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
    cardCount: (json['card_count'] as num?)?.toInt(),
    publishedOn: json['published_on']?.toString(),
  );

  final String setId;
  final String name;
  final int? cardCount;
  final String? publishedOn;

  /// Libellé du filtre : le nom du set, à défaut son code.
  String get label => name.isEmpty ? setId.toUpperCase() : name;
}
