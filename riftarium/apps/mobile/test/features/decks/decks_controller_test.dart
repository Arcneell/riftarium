import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/decks/application/decks_controller.dart';
import 'package:riftarium_mobile/features/decks/domain/deck.dart';
import 'package:riftarium_mobile/features/decks/domain/deck_code.dart';

import '../../support/fakes.dart';
import 'support/decks_fixtures.dart';

/// Code du deck `[{OGN-247, 1}, {OGN-004, 3}]`, sans champion élu
/// (voir `deck_code_test.dart`).
const importableCode = 'CMAAAAAAAAAAAAAAAEAQAAAEAAAQCAAA64AQAAAAAA';

void main() {
  ProviderContainer container(DecksFakeApi server, {String? token = 'jwt'}) {
    final store = InMemoryTokenStore(token);
    final result = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: server,
          ),
        ),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  Map<String, Object> routes([Map<String, Object> extra = const {}]) => {
    'GET /auth/me': profileJson,
    ...extra,
  };

  test('mes decks se chargent une fois la session restaurée', () async {
    final server = DecksFakeApi(
      routes({
        'GET /decks/mine': [deckJson(id: 1, name: 'Ahri')],
      }),
    );
    final ref = container(server);
    await ref.read(authControllerProvider.notifier).whenRestored;

    final decks = await ref.read(myDecksProvider.future);
    expect(decks.single.name, 'Ahri');
  });

  test('sans session, mes decks restent vides sans appel réseau', () async {
    final server = DecksFakeApi(const {});
    final ref = container(server, token: null);
    await ref.read(authControllerProvider.notifier).whenRestored;

    expect(await ref.read(myDecksProvider.future), isEmpty);
    expect(server.calls, isEmpty);
  });

  test('la communauté est lisible sans compte', () async {
    final server = DecksFakeApi({
      'GET /community/decks': communityPageJson(
        items: [communityDeckJson(id: 1, name: 'Deck de Jinx')],
      ),
    });
    final ref = container(server, token: null);
    await ref.read(authControllerProvider.notifier).whenRestored;

    final page = await ref.read(communityDecksProvider.future);
    expect(page.items.single.name, 'Deck de Jinx');
  });

  test('un changement de filtre relance la requête sur la page 1', () async {
    final server = DecksFakeApi({
      'GET /community/decks': communityPageJson(items: const []),
    });
    final ref = container(server, token: null);
    await ref.read(authControllerProvider.notifier).whenRestored;
    await ref.read(communityDecksProvider.future);

    final notifier = ref.read(communityQueryProvider.notifier);
    notifier.setPage(3);
    expect(ref.read(communityQueryProvider).page, 3);
    notifier.setSort('recent');
    expect(ref.read(communityQueryProvider).page, 1);
    expect(ref.read(communityQueryProvider).filters.sort, 'recent');

    await ref.read(communityDecksProvider.future);
    expect(
      server.on('GET', '/community/decks').last.queryParameters['sort'],
      'recent',
    );
  });

  test('les filtres multiples s’ajoutent et se retirent', () {
    final ref = container(DecksFakeApi(const {}), token: null);
    final notifier = ref.read(communityQueryProvider.notifier);

    notifier.toggleLegend('OGN-247');
    notifier.toggleLegend('OGN-248');
    expect(ref.read(communityQueryProvider).filters.legends, [
      'OGN-247',
      'OGN-248',
    ]);
    notifier.toggleLegend('OGN-247');
    expect(ref.read(communityQueryProvider).filters.legends, ['OGN-248']);

    notifier.toggleDomain('Fury');
    notifier.setFormat('free');
    notifier.setQuery('ahri');
    expect(ref.read(communityQueryProvider).filters.activeCount, 4);

    // Le tri n'est pas un filtre : il survit à la remise à zéro.
    notifier.setSort('views');
    notifier.reset();
    expect(ref.read(communityQueryProvider).filters.activeCount, 0);
    expect(ref.read(communityQueryProvider).filters.sort, 'views');
  });

  test('créer un deck rafraîchit la liste', () async {
    final server = DecksFakeApi(
      routes({
        'GET /decks/mine': [deckJson(id: 1, name: 'Ahri')],
        'POST /decks': deckJson(id: 2, name: 'Nouveau'),
      }),
    );
    final ref = container(server);
    await ref.read(authControllerProvider.notifier).whenRestored;
    await ref.read(myDecksProvider.future);

    final deck = await ref
        .read(deckActionsProvider)
        .create(const DeckInput(name: 'Nouveau'));
    expect(deck.name, 'Nouveau');

    await ref.read(myDecksProvider.future);
    expect(server.on('GET', '/decks/mine').length, greaterThanOrEqualTo(2));
  });

  test('une vue ratée ne remonte jamais d’erreur', () async {
    final server = DecksFakeApi(routes());
    final ref = container(server);
    await ref.read(authControllerProvider.notifier).whenRestored;

    await ref.read(deckActionsProvider).recordView(404);
    expect(server.on('POST', '/decks/404/view'), hasLength(1));
  });

  group('import d’un code de deck', () {
    test('résout les cartes puis crée le deck', () async {
      final server = DecksFakeApi(
        routes({
          'GET /cards': cardPageJson([
            deckCardJson(
              id: 'C-247',
              name: 'Daughter of the Void',
              riftboundId: 'ogn-247-298',
              type: 'Legend',
            ),
            deckCardJson(
              id: 'C-004',
              name: 'Charm',
              riftboundId: 'ogn-004-298',
            ),
          ]),
          'POST /decks': deckJson(id: 12, name: 'Deck importé'),
        }),
      );
      final ref = container(server);
      await ref.read(authControllerProvider.notifier).whenRestored;

      final outcome = await ref
          .read(deckActionsProvider)
          .importFromCode(importableCode, name: 'Deck importé');

      expect(outcome.deck.id, 12);
      expect(outcome.unresolved, isEmpty);

      final body = server.on('POST', '/decks').single.data! as Map;
      expect(body['name'], 'Deck importé');
      // Le code liste les quantités décroissantes : 3 exemplaires d'abord.
      expect(body['cards'], [
        {'card_id': 'C-004', 'qty': 3},
        {'card_id': 'C-247', 'qty': 1},
      ]);

      // Une recherche par code de carte, sans le suffixe de variante.
      expect(
        server.on('GET', '/cards').map((r) => r.queryParameters['q']),
        containsAll(<String>['ogn-247', 'ogn-004']),
      );
    });

    test('signale les cartes introuvables sans bloquer la création', () async {
      final server = DecksFakeApi(
        routes({
          'GET /cards': cardPageJson([
            deckCardJson(
              id: 'C-247',
              name: 'Daughter of the Void',
              riftboundId: 'ogn-247-298',
              type: 'Legend',
            ),
          ]),
          'POST /decks': deckJson(id: 13),
        }),
      );
      final ref = container(server);
      await ref.read(authControllerProvider.notifier).whenRestored;

      final outcome = await ref
          .read(deckActionsProvider)
          .importFromCode(importableCode, name: 'Partiel');

      expect(outcome.unresolved, ['OGN-004']);
      final body = server.on('POST', '/decks').single.data! as Map;
      expect(body['cards'], [
        {'card_id': 'C-247', 'qty': 1},
      ]);
    });

    test('refuse un code illisible', () async {
      final server = DecksFakeApi(routes());
      final ref = container(server);
      await ref.read(authControllerProvider.notifier).whenRestored;

      await expectLater(
        ref.read(deckActionsProvider).importFromCode('!!!', name: 'X'),
        throwsA(isA<DeckCodeException>()),
      );
    });

    test('refuse un code dont aucune carte n’existe en base', () async {
      final server = DecksFakeApi(
        routes({'GET /cards': cardPageJson(const [])}),
      );
      final ref = container(server);
      await ref.read(authControllerProvider.notifier).whenRestored;

      await expectLater(
        ref
            .read(deckActionsProvider)
            .importFromCode(importableCode, name: 'Vide'),
        throwsA(isA<DeckCodeException>()),
      );
      expect(server.on('POST', '/decks'), isEmpty);
    });
  });
}
