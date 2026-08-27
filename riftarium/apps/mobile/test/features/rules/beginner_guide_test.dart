import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/features/rules/ui/rule_section_screen.dart';
import 'package:riftarium_mobile/features/rules/ui/widgets/guide_board.dart';

import 'support/rules_app.dart';

void main() {
  testWidgets('la première étape montre le plateau et son texte', (
    tester,
  ) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.beginnerGuide),
    );
    await settle(tester);

    expect(find.text('Étape 1 sur 3'), findsOneWidget);
    expect(find.text('Ce qu’il faut pour jouer'), findsOneWidget);
    expect(find.byType(GuideBoard), findsOneWidget);
    // Les termes du pas à pas sont rappelés en pastilles.
    expect(find.text('deck principal'), findsOneWidget);
    expect(find.textContaining('Quatre éléments'), findsOneWidget);
  });

  testWidgets('« Suivant » avance d’une étape, « Précédent » revient', (
    tester,
  ) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.beginnerGuide),
    );
    await settle(tester);

    await tester.tap(find.text('Suivant'));
    await settle(tester);
    expect(find.text('Étape 2 sur 3'), findsOneWidget);
    expect(find.text('La mise en place'), findsOneWidget);

    await tester.tap(find.text('Précédent'));
    await settle(tester);
    expect(find.text('Étape 1 sur 3'), findsOneWidget);
  });

  testWidgets('la dernière étape renvoie vers l’aide avancée', (tester) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.beginnerGuide),
    );
    await settle(tester);

    await tester.tap(find.text('Suivant'));
    await settle(tester);
    await tester.tap(find.text('Suivant'));
    await settle(tester);

    expect(find.text('Étape 3 sur 3'), findsOneWidget);
    expect(find.text('Gagner la partie'), findsOneWidget);
    expect(find.text('Suivant'), findsNothing);
    expect(find.text('Terminer'), findsOneWidget);
  });

  testWidgets('le renvoi ouvre la règle officielle correspondante', (
    tester,
  ) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.beginnerGuide),
    );
    await settle(tester);

    await tester.tap(find.text('Règle 197 ↗'));
    await settle(tester);

    expect(find.byType(RuleSectionScreen), findsOneWidget);
    expect(find.textContaining('Chaque base est un emplacement'), findsWidgets);
  });
}
