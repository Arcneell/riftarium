import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/features/rules/ui/advanced_topic_screen.dart';

import 'support/rules_app.dart';

void main() {
  testWidgets('les mécaniques sont groupées par famille', (tester) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.advancedHelp),
    );
    await settle(tester);

    expect(find.text('Tour & timing'), findsNWidgets(2)); // puce + titre
    expect(find.text('Le déroulement du tour'), findsOneWidget);
    expect(find.text('La chaîne'), findsOneWidget);
    expect(find.text('Les étapes du combat'), findsOneWidget);
    expect(find.text('Dernier entré, premier résolu.'), findsOneWidget);
  });

  testWidgets('une puce de famille filtre la liste', (tester) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.advancedHelp),
    );
    await settle(tester);

    // La première occurrence est la puce de filtre, avant les sections.
    await tester.tap(find.text('Combat').first);
    await settle(tester);

    expect(find.text('Les étapes du combat'), findsOneWidget);
    expect(find.text('Le déroulement du tour'), findsNothing);
    expect(find.text('Tour & timing'), findsOneWidget); // plus que la puce

    // Un second appui rend la liste complète.
    await tester.tap(find.text('Combat').first);
    await settle(tester);
    expect(find.text('Le déroulement du tour'), findsOneWidget);
  });

  testWidgets('la recherche locale réduit la liste', (tester) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.advancedHelp),
    );
    await settle(tester);

    await tester.enterText(find.byType(TextField).first, 'chaine');
    await tester.pump(const Duration(milliseconds: 250));
    await settle(tester);

    expect(find.text('La chaîne'), findsOneWidget);
    expect(find.text('Les étapes du combat'), findsNothing);
  });

  testWidgets('un sujet s’ouvre depuis la liste', (tester) async {
    await tester.pumpWidget(
      rulesApp(tester: tester, location: AppRoutes.advancedHelp),
    );
    await settle(tester);

    await tester.tap(find.text('La chaîne'));
    await settle(tester);

    expect(find.byType(AdvancedTopicScreen), findsOneWidget);
    expect(find.text('Dernier entré, premier résolu.'), findsOneWidget);
  });
}
