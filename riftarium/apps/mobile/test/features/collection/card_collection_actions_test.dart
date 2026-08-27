import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/cards/domain/card.dart';
import 'package:riftarium_mobile/features/collection/ui/widgets/card_collection_actions.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  RiftCard cardWith({int? ownedQty, int? wishedQty}) => RiftCard.fromJson(
    cardJson(
      id: 'OGN-209',
      priceEur: 12.5,
      ownedQty: ownedQty,
      wishedQty: wishedQty,
    ),
  );

  /// Hôte minimal : la fiche carte n'existe pas encore, seule la zone d'actions
  /// est montée, avec les routes dont elle a besoin.
  Widget host(
    FakeHttpAdapter adapter, {
    String? token = 'jwt',
    RiftCard? card,
  }) {
    final store = InMemoryTokenStore(token);
    final router = GoRouter(
      initialLocation: AppRoutes.card('OGN-209'),
      routes: [
        GoRoute(
          path: '/cartes/:id',
          builder: (context, state) => Scaffold(
            body: Center(
              child: CardCollectionActions(card: card ?? cardWith()),
            ),
          ),
        ),
        GoRoute(
          path: AppRoutes.login,
          builder: (context, state) => Scaffold(
            body: Text('connexion depuis ${state.uri.queryParameters['from']}'),
          ),
        ),
      ],
    );
    return MediaQuery(
      // Le cœur de la wishlist s'anime : sans réduction de mouvement,
      // `pumpAndSettle` n'aurait jamais de fin.
      data: const MediaQueryData(disableAnimations: true),
      child: ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          dioProvider.overrideWith(
            (ref) => createApiClient(
              readToken: store.read,
              baseUrl: 'https://api.test/api',
              adapter: adapter,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  /// Deux passes : la première ouvre la session, la seconde laisse arriver les
  /// lots de la carte (chargés une fois la session connue).
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  }

  Map<String, FakeResponse> routes([
    Map<String, FakeResponse> extra = const {},
  ]) => {
    'GET /auth/me': const FakeResponse(200, profileJson),
    'GET /collection/OGN-209': FakeResponse(
      200,
      cardStateJson(cardId: 'OGN-209', entries: [entryJson(id: 12, qty: 2)]),
    ),
    ...extra,
  };

  testWidgets('sans session : invite à se connecter avec retour', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(routes());

    await tester.pumpWidget(host(adapter, token: null));
    await settle(tester);

    expect(find.text('Connecte-toi pour suivre ta collection'), findsOneWidget);
    expect(adapter.requests, isEmpty);

    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();

    expect(find.text('connexion depuis /cartes/OGN-209'), findsOneWidget);
  });

  testWidgets('avec session : la quantité possédée s’affiche et s’incrémente', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({
        'PUT /collection/OGN-209': const FakeResponse(200, {
          'card_id': 'OGN-209',
          'qty': 3,
          'condition': 'NM',
          'lang': 'EN',
        }),
      }),
    );

    await tester.pumpWidget(host(adapter));
    await settle(tester);

    expect(find.text('2 exemplaires'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // le chiffre du stepper

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump(); // mise à jour optimiste, avant la réponse du serveur
    expect(find.text('3 exemplaires'), findsOneWidget);

    await settle(tester);
    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.path, '/collection/OGN-209');
    expect(put.jsonBody, {'qty': 3, 'condition': 'NM', 'lang': 'EN'});
  });

  testWidgets('le bouton wishlist bascule l’envie (quantité 1)', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({'PUT /wishlist/OGN-209': const FakeResponse(204, {})}),
    );

    await tester.pumpWidget(host(adapter));
    await settle(tester);

    expect(find.text('Ajouter à la wishlist'), findsOneWidget);

    await tester.tap(find.text('Ajouter à la wishlist'));
    await tester.pumpAndSettle();

    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.path, '/wishlist/OGN-209');
    expect(put.jsonBody, {'qty': 1});
    expect(find.text('Dans ma wishlist'), findsOneWidget);
  });

  testWidgets('carte déjà souhaitée : le bouton retire de la wishlist', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({'DELETE /wishlist/OGN-209': const FakeResponse(204, {})}),
    );

    await tester.pumpWidget(
      host(adapter, card: cardWith(ownedQty: 2, wishedQty: 1)),
    );
    await settle(tester);

    await tester.tap(find.text('Dans ma wishlist'));
    await tester.pumpAndSettle();

    expect(
      adapter.requests.any(
        (r) => r.method == 'DELETE' && r.path == '/wishlist/OGN-209',
      ),
      isTrue,
    );
    expect(find.text('Ajouter à la wishlist'), findsOneWidget);
  });

  testWidgets('plusieurs lots : le détail est rappelé sous le stepper', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({
        'GET /collection/OGN-209': FakeResponse(
          200,
          cardStateJson(
            cardId: 'OGN-209',
            entries: [
              entryJson(id: 12, qty: 2),
              entryJson(id: 13, condition: 'EX', lang: 'FR'),
            ],
          ),
        ),
      }),
    );

    await tester.pumpWidget(host(adapter));
    await settle(tester);

    expect(find.text('3 exemplaires'), findsOneWidget);
    // Un badge mono par lot.
    expect(find.text('2× NM EN'), findsOneWidget);
    expect(find.text('1× EX FR'), findsOneWidget);
  });
}
