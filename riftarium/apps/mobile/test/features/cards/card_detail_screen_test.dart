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
  /// Une carte possédée brille en continu (reflet foil) : sans réduction de
  /// mouvement, `pumpAndSettle` n'aurait jamais de fin. Toutes les briques de
  /// la charte respectent ce réglage système.
  void reduceMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  /// Les révélations en cascade (`Reveal`) posent un minuteur par bloc, même
  /// en mouvement réduit : on les laisse s'écouler avant la fin du test.
  Future<void> settle(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 700));
  }

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
  /// recherches de texte. Les variantes voyagent dans la fiche elle-même
  /// (`GET /cards/{id}` renvoie `variants`) : pas de second appel.
  Map<String, Object> routes({
    Map<String, dynamic>? card,
    List<Map<String, dynamic>>? variants,
  }) => {
    'GET /cards': cardPageJson(total: 0, items: const []),
    'GET /sets': setsJson,
    'GET /prices/meta': pricesMetaJson,
    'GET /cards/OGN-209': {
      ...(card ?? jinx),
      'variants': variants ?? const <Map<String, dynamic>>[],
    },
  };

  testWidgets('la fiche affiche les champs de la carte', (tester) async {
    reduceMotion(tester);
    final api = CardsFakeApi(routes());

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.byType(CardDetailScreen), findsOneWidget);
    // Le nom apparaît sous le visuel et dans le substitut d'image (la fixture
    // n'a pas d'`image_url`).
    expect(find.text('Jinx, la Gâchette folle'), findsWidgets);
    expect(find.text('OGN 209'), findsOneWidget);
    expect(find.text('Unité · Épique · OGN'), findsOneWidget);
    expect(find.text('Champion'), findsOneWidget);
    // Un domaine, une pastille.
    expect(find.text('Fureur'), findsOneWidget);
    expect(find.text('Chaos'), findsOneWidget);
    expect(find.text('Zaun'), findsOneWidget);
    // Le texte de règles est rendu en spans (mots-clés, glyphes).
    expect(
      find.text('Quand Jinx arrive, infligez 2 dégâts.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('« Rien de personnel. »'), findsOneWidget);
    expect(find.text('Illustration : Riot Games'), findsOneWidget);
    // Statistiques : libellés en sur-titre, donc en capitales.
    expect(find.text('ÉNERGIE'), findsOneWidget);
    expect(find.text('PUISSANCE'), findsOneWidget);
    expect(find.text('POUVOIR'), findsOneWidget);
    // Valeurs en glyphes officiels, comme la fiche du site : pastille
    // d'énergie, glyphe de puissance + valeur, une rune par point de pouvoir
    // (premier domaine : Fureur).
    expect(_glyph('Énergie 5'), findsOneWidget);
    expect(_glyph('Puissance'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(_glyph('Rune de Fureur'), findsNWidgets(2));
    expect(find.text('Ouvrir sur le site'), findsOneWidget);
  });

  testWidgets('le prix est en euros, avec la date de mise à jour', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi(routes());

    await tester.pumpWidget(app(api));
    await settle(tester);

    // Espace insécable avant le symbole (voir formatEuro).
    expect(find.text('12,34\u00A0€'), findsOneWidget);
    expect(find.textContaining('20/08/2026'), findsOneWidget);
    expect(find.text('Voir sur Cardmarket ↗'), findsOneWidget);
  });

  testWidgets('le prix foil est affiché quand il diffère du prix normal', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi(routes(card: {...jinx, 'price_foil_eur': 22.5}));

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.text('12,34 €'), findsOneWidget);
    expect(find.text('foil : 22,50 €'), findsOneWidget);
  });

  testWidgets('les variantes sont proposées en carrousel', (tester) async {
    reduceMotion(tester);
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
    await settle(tester);

    expect(find.text('Variantes'), findsOneWidget);
    expect(find.text('Normale'), findsOneWidget);
    expect(find.text('Alt'), findsOneWidget);
  });

  testWidgets('sans variante supplémentaire, la section reste masquée', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi(routes(variants: [jinx]));

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.text('Variantes'), findsNothing);
    // Aucune requête de variantes : la fiche suffit.
    expect(
      api.requests.where((request) => request.path.endsWith('/variants')),
      isEmpty,
    );
  });

  testWidgets('carte introuvable : message d’erreur et nouvel essai', (
    tester,
  ) async {
    reduceMotion(tester);
    final api = CardsFakeApi({
      'GET /cards': cardPageJson(total: 0, items: const []),
      'GET /sets': setsJson,
    });

    await tester.pumpWidget(app(api));
    await settle(tester);

    expect(find.text('Carte introuvable'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });

  testWidgets('connecté : les quantités possédées apparaissent', (
    tester,
  ) async {
    reduceMotion(tester);
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
    await settle(tester);

    // Sans réponse de /collection/{id}, le bloc de collection retombe sur
    // owned_qty et wished_qty de la carte.
    expect(find.text('3 exemplaires'), findsOneWidget);
    expect(find.text('Dans ma wishlist'), findsOneWidget);
    // La quantité possédée se lit aussi sur la vignette de la grille.
    expect(find.text('MA COLLECTION'), findsOneWidget);
  });
}

/// Un glyphe officiel se repère à son étiquette d'accessibilité (CardGlyph).
Finder _glyph(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);
