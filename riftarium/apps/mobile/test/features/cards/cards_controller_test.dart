import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/cards/application/cards_controller.dart';

import 'support/cards_fixtures.dart';

void main() {
  ProviderContainer containerFor(CardsFakeApi api) {
    final store = InMemoryTokenStore();
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: api,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('la première page est chargée avec la taille attendue', () async {
    final api = CardsFakeApi({
      'GET /cards': CardsFakeRoute(
        (query) => generatedPage(page: _page(query), total: 45),
      ),
    });
    final container = containerFor(api);

    final list = await container.read(cardsListProvider.future);

    expect(list.items, hasLength(kCardsPageSize));
    expect(list.total, 45);
    expect(list.page, 1);
    expect(list.hasMore, isTrue);
    expect(api.cardQueries.single['size'], kCardsPageSize);
  });

  test('loadMore ajoute la page suivante et s’arrête à la fin', () async {
    final api = CardsFakeApi({
      'GET /cards': CardsFakeRoute(
        (query) => generatedPage(page: _page(query), total: 45),
      ),
    });
    final container = containerFor(api);
    await container.read(cardsListProvider.future);

    await container.read(cardsListProvider.notifier).loadMore();

    final list = container.read(cardsListProvider).requireValue;
    expect(list.items, hasLength(45));
    expect(list.items.first.name, 'Carte 1');
    expect(list.items.last.name, 'Carte 45');
    expect(list.page, 2);
    expect(list.hasMore, isFalse);
    expect(list.loadingMore, isFalse);
    expect(api.cardQueries.map((query) => query['page']), [1, 2]);

    // Plus rien à charger : aucune requête supplémentaire.
    await container.read(cardsListProvider.notifier).loadMore();
    expect(api.cardQueries, hasLength(2));
  });

  test('changer de filtre relance la liste depuis la page 1', () async {
    final api = CardsFakeApi({
      'GET /cards': CardsFakeRoute(
        (query) => generatedPage(page: _page(query), total: 45),
      ),
    });
    final container = containerFor(api);
    await container.read(cardsListProvider.future);
    await container.read(cardsListProvider.notifier).loadMore();

    container.read(cardFiltersProvider.notifier).setDomain('Fury');
    container.read(cardFiltersProvider.notifier).setQuery('jinx');
    final list = await container.read(cardsListProvider.future);

    expect(list.page, 1);
    expect(list.items, hasLength(kCardsPageSize));
    final last = api.cardQueries.last;
    expect(last['domain'], 'Fury');
    expect(last['q'], 'jinx');
    expect(last['page'], 1);
  });

  test('une erreur de première page remonte le message de l’API', () async {
    final api = CardsFakeApi({
      'GET /cards': const CardsFakeError(503, 'Service indisponible'),
    });
    final container = containerFor(api);

    await expectLater(
      container.read(cardsListProvider.future),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Service indisponible',
        ),
      ),
    );
    expect(container.read(cardsListProvider).hasError, isTrue);
  });

  test('une erreur de page suivante garde les cartes déjà affichées', () async {
    final api = CardsFakeApi({
      'GET /cards': CardsFakeRoute(
        (query) => _page(query) == 1
            ? generatedPage(page: 1, total: 45)
            : const CardsFakeError(500, 'Boum'),
      ),
    });
    final container = containerFor(api);
    await container.read(cardsListProvider.future);

    await container.read(cardsListProvider.notifier).loadMore();

    final list = container.read(cardsListProvider).requireValue;
    expect(list.items, hasLength(kCardsPageSize));
    expect(list.loadingMore, isFalse);
    expect(list.loadMoreError, 'Boum');
    expect(list.hasMore, isTrue);
  });

  test('le tri « aléatoire » est transmis tel quel', () async {
    final api = CardsFakeApi({
      'GET /cards': CardsFakeRoute(
        (query) => generatedPage(page: _page(query), total: 5),
      ),
    });
    final container = containerFor(api);
    await container.read(cardsListProvider.future);

    container.read(cardFiltersProvider.notifier).setSort('random');
    await container.read(cardsListProvider.future);

    expect(api.cardQueries.last['sort'], 'random');
  });
}

int _page(Map<String, dynamic> query) => int.tryParse('${query['page']}') ?? 1;
