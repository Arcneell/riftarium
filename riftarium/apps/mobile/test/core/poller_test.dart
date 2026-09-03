import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/poller.dart';

void main() {
  group('Poller', () {
    test('bat à la cadence demandée', () {
      fakeAsync((async) {
        var beats = 0;
        final poller = Poller(
          tick: () async => beats++,
          interval: const Duration(seconds: 2),
        );

        poller.start();
        expect(beats, 0, reason: 'rien avant la première échéance');

        async.elapse(const Duration(seconds: 2));
        expect(beats, 1);

        async.elapse(const Duration(seconds: 4));
        expect(beats, 3);

        poller.dispose();
      });
    });

    test('un intervalle nul n’arme aucun minuteur', () {
      fakeAsync((async) {
        var beats = 0;
        final poller = Poller(
          tick: () async => beats++,
          interval: Duration.zero,
        )..start();

        async.elapse(const Duration(minutes: 1));

        expect(beats, 0);
        expect(poller.isRunning, isFalse);
      });
    });

    test('un échec double l’attente, un succès la remet à la cadence', () {
      fakeAsync((async) {
        var failing = true;
        var beats = 0;
        final poller = Poller(
          tick: () async {
            beats++;
            if (failing) throw Exception('réseau injoignable');
          },
          interval: const Duration(seconds: 2),
          maxInterval: const Duration(seconds: 16),
        )..start();

        async.elapse(const Duration(seconds: 2));
        expect(beats, 1);
        expect(poller.delay, const Duration(seconds: 4));

        async.elapse(const Duration(seconds: 4));
        expect(beats, 2);
        expect(poller.delay, const Duration(seconds: 8));

        async.elapse(const Duration(seconds: 8));
        expect(beats, 3);
        expect(poller.delay, const Duration(seconds: 16));

        // Plafonné : l'attente ne dépasse pas `maxInterval`.
        async.elapse(const Duration(seconds: 16));
        expect(beats, 4);
        expect(poller.delay, const Duration(seconds: 16));

        failing = false;
        async.elapse(const Duration(seconds: 16));
        expect(beats, 5);
        expect(poller.delay, const Duration(seconds: 2));

        poller.dispose();
      });
    });

    test('en pause, rien ne bat ; reprendre bat tout de suite', () {
      fakeAsync((async) {
        var beats = 0;
        final poller = Poller(
          tick: () async => beats++,
          interval: const Duration(seconds: 2),
        )..start();

        async.elapse(const Duration(seconds: 2));
        expect(beats, 1);

        poller.pause();
        async.elapse(const Duration(minutes: 1));
        expect(beats, 1, reason: 'application en arrière-plan');

        poller.resume();
        async.flushMicrotasks();
        expect(beats, 2, reason: 'rattrapage immédiat au retour');

        async.elapse(const Duration(seconds: 2));
        expect(beats, 3, reason: 'la cadence reprend');

        poller.dispose();
      });
    });

    test('reprendre pendant un battement ne le double pas', () {
      fakeAsync((async) {
        var started = 0;
        final poller = Poller(
          tick: () async {
            started++;
            await Future<void>.delayed(const Duration(seconds: 5));
          },
          interval: const Duration(seconds: 2),
        )..start();

        async.elapse(const Duration(seconds: 2));
        expect(started, 1);

        poller.pause();
        poller.resume();
        async.flushMicrotasks();
        expect(started, 1, reason: 'le battement en vol est respecté');

        poller.dispose();
      });
    });

    test('arrêté puis libéré, plus rien ne bat', () {
      fakeAsync((async) {
        var beats = 0;
        final poller = Poller(
          tick: () async => beats++,
          interval: const Duration(seconds: 2),
        )..start();

        async.elapse(const Duration(seconds: 2));
        expect(beats, 1);

        poller.stop();
        async.elapse(const Duration(minutes: 1));
        expect(beats, 1);
        expect(poller.isRunning, isFalse);

        // Reprendre après un arrêt ne relance rien : il faut redémarrer.
        poller.resume();
        async.elapse(const Duration(minutes: 1));
        expect(beats, 1);

        poller.start();
        async.elapse(const Duration(seconds: 2));
        expect(beats, 2);

        poller.dispose();
        async.elapse(const Duration(minutes: 1));
        expect(beats, 2);
      });
    });
  });
}
