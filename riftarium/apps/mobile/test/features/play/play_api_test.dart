import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/play/data/play_api.dart';
import 'package:riftarium_mobile/features/play/domain/match.dart';

import 'support/play_fixtures.dart';

void main() {
  ({PlayApi api, PlayFakeApi server}) build(Map<String, Object> routes) {
    final server = PlayFakeApi(routes);
    return (
      api: PlayApi(
        createApiClient(
          readToken: () async => 'jwt',
          baseUrl: 'https://api.test/api',
          adapter: server,
        ),
      ),
      server: server,
    );
  }

  group('salons', () {
    test('createRoom poste le format et lit le code', () async {
      final fake = build({
        'POST /play/rooms': roomJson(code: 'KJ7Z2M', mode: 'match'),
      });

      final room = await fake.api.createRoom(mode: 'match');

      expect(fake.server.paths, ['POST /play/rooms']);
      expect(fake.server.calls.single.body, {'mode': 'match'});
      expect(room.code, 'KJ7Z2M');
      expect(room.modeLabel, 'Match');
      expect(room.roundsToWin, 2);
      expect(room.isOpen, isTrue);
    });

    test('room lit les deux sièges, la légende et le deck', () async {
      final fake = build({
        'GET /play/rooms/ABC234': roomJson(
          players: [
            roomPlayerJson(ready: true, legend: legendJson()),
            roomPlayerJson(
              userId: 8,
              handle: 'jinx',
              seat: 1,
              deck: playDeckJson(name: 'Jinx agro', format: 'free'),
            ),
          ],
        ),
      });

      final room = await fake.api.room('ABC234');

      expect(fake.server.paths, ['GET /play/rooms/ABC234']);
      expect(room.host?.user.handle, 'ezreal');
      expect(room.host?.legend?.name, 'Ahri');
      expect(room.host?.ready, isTrue);
      expect(room.guest?.user.id, 8);
      expect(room.guest?.deck?.name, 'Jinx agro');
      expect(room.guest?.deck?.formatLabel, 'Libre');
      expect(room.bothReady, isFalse);
    });

    test('updateMe envoie toujours les trois champs', () async {
      final fake = build({'PUT /play/rooms/ABC234/me': roomJson()});

      await fake.api.updateMe(
        'ABC234',
        legendCardId: 'OGN-001',
        deckId: null,
        ready: true,
      );

      final call = fake.server.last('PUT', '/play/rooms/ABC234/me')!;
      expect(call.body, {
        'legend_card_id': 'OGN-001',
        'deck_id': null,
        'ready': true,
      });
    });

    test('join, leave et delete rendent le salon à jour', () async {
      final fake = build({
        'POST /play/rooms/ABC234/join': roomJson(
          players: [roomPlayerJson(), roomPlayerJson(userId: 8, seat: 1)],
        ),
        'POST /play/rooms/ABC234/leave': roomJson(),
        'DELETE /play/rooms/ABC234': roomJson(status: 'cancelled'),
      });

      expect((await fake.api.joinRoom('ABC234')).players.length, 2);
      expect((await fake.api.leaveRoom('ABC234'))?.players.length, 1);
      expect((await fake.api.cancelRoom('ABC234'))?.isCancelled, isTrue);
      expect(fake.server.paths, [
        'POST /play/rooms/ABC234/join',
        'POST /play/rooms/ABC234/leave',
        'DELETE /play/rooms/ABC234',
      ]);
    });

    test('start poste le premier joueur et renvoie le match', () async {
      final fake = build({'POST /play/rooms/ABC234/start': matchJson()});

      final match = await fake.api.startMatch('ABC234', firstPlayerId: 8);

      expect(fake.server.calls.single.body, {'first_player_id': 8});
      expect(match.id, 1);
      expect(match.isLive, isTrue);
      expect(match.players.map((player) => player.user.handle), [
        'ezreal',
        'jinx',
      ]);
    });

    test('un salon plein remonte le message de l’API', () async {
      final fake = build({
        'POST /play/rooms/ABC234/join': const PlayFakeError(
          409,
          'Ce salon est déjà complet.',
        ),
      });

      await expectLater(
        fake.api.joinRoom('ABC234'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                'Ce salon est déjà complet.',
              ),
        ),
      );
    });
  });

  group('matchs', () {
    test('match lit l’instantané du compteur', () async {
      final fake = build({
        'GET /play/matches/1': matchJson(
          state: matchStateJson(
            round: 2,
            turn: 5,
            activeUserId: 8,
            scores: {'7': 3, '8': 1},
            xp: {'7': 2, '8': 0},
            roundsWon: {'7': 1, '8': 0},
          ),
        ),
      });

      final match = await fake.api.match(1);

      expect(match.state.round, 2);
      expect(match.state.turn, 5);
      expect(match.state.activeUserId, 8);
      expect(match.state.scoreOf(7), 3);
      expect(match.state.xpOf(7), 2);
      expect(match.state.roundsWonBy(7), 1);
      expect(match.version, 3);
    });

    test('putState envoie la version et les clés en chaîne', () async {
      final fake = build({'PUT /play/matches/1/state': matchJson(version: 4)});

      final match = await fake.api.putState(
        1,
        version: 3,
        state: const MatchState(
          round: 1,
          turn: 4,
          activeUserId: 7,
          scores: {7: 2, 8: 1},
          xp: {7: 0, 8: 3},
          roundsWon: {7: 0, 8: 0},
        ),
      );

      final call = fake.server.calls.single;
      expect(call.body['version'], 3);
      expect(call.body['state'], {
        'round': 1,
        'turn': 4,
        'active_user_id': 7,
        'scores': {'7': 2, '8': 1},
        'xp': {'7': 0, '8': 3},
        'rounds_won': {'7': 0, '8': 0},
      });
      expect(match.version, 4);
    });

    test('une version périmée remonte un 409', () async {
      final fake = build({
        'PUT /play/matches/1/state': const PlayFakeError(
          409,
          'Le compteur a changé entre-temps.',
        ),
      });

      await expectLater(
        fake.api.putState(1, version: 1, state: const MatchState()),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 409),
        ),
      );
    });

    test(
      'finish poste le vainqueur et un résultat de la forme de state',
      () async {
        final fake = build({
          'POST /play/matches/1/finish': matchJson(
            status: 'awaiting_confirmation',
            winnerUserId: 7,
          ),
        });

        final match = await fake.api.finish(
          1,
          winnerUserId: 7,
          result: const MatchState(
            round: 1,
            turn: 12,
            activeUserId: 7,
            scores: {7: 8, 8: 5},
            xp: {7: 4, 8: 2},
            roundsWon: {7: 1, 8: 0},
          ).toJson(),
        );

        final call = fake.server.calls.single;
        expect(call.body['winner_user_id'], 7);
        expect(
          (call.body['result'] as Map).keys,
          containsAll(<String>[
            'round',
            'turn',
            'active_user_id',
            'scores',
            'xp',
            'rounds_won',
          ]),
        );
        expect(match.isAwaitingConfirmation, isTrue);
        expect(match.statusLabel, 'En attente de confirmation');
      },
    );

    test('confirm, dispute et abandon visent les bons chemins', () async {
      final fake = build({
        'POST /play/matches/1/confirm': matchJson(status: 'confirmed'),
        'POST /play/matches/1/dispute': matchJson(status: 'disputed'),
        'POST /play/matches/1/abandon': matchJson(status: 'abandoned'),
      });

      expect((await fake.api.confirm(1)).isConfirmed, isTrue);
      expect((await fake.api.dispute(1)).isDisputed, isTrue);
      expect((await fake.api.abandon(1)).isAbandoned, isTrue);
      expect(fake.server.paths, [
        'POST /play/matches/1/confirm',
        'POST /play/matches/1/dispute',
        'POST /play/matches/1/abandon',
      ]);
    });
  });

  group('historique, statistiques et reprise', () {
    test('history pagine et lit adversaire, légendes et decks', () async {
      final fake = build({
        'GET /play/history': historyPageJson(
          items: [
            historyItemJson(),
            historyItemJson(
              matchId: 2,
              outcome: 'loss',
              status: 'abandoned',
              anonymousOpponent: true,
            ),
          ],
          total: 12,
        ),
      });

      final page = await fake.api.history(page: 2, size: 50);

      expect(fake.server.calls.single.query, {'page': 2, 'size': 50});
      expect(page.total, 12);
      expect(page.items.length, 2);
      final first = page.items.first;
      expect(first.opponent?.handle, 'jinx');
      expect(first.myLegend?.name, 'Ahri');
      expect(first.opponentDeck?.name, 'Jinx agro');
      expect(first.outcomeLabel, 'Victoire');
      expect(first.scoreLabel, '8 – 5');
      // Compte supprimé : la ligne reste, l'adversaire disparaît.
      expect(page.items[1].opponent, isNull);
      expect(page.items[1].isLoss, isTrue);
    });

    test('stats lit les totaux, les decks et les 30 derniers jours', () async {
      final fake = build({'GET /play/stats': statsJson()});

      final stats = await fake.api.stats();

      expect(stats.totals.played, 10);
      expect(stats.totals.winRateLabel, '60 %');
      expect(stats.totals.bestStreak, 4);
      expect(stats.byFormat.first.label, 'Duel');
      expect(stats.byDeck.single.name, 'Ahri contrôle');
      expect(stats.byLegend.single.name, 'Ahri');
      expect(stats.byOpponentLegend.single.name, 'Jinx');
      expect(stats.recent.length, 3);
      expect(stats.recent.last.day, '2026-08-27');
    });

    test('current renvoie un salon, un match, ou rien', () async {
      final fake = build({
        'GET /play/current': currentPlayJson(
          room: roomJson(status: 'playing', matchId: 1),
          match: matchJson(),
        ),
      });

      final current = await fake.api.current();
      expect(current.isEmpty, isFalse);
      expect(current.room?.matchId, 1);
      expect(current.match?.id, 1);

      final empty = build({'GET /play/current': currentPlayJson()});
      expect((await empty.api.current()).isEmpty, isTrue);
    });
  });
}
