import 'game_mode.dart';
import 'player.dart';

/// Cliché d'un instant de la partie : tout ce que le bouton « annuler »
/// restitue. La liste des joueurs n'y figure pas (renommer ou changer de
/// légende ne s'annule pas, cela ne fait pas partie du compte).
class GameMoment {
  const GameMoment({
    required this.scores,
    required this.xp,
    required this.roundsWon,
    required this.turnIndex,
    required this.turnNumber,
    this.winnerTeam,
  });

  factory GameMoment.fromJson(Map<String, dynamic> json) => GameMoment(
    scores: _intMap(json['scores']),
    xp: _playerMap(json['xp']),
    roundsWon: _intMap(json['rounds_won']),
    turnIndex: (json['turn_index'] as num?)?.toInt() ?? 0,
    turnNumber: (json['turn_number'] as num?)?.toInt() ?? 1,
    winnerTeam: (json['winner_team'] as num?)?.toInt(),
  );

  final Map<int, int> scores;

  /// XP par joueur : jamais partagée, même en 2c2 (729).
  final Map<String, int> xp;
  final Map<int, int> roundsWon;
  final int turnIndex;
  final int turnNumber;
  final int? winnerTeam;

  Map<String, dynamic> toJson() => {
    'scores': _mapToJson(scores),
    'xp': xp,
    'rounds_won': _mapToJson(roundsWon),
    'turn_index': turnIndex,
    'turn_number': turnNumber,
    'winner_team': winnerTeam,
  };
}

/// Partie en cours. Immuable : le moteur (`GameEngine`) renvoie toujours un
/// nouvel état, ce qui rend l'historique et la sauvegarde triviaux.
class GameState {
  const GameState({
    required this.mode,
    required this.players,
    required this.scores,
    required this.xp,
    required this.roundsWon,
    required this.turnOrder,
    required this.turnIndex,
    required this.turnNumber,
    required this.round,
    required this.startedAt,
    this.winnerTeam,
    this.hintSeen = false,
    this.history = const [],
  });

  final GameMode mode;
  final List<Player> players;

  /// Score par camp (en 2c2, les deux coéquipiers partagent la même entrée).
  final Map<int, int> scores;

  /// XP par joueur (729) : ressource publique, sans plafond, propre à chacun.
  /// Contrairement aux points, elle n'est jamais partagée entre coéquipiers.
  final Map<String, int> xp;

  /// Manches gagnées par camp.
  final Map<int, int> roundsWon;

  /// Identifiants des joueurs dans l'ordre des tours.
  final List<String> turnOrder;
  final int turnIndex;

  /// Numéro du tour en cours (un tour = un joueur qui joue).
  final int turnNumber;

  /// Numéro de la manche (1 hors match).
  final int round;

  /// Début du chronomètre.
  final DateTime startedAt;

  /// Camp vainqueur de la manche, null tant qu'aucun n'a gagné.
  final int? winnerTeam;

  /// Le rappel des ajustements du premier tour a déjà été affiché.
  final bool hintSeen;

  final List<GameMoment> history;

  Player playerById(String id) =>
      players.firstWhere((player) => player.id == id, orElse: () => players[0]);

  Player get activePlayer =>
      playerById(turnOrder[turnIndex % turnOrder.length]);

  int scoreOf(Player player) => scores[player.team] ?? 0;

  int scoreOfTeam(int team) => scores[team] ?? 0;

  int xpOf(Player player) => xp[player.id] ?? 0;

  int roundsWonBy(int team) => roundsWon[team] ?? 0;

  List<Player> teamPlayers(int team) =>
      players.where((player) => player.team == team).toList();

  /// Camps présents, dans l'ordre.
  List<int> get teams {
    final seen = <int>{};
    for (final player in players) {
      seen.add(player.team);
    }
    return seen.toList()..sort();
  }

  /// Nom affiché d'un camp : « Équipe A » en 2c2, le nom du joueur sinon.
  String teamName(int team) {
    if (mode.isTeamPlay) return 'Équipe ${teamLetter(team)}';
    final members = teamPlayers(team);
    return members.isEmpty ? 'Joueur ${team + 1}' : members.first.name;
  }

  bool get isOver => winnerTeam != null;

  /// La rencontre est finie : plus de manche à jouer.
  bool get isMatchOver =>
      winnerTeam != null && roundsWonBy(winnerTeam!) >= mode.roundsToWin;

  bool get canUndo => history.isNotEmpty;

  GameMoment get moment => GameMoment(
    scores: scores,
    xp: xp,
    roundsWon: roundsWon,
    turnIndex: turnIndex,
    turnNumber: turnNumber,
    winnerTeam: winnerTeam,
  );

  GameState copyWith({
    List<Player>? players,
    Map<int, int>? scores,
    Map<String, int>? xp,
    Map<int, int>? roundsWon,
    List<String>? turnOrder,
    int? turnIndex,
    int? turnNumber,
    int? round,
    DateTime? startedAt,
    int? winnerTeam,
    bool clearWinner = false,
    bool? hintSeen,
    List<GameMoment>? history,
  }) => GameState(
    mode: mode,
    players: players ?? this.players,
    scores: scores ?? this.scores,
    xp: xp ?? this.xp,
    roundsWon: roundsWon ?? this.roundsWon,
    turnOrder: turnOrder ?? this.turnOrder,
    turnIndex: turnIndex ?? this.turnIndex,
    turnNumber: turnNumber ?? this.turnNumber,
    round: round ?? this.round,
    startedAt: startedAt ?? this.startedAt,
    winnerTeam: clearWinner ? null : (winnerTeam ?? this.winnerTeam),
    hintSeen: hintSeen ?? this.hintSeen,
    history: history ?? this.history,
  );

  /// Sérialisation. Le chronomètre est écrit en durée écoulée, pas en date :
  /// une partie reprise plus tard repart de la durée déjà jouée, pas de
  /// l'heure à laquelle l'application a été fermée.
  Map<String, dynamic> toJson({DateTime? now}) => {
    'version': 1,
    'mode': mode.id,
    'players': players.map((player) => player.toJson()).toList(),
    'scores': _mapToJson(scores),
    'xp': xp,
    'rounds_won': _mapToJson(roundsWon),
    'turn_order': turnOrder,
    'turn_index': turnIndex,
    'turn_number': turnNumber,
    'round': round,
    'elapsed_us': (now ?? DateTime.now()).difference(startedAt).inMicroseconds,
    'winner_team': winnerTeam,
    'hint_seen': hintSeen,
    'history': history.map((moment) => moment.toJson()).toList(),
  };

  /// Relecture. Renvoie null si le fichier ne décrit pas une partie jouable
  /// (mode inconnu, aucun joueur) : mieux vaut repartir de la configuration.
  static GameState? fromJson(Object? source, {DateTime? now}) {
    if (source is! Map) return null;
    final json = Map<String, dynamic>.from(source);
    final mode = GameMode.byId(json['mode']);
    if (mode == null) return null;
    final players = (json['players'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Player.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    if (players.isEmpty) return null;
    final ids = players.map((player) => player.id).toSet();
    final order = (json['turn_order'] as List? ?? const [])
        .whereType<String>()
        .where(ids.contains)
        .toList();
    if (order.isEmpty) return null;
    final elapsed = (json['elapsed_us'] as num?)?.toInt() ?? 0;
    return GameState(
      mode: mode,
      players: players,
      scores: _intMap(json['scores']),
      xp: _playerMap(json['xp']),
      roundsWon: _intMap(json['rounds_won']),
      turnOrder: order,
      turnIndex: ((json['turn_index'] as num?)?.toInt() ?? 0) % order.length,
      turnNumber: (json['turn_number'] as num?)?.toInt() ?? 1,
      round: (json['round'] as num?)?.toInt() ?? 1,
      startedAt: (now ?? DateTime.now()).subtract(
        Duration(microseconds: elapsed),
      ),
      winnerTeam: (json['winner_team'] as num?)?.toInt(),
      hintSeen: json['hint_seen'] == true,
      history: (json['history'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => GameMoment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }
}

Map<String, int> _mapToJson(Map<int, int> values) => {
  for (final entry in values.entries) '${entry.key}': entry.value,
};

Map<String, int> _playerMap(Object? source) {
  if (source is! Map) return const {};
  final result = <String, int>{};
  for (final entry in source.entries) {
    final value = entry.value;
    if (value is num) result['${entry.key}'] = value.toInt();
  }
  return result;
}

Map<int, int> _intMap(Object? source) {
  if (source is! Map) return const {};
  final result = <int, int>{};
  for (final entry in source.entries) {
    final key = int.tryParse('${entry.key}');
    final value = entry.value;
    if (key != null && value is num) result[key] = value.toInt();
  }
  return result;
}
