import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/decks/ui/community_screen.dart';
import 'package:riftarium_mobile/features/decks/ui/decks_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart';
import 'support/decks_fixtures.dart';

void main() {
  Widget app(DecksFakeApi server, {String? token, String? location}) {
    final store = InMemoryTokenStore(token);
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(location ?? AppRoutes.decks),
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

  testWidgets('sans session : invite à se connecter, segment toujours là', (
    tester,
  ) async {
    await tester.pumpWidget(app(DecksFakeApi(const {})));
    await tester.pumpAndSettle();

    expect(find.byType(DecksScreen), findsOneWidget);
    expect(find.text('Tes decks'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    // Le segment reste visible : la communauté est à un tap.
    expect(find.text('Mes decks'), findsOneWidget);
    expect(find.text('Communauté'), findsOneWidget);
  });

  testWidgets('sans session : le segment ouvre la communauté', (tester) async {
    await tester.pumpWidget(
      app(
        DecksFakeApi({
          'GET /community/decks': communityPageJson(items: const []),
          'GET /community/legends': const <Map<String, dynamic>>[],
        }),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Communauté'));
    await tester.pumpAndSettle();

    expect(find.byType(CommunityScreen), findsOneWidget);
  });

  testWidgets('avec session : la liste vide invite à créer un deck', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        DecksFakeApi({
          'GET /auth/me': profileJson,
          'GET /decks/mine': const <Map<String, dynamic>>[],
        }),
        token: 'jwt',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mes decks'), findsWidgets);
    expect(find.text('Aucun deck'), findsOneWidget);
    expect(find.text('Nouveau deck'), findsOneWidget);
    // Barre d'actions + rappel dans l'invitation.
    expect(find.text('Importer un code'), findsNWidgets(2));
  });

  testWidgets('avec session : mes decks s’affichent avec leur état', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        DecksFakeApi({
          'GET /auth/me': profileJson,
          'GET /decks/mine': [
            deckJson(
              id: 1,
              name: 'Fureur d’Ahri',
              likes: 4,
              isPublic: true,
              cards: [
                deckEntryJson(
                  deckCardJson(id: 'L', name: 'Ahri', type: 'Legend'),
                  1,
                ),
              ],
              checks: [checkJson('legend', true, 'Exactement 1 légende')],
            ),
            deckJson(id: 2, name: 'Brouillon', format: 'free', cards: const []),
          ],
        }),
        token: 'jwt',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fureur d’Ahri'), findsOneWidget);
    // Le nom apparaît deux fois : substitut du visuel et ligne « légende ».
    expect(find.text('Ahri'), findsWidgets);
    expect(find.text('Légal'), findsOneWidget);
    expect(find.text('1 cartes'), findsOneWidget);
    expect(find.text('public'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    // Le deuxième deck est plus bas : la liste se construit à la demande.
    await tester.scrollUntilVisible(find.text('Brouillon'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Brouillon'), findsOneWidget);
    expect(find.text('Légende à choisir'), findsOneWidget);
    expect(find.text('Sans légende'), findsOneWidget);
    expect(find.text('Illégal'), findsOneWidget);
    expect(find.text('privé'), findsOneWidget);
  });

  testWidgets('un deck refusé par la modération le dit', (tester) async {
    await tester.pumpWidget(
      app(
        DecksFakeApi({
          'GET /auth/me': profileJson,
          'GET /decks/mine': [
            deckJson(
              id: 1,
              name: 'Deck écarté',
              isPublic: true,
              moderationStatus: 'rejected',
            ),
            deckJson(
              id: 2,
              name: 'Deck en attente',
              moderationStatus: 'pending',
            ),
          ],
        }),
        token: 'jwt',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('refusé'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Deck en attente'), 200);
    await tester.pumpAndSettle();
    expect(find.text('en modération'), findsOneWidget);
  });

  testWidgets('avec session : une erreur propose de réessayer', (tester) async {
    await tester.pumpWidget(
      app(
        DecksFakeApi({
          'GET /auth/me': profileJson,
          'GET /decks/mine': const DecksFakeError(500, 'Base indisponible'),
        }),
        token: 'jwt',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Base indisponible'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('la suppression demande confirmation avant d’appeler l’API', (
    tester,
  ) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/mine': [deckJson(id: 1, name: 'À jeter')],
      'DELETE /decks/1': <String, dynamic>{},
    });
    await tester.pumpWidget(app(server, token: 'jwt'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Supprimer le deck'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(server.on('DELETE', '/decks/1'), isEmpty);

    await tester.tap(find.byTooltip('Supprimer'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(server.on('DELETE', '/decks/1'), hasLength(1));
  });

  testWidgets('le formulaire de création envoie le deck puis l’ouvre', (
    tester,
  ) async {
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/mine': const <Map<String, dynamic>>[],
      'POST /decks': deckJson(id: 42, name: 'Nouveau deck'),
      'GET /decks/42': deckJson(id: 42, name: 'Nouveau deck'),
      'POST /decks/42/view': {'deck_id': 42, 'views': 0, 'counted': false},
    });
    await tester.pumpWidget(app(server, token: 'jwt'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nouveau deck'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Nouveau deck');
    await tester.tap(find.widgetWithText(TextButton, 'Créer'));
    await tester.pumpAndSettle();

    final body = server.on('POST', '/decks').single.data! as Map;
    expect(body['name'], 'Nouveau deck');
    expect(body['format'], 'tournament');
    expect(body['cards'], isEmpty);
    expect(server.on('GET', '/decks/42'), hasLength(1));
  });

  testWidgets('l’import d’un code crée le deck à partir des cartes trouvées', (
    tester,
  ) async {
    const code = 'CMAAAAAAAAAAAAAAAEAQAAAEAAAQCAAA64AQAAAAAA';
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/mine': const <Map<String, dynamic>>[],
      'GET /cards': cardPageJson([
        deckCardJson(
          id: 'C-247',
          name: 'Daughter of the Void',
          riftboundId: 'ogn-247-298',
          type: 'Legend',
        ),
        deckCardJson(id: 'C-004', name: 'Charm', riftboundId: 'ogn-004-298'),
      ]),
      'POST /decks': deckJson(id: 21, name: 'Deck importé'),
      'GET /decks/21': deckJson(id: 21, name: 'Deck importé'),
      'POST /decks/21/view': {'deck_id': 21, 'views': 0, 'counted': false},
    });
    await tester.pumpWidget(app(server, token: 'jwt'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importer un code').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, code);
    await tester.tap(find.widgetWithText(TextButton, 'Importer'));
    await tester.pumpAndSettle();

    final body = server.on('POST', '/decks').single.data! as Map;
    expect(body['name'], 'Deck importé');
    expect((body['cards'] as List), hasLength(2));
    expect(server.on('GET', '/decks/21'), hasLength(1));
  });

  testWidgets('l’import prévient que la réserve du code est ignorée', (
    tester,
  ) async {
    // Code croisé du jeu d'essai : 2× OGN-001 en deck principal, plus une
    // réserve de 3 exemplaires (OGN-022 ×2, OGN-088 ×1).
    const code = 'CMAAAAAAAAAAAAAAAAAQCAAAAEAAAAIBAAABMAIBAAAFQAIAAAAQ';
    final server = DecksFakeApi({
      'GET /auth/me': profileJson,
      'GET /decks/mine': const <Map<String, dynamic>>[],
      'GET /cards': cardPageJson([
        deckCardJson(
          id: 'C-001',
          name: 'Rune de Fureur',
          riftboundId: 'ogn-001',
        ),
      ]),
      'POST /decks': deckJson(id: 30, name: 'Deck importé'),
      'GET /decks/30': deckJson(id: 30, name: 'Deck importé'),
      'POST /decks/30/view': {'deck_id': 30, 'views': 0, 'counted': false},
    });
    await tester.pumpWidget(app(server, token: 'jwt'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Importer un code').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, code);
    await tester.tap(find.widgetWithText(TextButton, 'Importer'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('3 carte(s) de réserve ignorée(s)'),
      findsOneWidget,
    );
    final body = server.on('POST', '/decks').single.data! as Map;
    expect(body['cards'], [
      {'card_id': 'C-001', 'qty': 2},
    ]);
  });
}
