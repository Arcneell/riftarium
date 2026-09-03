import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/collection/ui/wishlist_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  final jinx = cardJson(id: 'OGN-209', priceEur: 12.5);

  /// La grille anime en continu (reflet foil des cartes possédées) : sans
  /// réduction de mouvement, `pumpAndSettle` n'aurait jamais de fin. Les
  /// briques de la charte respectent toutes ce réglage.
  Widget reduceMotion(Widget child) => MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: child,
  );

  Widget app(FakeHttpAdapter adapter, {String? token = 'jwt'}) {
    final store = InMemoryTokenStore(token);
    return reduceMotion(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          initialLocationProvider.overrideWithValue(AppRoutes.wishlist),
          dioProvider.overrideWith(
            (ref) => createApiClient(
              readToken: store.read,
              baseUrl: 'https://api.test/api',
              adapter: adapter,
            ),
          ),
        ],
        child: const RiftariumApp(),
      ),
    );
  }

  Map<String, FakeResponse> routes([
    Map<String, FakeResponse> extra = const {},
  ]) => {
    'GET /auth/me': const FakeResponse(200, profileJson),
    'GET /wishlist': FakeResponse(
      200,
      wishlistJson(items: [wishItemJson(card: jinx, qty: 2)], valueEur: 25),
    ),
    ...extra,
  };

  testWidgets('sans session : invite à se connecter', (tester) async {
    await tester.pumpWidget(app(FakeHttpAdapter(routes()), token: null));
    await tester.pumpAndSettle();

    expect(find.byType(WishlistScreen), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('avec session : cartes souhaitées, quantité et prix', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeHttpAdapter(routes())));
    await tester.pumpAndSettle();

    expect(find.text('CARTES SOUHAITÉES'), findsOneWidget);
    expect(find.text('25,00 €'), findsOneWidget); // valeur totale estimée
    expect(find.text('OGN 209 · 25,00 €'), findsOneWidget); // 2 × 12,50 €
    expect(find.text('2'), findsOneWidget); // quantité du stepper
    expect(find.byTooltip('Retirer'), findsOneWidget);
  });

  testWidgets('le stepper envoie la nouvelle quantité', (tester) async {
    final adapter = FakeHttpAdapter(
      routes({'PUT /wishlist/OGN-209': const FakeResponse(204, {})}),
    );

    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.path, '/wishlist/OGN-209');
    expect(put.jsonBody, {'qty': 3});
  });

  testWidgets('Retirer supprime la carte de la wishlist', (tester) async {
    final adapter = FakeHttpAdapter(
      routes({'DELETE /wishlist/OGN-209': const FakeResponse(204, {})}),
    );

    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Retirer'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.any(
        (r) => r.method == 'DELETE' && r.path == '/wishlist/OGN-209',
      ),
      isTrue,
    );
  });

  testWidgets('wishlist vide : message et lien vers les cartes', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({'GET /wishlist': FakeResponse(200, wishlistJson())}),
    );

    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Ta wishlist est vide'), findsOneWidget);
    expect(find.text('Parcourir les cartes'), findsOneWidget);
  });
}
