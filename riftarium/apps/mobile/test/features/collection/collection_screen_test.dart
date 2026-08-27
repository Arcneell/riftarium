import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/collection/ui/collection_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  final jinx = cardJson(id: 'OGN-209', priceEur: 12.5);

  Widget app(FakeHttpAdapter adapter, {String? token = 'jwt'}) {
    final store = InMemoryTokenStore(token);
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.collection),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: adapter,
          ),
        ),
      ],
      child: const RiftariumApp(),
    );
  }

  Map<String, FakeResponse> routes([
    Map<String, FakeResponse> extra = const {},
  ]) => {
    'GET /auth/me': const FakeResponse(200, profileJson),
    'GET /collection': FakeResponse(
      200,
      collectionPageJson(
        items: [
          collectionItemJson(
            card: jinx,
            entries: [entryJson(id: 12, qty: 2)],
            priceEur: 12.5,
          ),
        ],
        totalCards: 2,
        uniqueCards: 1,
        valueEur: 25,
        total: 1,
      ),
    ),
    'GET /collection/sets': const FakeResponse(200, setsProgressJson),
    ...extra,
  };

  testWidgets('sans session : invite à se connecter', (tester) async {
    await tester.pumpWidget(app(FakeHttpAdapter(routes()), token: null));
    await tester.pumpAndSettle();

    expect(find.byType(CollectionScreen), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect(find.text('Cartes différentes'), findsNothing);
  });

  testWidgets('avec session : résumé, progression et cartes possédées', (
    tester,
  ) async {
    await tester.pumpWidget(app(FakeHttpAdapter(routes())));
    await tester.pumpAndSettle();

    expect(find.text('Cartes différentes'), findsOneWidget);
    // Valeur totale en en-tête et valeur du lot sous la carte.
    expect(find.text('25,00 €'), findsNWidgets(2));
    // Le nom apparaît deux fois : sur le visuel de secours et sous la carte.
    expect(find.text('Jinx, la Gâchette folle'), findsWidgets);
    expect(find.text('OGN 209'), findsOneWidget);
    expect(find.text('×2 · NM · EN'), findsOneWidget);
    expect(find.textContaining('Progression par set'), findsOneWidget);

    // La progression est repliée par défaut : le détail apparaît au clic.
    expect(find.text('Origines'), findsNothing);
    await tester.tap(find.textContaining('Progression par set'));
    await tester.pumpAndSettle();
    expect(find.text('Origines'), findsOneWidget);
    expect(find.text('il manque 75 cartes (~210,50 €)'), findsWidgets);
  });

  testWidgets('collection vide : message d’accueil', (tester) async {
    final adapter = FakeHttpAdapter(
      routes({'GET /collection': FakeResponse(200, collectionPageJson())}),
    );

    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Ta collection est vide'), findsOneWidget);
  });

  testWidgets('erreur serveur : message et bouton Réessayer', (tester) async {
    final adapter = FakeHttpAdapter(
      routes({
        'GET /collection': const FakeResponse(500, {
          'detail': 'Base indisponible',
        }),
      }),
    );

    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    expect(find.text('Base indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('appui long : la feuille d’édition modifie le lot', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({
        'PATCH /collection/entries/12': FakeResponse(
          200,
          cardStateJson(
            cardId: 'OGN-209',
            entries: [entryJson(id: 12, qty: 3)],
          ),
        ),
      }),
    );

    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    // La grille passe sous la barre d'onglets : on la remonte avant l'appui.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('OGN 209'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter un lot'), findsOneWidget);
    expect(find.text('OGN 209 · 2 exemplaire(s)'), findsOneWidget);

    // Le premier « + » est celui du lot existant.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();

    final patch = adapter.requests.firstWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/collection/entries/12');
    expect(patch.jsonBody, {'qty': 3});

    // Rechargements déclenchés par la mutation (liste et progression).
    await tester.pump();
    await tester.pumpAndSettle();
  });

  testWidgets('en-tête : le bouton Wishlist ouvre la sous-route', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({'GET /wishlist': FakeResponse(200, wishlistJson())}),
    );

    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wishlist'));
    await tester.pumpAndSettle();

    expect(find.text('Ta wishlist est vide'), findsOneWidget);
  });
}
