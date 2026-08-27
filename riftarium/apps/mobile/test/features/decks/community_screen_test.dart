import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/decks/ui/community_screen.dart';
import 'package:riftarium_mobile/features/decks/ui/deck_detail_screen.dart';
import 'package:riftarium_mobile/features/decks/ui/deck_widgets.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';
import 'support/decks_fixtures.dart';

void main() {
  Widget app(DecksFakeApi server, {String? token}) {
    final store = InMemoryTokenStore(token);
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.community),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: server,
          ),
        ),
      ],
      child: const RiftariumApp(),
    );
  }

  final legends = [
    {'id': 'OGN-247', 'name': 'Ahri', 'image_url': null, 'deck_count': 12},
  ];

  testWidgets('sans compte : la liste des decks partagés est lisible', (
    tester,
  ) async {
    final server = DecksFakeApi({
      'GET /community/legends': legends,
      'GET /community/decks': communityPageJson(
        total: 2,
        items: [
          communityDeckJson(
            id: 1,
            name: 'Fureur d’Ahri',
            owner: 'jinx',
            likes: 9,
            views: 44,
            cardCount: 56,
            legend: deckCardJson(id: 'L', name: 'Ahri', type: 'Legend'),
          ),
          communityDeckJson(
            id: 2,
            name: 'Bazar illégal',
            format: 'free',
            legal: false,
            cardCount: 40,
          ),
        ],
      ),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityScreen), findsOneWidget);
    expect(find.text('Communauté'), findsWidgets);
    // Le segment épinglé ramène à « Mes decks » sans quitter l'onglet.
    expect(find.text('Mes decks'), findsOneWidget);
    expect(find.text('2 deck(s)'), findsOneWidget);
    expect(find.text('Fureur d’Ahri'), findsOneWidget);
    expect(find.text('Ahri · par jinx'), findsOneWidget);
    expect(find.text('56 cartes'), findsOneWidget);
    expect(find.text('Légal'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('44'), findsOneWidget);

    // Le filtre « Constructibles » n'a de sens qu'avec une collection : il
    // n'apparaît pas ici, même en déroulant toute la barre de filtres.
    await tester.drag(find.byType(ListView).first, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Constructibles'), findsNothing);

    // Le deuxième deck est plus bas : la liste se construit à la demande.
    await tester.scrollUntilVisible(
      find.text('Bazar illégal'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Bazar illégal'), findsOneWidget);
    expect(find.text('Illégal'), findsOneWidget);
  });

  testWidgets('la liste vide explique quoi faire', (tester) async {
    final server = DecksFakeApi({
      'GET /community/legends': const <Map<String, dynamic>>[],
      'GET /community/decks': communityPageJson(items: const []),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('Aucun deck partagé'), findsOneWidget);
  });

  testWidgets('une erreur propose de réessayer', (tester) async {
    final server = DecksFakeApi({
      'GET /community/legends': const <Map<String, dynamic>>[],
      'GET /community/decks': const DecksFakeError(500, 'Service indisponible'),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('Service indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('changer de tri relance la requête', (tester) async {
    final server = DecksFakeApi({
      'GET /community/legends': legends,
      'GET /community/decks': communityPageJson(
        items: [communityDeckJson(id: 1)],
      ),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(
      server.on('GET', '/community/decks').single.queryParameters['sort'],
      'likes',
    );

    await tester.tap(find.text('Récents'));
    await tester.pumpAndSettle();

    expect(
      server.on('GET', '/community/decks').last.queryParameters['sort'],
      'recent',
    );
  });

  testWidgets('la recherche part après la pause de saisie', (tester) async {
    final server = DecksFakeApi({
      'GET /community/legends': legends,
      'GET /community/decks': communityPageJson(items: const []),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ahri');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(
      server.on('GET', '/community/decks').last.queryParameters['q'],
      'ahri',
    );
  });

  testWidgets('sans compte, aimer un deck invite à se connecter', (
    tester,
  ) async {
    final server = DecksFakeApi({
      'GET /community/legends': legends,
      'GET /community/decks': communityPageJson(
        items: [communityDeckJson(id: 1, likes: 2)],
      ),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    final heart = find.descendant(
      of: find.byType(DeckBox),
      matching: find.byIcon(Icons.favorite_outline),
    );
    await tester.ensureVisible(heart);
    await tester.pumpAndSettle();
    await tester.tap(heart);
    await tester.pumpAndSettle();

    expect(find.text('Connexion requise'), findsOneWidget);
    expect(server.on('POST', '/decks/1/like'), isEmpty);
  });

  testWidgets('avec un compte, le like part vers l’API', (tester) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /community/legends': legends,
      'GET /community/decks': communityPageJson(
        items: [communityDeckJson(id: 1, likes: 2)],
      ),
      'POST /decks/1/like': {'deck_id': 1, 'likes': 3, 'liked_by_me': true},
    });
    await tester.pumpWidget(app(server, token: 'jwt'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Constructibles'), findsOneWidget);

    final heart = find.descendant(
      of: find.byType(DeckBox),
      matching: find.byIcon(Icons.favorite_outline),
    );
    await tester.ensureVisible(heart);
    await tester.pumpAndSettle();
    await tester.tap(heart);
    await tester.pumpAndSettle();
    // Le rechargement de la page déclenché par le like doit être consommé.
    await tester.pumpAndSettle();

    expect(server.on('POST', '/decks/1/like'), hasLength(1));
  });

  testWidgets('ouvrir un deck mène à sa fiche', (tester) async {
    final server = DecksFakeApi({
      'GET /community/legends': legends,
      'GET /community/decks': communityPageJson(
        items: [communityDeckJson(id: 8, name: 'Deck de Jinx')],
      ),
      'GET /decks/8': deckJson(id: 8, name: 'Deck de Jinx', owner: 'jinx'),
      'POST /decks/8/view': {'deck_id': 8, 'views': 1, 'counted': true},
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Deck de Jinx'));
    await tester.pumpAndSettle();

    expect(find.byType(DeckDetailScreen), findsOneWidget);
  });
}
