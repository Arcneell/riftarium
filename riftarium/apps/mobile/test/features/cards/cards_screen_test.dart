import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/cards/ui/cards_screen.dart';
import 'package:riftarium_mobile/features/cards/ui/widgets/card_filters_sheet.dart';
import 'package:riftarium_mobile/main.dart';

import 'support/cards_fixtures.dart';

void main() {
  /// Une carte possédée brille en continu (reflet foil) : sans réduction de
  /// mouvement, `pumpAndSettle` n'aurait jamais de fin. Toutes les briques de
  /// la charte respectent ce réglage système.
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Les révélations en cascade (`Reveal`) posent un minuteur par bloc, même
  /// en mouvement réduit : on les laisse s'écouler avant la fin du test.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Widget app(CardsFakeApi api) {
    final store = InMemoryTokenStore();
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.cards),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: api,
          ),
        ),
      ],
      child: const RiftariumApp(),
    );
  }

  testWidgets('la grille affiche les cartes, leur code et le total', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi({
      'GET /cards': cardPageJson(
        total: 2,
        items: [
          cardJson(id: 'OGN-209', name: 'Jinx', collectorNumber: 209),
          cardJson(id: 'OGN-210', name: 'Vi', collectorNumber: 210),
        ],
      ),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.byType(CardsScreen), findsOneWidget);
    // Le nom apparaît sous la vignette et dans le substitut d'image (les
    // fixtures n'ont pas d'`image_url`).
    expect(find.text('Jinx'), findsWidgets);
    expect(find.text('Vi'), findsWidgets);
    expect(find.text('OGN 209'), findsOneWidget);
    expect(find.text('OGN 210'), findsOneWidget);
    // Le décompte vit dans le sur-titre de la bannière, en capitales.
    expect(find.text('2 CARTES · 2 SETS'), findsOneWidget);
  });

  testWidgets('la recherche déclenche un appel avec q après la pause', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi({
      'GET /cards': cardPageJson(
        total: 1,
        items: [cardJson(id: 'OGN-209', name: 'Jinx', collectorNumber: 209)],
      ),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);
    expect(api.cardQueries.single.containsKey('q'), isFalse);

    await tester.enterText(find.byType(TextField), 'jinx');
    // Avant la fin du délai d'attente, rien n'est parti.
    await tester.pump(const Duration(milliseconds: 100));
    expect(api.cardQueries, hasLength(1));

    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);

    expect(api.cardQueries.last['q'], 'jinx');
    expect(api.cardQueries.last['page'], 1);
  });

  testWidgets('sans résultat, l’écran invite à changer les filtres', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi({
      'GET /cards': cardPageJson(total: 0, items: const []),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.text('Aucune carte'), findsWidgets);
    expect(find.text('Recharger la cartothèque'), findsOneWidget);
  });

  testWidgets('une erreur d’API propose de réessayer', (tester) async {
    reduceMotion(tester);
    final api = CardsFakeApi({
      'GET /cards': const CardsFakeError(500, 'Service indisponible'),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.text('Service indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('la feuille de filtres s’ouvre et pose une puce de rappel', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi({
      'GET /cards': cardPageJson(
        total: 1,
        items: [cardJson(id: 'OGN-209', name: 'Jinx', collectorNumber: 209)],
      ),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);

    await tester.tap(find.byIcon(Icons.tune));
    await settle(tester);
    expect(find.text('Filtres'), findsOneWidget);
    expect(find.text('Origines'), findsOneWidget);

    // La feuille défile paresseusement : la section « Rareté » n'est pas
    // encore construite à l'ouverture.
    await tester.scrollUntilVisible(
      find.text('Épique'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(CardFiltersSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await settle(tester);
    await tester.tap(find.text('Épique'));
    await settle(tester);
    expect(api.cardQueries.last['rarity'], 'Epic');

    // Le filtre « possédées / manquantes » reste réservé aux comptes connectés.
    expect(find.text('Ma collection'), findsNothing);

    await tester.tap(find.text('Voir 1 carte'));
    await settle(tester);
    expect(find.text('Épique'), findsOneWidget);
  });
}
