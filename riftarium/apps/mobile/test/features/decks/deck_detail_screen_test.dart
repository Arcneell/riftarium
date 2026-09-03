import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/decks/ui/deck_detail_screen.dart';
import 'package:riftarium_mobile/features/decks/ui/deck_editor_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';
import 'support/decks_fixtures.dart';

void main() {
  Widget app(DecksFakeApi server, {String? token = 'jwt', int deckId = 1}) {
    final store = InMemoryTokenStore(token);
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.deck(deckId)),
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

  /// Deck de test : une légende, un champ de bataille, des runes et une unité.
  Map<String, dynamic> fullDeck({
    List<Map<String, dynamic>>? checks,
    String owner = 'ezreal',
    bool isPublic = false,
    int likes = 0,
    bool likedByMe = false,
  }) => deckJson(
    id: 1,
    name: 'Fureur d’Ahri',
    description: 'Rapide et brutal.',
    owner: owner,
    isPublic: isPublic,
    likes: likes,
    likedByMe: likedByMe,
    views: 17,
    cards: [
      deckEntryJson(
        deckCardJson(id: 'L', name: 'Ahri, Légende', type: 'Legend'),
        1,
      ),
      deckEntryJson(
        deckCardJson(
          id: 'B',
          name: 'Autel',
          type: 'Battlefield',
          orientation: 'landscape',
        ),
        1,
      ),
      deckEntryJson(
        deckCardJson(id: 'R', name: 'Rune de fureur', type: 'Rune'),
        12,
      ),
      deckEntryJson(deckCardJson(id: 'U', name: 'Charm', energy: 2), 3),
    ],
    checks:
        checks ??
        [
          checkJson('legend', true, 'Exactement 1 légende (1 actuellement)'),
          checkJson('runes', true, '12 runes (12 actuellement)'),
        ],
  );

  testWidgets('affiche l’en-tête, les zones et « Deck légal »', (tester) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/1': fullDeck(),
      'POST /decks/1/view': {'deck_id': 1, 'views': 17, 'counted': false},
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.byType(DeckDetailScreen), findsOneWidget);
    expect(find.text('Fureur d’Ahri'), findsWidgets);
    expect(find.text('par ezreal'), findsOneWidget);
    expect(find.text('Rapide et brutal.'), findsOneWidget);
    expect(find.text('Deck légal'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);

    // Les zones sont plus bas : la liste est construite à la demande.
    for (final label in [
      'Légende · 1/1',
      'Champs de bataille · 1/3',
      'Runes · 12/12',
      'Deck principal · 3/40+',
    ]) {
      await tester.scrollUntilVisible(find.text(label), 200);
      await tester.pumpAndSettle();
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('×12'), findsOneWidget);
    expect(find.text('×3'), findsOneWidget);
  });

  testWidgets('liste les règles non respectées', (tester) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/1': fullDeck(
        checks: [
          checkJson('legend', true, 'Exactement 1 légende (1 actuellement)'),
          checkJson('runes', false, '12 runes (0 actuellement)'),
          checkJson('main_size', false, 'Deck principal : 40 cartes minimum'),
        ],
      ),
      'POST /decks/1/view': {'deck_id': 1, 'views': 17, 'counted': false},
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('À corriger'), findsOneWidget);
    expect(find.text('12 runes (0 actuellement)'), findsOneWidget);
    expect(find.text('Deck principal : 40 cartes minimum'), findsOneWidget);
    expect(find.text('Deck légal'), findsNothing);
  });

  testWidgets('enregistre une vue à l’ouverture', (tester) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/1': fullDeck(),
      'POST /decks/1/view': {'deck_id': 1, 'views': 18, 'counted': true},
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(server.on('POST', '/decks/1/view'), hasLength(1));
  });

  testWidgets('le propriétaire peut éditer et voir ses manquantes', (
    tester,
  ) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/1': fullDeck(),
      'POST /decks/1/view': {'deck_id': 1, 'views': 17, 'counted': false},
      'GET /decks/1/missing': {
        'items': [
          {
            'card': deckCardJson(id: 'U', name: 'Charm'),
            'needed': 3,
            'owned': 1,
            'missing': 2,
          },
        ],
        'missing_total': 2,
        'deck_total': 17,
      },
      'GET /cards': cardPageJson(const []),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('Modifier'), findsOneWidget);
    expect(find.text('Copier dans mes decks'), findsNothing);

    // Le bloc « Cartes manquantes » ferme la liste des zones, tout en bas.
    await tester.scrollUntilVisible(find.text('Cartes manquantes'), 300);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cartes manquantes'));
    await tester.pumpAndSettle();
    expect(
      find.text('Il te manque 2 carte(s) sur les 17 du deck.'),
      findsOneWidget,
    );
    expect(find.text('2 à trouver · 1/3 en collection'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckEditorScreen), findsOneWidget);
    // 1 légende + 1 champ de bataille + 12 runes + 3 unités : des exemplaires,
    // pas des lignes.
    expect(find.text('Mon deck (17)'), findsOneWidget);
  });

  testWidgets('un visiteur peut copier le deck et l’aimer', (tester) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/1': fullDeck(owner: 'jinx', isPublic: true, likes: 3),
      'POST /decks/1/view': {'deck_id': 1, 'views': 18, 'counted': true},
      'POST /decks/1/like': {'deck_id': 1, 'likes': 4, 'liked_by_me': true},
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('Copier dans mes decks'), findsOneWidget);
    expect(find.text('Modifier'), findsNothing);

    await tester.tap(find.byIcon(Icons.favorite_outline));
    await tester.pumpAndSettle();
    // Le rechargement de la fiche déclenché par le like doit être consommé.
    await tester.pumpAndSettle();
    expect(server.on('POST', '/decks/1/like'), hasLength(1));
  });

  testWidgets('une erreur de chargement propose de réessayer', (tester) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/1': const DecksFakeError(404, 'Deck introuvable'),
    });
    await tester.pumpWidget(app(server));
    await tester.pumpAndSettle();

    expect(find.text('Deck introuvable'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
