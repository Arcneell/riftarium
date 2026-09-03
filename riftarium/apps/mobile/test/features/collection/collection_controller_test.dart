import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/collection/application/collection_controller.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  final jinx = cardJson(id: 'OGN-209', priceEur: 12.5);

  Map<String, FakeResponse> routes([
    Map<String, FakeResponse> extra = const {},
  ]) => {
    'GET /auth/me': const FakeResponse(200, profileJson),
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
        totalCards: 2,
        uniqueCards: 1,
        valueEur: 25,
        total: 1,
      ),
    ),
    'GET /collection/sets': const FakeResponse(200, setsProgressJson),
    // Après chaque mutation, seule la carte touchée est relue.
    'GET /collection/OGN-209': FakeResponse(
      200,
      cardStateJson(cardId: 'OGN-209', entries: [entryJson(id: 12, qty: 2)]),
    ),
    ...extra,
  };

  test('la collection se charge dès que la session est restaurée', () async {
    final container = collectionContainer(FakeHttpAdapter(routes()));
    await container.read(authControllerProvider.notifier).whenRestored;

    final state = await container.read(collectionControllerProvider.future);

    expect(state.items.single.card.name, 'Jinx, la Gâchette folle');
    expect(state.uniqueCards, 1);
    expect(state.totalCards, 2);
    expect(state.valueEur, 25);
    expect(state.hasMore, isFalse);
  });

  test('sans session : aucune requête, collection vide', () async {
    final adapter = FakeHttpAdapter(routes());
    final container = collectionContainer(adapter, token: null);
    await container.read(authControllerProvider.notifier).whenRestored;

    final state = await container.read(collectionControllerProvider.future);

    expect(state.items, isEmpty);
    expect(adapter.requests, isEmpty);
  });

  test('setQuantity : la liste change avant la réponse du serveur', () async {
    final adapter = FakeHttpAdapter(
      routes({
        'PUT /collection/OGN-209': const FakeResponse(200, {
          'card_id': 'OGN-209',
          'qty': 5,
          'condition': 'NM',
          'lang': 'EN',
        }),
        'GET /collection/OGN-209': FakeResponse(
          200,
          cardStateJson(
            cardId: 'OGN-209',
            entries: [entryJson(id: 12, qty: 5)],
          ),
        ),
      }),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(collectionControllerProvider.future);

    final pending = container
        .read(collectionControllerProvider.notifier)
        .setQuantity(cardId: 'OGN-209', qty: 5);

    final optimistic = container.read(collectionControllerProvider).value!;
    expect(optimistic.items.single.totalQty, 5);
    expect(optimistic.totalCards, 5);
    expect(optimistic.valueEur, 62.5);

    await pending;
    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.path, '/collection/OGN-209');
    expect(put.jsonBody, {'qty': 5, 'condition': 'NM', 'lang': 'EN'});
    // Seule la carte touchée est relue : les lots reviennent du serveur (leurs
    // identifiants avec) et la liste ne repart pas de la première page.
    final state = container.read(collectionControllerProvider).value!;
    expect(state.items.single.entries.single.id, 12);
    expect(state.items.single.totalQty, 5);
    expect(
      adapter.requests.where((r) => r.path == '/collection').length,
      1,
      reason: 'la liste complète n’est pas rechargée',
    );
    expect(
      adapter.requests.any(
        (r) => r.method == 'GET' && r.path == '/collection/OGN-209',
      ),
      isTrue,
    );
  });

  test('setQuantity : échec serveur, la liste revient à son état', () async {
    final adapter = FakeHttpAdapter(
      routes({
        'PUT /collection/OGN-209': const FakeResponse(500, {
          'detail': 'Erreur',
        }),
      }),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(collectionControllerProvider.future);

    await expectLater(
      container
          .read(collectionControllerProvider.notifier)
          .setQuantity(cardId: 'OGN-209', qty: 5),
      throwsA(isA<ApiException>()),
    );

    expect(container.read(collectionControllerProvider).value!.totalCards, 2);
    expect(
      container.read(collectionControllerProvider).value!.items.single.totalQty,
      2,
    );
  });

  test('removeCard : un seul appel groupé, carte retirée', () async {
    final adapter = FakeHttpAdapter(
      routes({
        'POST /collection/bulk': const FakeResponse(200, {
          'updated': 0,
          'removed': 1,
        }),
      }),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(collectionControllerProvider.future);

    final pending = container
        .read(collectionControllerProvider.notifier)
        .removeCard('OGN-209');
    final optimistic = container.read(collectionControllerProvider).value!;
    expect(optimistic.items, isEmpty);
    expect(optimistic.uniqueCards, 0);

    await pending;
    final bulk = adapter.requests.firstWhere((r) => r.method == 'POST');
    expect(bulk.path, '/collection/bulk');
    expect(bulk.jsonBody, {
      'card_ids': ['OGN-209'],
      'remove': true,
    });
    expect(
      adapter.requests.any((r) => r.method == 'PATCH'),
      isFalse,
      reason: 'plus de suite de PATCH à moitié appliquée',
    );
    expect(container.read(collectionControllerProvider).value!.items, isEmpty);
  });

  test('addEntry : la quantité s’ajoute au lot existant', () async {
    final adapter = FakeHttpAdapter(
      routes({
        'POST /collection/OGN-209/entries': FakeResponse(
          200,
          cardStateJson(
            cardId: 'OGN-209',
            entries: [entryJson(id: 12, qty: 5)],
          ),
        ),
      }),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(collectionControllerProvider.future);

    final pending = container
        .read(collectionControllerProvider.notifier)
        .addEntry(cardId: 'OGN-209', qty: 3);
    expect(
      container.read(collectionControllerProvider).value!.items.single.totalQty,
      5,
    );

    await pending;
    final post = adapter.requests.firstWhere((r) => r.method == 'POST');
    expect(post.jsonBody, {'qty': 3, 'condition': 'NM', 'lang': 'EN'});
  });

  test('la déconnexion vide la collection et la progression', () async {
    final container = collectionContainer(FakeHttpAdapter(routes()));
    final subscription = container.listen(
      collectionControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(collectionControllerProvider.future);
    expect(container.read(collectionProgressProvider).valueOrNull, isNull);
    await container.read(collectionProgressProvider.future);

    await container.read(authControllerProvider.notifier).signOut();

    expect(
      await container.read(collectionControllerProvider.future),
      isA<CollectionState>().having((s) => s.items, 'items', isEmpty),
    );
    expect(
      (await container.read(collectionProgressProvider.future)).isEmpty,
      isTrue,
    );
  });

  test('recherche : envoyée à l’API après la temporisation', () async {
    final adapter = FakeHttpAdapter(routes());
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(collectionControllerProvider.future);

    container.read(collectionControllerProvider.notifier).search('jinx');
    expect(container.read(collectionControllerProvider).value!.query, 'jinx');

    await Future<void>.delayed(collectionSearchDelay * 2);
    final last = adapter.requests.last;
    expect(last.options.queryParameters['q'], 'jinx');
  });
}
