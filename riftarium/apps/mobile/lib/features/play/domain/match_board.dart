import '../../game/domain/game_engine.dart';
import '../../game/domain/game_state.dart';
import '../../game/domain/player.dart';
import 'match.dart';

/// Pont entre le match suivi (côté serveur) et la table du compteur (côté
/// appareil). Le serveur ne connaît que des identifiants de compte ; le moteur
/// ne connaît que des sièges et des camps. En duel comme en match, chaque
/// joueur est son propre camp : `team == seat`, la conversion reste directe.

/// Identifiant de joueur du moteur pour un compte.
String playerIdOf(int userId) => '$userId';

/// Compte correspondant à un joueur du moteur.
int? userIdOf(String playerId) => int.tryParse(playerId);

/// Reconstruit la table à partir de l'instantané du serveur.
GameState boardOfMatch(Match match, {DateTime? now}) {
  final mode = match.gameMode;
  final seats = [...match.players]..sort((a, b) => a.seat.compareTo(b.seat));
  final players = [
    for (final seat in seats)
      Player(
        id: playerIdOf(seat.user.id),
        name: seat.user.displayName,
        seat: seat.seat,
        team: mode.defaultTeam(seat.seat),
        legend: seat.legend,
      ),
  ];
  if (players.isEmpty) {
    // Match sans joueur lisible : la table repart des valeurs par défaut
    // plutôt que de lever (l'écran affichera l'erreur du chargement).
    return GameEngine.start(mode: mode, players: GameEngine.defaultPlayers(mode));
  }

  final order = [for (final player in players) player.id];
  final firstIndex = order.indexOf(playerIdOf(match.firstPlayerId));
  final rotated = firstIndex <= 0
      ? order
      : [...order.sublist(firstIndex), ...order.sublist(0, firstIndex)];

  final snapshot = match.state;
  final active = snapshot.activeUserId;
  final activeIndex = active == null
      ? 0
      : rotated.indexOf(playerIdOf(active)).clamp(0, rotated.length - 1);

  final board = GameState(
    mode: mode,
    players: players,
    scores: {
      for (final seat in seats)
        mode.defaultTeam(seat.seat): snapshot.scoreOf(seat.user.id),
    },
    xp: {
      for (final seat in seats)
        playerIdOf(seat.user.id): snapshot.xpOf(seat.user.id),
    },
    roundsWon: {
      for (final seat in seats)
        mode.defaultTeam(seat.seat): snapshot.roundsWonBy(seat.user.id),
    },
    turnOrder: rotated,
    turnIndex: activeIndex < 0 ? 0 : activeIndex,
    turnNumber: snapshot.turn < 1 ? 1 : snapshot.turn,
    round: snapshot.round < 1 ? 1 : snapshot.round,
    startedAt: match.startedAt?.toLocal() ?? now ?? DateTime.now(),
    // Le rappel du premier tour a déjà été lu dans le salon.
    hintSeen: true,
  );
  final winner = GameEngine.checkVictory(board);
  return winner == null ? board : board.copyWith(winnerTeam: winner);
}

/// Instantané à envoyer au serveur pour la table courante.
MatchState stateOfBoard(GameState board, Match match) {
  final mode = match.gameMode;
  return MatchState(
    round: board.round,
    turn: board.turnNumber,
    activeUserId: userIdOf(board.activePlayer.id),
    scores: {
      for (final player in match.players)
        player.user.id: board.scoreOfTeam(mode.defaultTeam(player.seat)),
    },
    xp: {
      for (final player in match.players)
        player.user.id: board.xp[playerIdOf(player.user.id)] ?? 0,
    },
    roundsWon: {
      for (final player in match.players)
        player.user.id: board.roundsWonBy(mode.defaultTeam(player.seat)),
    },
  );
}

/// Compte vainqueur de la table, ou null tant que personne n'a gagné.
int? winnerUserIdOf(GameState board, Match match) {
  final team = board.winnerTeam;
  if (team == null) return null;
  final mode = match.gameMode;
  for (final player in match.players) {
    if (mode.defaultTeam(player.seat) == team) return player.user.id;
  }
  return null;
}

/// Corps `result` de `POST /matches/{id}/finish` : scores et manches finaux.
Map<String, dynamic> resultOfBoard(GameState board, Match match) {
  final snapshot = stateOfBoard(board, match);
  return {
    'scores': {
      for (final entry in snapshot.scores.entries) '${entry.key}': entry.value,
    },
    'rounds_won': {
      for (final entry in snapshot.roundsWon.entries)
        '${entry.key}': entry.value,
    },
  };
}

/// La rencontre est jouée : score de victoire atteint et, en mode `match`, le
/// nombre de manches gagnantes aussi.
bool isMatchDecided(GameState board) => board.isMatchOver;
