import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/game/domain/game_engine.dart';
import 'package:riftarium_mobile/features/game/domain/game_mode.dart';
import 'package:riftarium_mobile/features/game/domain/game_state.dart';

GameState fresh(GameMode mode) =>
    GameEngine.start(mode: mode, players: GameEngine.defaultPlayers(mode));

/// Marque `points` points au camp de `playerId`.
GameState score(GameState state, String playerId, int points) {
  var next = state;
  for (var index = 0; index < points; index++) {
    next = GameEngine.addPoint(next, playerId: playerId);
  }
  return next;
}

void main() {
  group('modes', () {
    test('chaque mode annonce ses joueurs, son score et ses manches', () {
      expect(GameMode.duel.playerCount, 2);
      expect(GameMode.duel.victoryScore, 8);
      expect(GameMode.duel.roundsToWin, 1);
      expect(GameMode.match.roundsToWin, 2);
      expect(GameMode.skirmish.playerCount, 3);
      expect(GameMode.war.playerCount, 4);
      expect(GameMode.magmaChamber.playerCount, 4);
      expect(GameMode.magmaChamber.victoryScore, 11);
      expect(GameMode.magmaChamber.isTeamPlay, isTrue);
    });

    test('chaque mode rappelle ses ajustements de premier tour', () {
      for (final mode in GameMode.values) {
        expect(mode.firstTurnNotes, isNotEmpty);
      }
      expect(GameMode.duel.firstTurnNotes.first, contains('second joueur'));
      expect(GameMode.skirmish.firstTurnNotes.first, contains('ne pioche pas'));
    });
  });

  group('ordre des tours', () {
    test('en solo, les joueurs se suivent dans l’ordre des sièges', () {
      final state = fresh(GameMode.skirmish);
      expect(state.turnOrder, ['p0', 'p1', 'p2']);
      expect(state.activePlayer.id, 'p0');
      expect(state.turnNumber, 1);

      final second = GameEngine.nextTurn(state);
      expect(second.activePlayer.id, 'p1');
      expect(second.turnNumber, 2);

      final looped = GameEngine.nextTurn(GameEngine.nextTurn(second));
      expect(looped.activePlayer.id, 'p0');
      expect(looped.turnNumber, 4);
    });

    test('en 2c2, les équipes alternent', () {
      final state = fresh(GameMode.magmaChamber);
      expect(state.turnOrder, ['p0', 'p2', 'p1', 'p3']);
    });

    test('le tirage au sort fait commencer le joueur tiré', () {
      final mode = GameMode.war;
      final state = GameEngine.start(
        mode: mode,
        players: GameEngine.defaultPlayers(mode),
        firstPlayerId: 'p2',
      );
      expect(state.turnOrder, ['p2', 'p3', 'p0', 'p1']);
      expect(state.activePlayer.id, 'p2');
    });
  });

  group('points', () {
    test('un point n’appartient qu’au camp du joueur en solo', () {
      final state = score(fresh(GameMode.war), 'p1', 3);
      expect(state.scoreOf(state.playerById('p1')), 3);
      expect(state.scoreOf(state.playerById('p0')), 0);
      expect(state.scoreOf(state.playerById('p2')), 0);
    });

    test('en 2c2, les coéquipiers partagent le score', () {
      final state = score(fresh(GameMode.magmaChamber), 'p0', 4);
      expect(state.scoreOf(state.playerById('p0')), 4);
      expect(state.scoreOf(state.playerById('p1')), 4);
      expect(state.scoreOf(state.playerById('p2')), 0);
    });

    test('le score ne descend pas sous zéro', () {
      final state = GameEngine.removePoint(
        fresh(GameMode.duel),
        playerId: 'p0',
      );
      expect(state.scoreOf(state.playerById('p0')), 0);
      expect(state.canUndo, isFalse);
    });

    test('l’exténuation donne un point à un adversaire, jamais à un allié', () {
      final start = fresh(GameMode.magmaChamber);
      final given = GameEngine.exhaustion(
        start,
        fromPlayerId: 'p0',
        toPlayerId: 'p2',
      );
      expect(given.scoreOfTeam(1), 1);
      expect(given.scoreOfTeam(0), 0);

      final refused = GameEngine.exhaustion(
        start,
        fromPlayerId: 'p0',
        toPlayerId: 'p1',
      );
      expect(refused.scoreOfTeam(0), 0);
      expect(refused.canUndo, isFalse);
    });
  });

  group('victoire', () {
    test('huit points et une avance stricte l’emportent', () {
      final state = score(fresh(GameMode.duel), 'p0', 8);
      expect(state.winnerTeam, 0);
      expect(state.isOver, isTrue);
      expect(state.isMatchOver, isTrue);
    });

    test('une égalité au score de victoire ne gagne pas', () {
      var state = score(fresh(GameMode.duel), 'p0', 7);
      state = score(state, 'p1', 8);
      expect(state.winnerTeam, 1);

      state = GameEngine.addPoint(state, playerId: 'p0');
      expect(state.scoreOfTeam(0), 8);
      expect(state.winnerTeam, isNull, reason: '8 – 8 : personne ne l’emporte');

      state = GameEngine.addPoint(state, playerId: 'p0');
      expect(state.winnerTeam, 0);
    });

    test('la chambre magmatique se gagne à onze', () {
      var state = score(fresh(GameMode.magmaChamber), 'p0', 8);
      expect(state.winnerTeam, isNull);
      state = score(state, 'p0', 3);
      expect(state.scoreOfTeam(0), 11);
      expect(state.winnerTeam, 0);
    });

    test('perdre un point après la victoire remet la manche en jeu', () {
      var state = score(fresh(GameMode.duel), 'p0', 8);
      expect(state.roundsWonBy(0), 1);
      state = GameEngine.removePoint(state, playerId: 'p0');
      expect(state.winnerTeam, isNull);
      expect(state.roundsWonBy(0), 0);
    });
  });

  group('manches', () {
    test('un match se joue en deux manches gagnantes', () {
      var state = score(fresh(GameMode.match), 'p0', 8);
      expect(state.roundsWonBy(0), 1);
      expect(state.isMatchOver, isFalse);

      state = GameEngine.newRound(state);
      expect(state.round, 2);
      expect(state.scoreOfTeam(0), 0);
      expect(state.winnerTeam, isNull);
      expect(state.roundsWonBy(0), 1);
      expect(state.canUndo, isFalse);

      state = score(state, 'p0', 8);
      expect(state.roundsWonBy(0), 2);
      expect(state.isMatchOver, isTrue);
    });

    test('une nouvelle manche remet l’XP à zéro', () {
      var state = GameEngine.addXp(
        fresh(GameMode.match),
        playerId: 'p0',
        amount: 4,
      );
      state = GameEngine.newRound(state);
      expect(state.xpOf(state.playerById('p0')), 0);
    });
  });

  group('annuler', () {
    test('annuler revient sur le dernier point compté', () {
      var state = score(fresh(GameMode.duel), 'p0', 2);
      expect(state.canUndo, isTrue);
      state = GameEngine.undo(state);
      expect(state.scoreOfTeam(0), 1);
      state = GameEngine.undo(state);
      expect(state.scoreOfTeam(0), 0);
      expect(state.canUndo, isFalse);
      expect(GameEngine.undo(state).scoreOfTeam(0), 0);
    });

    test('annuler défait aussi la victoire et le tour', () {
      var state = score(fresh(GameMode.duel), 'p0', 8);
      state = GameEngine.undo(state);
      expect(state.winnerTeam, isNull);
      expect(state.roundsWonBy(0), 0);

      final turned = GameEngine.nextTurn(state);
      expect(GameEngine.undo(turned).activePlayer.id, state.activePlayer.id);
      expect(GameEngine.undo(turned).turnNumber, state.turnNumber);
    });

    test('l’historique reste borné', () {
      var state = fresh(GameMode.duel);
      for (var index = 0; index < GameEngine.historyLimit + 20; index++) {
        state = GameEngine.nextTurn(state);
      }
      expect(state.history.length, GameEngine.historyLimit);
    });
  });

  group('xp', () {
    test('gagner et dépenser de l’XP, sans passer sous zéro', () {
      var state = GameEngine.addXp(
        fresh(GameMode.duel),
        playerId: 'p0',
        amount: 3,
      );
      expect(state.xpOf(state.playerById('p0')), 3);

      state = GameEngine.spendXp(state, playerId: 'p0', amount: 2);
      expect(state.xpOf(state.playerById('p0')), 1);

      final refused = GameEngine.spendXp(state, playerId: 'p0', amount: 5);
      expect(refused.xpOf(refused.playerById('p0')), 1);
    });

    test('l’XP n’est pas partagée entre coéquipiers', () {
      final state = GameEngine.addXp(
        fresh(GameMode.magmaChamber),
        playerId: 'p0',
        amount: 6,
      );
      expect(state.xpOf(state.playerById('p0')), 6);
      expect(state.xpOf(state.playerById('p1')), 0);
      // Les points, eux, restent communs.
      final scored = GameEngine.addPoint(state, playerId: 'p0');
      expect(scored.scoreOf(scored.playerById('p1')), 1);
    });

    test('annuler rend l’XP dépensée', () {
      var state = GameEngine.addXp(
        fresh(GameMode.duel),
        playerId: 'p0',
        amount: 2,
      );
      state = GameEngine.spendXp(state, playerId: 'p0');
      expect(state.xpOf(state.playerById('p0')), 1);
      state = GameEngine.undo(state);
      expect(state.xpOf(state.playerById('p0')), 2);
    });

    test('la saisie directe fixe la réserve', () {
      final state = GameEngine.setXp(
        fresh(GameMode.duel),
        playerId: 'p1',
        value: 5,
      );
      expect(state.xpOf(state.playerById('p1')), 5);
      expect(GameEngine.undo(state).xpOf(state.playerById('p1')), 0);
      expect(
        GameEngine.setXp(state, playerId: 'p1', value: -1),
        same(state),
        reason: 'une valeur négative est refusée',
      );
    });
  });
}
