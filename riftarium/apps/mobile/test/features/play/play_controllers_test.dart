import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/play/application/play_providers.dart';
import 'package:riftarium_mobile/features/play/application/room_controller.dart';
import 'package:riftarium_mobile/features/play/application/tracked_match_controller.dart';

import 'support/play_app.dart';
import 'support/play_fixtures.dart';

void main() {
  /// Garde le provider vivant : `autoDispose` le jetterait sitôt lu.
  void keep<T>(ProviderContainer container, ProviderListenable<T> provider) {
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
  }

  /// Laisse passer le délai d'anti-rebond (300 ms) puis l'aller-retour réseau.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 450));

  group('reprise', () {
    test('currentPlayProvider rend le salon et le match en cours', () async {
      final server = PlayFakeApi({
        'GET /play/current': currentPlayJson(
          room: roomJson(status: 'playing', matchId: 1),
          match: matchJson(),
        ),
      });
      final container = playContainer(server: server);

      final current = await container.read(currentPlayProvider.future);

      expect(current.isEmpty, isFalse);
      expect(current.room?.code, 'ABC234');
      expect(current.match?.id, 1);
    });

    test('hors session, rien n’est demandé au serveur', () async {
      final server = PlayFakeApi();
      final container = playContainer(server: server, signedIn: false);

      final current = await container.read(currentPlayProvider.future);

      expect(current.isEmpty, isTrue);
      expect(server.calls, isEmpty);
    });
  });

  group('salon', () {
    test('un battement de sondage rapporte le salon à jour', () async {
      final server = PlayFakeApi({'GET /play/rooms/ABC234': roomJson()});
      final container = playContainer(server: server);
      final provider = roomControllerProvider('ABC234');
      keep(container, provider);

      final first = await container.read(provider.future);
      expect(first.guest, isNull);

      // L'invité arrive entre deux battements.
      server.set(
        'GET /play/rooms/ABC234',
        roomJson(
          version: 2,
          players: [
            roomPlayerJson(ready: true),
            roomPlayerJson(userId: 8, handle: 'jinx', seat: 1, ready: true),
          ],
        ),
      );
      await container.read(provider.notifier).refresh();

      final room = container.read(provider).requireValue;
      expect(room.version, 2);
      expect(room.guest?.user.handle, 'jinx');
      expect(room.bothReady, isTrue);
      expect(server.on('GET', '/play/rooms/ABC234').length, 2);
    });

    test('se déclarer prêt conserve la légende et le deck choisis', () async {
      final chosen = roomJson(
        players: [
          roomPlayerJson(legend: legendJson(), deck: playDeckJson()),
          roomPlayerJson(userId: 8, handle: 'jinx', seat: 1),
        ],
      );
      final server = PlayFakeApi({
        'GET /play/rooms/ABC234': chosen,
        'PUT /play/rooms/ABC234/me': chosen,
      });
      final container = playContainer(server: server);
      final provider = roomControllerProvider('ABC234');
      keep(container, provider);
      await container.read(provider.future);

      await container.read(provider.notifier).setReady(true);

      final call = server.last('PUT', '/play/rooms/ABC234/me')!;
      expect(call.body, {
        'legend_card_id': 'OGN-001',
        'deck_id': 3,
        'ready': true,
      });
    });

    test('une erreur de sondage laisse le salon affiché', () async {
      final server = PlayFakeApi({'GET /play/rooms/ABC234': roomJson()});
      final container = playContainer(server: server);
      final provider = roomControllerProvider('ABC234');
      keep(container, provider);
      await container.read(provider.future);

      server.set(
        'GET /play/rooms/ABC234',
        const PlayFakeError(500, 'Serveur indisponible.'),
      );
      await container.read(provider.notifier).refresh();

      expect(container.read(provider).hasValue, isTrue);
      expect(container.read(provider).requireValue.code, 'ABC234');
    });
  });

  group('match suivi', () {
    test('un point de l’hôte part en PUT state après l’anti-rebond', () async {
      final server = PlayFakeApi({
        'GET /play/matches/1': matchJson(version: 3),
        'PUT /play/matches/1/state': matchJson(version: 4),
      });
      final container = playContainer(server: server);
      final provider = trackedMatchControllerProvider(1);
      keep(container, provider);
      await container.read(provider.future);

      final controller = container.read(provider.notifier);
      controller.addPoint('7');
      controller.addPoint('7');

      // Deux gestes rapprochés, un seul envoi.
      expect(container.read(provider).requireValue.sync, PlaySync.pending);
      await settle();

      final puts = server.on('PUT', '/play/matches/1/state').toList();
      expect(puts.length, 1);
      expect(puts.single.body['version'], 3);
      expect((puts.single.body['state'] as Map)['scores'], {'7': 2, '8': 0});
      final tracked = container.read(provider).requireValue;
      expect(tracked.sync, PlaySync.synced);
      expect(tracked.match.version, 4);
      expect(tracked.board.scoreOfTeam(0), 2);
    });

    test('un 409 recharge le match puis réapplique la table', () async {
      final server = PlayFakeApi({
        'GET /play/matches/1': PlayFakeSequence([
          matchJson(version: 3),
          matchJson(version: 9),
        ]),
        'PUT /play/matches/1/state': PlayFakeSequence([
          const PlayFakeError(409, 'Le compteur a changé entre-temps.'),
          matchJson(version: 10),
        ]),
      });
      final container = playContainer(server: server);
      final provider = trackedMatchControllerProvider(1);
      keep(container, provider);
      await container.read(provider.future);

      container.read(provider.notifier).addPoint('7');
      await settle();

      final puts = server.on('PUT', '/play/matches/1/state').toList();
      expect(puts.length, 2);
      expect(puts.first.body['version'], 3);
      // Rechargé (version 9), puis réappliqué avec le point marqué en local.
      expect(puts.last.body['version'], 9);
      expect((puts.last.body['state'] as Map)['scores'], {'7': 1, '8': 0});
      expect(server.on('GET', '/play/matches/1').length, 2);
      expect(container.read(provider).requireValue.sync, PlaySync.synced);
    });

    test(
      'l’envoi impossible passe la table hors ligne sans la perdre',
      () async {
        final server = PlayFakeApi({
          'GET /play/matches/1': matchJson(version: 3),
          'PUT /play/matches/1/state': const PlayFakeError(500, 'Panne.'),
        });
        final container = playContainer(server: server);
        final provider = trackedMatchControllerProvider(1);
        keep(container, provider);
        await container.read(provider.future);

        container.read(provider.notifier).addPoint('7');
        await settle();

        final tracked = container.read(provider).requireValue;
        expect(tracked.sync, PlaySync.offline);
        expect(tracked.board.scoreOfTeam(0), 1);
      },
    );

    test('l’invité ne compte pas : aucun geste ne part', () async {
      final server = PlayFakeApi({
        // Hôte : le compte 8. Moi : le compte 7, donc invité.
        'GET /play/matches/1': matchJson(hostId: 8, firstPlayerId: 8),
      });
      final container = playContainer(server: server);
      final provider = trackedMatchControllerProvider(1);
      keep(container, provider);
      await container.read(provider.future);

      container.read(provider.notifier).addPoint('7');
      await settle();

      expect(server.on('PUT', '/play/matches/1/state'), isEmpty);
      expect(container.read(provider).requireValue.board.scoreOfTeam(0), 0);
    });

    test('le sondage de l’invité reprend l’instantané de l’hôte', () async {
      final server = PlayFakeApi({
        'GET /play/matches/1': matchJson(hostId: 8, firstPlayerId: 8),
      });
      final container = playContainer(server: server);
      final provider = trackedMatchControllerProvider(1);
      keep(container, provider);
      await container.read(provider.future);

      server.set(
        'GET /play/matches/1',
        matchJson(
          hostId: 8,
          firstPlayerId: 8,
          version: 6,
          state: matchStateJson(
            turn: 4,
            activeUserId: 7,
            scores: {'7': 1, '8': 3},
          ),
        ),
      );
      await container.read(provider.notifier).refresh();

      final board = container.read(provider).requireValue.board;
      expect(board.scoreOfTeam(0), 1);
      expect(board.scoreOfTeam(1), 3);
      expect(board.turnNumber, 4);
      expect(board.activePlayer.id, '7');
    });

    test('la victoire de l’hôte se clôt par finish', () async {
      final server = PlayFakeApi({
        'GET /play/matches/1': matchJson(
          version: 3,
          state: matchStateJson(scores: {'7': 7, '8': 5}),
        ),
        'PUT /play/matches/1/state': matchJson(version: 4),
        'POST /play/matches/1/finish': matchJson(
          status: 'awaiting_confirmation',
          winnerUserId: 7,
        ),
      });
      final container = playContainer(server: server);
      final provider = trackedMatchControllerProvider(1);
      keep(container, provider);
      await container.read(provider.future);

      container.read(provider.notifier).addPoint('7');
      await settle();
      expect(container.read(provider).requireValue.board.isOver, isTrue);

      await container.read(provider.notifier).finishMatch();

      final finish = server.last('POST', '/play/matches/1/finish')!;
      expect(finish.body['winner_user_id'], 7);
      expect((finish.body['result'] as Map)['scores'], {'7': 8, '8': 5});
      expect(
        container.read(provider).requireValue.match.isAwaitingConfirmation,
        isTrue,
      );
    });
  });
}
