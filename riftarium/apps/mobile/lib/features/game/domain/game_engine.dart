import '../../cards/domain/card.dart';
import 'game_mode.dart';
import 'game_state.dart';
import 'player.dart';

/// Moteur du compteur : des fonctions pures qui prennent un état et en
/// renvoient un autre. Aucune dépendance à Flutter, au réseau ni au stockage,
/// pour que toutes les règles se testent directement.
abstract final class GameEngine {
  /// Profondeur de l'historique : de quoi annuler une série de fausses
  /// manipulations sans faire enfler la sauvegarde.
  static const historyLimit = 50;

  /// Le mot-clé « Niveau N » va de 1 à 6 sur les cartes actuelles (824) : six
  /// repères suffisent à lire d'un coup d'œil ce qu'une légende a débloqué.
  static const maxLevel = 6;

  /// Joueurs par défaut d'un mode : « Joueur 1 »… sans légende.
  static List<Player> defaultPlayers(GameMode mode) => [
    for (var seat = 0; seat < mode.playerCount; seat++)
      Player(
        id: 'p$seat',
        name: 'Joueur ${seat + 1}',
        seat: seat,
        team: mode.defaultTeam(seat),
      ),
  ];

  /// Ordre des tours. En 2c2 les équipes alternent (A, B, A, B) ; ailleurs on
  /// suit l'ordre des sièges.
  static List<String> turnOrderFor(GameMode mode, List<Player> players) {
    if (!mode.isTeamPlay) return [for (final player in players) player.id];
    final byTeam = <int, List<Player>>{};
    for (final player in players) {
      byTeam.putIfAbsent(player.team, () => []).add(player);
    }
    final teams = byTeam.keys.toList()..sort();
    final order = <String>[];
    var depth = 0;
    var remaining = true;
    while (remaining) {
      remaining = false;
      for (final team in teams) {
        final members = byTeam[team]!;
        if (depth >= members.length) continue;
        order.add(members[depth].id);
        remaining = true;
      }
      depth++;
    }
    return order;
  }

  /// Pivote l'ordre des tours pour commencer par `firstPlayerId`, ce qui
  /// préserve l'alternance en 2c2. Identifiant inconnu : ordre inchangé.
  static List<String> _rotated(List<String> order, String? firstPlayerId) {
    final start = firstPlayerId == null ? 0 : order.indexOf(firstPlayerId);
    return start <= 0
        ? order
        : [...order.sublist(start), ...order.sublist(0, start)];
  }

  /// Nouvelle partie. `firstPlayerId` est le joueur tiré au sort (ou, en
  /// tournoi, celui que le joueur désigné a choisi). `roundLimit` n'a de
  /// sens qu'en tournoi : durée de la ronde, null sans limite.
  static GameState start({
    required GameMode mode,
    required List<Player> players,
    String? firstPlayerId,
    DateTime? startedAt,
    Duration? roundLimit,
  }) {
    return GameState(
      mode: mode,
      players: players,
      scores: {for (final player in players) player.team: 0},
      xp: {for (final player in players) player.id: 0},
      roundsWon: {for (final player in players) player.team: 0},
      turnOrder: _rotated(turnOrderFor(mode, players), firstPlayerId),
      turnIndex: 0,
      turnNumber: 1,
      round: 1,
      startedAt: startedAt ?? DateTime.now(),
      roundLimit: mode.isTournament ? roundLimit : null,
    );
  }

  /// Ajoute (ou retire, si `delta` est négatif) des points au camp du joueur.
  /// Le score ne descend jamais sous zéro ; la victoire est réévaluée à chaque
  /// changement, comme au nettoyage (472). Une manche close au temps ne
  /// bouge plus : son résultat est acquis.
  static GameState addPoint(
    GameState state, {
    required String playerId,
    int delta = 1,
  }) {
    if (state.timedOut) return state;
    final player = state.playerById(playerId);
    final current = state.scoreOfTeam(player.team);
    final next = current + delta;
    if (next < 0) return state;
    final scores = Map<int, int>.from(state.scores)..[player.team] = next;
    return _settle(state, scores: scores, pushHistory: true);
  }

  static GameState removePoint(GameState state, {required String playerId}) =>
      addPoint(state, playerId: playerId, delta: -1);

  /// Exténuation (431.3.a) : piocher dans un deck vide donne un point à un
  /// adversaire. Un coéquipier n'est pas un adversaire : rien ne bouge alors.
  static GameState exhaustion(
    GameState state, {
    required String fromPlayerId,
    required String toPlayerId,
  }) {
    final from = state.playerById(fromPlayerId);
    final to = state.playerById(toPlayerId);
    if (from.team == to.team) return state;
    return addPoint(state, playerId: to.id);
  }

  /// Gagne de l'XP (mot-clé « Chasse X » : +X en conquérant ou en occupant).
  /// L'XP appartient au joueur seul : en 2c2, le coéquipier ne reçoit rien.
  static GameState addXp(
    GameState state, {
    required String playerId,
    int amount = 1,
  }) {
    final player = state.playerById(playerId);
    final next = state.xpOf(player) + amount;
    if (next < 0) return state;
    return state.copyWith(
      xp: Map<String, int>.from(state.xp)..[player.id] = next,
      history: _pushed(state),
    );
  }

  /// Dépense de l'XP. Jamais en dessous de zéro : une dépense trop grande est
  /// ignorée plutôt que de laisser un compte faux sur la table.
  static GameState spendXp(
    GameState state, {
    required String playerId,
    int amount = 1,
  }) => addXp(state, playerId: playerId, amount: -amount);

  /// Fixe directement l'XP d'un joueur (saisie dans sa feuille).
  static GameState setXp(
    GameState state, {
    required String playerId,
    required int value,
  }) {
    if (value < 0) return state;
    final player = state.playerById(playerId);
    if (state.xpOf(player) == value) return state;
    return state.copyWith(
      xp: Map<String, int>.from(state.xp)..[player.id] = value,
      history: _pushed(state),
    );
  }

  /// Passe la main au joueur suivant dans l'ordre du mode.
  ///
  /// Tournoi, temps écoulé (RT 408.2) : le tour en cours s'achève, puis trois
  /// tours supplémentaires ; au bout du dernier, la manche s'arrête. Deux
  /// points d'avance ou plus l'emportent, sinon égalité.
  static GameState nextTurn(GameState state) {
    if (state.drawn) return state;
    if (state.timeCalled) {
      final left = state.overtimeTurnsLeft - 1;
      if (left <= 0) return _timeOut(state);
      return state.copyWith(
        turnIndex: (state.turnIndex + 1) % state.turnOrder.length,
        turnNumber: state.turnNumber + 1,
        overtimeTurnsLeft: left,
        history: _pushed(state),
      );
    }
    return state.copyWith(
      turnIndex: (state.turnIndex + 1) % state.turnOrder.length,
      turnNumber: state.turnNumber + 1,
      history: _pushed(state),
    );
  }

  /// Tournoi : la fin du temps est annoncée. Le tour en cours compte, puis
  /// [kTournamentExtraTurns] tours supplémentaires. Entre deux manches, aucune
  /// nouvelle manche n'est lancée (RT 408.2.d) : le match se clôt aussitôt.
  /// Sans effet hors tournoi ou si le temps est déjà annoncé. Ne s'annule pas.
  static GameState callTime(GameState state) {
    if (!state.mode.isTournament || state.timeCalled) return state;
    return state.copyWith(
      timeCalled: true,
      overtimeTurnsLeft: state.isOver ? 0 : kTournamentExtraTurns + 1,
    );
  }

  /// Fin de manche au temps (RT 408.2.b) : le camp qui a
  /// [kTournamentTimeLead] points d'avance ou plus gagne ; sinon égalité.
  static GameState _timeOut(GameState state) {
    int? leader;
    var lead = 0;
    for (final team in state.teams) {
      final mine = state.scoreOfTeam(team);
      final others = [
        for (final other in state.teams)
          if (other != team) state.scoreOfTeam(other),
      ];
      final best = others.isEmpty ? 0 : others.reduce((a, b) => a > b ? a : b);
      if (mine - best >= kTournamentTimeLead && mine - best > lead) {
        leader = team;
        lead = mine - best;
      }
    }
    if (leader == null) {
      return state.copyWith(
        overtimeTurnsLeft: 0,
        drawn: true,
        history: _pushed(state),
      );
    }
    final rounds = Map<int, int>.from(state.roundsWon)
      ..[leader] = (state.roundsWon[leader] ?? 0) + 1;
    return state.copyWith(
      overtimeTurnsLeft: 0,
      winnerTeam: leader,
      roundsWon: rounds,
      history: _pushed(state),
    );
  }

  /// Camp qui l'emporte : il atteint le score de victoire *et* devance
  /// strictement tous les autres (472). Une égalité à 8 ne gagne pas.
  static int? checkVictory(GameState state, {Map<int, int>? scores}) {
    final table = scores ?? state.scores;
    int? best;
    var bestScore = -1;
    var tied = false;
    for (final team in state.teams) {
      final score = table[team] ?? 0;
      if (score > bestScore) {
        bestScore = score;
        best = team;
        tied = false;
      } else if (score == bestScore) {
        tied = true;
      }
    }
    if (best == null || tied) return null;
    return bestScore >= state.mode.victoryScore ? best : null;
  }

  /// Manche suivante : les scores et l'XP repartent de zéro, les manches
  /// gagnées et les joueurs restent. L'historique est vidé (on n'annule pas
  /// au-delà d'une manche). `firstPlayerId` (tournoi : le choix du perdant,
  /// RT 407.4) fait commencer ce joueur ; sinon l'ordre reste celui de la
  /// manche précédente. Une fois le temps annoncé, plus de nouvelle manche.
  static GameState newRound(GameState state, {String? firstPlayerId}) {
    if (state.mode.isTournament && state.timeCalled) return state;
    return state.copyWith(
      scores: {for (final team in state.teams) team: 0},
      xp: {for (final player in state.players) player.id: 0},
      turnOrder: _rotated(state.turnOrder, firstPlayerId),
      turnIndex: 0,
      turnNumber: 1,
      round: state.round + 1,
      clearWinner: true,
      drawn: false,
      history: const [],
    );
  }

  /// Annule la dernière action comptée (point, tour, exténuation). L'annonce
  /// du temps ne s'annule jamais : le compte des tours supplémentaires
  /// revient en arrière, pas l'horloge.
  static GameState undo(GameState state) {
    if (state.history.isEmpty) return state;
    final history = List<GameMoment>.from(state.history);
    final moment = history.removeLast();
    return state.copyWith(
      scores: moment.scores,
      xp: moment.xp,
      roundsWon: moment.roundsWon,
      turnIndex: moment.turnIndex,
      turnNumber: moment.turnNumber,
      winnerTeam: moment.winnerTeam,
      clearWinner: moment.winnerTeam == null,
      timeCalled: state.timeCalled || moment.timeCalled,
      overtimeTurnsLeft: moment.timeCalled
          ? moment.overtimeTurnsLeft
          : state.overtimeTurnsLeft,
      drawn: moment.drawn,
      history: history,
    );
  }

  /// Remet la partie à zéro sans quitter la table : mêmes joueurs, même mode,
  /// même limite de temps ; l'horloge de la ronde repart.
  static GameState reset(GameState state, {DateTime? startedAt}) => start(
    mode: state.mode,
    players: state.players,
    firstPlayerId: state.turnOrder.first,
    startedAt: startedAt,
    roundLimit: state.roundLimit,
  );

  /// Renomme un joueur ou lui change sa légende, sans toucher au compte.
  static GameState updatePlayer(
    GameState state, {
    required String playerId,
    String? name,
    RiftCard? legend,
    bool clearLegend = false,
  }) => state.copyWith(
    players: [
      for (final player in state.players)
        if (player.id == playerId)
          player.copyWith(name: name, legend: legend, clearLegend: clearLegend)
        else
          player,
    ],
  );

  /// Réévalue la victoire après un changement de score et tient à jour les
  /// manches gagnées : gagner en ajoute une, annuler la reprend.
  static GameState _settle(
    GameState state, {
    required Map<int, int> scores,
    required bool pushHistory,
  }) {
    final previous = state.winnerTeam;
    final winner = checkVictory(state, scores: scores);
    var rounds = state.roundsWon;
    if (winner != previous) {
      rounds = Map<int, int>.from(rounds);
      if (previous != null) {
        rounds[previous] = ((rounds[previous] ?? 1) - 1).clamp(0, 99);
      }
      if (winner != null) rounds[winner] = (rounds[winner] ?? 0) + 1;
    }
    return state.copyWith(
      scores: scores,
      roundsWon: rounds,
      winnerTeam: winner,
      clearWinner: winner == null,
      history: pushHistory ? _pushed(state) : state.history,
    );
  }

  static List<GameMoment> _pushed(GameState state) {
    final history = [...state.history, state.moment];
    if (history.length <= historyLimit) return history;
    return history.sublist(history.length - historyLimit);
  }
}
