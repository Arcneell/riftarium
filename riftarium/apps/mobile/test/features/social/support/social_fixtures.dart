import '../../play/support/play_fixtures.dart';

/// Un haut fait du catalogue (`GET /api/me/achievements`).
Map<String, dynamic> achievementJson({
  String key = 'first_blood',
  String title = 'Premier sang',
  String description = 'Remporte un match suivi.',
  String icon = 'military_tech',
  String tier = 'bronze',
  String family = 'duels',
  int threshold = 1,
  int current = 1,
  String? unlockedAt = '2026-08-20T18:00:00Z',
}) => {
  'key': key,
  'title': title,
  'description': description,
  'icon': icon,
  'tier': tier,
  'family': family,
  'threshold': threshold,
  'current': current,
  'unlocked_at': unlockedAt,
};

/// Catalogue de test : un débloqué, un en cours, un verrouillé d'une autre
/// famille.
List<Map<String, dynamic>> achievementsJson() => [
  achievementJson(),
  achievementJson(
    key: 'veteran_10',
    title: 'Vétéran',
    description: 'Joue 10 matchs suivis.',
    tier: 'silver',
    threshold: 10,
    current: 4,
    unlockedAt: null,
  ),
  achievementJson(
    key: 'collector_100',
    title: 'Collectionneur',
    description: 'Possède 100 cartes différentes.',
    icon: 'style',
    tier: 'bronze',
    family: 'collection',
    threshold: 100,
    current: 100,
  ),
];

Map<String, dynamic> socialUserJson({
  int id = 8,
  String handle = 'jinx',
  String? lastMatchAt,
}) => {
  'id': id,
  'handle': handle,
  'avatar_url': null,
  'last_match_at': ?lastMatchAt,
};

Map<String, dynamic> followsJson({
  List<Map<String, dynamic>>? following,
  List<Map<String, dynamic>>? followers,
}) => {
  'following': following ?? [socialUserJson()],
  'followers': followers ?? [socialUserJson(id: 9, handle: 'vi')],
};

Map<String, dynamic> collectionSummaryJson() => {
  'unique_cards': 120,
  'total_cards': 300,
  'sets': [
    {'set_id': 'OGN', 'name': 'Origines', 'owned': 120, 'total': 298},
  ],
};

Map<String, dynamic> profileDeckJson({
  int id = 3,
  String name = 'Ahri contrôle',
  String format = 'tournament',
  int likes = 12,
}) => {
  'id': id,
  'name': name,
  'format': format,
  'likes': likes,
  'legend': legendJson(),
};

/// Collection publique : même forme que `GET /api/collection`, sans les lots.
Map<String, dynamic> profileCollectionJson({int total = 1}) => {
  'total_cards': 300,
  'unique_cards': 120,
  'total': total,
  'page': 1,
  'size': 60,
  'items': [
    {
      'card': legendJson(id: 'OGN-010', name: 'Yasuo'),
      'total_qty': 3,
      'entries': const <Map<String, dynamic>>[],
    },
  ],
};

/// Profil public. Par défaut tout est ouvert ; passer `visible: false` ferme
/// les quatre sections et coupe leurs contenus, comme le fait l'API.
Map<String, dynamic> publicProfileJson({
  String handle = 'jinx',
  bool visible = true,
  bool isFollowed = false,
  bool isMe = false,
  int followersCount = 4,
  int followingCount = 2,
}) => {
  'id': 8,
  'handle': handle,
  'avatar_url': null,
  'bio': 'Boum.',
  'created_at': '2026-01-15T10:00:00Z',
  'is_me': isMe,
  'is_followed': isFollowed,
  'followers_count': followersCount,
  'following_count': followingCount,
  'visibility': {
    'show_stats': visible,
    'show_collection': visible,
    'show_decks': visible,
    'show_achievements': visible,
  },
  'stats': visible
      ? {
          'totals': {
            'played': 10,
            'won': 6,
            'lost': 4,
            'win_rate': 0.6,
            'current_streak': 2,
            'best_streak': 4,
          },
          'by_legend': [
            {
              'card_id': 'OGN-002',
              'name': 'Jinx',
              'image_url': null,
              'played': 5,
              'won': 3,
              'lost': 2,
            },
          ],
        }
      : null,
  'achievements': visible ? [achievementJson()] : null,
  'collection_summary': visible ? collectionSummaryJson() : null,
  'decks': visible ? [profileDeckJson()] : null,
};
