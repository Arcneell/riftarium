import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/collection/ui/binder_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  /// Le classeur anime en continu (reflet foil, pivotement des pages) : la
  /// réduction de mouvement rend `pumpAndSettle` fiable, comme ailleurs.
  Widget reduceMotion(Widget child) => MediaQuery(
    data: const MediaQueryData(disableAnimations: true),
    child: child,
  );

  Widget app(
    FakeHttpAdapter adapter, {
    String? token = 'jwt',
    String location = AppRoutes.binder,
  }) {
    final store = InMemoryTokenStore(token);
    return reduceMotion(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          initialLocationProvider.overrideWithValue(location),
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

  /// Deux sets : Origines incomplet (ouvert par défaut), Vendetta complet.
  const progressJson = {
    'sets': [
      {
        'set_id': 'OGN',
        'name': 'Origines',
        'total': 100,
        'owned': 25,
        'missing': 75,
        'missing_cost_eur': 210.5,
        'owned_value_eur': 64.0,
      },
      {
        'set_id': 'VDT',
        'name': 'Vendetta',
        'total': 40,
        'owned': 40,
        'missing': 0,
        'missing_cost_eur': null,
        'owned_value_eur': 80.0,
      },
    ],
    'overall': {
      'total': 140,
      'owned': 65,
      'missing': 75,
      'missing_cost_eur': 210.5,
      'owned_value_eur': 144.0,
    },
  };

  /// Une page du classeur : une carte possédée (×2) et une manquante.
  Map<String, dynamic> binderPageJson() => {
    'total': 20,
    'page': 1,
    'size': 9,
    'items': [
      cardJson(
        id: 'OGN-209',
        collectorNumber: 209,
        ownedQty: 2,
        priceEur: 12.5,
      ),
      cardJson(
        id: 'OGN-210',
        name: 'Mécano de Zaun',
        collectorNumber: 210,
        ownedQty: 0,
        priceEur: 2.5,
      ),
    ],
  };

  Map<String, FakeResponse> routes([
    Map<String, FakeResponse> extra = const {},
  ]) => {
    'GET /auth/me': const FakeResponse(200, profileJson),
    'GET /collection/sets': const FakeResponse(200, progressJson),
    'GET /cards': FakeResponse(200, binderPageJson()),
    ...extra,
  };

  testWidgets(
    'ouvre le premier set incomplet : pochettes pleines et fantômes',
    (tester) async {
      final adapter = FakeHttpAdapter(routes());
      await tester.pumpWidget(app(adapter));
      await tester.pumpAndSettle();

      expect(find.byType(BinderScreen), findsOneWidget);
      expect(find.text('Classeur'), findsOneWidget);

      // Puce du set incomplet (avec pourcentage) et du set complet (coche).
      expect(find.text('OGN · 25 %'), findsOneWidget);
      expect(find.text('VDT'), findsOneWidget);

      // Panneau du set ouvert : nom, compteur, cartes manquantes.
      expect(find.text('Origines'), findsOneWidget);
      expect(find.text('25/100'), findsOneWidget);
      expect(
        find.text('25 % · Il manque 75 cartes (~210,50 €)'),
        findsOneWidget,
      );

      // La double page demande les cartes du set par pages de 9.
      final request = adapter.requests.firstWhere((r) => r.path == '/cards');
      expect(request.options.queryParameters['set_id'], 'OGN');
      expect(request.options.queryParameters['size'], 9);

      // Carte possédée : pastille de quantité. Manquante : code et prix.
      expect(find.text('×2'), findsOneWidget);
      expect(find.text('OGN 210'), findsOneWidget);
      expect(find.text('2,50 €'), findsOneWidget);

      // 20 cartes par pages de 9 : trois doubles pages.
      expect(find.text('page 1 / 3'), findsOneWidget);
    },
  );

  testWidgets('filtre « Manquantes » : recharge la page avec owned=0', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(routes());
    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manquantes'));
    await tester.pumpAndSettle();

    final filtered = adapter.requests.where(
      (r) => r.path == '/cards' && r.options.queryParameters['owned'] == '0',
    );
    expect(filtered, isNotEmpty);
  });

  testWidgets('puce d’un autre set : ouvre ce set à la première page', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(routes());
    await tester.pumpWidget(app(adapter));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VDT'));
    await tester.pumpAndSettle();

    final vendetta = adapter.requests.where(
      (r) => r.path == '/cards' && r.options.queryParameters['set_id'] == 'VDT',
    );
    expect(vendetta, isNotEmpty);
    expect(find.text('Vendetta'), findsOneWidget);
  });

  testWidgets('l’onglet Collection ouvre le classeur (action dorée)', (
    tester,
  ) async {
    final adapter = FakeHttpAdapter(
      routes({
        'GET /collection': FakeResponse(
          200,
          collectionPageJson(
            items: [
              collectionItemJson(
                card: cardJson(id: 'OGN-209'),
                entries: [entryJson(id: 12, qty: 2)],
              ),
            ],
            totalCards: 2,
            uniqueCards: 1,
            total: 1,
          ),
        ),
      }),
    );
    await tester.pumpWidget(app(adapter, location: AppRoutes.collection));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Ouvrir le classeur'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ouvrir le classeur'));
    await tester.pumpAndSettle();

    expect(find.byType(BinderScreen), findsOneWidget);
    expect(find.text('page 1 / 3'), findsOneWidget);
  });

  testWidgets('sans session : invite à se connecter', (tester) async {
    await tester.pumpWidget(app(FakeHttpAdapter(routes()), token: null));
    await tester.pumpAndSettle();

    expect(find.byType(BinderScreen), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });
}
