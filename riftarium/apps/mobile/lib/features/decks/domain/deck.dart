import '../../cards/domain/card.dart';

/// Une entrée du deck : une carte et son nombre d'exemplaires.
class DeckCard {
  const DeckCard({required this.card, required this.qty});

  factory DeckCard.fromJson(Map<String, dynamic> json) => DeckCard(
    card: RiftCard.fromJson(
      (json['card'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    qty: (json['qty'] as num?)?.toInt() ?? 0,
  );

  final RiftCard card;
  final int qty;

  DeckCard copyWith({int? qty}) => DeckCard(card: card, qty: qty ?? this.qty);
}

/// Résultat d'un contrôle de construction (`validate_deck` côté API).
class DeckCheck {
  const DeckCheck({
    required this.rule,
    required this.ok,
    required this.message,
  });

  factory DeckCheck.fromJson(Map<String, dynamic> json) => DeckCheck(
    rule: (json['rule'] as String?) ?? '',
    ok: json['ok'] == true,
    message: (json['message'] as String?) ?? '',
  );

  final String rule;
  final bool ok;
  final String message;
}

/// Deck complet tel que renvoyé par `deck_out` (`/decks/mine`, `/decks/{id}`).
class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.format,
    required this.isPublic,
    required this.moderationStatus,
    required this.likes,
    required this.likedByMe,
    required this.views,
    required this.owner,
    required this.cardCount,
    required this.cards,
    required this.checks,
    this.description,
    this.ownerAvatar,
    this.totalEur,
    this.missingEur,
    this.updatedAt,
  });

  factory Deck.fromJson(Map<String, dynamic> json) {
    final prices =
        (json['prices'] as Map?)?.cast<String, dynamic>() ?? const {};
    return Deck(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      format: (json['format'] as String?) ?? 'tournament',
      isPublic: json['is_public'] == true,
      moderationStatus: (json['moderation_status'] as String?) ?? 'published',
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      views: (json['views'] as num?)?.toInt() ?? 0,
      owner: (json['owner'] as String?) ?? '',
      ownerAvatar: json['owner_avatar'] as String?,
      cardCount: (json['card_count'] as num?)?.toInt() ?? 0,
      totalEur: (prices['total_eur'] as num?)?.toDouble(),
      missingEur: (prices['missing_eur'] as num?)?.toDouble(),
      cards: (json['cards'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => DeckCard.fromJson(item.cast<String, dynamic>()))
          .toList(),
      checks: (json['checks'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => DeckCheck.fromJson(item.cast<String, dynamic>()))
          .toList(),
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final String name;
  final String? description;

  /// `tournament` (« légal ») ou `free` (« illégal », format libre).
  final String format;
  final bool isPublic;
  final String moderationStatus;
  final int likes;
  final bool likedByMe;
  final int views;
  final String owner;
  final String? ownerAvatar;
  final int cardCount;
  final double? totalEur;
  final double? missingEur;
  final List<DeckCard> cards;
  final List<DeckCheck> checks;
  final String? updatedAt;

  bool get isTournament => format != 'free';

  /// Publié et public : le lien de partage a un sens pour un tiers.
  bool get isShareable => isPublic && moderationStatus == 'published';

  bool get isPending => moderationStatus == 'pending';

  /// Légal = format officiel *et* tous les contrôles au vert.
  bool get isLegal => isTournament && checks.every((check) => check.ok);

  RiftCard? get legend {
    for (final entry in cards) {
      if (entry.card.type == 'Legend') return entry.card;
    }
    return null;
  }

  Deck copyWith({
    String? name,
    String? description,
    String? format,
    bool? isPublic,
    int? likes,
    bool? likedByMe,
    int? views,
    List<DeckCard>? cards,
  }) => Deck(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    format: format ?? this.format,
    isPublic: isPublic ?? this.isPublic,
    moderationStatus: moderationStatus,
    likes: likes ?? this.likes,
    likedByMe: likedByMe ?? this.likedByMe,
    views: views ?? this.views,
    owner: owner,
    ownerAvatar: ownerAvatar,
    cardCount: cardCount,
    totalEur: totalEur,
    missingEur: missingEur,
    cards: cards ?? this.cards,
    checks: checks,
    updatedAt: updatedAt,
  );
}

/// Corps de `POST /api/decks` et `PUT /api/decks/{id}`.
class DeckInput {
  const DeckInput({
    required this.name,
    this.description = '',
    this.format = 'tournament',
    this.isPublic = false,
    this.cards = const [],
  });

  factory DeckInput.fromDeck(Deck deck, {List<DeckCard>? cards}) => DeckInput(
    name: deck.name,
    description: deck.description ?? '',
    format: deck.format,
    isPublic: deck.isPublic,
    cards: (cards ?? deck.cards)
        .map((entry) => DeckCardInput(entry.card.id, entry.qty))
        .toList(),
  );

  final String name;
  final String description;
  final String format;
  final bool isPublic;
  final List<DeckCardInput> cards;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'format': format,
    'is_public': isPublic,
    'cards': cards.map((entry) => entry.toJson()).toList(),
  };
}

class DeckCardInput {
  const DeckCardInput(this.cardId, this.qty);

  final String cardId;
  final int qty;

  Map<String, dynamic> toJson() => {'card_id': cardId, 'qty': qty};
}

/// Réponse de `POST /api/decks/{id}/like`.
class DeckLikeResult {
  const DeckLikeResult({required this.likes, required this.likedByMe});

  factory DeckLikeResult.fromJson(Map<String, dynamic> json) => DeckLikeResult(
    likes: (json['likes'] as num?)?.toInt() ?? 0,
    likedByMe: json['liked_by_me'] == true,
  );

  final int likes;
  final bool likedByMe;
}

/// Une ligne de `GET /api/decks/{id}/missing`.
class DeckMissingItem {
  const DeckMissingItem({
    required this.card,
    required this.needed,
    required this.owned,
    required this.missing,
  });

  factory DeckMissingItem.fromJson(Map<String, dynamic> json) =>
      DeckMissingItem(
        card: RiftCard.fromJson(
          (json['card'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        needed: (json['needed'] as num?)?.toInt() ?? 0,
        owned: (json['owned'] as num?)?.toInt() ?? 0,
        missing: (json['missing'] as num?)?.toInt() ?? 0,
      );

  final RiftCard card;
  final int needed;
  final int owned;
  final int missing;
}

/// Liste d'achats d'un deck (`GET /api/decks/{id}/missing`).
class DeckMissing {
  const DeckMissing({
    required this.items,
    required this.missingTotal,
    required this.deckTotal,
  });

  factory DeckMissing.fromJson(Map<String, dynamic> json) => DeckMissing(
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => DeckMissingItem.fromJson(item.cast<String, dynamic>()))
        .toList(),
    missingTotal: (json['missing_total'] as num?)?.toInt() ?? 0,
    deckTotal: (json['deck_total'] as num?)?.toInt() ?? 0,
  );

  final List<DeckMissingItem> items;
  final int missingTotal;
  final int deckTotal;
}

/// Deck public du listing communautaire (`_community_deck_out`).
class CommunityDeck {
  const CommunityDeck({
    required this.id,
    required this.name,
    required this.format,
    required this.legal,
    required this.likes,
    required this.likedByMe,
    required this.views,
    required this.owner,
    required this.cardCount,
    required this.domains,
    this.description,
    this.ownerAvatar,
    this.legend,
    this.missingCards,
    this.missingCostEur,
    this.updatedAt,
  });

  factory CommunityDeck.fromJson(Map<String, dynamic> json) {
    final legend = json['legend'];
    return CommunityDeck(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
      format: (json['format'] as String?) ?? 'tournament',
      legal: json['legal'] == true,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] == true,
      views: (json['views'] as num?)?.toInt() ?? 0,
      owner: (json['owner'] as String?) ?? '',
      ownerAvatar: json['owner_avatar'] as String?,
      cardCount: (json['card_count'] as num?)?.toInt() ?? 0,
      legend: legend is Map
          ? RiftCard.fromJson(legend.cast<String, dynamic>())
          : null,
      domains: (json['domains'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      missingCards: (json['missing_cards'] as num?)?.toInt(),
      missingCostEur: (json['missing_cost_eur'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] as String?,
    );
  }

  final int id;
  final String name;
  final String? description;
  final String format;
  final bool legal;
  final int likes;
  final bool likedByMe;
  final int views;
  final String owner;
  final String? ownerAvatar;
  final int cardCount;
  final RiftCard? legend;
  final List<String> domains;

  /// Exemplaires manquants dans la collection du visiteur (null si anonyme).
  final int? missingCards;
  final double? missingCostEur;
  final String? updatedAt;

  CommunityDeck copyWith({int? likes, bool? likedByMe}) => CommunityDeck(
    id: id,
    name: name,
    description: description,
    format: format,
    legal: legal,
    likes: likes ?? this.likes,
    likedByMe: likedByMe ?? this.likedByMe,
    views: views,
    owner: owner,
    ownerAvatar: ownerAvatar,
    cardCount: cardCount,
    legend: legend,
    domains: domains,
    missingCards: missingCards,
    missingCostEur: missingCostEur,
    updatedAt: updatedAt,
  );
}

/// Page de `GET /api/community/decks`.
class CommunityPage {
  const CommunityPage({
    required this.total,
    required this.page,
    required this.size,
    required this.items,
  });

  factory CommunityPage.fromJson(Map<String, dynamic> json) => CommunityPage(
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    size: (json['size'] as num?)?.toInt() ?? 20,
    items: (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CommunityDeck.fromJson(item.cast<String, dynamic>()))
        .toList(),
  );

  final int total;
  final int page;
  final int size;
  final List<CommunityDeck> items;

  int get pageCount =>
      size <= 0 ? 1 : ((total + size - 1) ~/ size).clamp(1, 9999);
}

/// Légende du filtre communautaire (`GET /api/community/legends`).
class CommunityLegend {
  const CommunityLegend({
    required this.id,
    required this.name,
    required this.deckCount,
    this.imageUrl,
  });

  factory CommunityLegend.fromJson(Map<String, dynamic> json) =>
      CommunityLegend(
        id: (json['id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        imageUrl: json['image_url'] as String?,
        deckCount: (json['deck_count'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String name;
  final String? imageUrl;
  final int deckCount;
}
