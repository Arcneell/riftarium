import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/game/domain/game_engine.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';
import 'package:riftarium_mobile/features/game/domain/game_state.dart';

/// Match de tournoi frais, ronde de 60 minutes, démarré à `startedAt`.
GameState fresh({
  DateTime? startedAt,
  Duration? limit = kTournamentRoundLimit,
}) => GameEngine.start(
  mode: GameMode.tournament,
  players: GameEngine.defaultPlayers(GameMode.tournament),
  startedAt: startedAt,
  roundLimit: limit,
);

GameState score(GameState state, String playerId, int points) {
  var next = state;
  for (var index = 0; index < points; index++) {
    next = GameEngine.addPoint(next, playerId: playerId);
  }
  return next;
}

GameState turns(GameState state, int count) {
  var next = state;
  for (var index = 0; index < count; index++) {
    next = GameEngine.nextTurn(next);
  }
  return next;
}

void main() {
  group('mode tournoi', () {
    test(
      'deux joueurs, 8 points, deux manches gagnantes, règles de tournoi',
      () {
        expect(GameMode.tournament.playerCount, 2);
        expect(GameMode.tournament.victoryScore, 8);
        expect(GameMode.tournament.roundsToWin, 2);
        expect(GameMode.tournament.isTournament, isTrue);
        expect(GameMode.tournament.isTeamPlay, isFalse);
        expect(GameMode.byId('tournament'), GameMode.tournament);
        for (final mode in GameMode.values) {
          if (mode != GameMode.tournament) expect(mode.isTournament, isFalse);
        }
      },
    );

    test('la limite de ronde ne s’applique qu’au tournoi', () {
      expect(fresh().roundLimit, kTournamentRoundLimit);
      expect(fresh(limit: null).roundLimit, isNull);
      final duel = GameEngine.start(
        mode: GameMode.duel,
        players: GameEngine.defaultPlayers(GameMode.duel),
        roundLimit: kTournamentRoundLimit,
      );
      expect(duel.roundLimit, isNull);
    });

    test('le temps restant décroît puis s’arrête à zéro', () {
      final start = DateTime.utc(2026, 9, 3, 14);
      final state = fresh(startedAt: start);
      expect(
        state.remainingTime(start.add(const Duration(minutes: 20))),
        const Duration(minutes: 40),
      );
      expect(
        state.remainingTime(start.add(const Duration(minutes: 75))),
        Duration.zero,
      );
      expect(fresh(limit: null).remainingTime(start), isNull);
    });
  });

  group('joueur désigné et perdant qui choisit', () {
    test('le joueur désigné peut faire commencer l’adversaire', () {
      final state = GameEngine.start(
        mode: GameMode.tournament,
        players: GameEngine.defaultPlayers(GameMode.tournament),
        firstPlayerId: 'p1',
      );
      expect(state.turnOrder, ['p1', 'p0']);
      expect(state.activePlayer.id, 'p1');
    });

    test('la manche suivante commence par le joueur choisi', () {
      var state = score(fresh(), 'p0', 8);
      expect(state.isOver, isTrue);
      expect(state.isMatchOver, isFalse);
      state = GameEngine.newRound(state, firstPlayerId: 'p1');
      expect(state.round, 2);
      expect(state.turnOrder, ['p1', 'p0']);
      expect(state.activePlayer.id, 'p1');
      expect(state.scoreOfTeam(0), 0);
      expect(state.roundsWonBy(0), 1);
    });

    test('sans choix, l’ordre de la manche précédente est gardé', () {
      var state = score(fresh(), 'p1', 8);
      state = GameEngine.newRound(state);
      expect(state.turnOrder, ['p0', 'p1']);
    });
  });

  group('fin du temps (RT 408.2)', () {
    test('l’annonce laisse finir le tour puis trois tours supplémentaires', () {
      var state = GameEngine.callTime(fresh());
      expect(state.timeCalled, isTrue);
      expect(state.overtimeTurnsLeft, kTournamentExtraTurns + 1);
      expect(state.isOver, isFalse);

      state = turns(state, 3);
      expect(state.overtimeTurnsLeft, 1);
      expect(state.isOver, isFalse);
      expect(state.turnNumber, 4);
    });

    test('deux points d’avance au temps gagnent la manche et le match', () {
      var state = score(fresh(), 'p0', 5);
      state = score(state, 'p1', 3);
      state = GameEngine.callTime(state);
      state = turns(state, 4);
      expect(state.isOver, isTrue);
      expect(state.timedOut, isTrue);
      expect(state.winnerTeam, 0);
      expect(state.drawn, isFalse);
      expect(state.roundsWonBy(0), 1);
      expect(state.isMatchOver, isTrue);
      expect(state.matchWinnerTeam, 0);
      expect(state.isMatchDrawn, isFalse);
    });

    test('un seul point d’écart au temps : égalité, puis match nul', () {
      var state = score(fresh(), 'p0', 6);
      state = score(state, 'p1', 5);
      state = GameEngine.callTime(state);
      state = turns(state, 4);
      expect(state.isOver, isTrue);
      expect(state.drawn, isTrue);
      expect(state.winnerTeam, isNull);
      expect(state.roundsWonBy(0), 0);
      expect(state.roundsWonBy(1), 0);
      expect(state.isMatchOver, isTrue);
      expect(state.isMatchDrawn, isTrue);
      // Plus rien ne bouge : ni point ni tour ni nouvelle manche.
      expect(GameEngine.addPoint(state, playerId: 'p0'), same(state));
      expect(GameEngine.nextTurn(state), same(state));
      expect(GameEngine.newRound(state), same(state));
    });

    test('égalité au temps : le plus de manches gagnées l’emporte', () {
      var state = score(fresh(), 'p1', 8);
      state = GameEngine.newRound(state, firstPlayerId: 'p0');
      state = score(state, 'p0', 4);
      state = score(state, 'p1', 4);
      state = GameEngine.callTime(state);
      state = turns(state, 4);
      expect(state.drawn, isTrue);
      expect(state.isMatchOver, isTrue);
      expect(state.matchWinnerTeam, 1);
    });

    test(
      'une victoire à 8 pendant les tours supplémentaires clôt le match',
      () {
        var state = score(fresh(), 'p0', 7);
        state = GameEngine.callTime(state);
        state = GameEngine.nextTurn(state);
        state = GameEngine.addPoint(state, playerId: 'p0');
        expect(state.winnerTeam, 0);
        expect(state.timedOut, isFalse);
        // 1–0 aux manches, plus de nouvelle manche : le match est gagné.
        expect(state.isMatchOver, isTrue);
        expect(state.matchWinnerTeam, 0);
      },
    );

    test('entre deux manches, aucune nouvelle manche n’est lancée', () {
      var state = score(fresh(), 'p0', 8);
      state = GameEngine.callTime(state);
      expect(state.overtimeTurnsLeft, 0);
      expect(state.isMatchOver, isTrue);
      expect(state.matchWinnerTeam, 0);
      expect(GameEngine.newRound(state, firstPlayerId: 'p1'), same(state));
    });

    test('hors tournoi, l’annonce du temps ne fait rien', () {
      final duel = GameEngine.start(
        mode: GameMode.match,
        players: GameEngine.defaultPlayers(GameMode.match),
      );
      expect(GameEngine.callTime(duel), same(duel));
    });

    test('annuler recule les tours supplémentaires, jamais l’annonce', () {
      var state = score(fresh(), 'p0', 2);
      state = GameEngine.callTime(state);
      state = turns(state, 2);
      expect(state.overtimeTurnsLeft, 2);

      state = GameEngine.undo(state);
      expect(state.timeCalled, isTrue);
      expect(state.overtimeTurnsLeft, 3);

      // Remonter avant l'annonce garde le temps annoncé et son décompte.
      state = GameEngine.undo(GameEngine.undo(state));
      expect(state.scoreOfTeam(0), 1);
      expect(state.timeCalled, isTrue);
      expect(state.overtimeTurnsLeft, 4);
    });

    test('annuler la fin au temps rend la manche en cours', () {
      var state = score(fresh(), 'p0', 6);
      state = score(state, 'p1', 5);
      state = GameEngine.callTime(state);
      state = turns(state, 4);
      expect(state.drawn, isTrue);
      state = GameEngine.undo(state);
      expect(state.drawn, isFalse);
      expect(state.isOver, isFalse);
      expect(state.overtimeTurnsLeft, 1);
    });
  });

  group('sauvegarde', () {
    test('la limite, l’annonce et l’égalité font l’aller-retour JSON', () {
      final now = DateTime.utc(2026, 9, 3, 15);
      var state = score(fresh(startedAt: now), 'p0', 6);
      state = score(state, 'p1', 5);
      state = GameEngine.callTime(state);
      state = turns(state, 4);
      final later = now.add(const Duration(minutes: 30));
      final json = state.toJson(now: later);
      final back = GameState.fromJson(json, now: later)!;
      expect(back.mode, GameMode.tournament);
      expect(back.roundLimit, kTournamentRoundLimit);
      expect(back.timeCalled, isTrue);
      expect(back.overtimeTurnsLeft, 0);
      expect(back.drawn, isTrue);
      expect(back.isMatchDrawn, isTrue);
      expect(back.remainingTime(later), const Duration(minutes: 30));
      expect(back.history.last.timeCalled, isTrue);
    });

    test('une sauvegarde d’avant le tournoi se relit sans ces champs', () {
      final json =
          GameEngine.start(
            mode: GameMode.duel,
            players: GameEngine.defaultPlayers(GameMode.duel),
          ).toJson()..removeWhere(
            (key, _) => const {
              'round_limit_s',
              'time_called',
              'overtime_turns_left',
              'drawn',
            }.contains(key),
          );
      final back = GameState.fromJson(json)!;
      expect(back.roundLimit, isNull);
      expect(back.timeCalled, isFalse);
      expect(back.drawn, isFalse);
    });
  });
}
