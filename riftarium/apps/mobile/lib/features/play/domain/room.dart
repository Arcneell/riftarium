import '../../cards/domain/card.dart';
import '../../game/domain/card_codec.dart';
import '../../game/domain/game_mode.dart';

/// Un compte tel que l'API le renvoie autour d'une partie suivie
/// (`RoomPlayerOut.user`, `MatchPlayerOut.user`).
class PlayUser {
  const PlayUser({required this.id, required this.handle, this.avatarUrl});

  factory PlayUser.fromJson(Map<String, dynamic> json) => PlayUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    handle: (json['handle'] as String?) ?? '',
    avatarUrl: json['avatar_url'] as String?,
  );

  /// Adversaire anonymisé (compte supprimé) : `opponent` vaut null.
  static PlayUser? maybe(Object? json) =>
      json is Map ? PlayUser.fromJson(json.cast<String, dynamic>()) : null;

  final int id;
  final String handle;
  final String? avatarUrl;

  /// Nom affiché : le pseudo, ou « Joueur retiré » pour un compte supprimé.
  String get displayName => handle.isEmpty ? 'Joueur retiré' : handle;

  String get initial =>
      handle.isEmpty ? '?' : handle.substring(0, 1).toUpperCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'handle': handle,
    'avatar_url': avatarUrl,
  };
}

/// Deck choisi, réduit à ce que le salon et l'historique en montrent.
class PlayDeck {
  const PlayDeck({required this.id, required this.name, required this.format});

  factory PlayDeck.fromJson(Map<String, dynamic> json) => PlayDeck(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] as String?) ?? '',
    format: (json['format'] as String?) ?? 'tournament',
  );

  static PlayDeck? maybe(Object? json) =>
      json is Map ? PlayDeck.fromJson(json.cast<String, dynamic>()) : null;

  final int id;
  final String name;

  /// `tournament` (légal) ou `free` (format libre).
  final String format;

  String get formatLabel => format == 'free' ? 'Libre' : 'Tournoi';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'format': format};
}

/// Un siège du salon (`RoomPlayerOut`).
class RoomPlayer {
  const RoomPlayer({
    required this.user,
    required this.seat,
    required this.ready,
    this.legend,
    this.deck,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
    user: PlayUser.fromJson(
      (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    seat: (json['seat'] as num?)?.toInt() ?? 0,
    ready: json['ready'] == true,
    legend: cardFromJson(json['legend']),
    deck: PlayDeck.maybe(json['deck']),
  );

  final PlayUser user;

  /// 0 = hôte, 1 = invité.
  final int seat;
  final bool ready;
  final RiftCard? legend;
  final PlayDeck? deck;

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'seat': seat,
    'ready': ready,
    'legend': legend == null ? null : cardToJson(legend!),
    'deck': deck?.toJson(),
  };
}

/// Salon d'attente (`RoomOut`). Le code vaut secret : qui l'a peut rejoindre.
class Room {
  const Room({
    required this.code,
    required this.mode,
    required this.status,
    required this.hostId,
    required this.players,
    required this.version,
    required this.victoryScore,
    required this.roundsToWin,
    this.matchId,
    this.expiresAt,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    final mode = (json['mode'] as String?) ?? 'duel';
    return Room(
      code: (json['code'] as String?) ?? '',
      mode: mode,
      status: (json['status'] as String?) ?? 'open',
      hostId: (json['host_id'] as num?)?.toInt() ?? 0,
      players: (json['players'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => RoomPlayer.fromJson(item.cast<String, dynamic>()))
          .toList(),
      matchId: (json['match_id'] as num?)?.toInt(),
      expiresAt: DateTime.tryParse('${json['expires_at']}'),
      version: (json['version'] as num?)?.toInt() ?? 0,
      victoryScore: (json['victory_score'] as num?)?.toInt() ?? 8,
      roundsToWin: (json['rounds_to_win'] as num?)?.toInt() ?? 1,
    );
  }

  final String code;

  /// `duel` ou `match` en v1.
  final String mode;

  /// `open`, `playing`, `finished` ou `cancelled`.
  final String status;
  final int hostId;
  final List<RoomPlayer> players;
  final int? matchId;
  final DateTime? expiresAt;
  final int version;
  final int victoryScore;
  final int roundsToWin;

  /// Format du compteur correspondant (`duel` par défaut).
  GameMode get gameMode => GameMode.byId(mode) ?? GameMode.duel;

  String get modeLabel => gameMode.label;

  bool get isOpen => status == 'open';
  bool get isPlaying => status == 'playing';
  bool get isCancelled => status == 'cancelled';
  bool get isFinished => status == 'finished';

  RoomPlayer? get host => playerAtSeat(0);
  RoomPlayer? get guest => playerAtSeat(1);

  RoomPlayer? playerAtSeat(int seat) {
    for (final player in players) {
      if (player.seat == seat) return player;
    }
    return null;
  }

  RoomPlayer? playerOf(int? userId) {
    if (userId == null) return null;
    for (final player in players) {
      if (player.user.id == userId) return player;
    }
    return null;
  }

  bool isHost(int? userId) => userId != null && userId == hostId;

  /// Les deux sièges sont occupés et prêts : l'hôte peut lancer la partie.
  bool get bothReady =>
      players.length >= 2 && players.every((player) => player.ready);

  /// Salon `open` dont l'échéance est passée : lu comme annulé.
  bool expired({DateTime? now}) {
    final deadline = expiresAt;
    if (deadline == null || !isOpen) return false;
    return (now ?? DateTime.now()).isAfter(deadline);
  }

  /// Lien partageable du salon, identique à celui du site.
  String shareUrl(String webBaseUrl) => '$webBaseUrl/salon/$code';

  Map<String, dynamic> toJson() => {
    'code': code,
    'mode': mode,
    'status': status,
    'host_id': hostId,
    'players': players.map((player) => player.toJson()).toList(),
    'match_id': matchId,
    'expires_at': expiresAt?.toIso8601String(),
    'version': version,
    'victory_score': victoryScore,
    'rounds_to_win': roundsToWin,
  };
}
