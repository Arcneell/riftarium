import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/main.dart';

import '../cards/support/cards_fixtures.dart';

void main() {
  /// Le reflet foil de la carte du moment tourne en boucle : sans réduction de
  /// mouvement, `pumpAndSettle` n'aurait jamais de fin.
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// Fenêtre assez haute pour que la carte du moment tienne sans défilement :
  /// la fenêtre de test par défaut (800 × 600) la laisse hors vue, et les
  /// finders ignorent ce qui n'est pas dans le viewport.
  Future<void> tallWindow(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Widget app(CardsFakeApi api) {
    final store = InMemoryTokenStore(null);
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.home),
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

  testWidgets('la carte du moment porte des libellés français', (tester) async {
    reduceMotion(tester);
    await tallWindow(tester);
    final api = CardsFakeApi({
      'GET /cards': cardPageJson(
        total: 1,
        items: [
          cardJson(
            id: 'OGN-209',
            name: 'Jinx, la Gâchette folle',
            collectorNumber: 209,
            type: 'Unit',
            rarity: 'Epic',
          ),
        ],
      ),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.text('Carte du moment'), findsOneWidget);
    expect(find.text('Jinx, la Gâchette folle'), findsWidgets);
    // Type et rareté traduits, jamais les valeurs brutes de l'API.
    expect(find.text('Unité · Épique'), findsOneWidget);
    expect(find.text('Unit · Epic'), findsNothing);
    // Une carte au hasard : c'est bien un tirage aléatoire qui est demandé.
    expect(api.cardQueries.first['sort'], 'random');
  });

  testWidgets('cartothèque muette : la carte du moment se réessaie', (
    tester,
  ) async {
    reduceMotion(tester);
    await tallWindow(tester);
    final api = CardsFakeApi({
      'GET /cards': const CardsFakeError(500, 'Panne'),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(
      find.text('La cartothèque ne répond pas pour le moment.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
