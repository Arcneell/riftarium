import '../../cards/domain/card.dart';
import '../../game/domain/card_codec.dart';
import '../../game/domain/game_mode.dart';
import 'room.dart';

/// Instantané du compteur partagé (`matches.state`). Les clés du JSON sont des
/// identifiants de compte en chaîne ; ici ce sont des entiers.
class MatchState {
  const MatchState({
    this.round = 1,
    this.turn = 1,
    this.activeUserId,
    this.scores = const {},
    this.xp = const {},
    this.roundsWon = const {},
  });

  factory MatchState.fromJson(Object? source) {
    final json = source is Map
        ? source.cast<String, dynamic>()
        : const <String, dynamic>{};
    return MatchState(
      round: (json['round'] as num?)?.toInt() ?? 1,
      turn: (json['turn'] as num?)?.toInt() ?? 1,
      activeUserId: (json['active_user_id'] as num?)?.toInt(),
      scores: _counts(json['scores']),
      xp: _counts(json['xp']),
      roundsWon: _counts(json['rounds_won']),
    );
  }

  final int round;
  final int turn;
  final int? activeUserId;

  /// Points, XP et manches gagnées, par identifiant de compte.
  final Map<int, int> scores;
  final Map<int, int> xp;
  final Map<int, int> roundsWon;

  int scoreOf(int userId) => scores[userId] ?? 0;
  int xpOf(int userId) => xp[userId] ?? 0;
  int roundsWonBy(int userId) => roundsWon[userId] ?? 0;

  Map<String, dynamic> toJson() => {
    'round': round,
    'turn': turn,
    'active_user_id': activeUserId,
    'scores': _keysToString(scores),
    'xp': _keysToString(xp),
    'rounds_won': _keysToString(roundsWon),
  };

  static Map<int, int> _counts(Object? source) {
    if (source is! Map) return const {};
    final result = <int, int>{};
    for (final entry in source.entries) {
      final key = int.tryParse('${entry.key}');
      final value = entry.value;
      if (key != null && value is num) result[key] = value.toInt();
    }
    return result;
  }

  static Map<String, int> _keysToString(Map<int, int> values) => {
    for (final entry in values.entries) '${entry.key}': entry.value,
  };
}

/// Un siège du match (`MatchPlayerOut`).
class MatchPlayer {
  const MatchPlayer({
    required this.user,
    required this.seat,
    required this.score,
    required this.roundsWon,
    required this.confirmed,
    this.legend,
    this.deck,
  });

  factory MatchPlayer.fromJson(Map<String, dynamic> json) => MatchPlayer(
    user: PlayUser.fromJson(
      (json['user'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    seat: (json['seat'] as num?)?.toInt() ?? 0,
    score: (json['score'] as num?)?.toInt() ?? 0,
    roundsWon: (json['rounds_won'] as num?)?.toInt() ?? 0,
    confirmed: json['confirmed'] == true,
    legend: cardFromJson(json['legend']),
    deck: PlayDeck.maybe(json['deck']),
  );

  final PlayUser user;
  final int seat;
  final int score;
  final int roundsWon;

  /// Ce joueur a validé le résultat.
  final bool confirmed;
  final RiftCard? legend;
  final PlayDeck? deck;

  Map<String, dynamic> toJson() => {
    'user': user.toJson(),
    'seat': seat,
    'score': score,
    'rounds_won': roundsWon,
    'confirmed': confirmed,
    'legend': legend == null ? null : cardToJson(legend!),
    'deck': deck?.toJson(),
  };
}

/// Match suivi (`MatchOut`). Seul l'hôte écrit `state` ; l'invité le lit.
class Match {
  const Match({
    required this.id,
    required this.mode,
    required this.status,
    required this.hostId,
    required this.firstPlayerId,
    required this.players,
    required this.state,
    required this.version,
    this.roomCode,
    this.startedAt,
    this.endedAt,
    this.winnerUserId,
    this.result,
  });

  factory Match.fromJson(Map<String, dynamic> json) => Match(
    id: (json['id'] as num?)?.toInt() ?? 0,
    roomCode: json['room_code'] as String?,
    mode: (json['mode'] as String?) ?? 'duel',
    status: (json['status'] as String?) ?? 'live',
    hostId: (json['host_id'] as num?)?.toInt() ?? 0,
    firstPlayerId: (json['first_player_id'] as num?)?.toInt() ?? 0,
    startedAt: DateTime.tryParse('${json['started_at']}'),
    endedAt: DateTime.tryParse('${json['ended_at']}'),
    winnerUserId: (json['winner_user_id'] as num?)?.toInt(),
    players: (json['players'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => MatchPlayer.fromJson(item.cast<String, dynamic>()))
        .toList(),
    state: MatchState.fromJson(json['state']),
    result: (json['result'] as Map?)?.cast<String, dynamic>(),
    version: (json['version'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String? roomCode;
  final String mode;

  /// `live`, `awaiting_confirmation`, `confirmed`, `disputed` ou `abandoned`.
  final String status;
  final int hostId;
  final int firstPlayerId;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? winnerUserId;
  final List<MatchPlayer> players;
  final MatchState state;
  final Map<String, dynamic>? result;
  final int version;

  GameMode get gameMode => GameMode.byId(mode) ?? GameMode.duel;

  bool get isLive => status == 'live';
  bool get isAwaitingConfirmation => status == 'awaiting_confirmation';
  bool get isConfirmed => status == 'confirmed';
  bool get isDisputed => status == 'disputed';
  bool get isAbandoned => status == 'abandoned';

  /// La partie est jouée : plus personne ne touche au compteur.
  bool get isOver => !isLive;

  bool isHost(int? userId) => userId != null && userId == hostId;

  MatchPlayer? playerOf(int? userId) {
    if (userId == null) return null;
    for (final player in players) {
      if (player.user.id == userId) return player;
    }
    return null;
  }

  MatchPlayer? opponentOf(int? userId) {
    if (userId == null) return null;
    for (final player in players) {
      if (player.user.id != userId) return player;
    }
    return null;
  }

  MatchPlayer? playerAtSeat(int seat) {
    for (final player in players) {
      if (player.seat == seat) return player;
    }
    return null;
  }

  /// Étiquette du statut, telle qu'elle s'affiche sur l'écran de résultat.
  String get statusLabel => switch (status) {
    'live' => 'En cours',
    'awaiting_confirmation' => 'En attente de confirmation',
    'confirmed' => 'Résultat confirmé',
    'disputed' => 'Résultat contesté',
    'abandoned' => 'Abandon',
    _ => status,
  };

  Match copyWith({MatchState? state, int? version, String? status}) => Match(
    id: id,
    roomCode: roomCode,
    mode: mode,
    status: status ?? this.status,
    hostId: hostId,
    firstPlayerId: firstPlayerId,
    startedAt: startedAt,
    endedAt: endedAt,
    winnerUserId: winnerUserId,
    players: players,
    state: state ?? this.state,
    result: result,
    version: version ?? this.version,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'room_code': roomCode,
    'mode': mode,
    'status': status,
    'host_id': hostId,
    'first_player_id': firstPlayerId,
    'started_at': startedAt?.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'winner_user_id': winnerUserId,
    'players': players.map((player) => player.toJson()).toList(),
    'state': state.toJson(),
    'result': result,
    'version': version,
  };
}

/// Réponse de `GET /api/play/current` : ma reprise après fermeture de l'app.
class CurrentPlay {
  const CurrentPlay({this.room, this.match});

  factory CurrentPlay.fromJson(Map<String, dynamic> json) => CurrentPlay(
    room: json['room'] is Map
        ? Room.fromJson((json['room'] as Map).cast<String, dynamic>())
        : null,
    match: json['match'] is Map
        ? Match.fromJson((json['match'] as Map).cast<String, dynamic>())
        : null,
  );

  final Room? room;
  final Match? match;

  bool get isEmpty => room == null && match == null;

  Map<String, dynamic> toJson() => {
    'room': room?.toJson(),
    'match': match?.toJson(),
  };
}
