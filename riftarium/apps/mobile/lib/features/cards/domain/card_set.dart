/// Set de cartes tel que renvoyé par `GET /api/sets`.
///
/// L'API répond par une liste JSON nue d'objets
/// `{set_id, name, card_count, published_on}`, triée par date de sortie. Le
/// filtre n'a besoin que du code et du nom ; la complétion d'un set se lit
/// dans `GET /api/collection/sets`.
class CardSet {
  const CardSet({required this.setId, required this.name});

  factory CardSet.fromJson(Map<String, dynamic> json) => CardSet(
    setId: (json['set_id'] as String?) ?? '',
    name: (json['name'] as String?) ?? '',
  );

  final String setId;
  final String name;

  /// Libellé du filtre : le nom du set, à défaut son code.
  String get label => name.isEmpty ? setId.toUpperCase() : name;
}
