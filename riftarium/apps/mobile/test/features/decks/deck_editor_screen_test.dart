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
  final legend = deckCardJson(
    id: 'L',
    name: 'Ahri, Légende',
    type: 'Legend',
    domains: const ['Fury'],
  );
  final unit = deckCardJson(id: 'U', name: 'Charm', energy: 2);
  final offDomain = deckCardJson(
    id: 'O',
    name: 'Intruse',
    domains: const ['Calm'],
  );

  Widget app(DecksFakeApi server) {
    final store = InMemoryTokenStore('jwt');
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.deck(1)),
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

  DecksFakeApi server({List<Map<String, dynamic>>? cards}) => DecksFakeApi({
    'GET /auth/me': profileJson,
    'GET /decks/1': deckJson(
      id: 1,
      name: 'Brouillon',
      cards: cards ?? const [],
    ),
    'POST /decks/1/view': {'deck_id': 1, 'views': 0, 'counted': false},
    'PUT /decks/1': deckJson(id: 1, name: 'Brouillon'),
    'GET /cards': cardPageJson([legend, unit, offDomain]),
  });

  Future<void> openEditor(WidgetTester tester, DecksFakeApi api) async {
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckEditorScreen), findsOneWidget);
  }

  testWidgets('la recherche liste les cartes et l’ajout suit les règles', (
    tester,
  ) async {
    final api = server();
    await openEditor(tester, api);

    expect(find.text('Mon deck (0)'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    // Sans légende, rien d'autre n'est acceptable.
    await tester.tap(find.text('Charm').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Choisis d’abord ta légende'), findsOneWidget);
    expect(find.text('Mon deck (0)'), findsOneWidget);

    await tester.tap(find.text('Ahri, Légende').first);
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Mon deck (1)'), findsOneWidget);

    await tester.tap(find.text('Charm').first);
    await tester.pumpAndSettle();
    expect(find.text('Mon deck (2)'), findsOneWidget);
    expect(find.text('1/40+'), findsOneWidget);

    // Hors des domaines de la légende : refusé.
    await tester.tap(find.text('Intruse').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('hors des domaines de ta légende'),
      findsOneWidget,
    );
    expect(find.text('Mon deck (2)'), findsOneWidget);
  });

  testWidgets('l’onglet « Mon deck » ajuste les quantités', (tester) async {
    final api = server(
      cards: [deckEntryJson(legend, 1), deckEntryJson(unit, 2)],
    );
    await openEditor(tester, api);

    // Le libellé compte les exemplaires (1 légende + 2 unités), pas les lignes.
    await tester.tap(find.text('Mon deck (3)'));
    await tester.pumpAndSettle();

    expect(find.text('Légende · 1/1'), findsOneWidget);
    expect(find.text('Deck principal · 2/40+'), findsOneWidget);

    await tester.tap(find.byTooltip('Ajouter un exemplaire').last);
    await tester.pumpAndSettle();
    expect(find.text('Deck principal · 3/40+'), findsOneWidget);
    expect(find.text('Mon deck (4)'), findsOneWidget);

    // Le plafond de 3 exemplaires est respecté.
    await tester.tap(find.byTooltip('Ajouter un exemplaire').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Maximum 3 exemplaires'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer un exemplaire').last);
    await tester.pumpAndSettle();
    expect(find.text('Deck principal · 2/40+'), findsOneWidget);
  });

  testWidgets('quitter un deck modifié demande confirmation', (tester) async {
    final api = server();
    await openEditor(tester, api);

    // Rien de changé : le retour sort tout de suite.
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckEditorScreen), findsNothing);

    await tester.tap(find.text('Modifier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ahri, Légende').first);
    await tester.pumpAndSettle();

    // Une carte ajoutée : le retour prévient avant de perdre le travail.
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('Quitter sans enregistrer ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Rester'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckEditorScreen), findsOneWidget);
    expect(find.text('Mon deck (1)'), findsOneWidget);

    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Quitter'));
    await tester.pumpAndSettle();
    expect(find.byType(DeckEditorScreen), findsNothing);
    expect(api.on('PUT', '/decks/1'), isEmpty);
  });

  testWidgets('l’enregistrement envoie le deck et referme l’éditeur', (
    tester,
  ) async {
    final api = server(
      cards: [deckEntryJson(legend, 1), deckEntryJson(unit, 2)],
    );
    await openEditor(tester, api);

    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final body = api.on('PUT', '/decks/1').single.data! as Map;
    expect(body['name'], 'Brouillon');
    expect(body['cards'], [
      {'card_id': 'L', 'qty': 1},
      {'card_id': 'U', 'qty': 2},
    ]);
    expect(find.byType(DeckEditorScreen), findsNothing);
    expect(find.byType(DeckDetailScreen), findsOneWidget);
  });
}
