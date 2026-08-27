import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/rules/ui/advanced_help_screen.dart';
import 'package:riftarium_mobile/features/rules/ui/rules_screen.dart';

import 'support/rules_app.dart';

void main() {
  testWidgets('le hub propose les deux paliers, aide avancée en tête', (
    tester,
  ) async {
    await tester.pumpWidget(rulesApp(tester: tester));
    await settle(tester);

    expect(find.byType(RulesScreen), findsOneWidget);
    expect(find.text('Aide avancée'), findsOneWidget);
    expect(find.text('Règles officielles'), findsOneWidget);

    // Chaque palier annonce ce qu'il contient, compté sur les fichiers.
    expect(find.text('3 mécaniques, des cas concrets'), findsOneWidget);
    expect(find.text('5 + 1 règles'), findsOneWidget);
  });

  testWidgets('les sujets fréquents et la règle d’or sont rappelés', (
    tester,
  ) async {
    await tester.pumpWidget(rulesApp(tester: tester));
    await settle(tester);

    expect(find.text('Sujets fréquents'), findsOneWidget);
    expect(find.text('Le déroulement du tour'), findsOneWidget);
    expect(find.text('La chaîne'), findsOneWidget);
    expect(
      find.textContaining('a priorité sur ce qui est inscrit'),
      findsOneWidget,
    );
  });

  testWidgets('la recherche groupe les guides puis le texte officiel', (
    tester,
  ) async {
    await tester.pumpWidget(rulesApp(tester: tester));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'unite');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);

    expect(find.text('Guides'), findsOneWidget);
    expect(find.text('Texte officiel'), findsOneWidget);
    // Un sujet et une règle officielle répondent au même mot.
    expect(find.text('Les étapes du combat'), findsOneWidget);
    expect(find.text('051.1.'), findsOneWidget);
    // Les paliers laissent la place aux résultats.
    expect(find.text('Sujets fréquents'), findsNothing);
  });

  testWidgets('une recherche sans réponse invite à l’aide avancée', (
    tester,
  ) async {
    await tester.pumpWidget(rulesApp(tester: tester));
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);

    expect(find.textContaining('Rien pour « zzzz »'), findsOneWidget);
    expect(find.text('Ouvrir l’aide avancée'), findsOneWidget);
  });

  testWidgets('un palier mène à son écran', (tester) async {
    await tester.pumpWidget(rulesApp(tester: tester));
    await settle(tester);

    await tester.tap(find.text('Aide avancée'));
    await settle(tester);
    expect(find.byType(AdvancedHelpScreen), findsOneWidget);
  });
}
