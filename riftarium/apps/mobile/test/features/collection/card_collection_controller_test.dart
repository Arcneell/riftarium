import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/collection/application/card_collection_controller.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  Map<String, FakeResponse> routes(
    List<Map<String, dynamic>> entries, [
    Map<String, FakeResponse> extra = const {},
  ]) => {
    'GET /auth/me': const FakeResponse(200, profileJson),
    'GET /collection/OGN-209': FakeResponse(
      200,
      cardStateJson(cardId: 'OGN-209', entries: entries),
    ),
    'PUT /collection/OGN-209': const FakeResponse(200, {
      'card_id': 'OGN-209',
      'qty': 3,
      'condition': 'NM',
      'lang': 'EN',
    }),
    ...extra,
  };

  test('adjust : le lot unique est incrémenté', () async {
    final adapter = FakeHttpAdapter(routes([entryJson(id: 12, qty: 2)]));
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(cardCollectionProvider('OGN-209').future);

    final pending = container
        .read(cardCollectionProvider('OGN-209').notifier)
        .adjust(1);
    // Affiché immédiatement, avant la réponse du serveur.
    expect(
      container.read(cardCollectionProvider('OGN-209')).value!.totalQty,
      3,
    );

    await pending;
    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.jsonBody, {'qty': 3, 'condition': 'NM', 'lang': 'EN'});
  });

  test('adjust : sans lot NM/EN, l’ajout crée le lot par défaut', () async {
    final adapter = FakeHttpAdapter(
      routes([
        entryJson(id: 13, qty: 1, condition: 'EX', lang: 'FR'),
        entryJson(id: 14, qty: 1, condition: 'LP', lang: 'DE'),
      ]),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    final state = await container.read(
      cardCollectionProvider('OGN-209').future,
    );
    expect(state.mainEntry, isNull);
    expect(state.hasSeveralLots, isTrue);

    await container.read(cardCollectionProvider('OGN-209').notifier).adjust(1);

    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.jsonBody, {'qty': 1, 'condition': 'NM', 'lang': 'EN'});
  });

  test('sans session : aucun appel, quantité nulle', () async {
    final adapter = FakeHttpAdapter(routes([entryJson(id: 12, qty: 2)]));
    final container = collectionContainer(adapter, token: null);
    await container.read(authControllerProvider.notifier).whenRestored;

    final state = await container.read(
      cardCollectionProvider('OGN-209').future,
    );

    expect(state.totalQty, 0);
    expect(adapter.requests, isEmpty);
  });
}
