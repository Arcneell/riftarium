import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/features/rules/ui/rule_chapter_screen.dart';
import 'package:riftarium_mobile/features/rules/ui/rule_section_screen.dart';

import '../../support/fakes.dart';
import 'rules_fixture.dart';
import 'support/rules_app.dart';

void main() {
  Future<void> pumpOfficial(
    WidgetTester tester, {
    FakeHttpAdapter? adapter,
  }) async {
    await tester.pumpWidget(
      rulesApp(
        tester: tester,
        location: AppRoutes.officialRules,
        rulesAdapter: adapter,
      ),
    );
    await settle(tester);
  }

  testWidgets('les chapitres du livre principal sont listés', (tester) async {
    await pumpOfficial(tester);

    expect(find.text('Règles d’or et d’argent'), findsOneWidget);
    expect(find.text('Éléments de jeu'), findsOneWidget);
    expect(find.text('Mis à jour le 16 juillet 2026'), findsOneWidget);
    expect(find.text('5 règles'), findsOneWidget);
    expect(find.text('PDF officiel ↗'), findsOneWidget);
  });

  testWidgets('un chapitre mène à ses sections puis à son texte', (
    tester,
  ) async {
    await pumpOfficial(tester);

    await tester.tap(find.text('Éléments de jeu'));
    await settle(tester);
    expect(find.byType(RuleChapterScreen), findsOneWidget);

    await tester.tap(find.text('Emplacements'));
    await settle(tester);
    expect(find.byType(RuleSectionScreen), findsOneWidget);
    expect(
      find.textContaining('Chaque base est un emplacement'),
      findsOneWidget,
    );
  });

  testWidgets('la recherche affiche des résultats avec leur fil', (
    tester,
  ) async {
    await pumpOfficial(tester);

    await tester.enterText(find.byType(TextField).first, 'unite');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);

    expect(find.text('2 règles pour « unite »'), findsOneWidget);
    expect(find.text('051.1.'), findsOneWidget);
    expect(find.text('198.1.'), findsOneWidget);
    expect(
      find.textContaining('Règles du jeu › Éléments de jeu'),
      findsOneWidget,
    );

    // Le résultat ouvre la section, règle mise en évidence.
    await tester.tap(find.text('198.1.'));
    await settle(tester);
    expect(find.byType(RuleSectionScreen), findsOneWidget);
    expect(find.textContaining('un autre emplacement'), findsWidgets);
  });

  testWidgets('la bascule affiche les règles de tournoi', (tester) async {
    await pumpOfficial(tester);

    await tester.tap(find.text('Règles de tournoi'));
    await settle(tester);

    expect(find.text('Cadre général'), findsOneWidget);
    expect(find.text('Cadre officiel du jeu organisé'), findsOneWidget);
    expect(find.text('Règles d’or et d’argent'), findsNothing);
  });

  testWidgets('une version en ligne plus récente remplace la locale', (
    tester,
  ) async {
    await pumpOfficial(
      tester,
      adapter: FakeHttpAdapter({
        kTestRemoteRulesRoute: FakeResponse(200, rulesFixtureUpdated()),
      }),
    );

    expect(find.text('Mis à jour le 20 août 2026'), findsOneWidget);
    expect(find.text('6 règles'), findsOneWidget);
  });

  testWidgets('« Actualiser » explique l’échec sans vider l’écran', (
    tester,
  ) async {
    await pumpOfficial(tester);

    await tester.tap(find.text('Actualiser'));
    await settle(tester);

    expect(
      find.textContaining('Les règles enregistrées restent consultables'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text('Règles d’or et d’argent'), findsOneWidget);
  });
}
