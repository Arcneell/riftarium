import 'game_mode.dart';
import 'player.dart';

/// Version du format de sauvegarde d'une partie. À incrémenter le jour où un
/// champ change de sens (un ajout avec repli n'en a pas besoin).
const int kGameSaveVersion = 1;

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
    this.timeCalled = false,
    this.overtimeTurnsLeft = 0,
    this.drawn = false,
  });

  factory GameMoment.fromJson(Map<String, dynamic> json) => GameMoment(
    scores: _intMap(json['scores']),
    xp: _playerMap(json['xp']),
    roundsWon: _intMap(json['rounds_won']),
    turnIndex: (json['turn_index'] as num?)?.toInt() ?? 0,
    turnNumber: (json['turn_number'] as num?)?.toInt() ?? 1,
    winnerTeam: (json['winner_team'] as num?)?.toInt(),
    timeCalled: json['time_called'] == true,
    overtimeTurnsLeft: (json['overtime_turns_left'] as num?)?.toInt() ?? 0,
    drawn: json['drawn'] == true,
  );

  final Map<int, int> scores;

  /// XP par joueur : jamais partagée, même en 2c2 (729).
  final Map<String, int> xp;
  final Map<int, int> roundsWon;
  final int turnIndex;
  final int turnNumber;
  final int? winnerTeam;
  final bool timeCalled;
  final int overtimeTurnsLeft;
  final bool drawn;

  Map<String, dynamic> toJson() => {
    'scores': _mapToJson(scores),
    'xp': xp,
    'rounds_won': _mapToJson(roundsWon),
    'turn_index': turnIndex,
    'turn_number': turnNumber,
    'winner_team': winnerTeam,
    'time_called': timeCalled,
    'overtime_turns_left': overtimeTurnsLeft,
    'drawn': drawn,
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
    this.roundLimit,
    this.timeCalled = false,
    this.overtimeTurnsLeft = 0,
    this.drawn = false,
    this.endedOnTime = false,
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

  /// Début du chronomètre. En tournoi, c'est l'horloge de la ronde : elle
  /// court sur tout le match, pas seulement sur la manche en cours.
  final DateTime startedAt;

  /// Camp vainqueur de la manche, null tant qu'aucun n'a gagné.
  final int? winnerTeam;

  /// Le rappel des ajustements du premier tour a déjà été affiché.
  final bool hintSeen;

  final List<GameMoment> history;

  /// Tournoi : durée de la ronde (RT 604.1), null sans limite de temps
  /// (élimination directe, ou l'arbitre annonce le temps lui-même).
  final Duration? roundLimit;

  /// Tournoi : la fin du temps a été annoncée (RT 408.2). Irréversible.
  final bool timeCalled;

  /// Tournoi : tours restant à jouer après l'annonce, tour en cours compris.
  /// 4 à l'annonce (le tour en cours puis trois tours supplémentaires), 0
  /// quand la partie s'arrête au temps. Sans signification si [timeCalled]
  /// est faux.
  final int overtimeTurnsLeft;

  /// La manche s'est terminée sur une égalité (temps écoulé sans deux points
  /// d'écart, RT 408.2.b). Une égalité ne compte pas comme manche gagnée.
  final bool drawn;

  /// La manche s'est achevée au bout des tours supplémentaires (RT 408.2.b) :
  /// c'est la seule situation où deux points d'avance emportent le match
  /// entier. À ne pas confondre avec un temps annoncé *entre deux manches*
  /// (RT 408.2.d), qui clôt le match sur le compte des manches. Posé par le
  /// moteur seul, quand le dernier tour supplémentaire s'achève.
  final bool endedOnTime;

  /// Joueur d'un identifiant, ou null s'il n'est pas à cette table : le
  /// moteur ignore alors le geste plutôt que de le compter au mauvais joueur.
  Player? playerById(String id) {
    for (final player in players) {
      if (player.id == id) return player;
    }
    return null;
  }

  /// Joueur dont c'est le tour. L'ordre des tours n'est jamais vide sur une
  /// table jouable (la relecture refuse une sauvegarde sans ordre) ; la garde
  /// évite malgré tout de faire tomber un écran sur un état bancal.
  Player get activePlayer {
    if (turnOrder.isEmpty) return players.first;
    return playerById(turnOrder[turnIndex % turnOrder.length]) ?? players.first;
  }

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

  /// La manche est finie : un vainqueur, ou une égalité au temps.
  bool get isOver => winnerTeam != null || drawn;

  /// La manche s'est arrêtée au temps, après les tours supplémentaires
  /// (RT 408.2.b). Faux quand le temps a été annoncé entre deux manches :
  /// là, c'est le compte des manches qui décide (RT 408.2.d).
  bool get timedOut => endedOnTime && isOver;

  /// La rencontre est finie : plus de manche à jouer. En tournoi, la fin du
  /// temps clôt le match dès que la manche en cours s'achève (RT 408.2.d).
  bool get isMatchOver {
    final winner = winnerTeam;
    if (winner != null && roundsWonBy(winner) >= mode.roundsToWin) return true;
    return mode.isTournament && timeCalled && isOver;
  }

  /// Camp qui remporte la rencontre, null si elle continue ou si elle est
  /// nulle. Au temps : deux points d'avance gagnent le match (RT 408.2.b),
  /// sinon le plus de manches gagnées (RT 404.4), sinon match nul (404.5).
  int? get matchWinnerTeam {
    if (!isMatchOver) return null;
    final winner = winnerTeam;
    if (winner != null && roundsWonBy(winner) >= mode.roundsToWin) {
      return winner;
    }
    if (timedOut && winner != null) return winner;
    int? best;
    var bestRounds = -1;
    var tied = false;
    for (final team in teams) {
      final rounds = roundsWonBy(team);
      if (rounds > bestRounds) {
        bestRounds = rounds;
        best = team;
        tied = false;
      } else if (rounds == bestRounds) {
        tied = true;
      }
    }
    return tied ? null : best;
  }

  /// Match nul : la rencontre est finie sans vainqueur.
  bool get isMatchDrawn => isMatchOver && matchWinnerTeam == null;

  /// Temps restant dans la ronde, null sans limite. Jamais négatif.
  Duration? remainingTime(DateTime now) {
    final limit = roundLimit;
    if (limit == null) return null;
    final left = limit - now.difference(startedAt);
    return left.isNegative ? Duration.zero : left;
  }

  bool get canUndo => history.isNotEmpty;

  GameMoment get moment => GameMoment(
    scores: scores,
    xp: xp,
    roundsWon: roundsWon,
    turnIndex: turnIndex,
    turnNumber: turnNumber,
    winnerTeam: winnerTeam,
    timeCalled: timeCalled,
    overtimeTurnsLeft: overtimeTurnsLeft,
    drawn: drawn,
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
    Duration? roundLimit,
    bool clearRoundLimit = false,
    bool? timeCalled,
    int? overtimeTurnsLeft,
    bool? drawn,
    bool? endedOnTime,
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
    roundLimit: clearRoundLimit ? null : (roundLimit ?? this.roundLimit),
    timeCalled: timeCalled ?? this.timeCalled,
    overtimeTurnsLeft: overtimeTurnsLeft ?? this.overtimeTurnsLeft,
    drawn: drawn ?? this.drawn,
    endedOnTime: endedOnTime ?? this.endedOnTime,
  );

  /// Sérialisation. Le chronomètre est écrit en durée écoulée, pas en date :
  /// une partie reprise plus tard repart de la durée déjà jouée, pas de
  /// l'heure à laquelle l'application a été fermée.
  Map<String, dynamic> toJson({DateTime? now}) => {
    'version': kGameSaveVersion,
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
    'round_limit_s': roundLimit?.inSeconds,
    'time_called': timeCalled,
    'overtime_turns_left': overtimeTurnsLeft,
    'drawn': drawn,
    'ended_on_time': endedOnTime,
  };

  /// Relecture. Renvoie null si le fichier ne décrit pas une partie jouable
  /// (mode inconnu, aucun joueur) : mieux vaut repartir de la configuration.
  static GameState? fromJson(Object? source, {DateTime? now}) {
    if (source is! Map) return null;
    final json = Map<String, dynamic>.from(source);
    // Version du format : aucune migration à ce jour (les champs ajoutés ont
    // tous un repli). Une sauvegarde plus récente que l'application est
    // ignorée plutôt que relue de travers.
    final version = (json['version'] as num?)?.toInt() ?? kGameSaveVersion;
    if (version > kGameSaveVersion) return null;
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
    final limitSeconds = (json['round_limit_s'] as num?)?.toInt();
    return GameState(
      mode: mode,
      players: players,
      scores: _intMap(json['scores']),
      xp: _playerMap(json['xp']),
      roundsWon: _intMap(json['rounds_won']),
      turnOrder: order,
      turnIndex: ((json['turn_index'] as num?)?.toInt() ?? 0) % order.length,
      // Un numéro de tour ou de manche à zéro n'existe pas : une sauvegarde
      // bricolée repart de 1 plutôt que d'afficher « TOUR 0 ».
      turnNumber: ((json['turn_number'] as num?)?.toInt() ?? 1).clamp(1, 9999),
      round: ((json['round'] as num?)?.toInt() ?? 1).clamp(1, 999),
      startedAt: (now ?? DateTime.now()).subtract(
        Duration(microseconds: elapsed),
      ),
      winnerTeam: (json['winner_team'] as num?)?.toInt(),
      hintSeen: json['hint_seen'] == true,
      history: (json['history'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => GameMoment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      roundLimit: limitSeconds == null || limitSeconds <= 0
          ? null
          : Duration(seconds: limitSeconds),
      timeCalled: json['time_called'] == true,
      overtimeTurnsLeft: (json['overtime_turns_left'] as num?)?.toInt() ?? 0,
      drawn: json['drawn'] == true,
      // Sauvegarde d'avant ce champ : la manche n'a pas fini au temps.
      endedOnTime: json['ended_on_time'] == true,
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
