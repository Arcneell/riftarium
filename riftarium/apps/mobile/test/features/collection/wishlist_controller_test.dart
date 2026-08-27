import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/collection/application/wishlist_controller.dart';

import '../../support/fakes.dart';
import 'support/collection_fixtures.dart';

void main() {
  final jinx = cardJson(id: 'OGN-209', priceEur: 12.5);

  Map<String, FakeResponse> routes([
    Map<String, FakeResponse> extra = const {},
  ]) => {
    'GET /auth/me': const FakeResponse(200, profileJson),
    'GET /wishlist': FakeResponse(
      200,
      wishlistJson(items: [wishItemJson(card: jinx, qty: 2)], valueEur: 25),
    ),
    ...extra,
  };

  test('la wishlist se charge avec sa valeur estimée', () async {
    final container = collectionContainer(FakeHttpAdapter(routes()));
    await container.read(authControllerProvider.notifier).whenRestored;

    final wishlist = await container.read(wishlistControllerProvider.future);

    expect(wishlist.total, 1);
    expect(wishlist.valueEur, 25);
    expect(wishlist.items.single.qty, 2);
  });

  test('sans session : wishlist vide, aucune requête', () async {
    final adapter = FakeHttpAdapter(routes());
    final container = collectionContainer(adapter, token: null);
    await container.read(authControllerProvider.notifier).whenRestored;

    expect(
      (await container.read(wishlistControllerProvider.future)).items,
      isEmpty,
    );
    expect(adapter.requests, isEmpty);
  });

  test('setQuantity : quantité bornée, affichée avant la réponse', () async {
    final adapter = FakeHttpAdapter(
      routes({'PUT /wishlist/OGN-209': const FakeResponse(204, {})}),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(wishlistControllerProvider.future);

    final pending = container
        .read(wishlistControllerProvider.notifier)
        .setQuantity(cardId: 'OGN-209', qty: 300);
    expect(
      container.read(wishlistControllerProvider).value!.items.single.qty,
      99,
    );

    await pending;
    final put = adapter.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.path, '/wishlist/OGN-209');
    expect(put.jsonBody, {'qty': 99});
  });

  test('remove : la carte disparaît puis DELETE est appelé', () async {
    final adapter = FakeHttpAdapter(
      routes({'DELETE /wishlist/OGN-209': const FakeResponse(204, {})}),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(wishlistControllerProvider.future);

    final pending = container
        .read(wishlistControllerProvider.notifier)
        .remove('OGN-209');
    expect(container.read(wishlistControllerProvider).value!.items, isEmpty);

    await pending;
    expect(
      adapter.requests.any(
        (r) => r.method == 'DELETE' && r.path == '/wishlist/OGN-209',
      ),
      isTrue,
    );
  });

  test('échec : la wishlist retrouve son état précédent', () async {
    final adapter = FakeHttpAdapter(
      routes({
        'DELETE /wishlist/OGN-209': const FakeResponse(500, {
          'detail': 'Serveur indisponible',
        }),
      }),
    );
    final container = collectionContainer(adapter);
    await container.read(authControllerProvider.notifier).whenRestored;
    await container.read(wishlistControllerProvider.future);

    await expectLater(
      container.read(wishlistControllerProvider.notifier).remove('OGN-209'),
      throwsA(isA<ApiException>()),
    );

    expect(container.read(wishlistControllerProvider).value!.items.length, 1);
  });
}
