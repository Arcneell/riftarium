import '../../../core/api_exception.dart';

/// Réponse de `POST /api/auth/login` et `/register` pour le client mobile
/// (`SessionOut` côté API, avec le champ `token`).
class Session {
  const Session({
    required this.handle,
    required this.token,
    this.avatarUrl,
    this.isAdmin = false,
  });

  factory Session.fromJson(Map<String, dynamic> json) {
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      // L'API n'a pas reconnu le client mobile (en-tête absent ou API trop
      // ancienne) : sans jeton, aucune session possible côté natif.
      throw const ApiException(
        "Réponse d'authentification incomplète : jeton absent.",
      );
    }
    return Session(
      handle: json['handle'] as String,
      token: token,
      avatarUrl: json['avatar_url'] as String?,
      isAdmin: json['is_admin'] == true,
    );
  }

  final String handle;
  final String token;
  final String? avatarUrl;
  final bool isAdmin;
}

/// Profil complet renvoyé par `GET /api/auth/me` (`user_out` avec e-mail et
/// statistiques).
class Profile {
  const Profile({
    required this.id,
    required this.handle,
    required this.bio,
    required this.email,
    required this.emailVerified,
    required this.isAdmin,
    this.avatarCardId,
    this.avatarUrl,
    this.createdAt,
    this.stats = const {},
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final rawStats = json['stats'];
    return Profile(
      id: (json['id'] as num).toInt(),
      handle: json['handle'] as String,
      bio: (json['bio'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      emailVerified: json['email_verified'] == true,
      isAdmin: json['is_admin'] == true,
      avatarCardId: json['avatar_card_id'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] is String
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      stats: rawStats is Map
          ? rawStats.map(
              (key, value) => MapEntry(key.toString(), _asInt(value)),
            )
          : const {},
    );
  }

  final int id;
  final String handle;
  final String bio;
  final String email;
  final bool emailVerified;
  final bool isAdmin;
  final String? avatarCardId;
  final String? avatarUrl;
  final DateTime? createdAt;
  final Map<String, int> stats;

  static int _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;
}
