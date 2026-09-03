import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/collection/data/collection_api.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  CollectionApi apiWith(FakeHttpAdapter adapter) => CollectionApi(
    createApiClient(
      readToken: () async => 'jwt',
      baseUrl: 'https://api.test/api',
      adapter: adapter,
    ),
  );

  final jinx = cardJson(id: 'OGN-209', priceEur: 12.5);

  test('list : chemin, paramètres et parsing de la page', () async {
    final adapter = FakeHttpAdapter({
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
          totalCards: 5,
          uniqueCards: 3,
          valueEur: 62.5,
          total: 3,
        ),
      ),
    });

    final page = await apiWith(adapter).list(query: 'jinx', page: 2, size: 30);

    expect(adapter.requests.single.options.queryParameters, {
      'q': 'jinx',
      'page': 2,
      'size': 30,
    });
    expect(page.totalCards, 5);
    expect(page.uniqueCards, 3);
    expect(page.valueEur, 62.5);
    expect(page.items.single.card.name, 'Jinx, la Gâchette folle');
    expect(page.items.single.totalQty, 2);
    expect(page.items.single.entries.single.id, 12);
    expect(page.items.single.entriesLabel, 'NM · EN');
    expect(page.items.single.valueEur, 25);
  });

  test('progress : complétion par set et cumul', () async {
    final adapter = FakeHttpAdapter({
      'GET /collection/sets': const FakeResponse(200, setsProgressJson),
    });

    final progress = await apiWith(adapter).progress();

    expect(progress.sets.single.setId, 'OGN');
    expect(progress.sets.single.name, 'Origines');
    expect(progress.sets.single.percent, 25);
    expect(
      progress.sets.single.missingLabel,
      'il manque 75 cartes (~210,50 €)',
    );
    expect(progress.overall.name, 'Tous sets confondus');
    expect(progress.overall.owned, 25);
  });

  test('cardState : lots possédés d’une carte', () async {
    final adapter = FakeHttpAdapter({
      'GET /collection/OGN-209': FakeResponse(
        200,
        cardStateJson(
          cardId: 'OGN-209',
          entries: [
            entryJson(id: 12, qty: 2),
            entryJson(id: 13, condition: 'EX', lang: 'FR'),
          ],
        ),
      ),
    });

    final state = await apiWith(adapter).cardState('OGN-209');

    expect(state.totalQty, 3);
    expect(state.entries.length, 2);
    expect(state.mainEntry?.id, 12); // le lot NM/EN pilote le stepper
    expect(state.hasSeveralLots, isTrue);
  });

  test('setQuantity : PUT avec état et langue', () async {
    final adapter = FakeHttpAdapter({
      'PUT /collection/OGN-209': const FakeResponse(200, {
        'card_id': 'OGN-209',
        'qty': 3,
        'condition': 'NM',
        'lang': 'EN',
      }),
    });

    await apiWith(adapter).setQuantity(cardId: 'OGN-209', qty: 3);

    expect(adapter.requests.single.method, 'PUT');
    expect(adapter.requests.single.jsonBody, {
      'qty': 3,
      'condition': 'NM',
      'lang': 'EN',
    });
  });

  test('addEntry : POST sur /entries', () async {
    final adapter = FakeHttpAdapter({
      'POST /collection/OGN-209/entries': FakeResponse(
        200,
        cardStateJson(
          cardId: 'OGN-209',
          entries: [entryJson(id: 14, qty: 4, condition: 'EX', lang: 'FR')],
        ),
      ),
    });

    final state = await apiWith(
      adapter,
    ).addEntry(cardId: 'OGN-209', qty: 4, condition: 'EX', lang: 'FR');

    expect(adapter.requests.single.jsonBody, {
      'qty': 4,
      'condition': 'EX',
      'lang': 'FR',
    });
    expect(state.totalQty, 4);
  });

  test('updateEntry : PATCH n’envoie que les champs fournis', () async {
    final adapter = FakeHttpAdapter({
      'PATCH /collection/entries/12': FakeResponse(
        200,
        cardStateJson(cardId: 'OGN-209'),
      ),
    });

    final state = await apiWith(adapter).updateEntry(entryId: 12, qty: 0);

    expect(adapter.requests.single.method, 'PATCH');
    expect(adapter.requests.single.jsonBody, {'qty': 0});
    expect(state.entries, isEmpty);
  });

  test('wishlist : liste, valeur estimée et quantités', () async {
    final adapter = FakeHttpAdapter({
      'GET /wishlist': FakeResponse(
        200,
        wishlistJson(
          items: [
            wishItemJson(card: cardJson(id: 'OGN-209', priceEur: 12.5), qty: 2),
          ],
          valueEur: 25,
        ),
      ),
    });

    final wishlist = await apiWith(adapter).wishlist();

    expect(wishlist.total, 1);
    expect(wishlist.valueEur, 25);
    expect(wishlist.items.single.qty, 2);
    expect(wishlist.items.single.valueEur, 25);
  });

  test('setWish et removeWish : PUT puis DELETE (204)', () async {
    final adapter = FakeHttpAdapter({
      'PUT /wishlist/OGN-209': const FakeResponse(204, {}),
      'DELETE /wishlist/OGN-209': const FakeResponse(204, {}),
    });
    final api = apiWith(adapter);

    await api.setWish(cardId: 'OGN-209', qty: 2);
    await api.removeWish('OGN-209');

    expect(adapter.requests.first.jsonBody, {'qty': 2});
    expect(adapter.requests.last.method, 'DELETE');
  });

  test('erreur : le detail de l’API devient le message affiché', () async {
    final adapter = FakeHttpAdapter({
      'GET /collection/INCONNUE': const FakeResponse(404, {
        'detail': 'Carte introuvable',
      }),
    });

    await expectLater(
      apiWith(adapter).cardState('INCONNUE'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.message, 'message', 'Carte introuvable')
            .having((e) => e.statusCode, 'statusCode', 404),
      ),
    );
  });
}
