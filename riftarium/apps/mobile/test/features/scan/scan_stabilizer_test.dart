import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/scan/domain/collector_code.dart';

void main() {
  late DateTime clock;

  ScanStabilizer build({
    int streak = 3,
    int window = 6,
    int majority = 4,
    Duration cooldown = const Duration(seconds: 4),
  }) {
    clock = DateTime(2026, 8, 27, 10);
    return ScanStabilizer(
      streak: streak,
      window: window,
      majority: majority,
      cooldown: cooldown,
      clock: () => clock,
    );
  }

  test('une lecture isolée ne verrouille pas', () {
    final stabilizer = build();
    expect(stabilizer.offer('a'), isNull);
    expect(stabilizer.offer('a'), isNull);
    expect(stabilizer.pending, 2);
  });

  test('trois lectures identiques d’affilée verrouillent', () {
    final stabilizer = build();
    stabilizer.offer('a');
    stabilizer.offer('a');
    expect(stabilizer.offer('a'), 'a');
    expect(stabilizer.pending, 0, reason: 'la fenêtre repart de zéro');
  });

  test('une lecture différente casse la série', () {
    final stabilizer = build();
    stabilizer.offer('a');
    stabilizer.offer('b');
    expect(stabilizer.offer('a'), isNull);
    expect(stabilizer.offer('a'), isNull);
    // a, b, a, a, a : trois d’affilée.
    expect(stabilizer.offer('a'), 'a');
  });

  test('majorité sur la fenêtre : 4 lectures sur 6, sans série de trois', () {
    final stabilizer = build();
    // La carte bouge un peu : une lecture sur cinq part sur une voisine.
    expect(stabilizer.offer('a'), isNull);
    expect(stabilizer.offer('a'), isNull);
    expect(stabilizer.offer('b'), isNull);
    expect(stabilizer.offer('a'), isNull);
    // a, a, b, a, a : quatre « a » sur cinq, jamais trois d’affilée.
    expect(stabilizer.offer('a'), 'a');
  });

  test('une alternance stricte ne verrouille jamais', () {
    final stabilizer = build();
    for (var i = 0; i < 10; i++) {
      expect(stabilizer.offer(i.isEven ? 'a' : 'b'), isNull);
    }
  });

  test('la même carte reste ignorée pendant le délai d’anti-doublon', () {
    final stabilizer = build();
    stabilizer.offer('a');
    stabilizer.offer('a');
    expect(stabilizer.offer('a'), 'a');

    clock = clock.add(const Duration(seconds: 1));
    for (var i = 0; i < 6; i++) {
      expect(stabilizer.offer('a'), isNull);
    }
    expect(
      stabilizer.pending,
      0,
      reason: 'rien ne s’accumule pendant le délai',
    );
  });

  test('une autre carte verrouille malgré le délai de la précédente', () {
    final stabilizer = build();
    stabilizer.offer('a');
    stabilizer.offer('a');
    stabilizer.offer('a');

    clock = clock.add(const Duration(seconds: 1));
    stabilizer.offer('b');
    stabilizer.offer('b');
    expect(stabilizer.offer('b'), 'b');
  });

  test('après le délai, la même carte redevient reconnaissable', () {
    final stabilizer = build();
    stabilizer.offer('a');
    stabilizer.offer('a');
    expect(stabilizer.offer('a'), 'a');

    clock = clock.add(const Duration(seconds: 5));
    stabilizer.offer('a');
    stabilizer.offer('a');
    expect(stabilizer.offer('a'), 'a');
  });

  test('clearPending oublie la fenêtre, pas le délai d’anti-doublon', () {
    final stabilizer = build();
    stabilizer.offer('a');
    stabilizer.offer('a');
    expect(stabilizer.offer('a'), 'a');

    stabilizer.clearPending();
    clock = clock.add(const Duration(seconds: 1));
    expect(stabilizer.offer('a'), isNull, reason: 'le délai court toujours');
  });
}
