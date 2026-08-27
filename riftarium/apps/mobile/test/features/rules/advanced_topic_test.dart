import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/features/rules/ui/rule_entry_view.dart';
import 'package:riftarium_mobile/features/rules/ui/widgets/topic_demo.dart';

import 'support/rules_app.dart';

void main() {
  testWidgets('la fiche donne l’essentiel avant le texte officiel', (
    tester,
  ) async {
    await tester.pumpWidget(
      rulesApp(
        tester: tester,
        location: AppRoutes.advancedTopic('deroulement-du-tour'),
      ),
    );
    await settle(tester);

    expect(find.text('L’essentiel'), findsOneWidget);
    expect(find.textContaining('vous redressez'), findsOneWidget);
    expect(find.text('Cas concrets'), findsOneWidget);
    expect(find.text('Le texte officiel'), findsOneWidget);
    // Le texte officiel est replié : il ne prend pas la place de la fiche.
    expect(find.byType(RuleEntryView), findsNothing);
    expect(find.text('Voir le texte officiel'), findsOneWidget);
  });

  testWidgets('un cas concret se déplie sur sa réponse', (tester) async {
    await tester.pumpWidget(
      rulesApp(
        tester: tester,
        location: AppRoutes.advancedTopic('deroulement-du-tour'),
      ),
    );
    await settle(tester);

    expect(find.text('À l’étape des scores, avant la pioche.'), findsNothing);

    await tester.tap(find.textContaining('Quand marque-t-on'));
    await settle(tester);

    expect(find.text('À l’étape des scores, avant la pioche.'), findsOneWidget);
  });

  testWidgets('« Voir le texte officiel » déplie les sections citées', (
    tester,
  ) async {
    await tester.pumpWidget(
      rulesApp(
        tester: tester,
        location: AppRoutes.advancedTopic('deroulement-du-tour'),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Voir le texte officiel'));
    await settle(tester);

    expect(find.text('Emplacements'), findsOneWidget);
    expect(find.byType(RuleEntryView), findsNWidgets(2));
    expect(find.textContaining('Chaque base est un emplacement'), findsWidgets);
    expect(find.text('Replier le texte officiel'), findsOneWidget);
  });

  testWidgets('la démo et les cartes d’exemple s’affichent quand il y en a', (
    tester,
  ) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.advancedTopic('la-chaine')),
    );
    await settle(tester);

    expect(find.byType(TopicDemoView), findsOneWidget);
    expect(find.text('Vous jouez un sort.'), findsOneWidget);
    expect(find.text('Cartes d’exemple'), findsOneWidget);
    expect(find.text('Get Excited!'), findsWidgets);
    // Le sujet suivant reste à portée de pouce.
    expect(find.text('Ensuite : Les étapes du combat'), findsOneWidget);
    expect(find.text('Sujet suivant'), findsOneWidget);
  });

  testWidgets('un slug inconnu propose de revenir à l’aide avancée', (
    tester,
  ) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.advancedTopic('inconnu')),
    );
    await settle(tester);

    expect(find.text('Sujet introuvable'), findsWidgets);
    expect(find.text('Toute l’aide avancée'), findsOneWidget);
  });
}
