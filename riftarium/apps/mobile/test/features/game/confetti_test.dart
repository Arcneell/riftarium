import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/theme.dart';
import 'package:riftarium_mobile/features/game/ui/widgets/confetti.dart';

void main() {
  Iterable<CustomPaint> confettiPainters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .where((paint) => paint.painter is ConfettiPainter);

  Widget scene({required bool reduceMotion, int burst = 0}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 400,
        height: 800,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ConfettiOverlay(
              colors: confettiPalette(const ['Chaos', 'Fury']),
              burst: burst,
            ),
          ],
        ),
      ),
    ),
  );

  testWidgets('la pluie se peint puis s’arrête', (tester) async {
    await tester.pumpWidget(scene(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 400));

    expect(confettiPainters(tester), hasLength(1));

    // L'animation a une fin : sans cela, la table battrait indéfiniment.
    await tester.pumpAndSettle();
    expect(confettiPainters(tester), hasLength(1));
  });

  testWidgets('rien n’est peint en mouvement réduit', (tester) async {
    await tester.pumpWidget(scene(reduceMotion: true));
    await tester.pumpAndSettle();

    expect(confettiPainters(tester), isEmpty);
  });

  testWidgets('« Encore ! » relance une pluie différente', (tester) async {
    await tester.pumpWidget(scene(reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 200));
    final first =
        (confettiPainters(tester).single.painter! as ConfettiPainter).flakes;

    await tester.pumpWidget(scene(reduceMotion: false, burst: 1));
    await tester.pump(const Duration(milliseconds: 200));
    final second =
        (confettiPainters(tester).single.painter! as ConfettiPainter).flakes;

    expect(second, isNot(same(first)));
    expect(second, hasLength(first.length));
    await tester.pumpAndSettle();
  });

  test('la palette mêle l’or, le parchemin et les domaines du gagnant', () {
    final palette = confettiPalette(const ['Chaos', 'Colorless']);
    expect(palette, contains(RiftColors.gold));
    expect(palette, contains(RiftColors.paper));
    expect(palette, contains(RiftColors.chaos));
    // Un domaine sans couleur propre n'ajoute pas de gris terne.
    expect(palette, isNot(contains(RiftColors.muted)));
    expect(confettiPalette(const []), isNotEmpty);
  });
}
