import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/app/router.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/cards/ui/card_detail_screen.dart';
import 'package:riftarium_mobile/main.dart';

import '../../support/fakes.dart' show profileJson;
import 'support/cards_fixtures.dart';

final Map<String, dynamic> jinx = cardJson(
  id: 'OGN-209',
  name: 'Jinx, la Gâchette folle',
  riftboundId: 'OGN-209',
  collectorNumber: 209,
  supertype: 'Champion',
  rarity: 'Epic',
  domains: const ['Fury', 'Chaos'],
  tags: const ['Zaun'],
  energy: 5,
  might: 4,
  power: 2,
  text: 'Quand Jinx arrive, infligez 2 dégâts.',
  flavour: 'Rien de personnel.',
  artist: 'Riot Games',
  priceEur: 12.34,
);

void main() {
  Widget app(CardsFakeApi api, {String token = ''}) {
    final store = InMemoryTokenStore(token.isEmpty ? null : token);
    return ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        initialLocationProvider.overrideWithValue(AppRoutes.card('OGN-209')),
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

  /// La cartothèque sous la fiche est vide : ses cartes ne brouillent pas les
  /// recherches de texte.
  Map<String, Object> routes({
    Map<String, dynamic>? card,
    List<Map<String, dynamic>>? variants,
  }) => {
    'GET /cards': cardPageJson(total: 0, items: const []),
    'GET /sets': setsJson,
    'GET /prices/meta': pricesMetaJson,
    'GET /cards/OGN-209': card ?? jinx,
    'GET /cards/OGN-209/variants': variants ?? const <Map<String, dynamic>>[],
  };

  testWidgets('la fiche affiche les champs de la carte', (tester) async {
    final api = CardsFakeApi(routes());

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(find.byType(CardDetailScreen), findsOneWidget);
    // Le nom apparaît dans la barre de navigation et dans le corps.
    expect(find.text('Jinx, la Gâchette folle'), findsWidgets);
    expect(find.text('OGN 209'), findsOneWidget);
    expect(find.text('OGN · Épique'), findsOneWidget);
    expect(find.text('Unité'), findsOneWidget);
    expect(find.text('Champion'), findsOneWidget);
    expect(find.text('Fureur / Chaos'), findsOneWidget);
    expect(find.text('Zaun'), findsOneWidget);
    expect(find.text('Quand Jinx arrive, infligez 2 dégâts.'), findsOneWidget);
    expect(find.text('« Rien de personnel. »'), findsOneWidget);
    expect(find.text('Illustration : Riot Games'), findsOneWidget);
    expect(find.text('Énergie'), findsOneWidget);
    expect(find.text('Puissance'), findsOneWidget);
    expect(find.text('Pouvoir'), findsOneWidget);
    expect(find.text('Ouvrir sur le site'), findsOneWidget);
  });

  testWidgets('le prix est en euros, avec la date de mise à jour', (
    tester,
  ) async {
    final api = CardsFakeApi(routes());

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    // Espace insécable avant le symbole (voir formatEuro).
    expect(find.text('12,34\u00A0€'), findsOneWidget);
    expect(find.textContaining('Mise à jour : 20/08/2026'), findsOneWidget);
  });

  testWidgets('les variantes sont proposées en carrousel', (tester) async {
    final api = CardsFakeApi(
      routes(
        variants: [
          jinx,
          cardJson(
            id: 'OGN-209a',
            name: 'Jinx, la Gâchette folle',
            riftboundId: 'OGN-209a',
            collectorNumber: 209,
            alternateArt: true,
          ),
        ],
      ),
    );

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(find.text('Variantes'), findsOneWidget);
    expect(find.text('Normale'), findsOneWidget);
    expect(find.text('Alt'), findsOneWidget);
  });

  testWidgets('sans variante supplémentaire, la section reste masquée', (
    tester,
  ) async {
    final api = CardsFakeApi(routes(variants: [jinx]));

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(find.text('Variantes'), findsNothing);
  });

  testWidgets('carte introuvable : message d’erreur et nouvel essai', (
    tester,
  ) async {
    final api = CardsFakeApi({
      'GET /cards': cardPageJson(total: 0, items: const []),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();

    expect(find.text('Carte introuvable'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('connecté : les quantités possédées apparaissent', (
    tester,
  ) async {
    final api = CardsFakeApi({
      ...routes(
        card: cardJson(
          id: 'OGN-209',
          name: 'Jinx',
          collectorNumber: 209,
          ownedQty: 3,
          wishedQty: 1,
        ),
      ),
      'GET /auth/me': profileJson,
    });

    await tester.pumpWidget(app(api, token: 'jwt-de-test'));
    await tester.pumpAndSettle();

    // Sans réponse de /collection/{id}, le widget retombe sur owned_qty et
    // wished_qty de la carte.
    expect(find.text('Dans ma collection : 3'), findsOneWidget);
    expect(find.text('Dans ma wishlist'), findsOneWidget);
  });
}
