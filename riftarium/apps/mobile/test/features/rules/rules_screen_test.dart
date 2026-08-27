import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/theme.dart';
import 'package:riftarium_mobile/features/rules/application/rules_providers.dart';
import 'package:riftarium_mobile/features/rules/data/rules_repository.dart';
import 'package:riftarium_mobile/features/rules/domain/rules.dart';
import 'package:riftarium_mobile/features/rules/ui/rule_chapter_screen.dart';
import 'package:riftarium_mobile/features/rules/ui/rule_section_screen.dart';
import 'package:riftarium_mobile/features/rules/ui/rules_screen.dart';

import '../../support/fakes.dart';
import 'rules_fixture.dart';

class _FixtureAssets implements RulesAssetLoader {
  const _FixtureAssets();

  @override
  Future<String> load(String key) async => kRulesFixtureSource;
}

class _NoCache implements RulesCacheStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<bool> write(String source) async => true;
}

void main() {
  const remoteUrl = 'https://riftarium.test/data/rules-fr.json';
  const routeKey = 'GET $remoteUrl';

  RulesRepository repository({FakeHttpAdapter? adapter}) => RulesRepository(
    assets: const _FixtureAssets(),
    cache: _NoCache(),
    parse: (source) async => parseRulesDocument(source),
    remoteUrl: remoteUrl,
    dio: Dio()..httpClientAdapter = adapter ?? FakeHttpAdapter({}),
  );

  Widget app({FakeHttpAdapter? adapter}) => ProviderScope(
    overrides: [
      rulesRepositoryProvider.overrideWithValue(repository(adapter: adapter)),
    ],
    child: MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const RulesScreen(),
    ),
  );

  testWidgets('les chapitres du livre principal sont listés', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Règles d’or et d’argent'), findsOneWidget);
    expect(find.text('Éléments de jeu'), findsOneWidget);
    expect(
      find.text('Mis à jour le 16 juillet 2026 · 5 règles'),
      findsOneWidget,
    );
    expect(find.text('PDF officiel ↗'), findsOneWidget);
  });

  testWidgets('un chapitre mène à ses sections puis à son texte', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Éléments de jeu'));
    await tester.pumpAndSettle();
    expect(find.byType(RuleChapterScreen), findsOneWidget);

    await tester.tap(find.text('197 · Emplacements'));
    await tester.pumpAndSettle();
    expect(find.byType(RuleSectionScreen), findsOneWidget);
    expect(
      find.textContaining('Chaque base est un emplacement'),
      findsOneWidget,
    );
  });

  testWidgets('la recherche affiche des résultats avec leur fil', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'unite');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('2 règles pour « unite »'), findsOneWidget);
    expect(find.text('051.1.'), findsOneWidget);
    expect(find.text('198.1.'), findsOneWidget);
    expect(
      find.textContaining('Règles du jeu › Éléments de jeu'),
      findsOneWidget,
    );

    // Le résultat ouvre la section, règle mise en évidence.
    await tester.tap(find.text('198.1.'));
    await tester.pumpAndSettle();
    expect(find.byType(RuleSectionScreen), findsOneWidget);
    expect(find.textContaining('un autre emplacement'), findsWidgets);
  });

  testWidgets('la bascule affiche les règles de tournoi', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Règles de tournoi'));
    await tester.pumpAndSettle();

    expect(find.text('Cadre général'), findsOneWidget);
    expect(find.text('Cadre officiel du jeu organisé'), findsOneWidget);
    expect(find.text('Règles d’or et d’argent'), findsNothing);
  });

  testWidgets('une version en ligne plus récente remplace la locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        adapter: FakeHttpAdapter({
          routeKey: FakeResponse(200, rulesFixtureUpdated()),
        }),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mis à jour le 20 août 2026 · 6 règles'), findsOneWidget);
  });

  testWidgets('« Actualiser » explique l’échec sans vider l’écran', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Actualiser'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Les règles enregistrées restent consultables'),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Règles d’or et d’argent'), findsOneWidget);
  });
}
