import '../../cards/domain/card.dart';
import '../../game/domain/card_codec.dart';
import '../../play/domain/play_stats.dart';
import 'achievement.dart';

/// Ce que le joueur accepte de montrer (`PublicProfileOut.visibility`).
/// Valeurs par défaut du contrat : tout est fermé sauf les decks et les hauts
/// faits.
class ProfileVisibility {
  const ProfileVisibility({
    this.showStats = false,
    this.showCollection = false,
    this.showDecks = true,
    this.showAchievements = true,
  });

  factory ProfileVisibility.fromJson(Object? source) {
    final json = source is Map
        ? source.cast<String, dynamic>()
        : const <String, dynamic>{};
    return ProfileVisibility(
      showStats: json['show_stats'] == true,
      showCollection: json['show_collection'] == true,
      showDecks: json['show_decks'] != false,
      showAchievements: json['show_achievements'] != false,
    );
  }

  final bool showStats;
  final bool showCollection;
  final bool showDecks;
  final bool showAchievements;
}

/// Une ligne du résumé de collection : un set et sa complétion.
class ProfileSetSummary {
  const ProfileSetSummary({
    required this.setId,
    required this.name,
    required this.owned,
    required this.total,
  });

  factory ProfileSetSummary.fromJson(Map<String, dynamic> json) =>
      ProfileSetSummary(
        setId: (json['set_id'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        owned: (json['owned'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );

  final String setId;
  final String name;
  final int owned;
  final int total;

  double get ratio => total == 0 ? 0 : owned / total;

  int get percent => (ratio * 100).round();
}

/// Résumé de collection d'un profil public (`collection_summary`).
class ProfileCollection {
  const ProfileCollection({
    required this.uniqueCards,
    required this.totalCards,
    required this.sets,
  });

  factory ProfileCollection.fromJson(Map<String, dynamic> json) =>
      ProfileCollection(
        uniqueCards: (json['unique_cards'] as num?)?.toInt() ?? 0,
        totalCards: (json['total_cards'] as num?)?.toInt() ?? 0,
        sets: (json['sets'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) =>
                  ProfileSetSummary.fromJson(item.cast<String, dynamic>()),
            )
            .toList(),
      );

  final int uniqueCards;
  final int totalCards;
  final List<ProfileSetSummary> sets;
}

/// Deck public listé sur un profil (résumé : la fiche complète reste
/// `/decks/{id}`).
class ProfileDeck {
  const ProfileDeck({
    required this.id,
    required this.name,
    required this.format,
    required this.likes,
    this.legend,
  });

  factory ProfileDeck.fromJson(Map<String, dynamic> json) => ProfileDeck(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] as String?) ?? '',
    format: (json['format'] as String?) ?? 'tournament',
    likes: (json['likes'] as num?)?.toInt() ?? 0,
    legend: cardFromJson(json['legend']),
  );

  final int id;
  final String name;

  /// `tournament` (légal) ou `free` (format libre).
  final String format;
  final int likes;
  final RiftCard? legend;

  bool get isTournament => format != 'free';
}

/// Un compte tel que le renvoient la recherche et les listes d'amis.
class SocialUser {
  const SocialUser({
    required this.id,
    required this.handle,
    this.avatarUrl,
    this.lastMatchAt,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    handle: (json['handle'] as String?) ?? '',
    avatarUrl: json['avatar_url'] as String?,
    lastMatchAt: DateTime.tryParse('${json['last_match_at']}'),
  );

  static List<SocialUser> listFrom(Object? source) =>
      (source as List? ?? const [])
          .whereType<Map>()
          .map((item) => SocialUser.fromJson(item.cast<String, dynamic>()))
          .toList();

  final int id;
  final String handle;
  final String? avatarUrl;

  /// Dernier match suivi (liste des suivis) : null si aucun.
  final DateTime? lastMatchAt;

  String get initial =>
      handle.isEmpty ? '?' : handle.substring(0, 1).toUpperCase();
}

/// Mes suivis et mes abonnés (`GET /api/me/follows`).
class FollowLists {
  const FollowLists({this.following = const [], this.followers = const []});

  factory FollowLists.fromJson(Map<String, dynamic> json) => FollowLists(
    following: SocialUser.listFrom(json['following']),
    followers: SocialUser.listFrom(json['followers']),
  );

  final List<SocialUser> following;
  final List<SocialUser> followers;
}

/// Profil public d'un joueur (`GET /api/users/{handle}`).
///
/// Les sections que le joueur garde pour lui arrivent à `null` : c'est ce qui
/// distingue « masqué » de « vide ».
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.handle,
    required this.bio,
    required this.visibility,
    this.avatarUrl,
    this.createdAt,
    this.isMe = false,
    this.isFollowed = false,
    this.followersCount = 0,
    this.followingCount = 0,
    this.stats,
    this.achievements,
    this.collection,
    this.decks,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'];
    final collection = json['collection_summary'];
    final decks = json['decks'];
    return PublicProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      handle: (json['handle'] as String?) ?? '',
      bio: (json['bio'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.tryParse('${json['created_at']}'),
      isMe: json['is_me'] == true,
      isFollowed: json['is_followed'] == true,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (json['following_count'] as num?)?.toInt() ?? 0,
      visibility: ProfileVisibility.fromJson(json['visibility']),
      stats: stats is Map
          ? PlayStats.fromJson(stats.cast<String, dynamic>())
          : null,
      achievements: json['achievements'] == null
          ? null
          : Achievement.listFrom(json['achievements']),
      collection: collection is Map
          ? ProfileCollection.fromJson(collection.cast<String, dynamic>())
          : null,
      decks: decks is List
          ? decks
                .whereType<Map>()
                .map(
                  (item) => ProfileDeck.fromJson(item.cast<String, dynamic>()),
                )
                .toList()
          : null,
    );
  }

  final int id;
  final String handle;
  final String bio;
  final String? avatarUrl;
  final DateTime? createdAt;
  final bool isMe;
  final bool isFollowed;
  final int followersCount;
  final int followingCount;
  final ProfileVisibility visibility;

  /// Statistiques de duels allégées (`totals` + `by_legend`), null si masquées.
  final PlayStats? stats;
  final List<Achievement>? achievements;
  final ProfileCollection? collection;
  final List<ProfileDeck>? decks;

  String get initial =>
      handle.isEmpty ? '?' : handle.substring(0, 1).toUpperCase();

  /// Le suivi est le seul champ que l'écran modifie de lui-même (mise à jour
  /// optimiste) : le reste vient toujours du serveur.
  PublicProfile copyWith({bool? isFollowed, int? followersCount}) =>
      PublicProfile(
        id: id,
        handle: handle,
        bio: bio,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
        isMe: isMe,
        isFollowed: isFollowed ?? this.isFollowed,
        followersCount: followersCount ?? this.followersCount,
        followingCount: followingCount,
        visibility: visibility,
        stats: stats,
        achievements: achievements,
        collection: collection,
        decks: decks,
      );
}
