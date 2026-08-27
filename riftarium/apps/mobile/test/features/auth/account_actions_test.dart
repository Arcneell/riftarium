import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';
import 'package:riftarium_mobile/features/auth/data/auth_api.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late InMemoryTokenStore store;

  AuthApi apiWith(FakeHttpAdapter adapter) => AuthApi(
    createApiClient(
      readToken: () async => 'jwt',
      baseUrl: 'https://api.test/api',
      adapter: adapter,
    ),
  );

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(store),
        dioProvider.overrideWith(
          (ref) => createApiClient(
            readToken: store.read,
            baseUrl: 'https://api.test/api',
            adapter: adapter,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AuthApi', () {
    test('changePassword poste les deux mots de passe', () async {
      adapter = FakeHttpAdapter({
        'POST /auth/password': const FakeResponse(200, sessionJson),
      });
      await apiWith(
        adapter,
      ).changePassword(currentPassword: 'ancien-12', newPassword: 'nouveau-12');
      expect(adapter.requests.single.jsonBody, {
        'current_password': 'ancien-12',
        'new_password': 'nouveau-12',
      });
    });

    test(
      'deleteAccount envoie mot de passe et pseudo en DELETE /auth/me',
      () async {
        adapter = FakeHttpAdapter({
          'DELETE /auth/me': const FakeResponse(204, {}),
        });
        await apiWith(adapter).deleteAccount(password: 'x', handle: 'ezreal');
        final request = adapter.requests.single;
        expect(request.method, 'DELETE');
        expect(request.jsonBody, {'password': 'x', 'handle': 'ezreal'});
      },
    );

    test('exportAccount renvoie le JSON complet', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/export': const FakeResponse(200, {
          'user': {'handle': 'ezreal'},
          'decks': [],
        }),
      });
      final data = await apiWith(adapter).exportAccount();
      expect(data['user'], {'handle': 'ezreal'});
    });

    test('resendVerification traduit une erreur 429', () async {
      adapter = FakeHttpAdapter({
        'POST /auth/resend-verification': const FakeResponse(429, {
          'detail': 'Trop de demandes',
        }),
      });
      await expectLater(
        apiWith(adapter).resendVerification(),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 429),
        ),
      );
    });
  });

  group('AuthController', () {
    test('changePassword ferme la session locale après succès', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
        'POST /auth/password': const FakeResponse(200, sessionJson),
      });
      store = InMemoryTokenStore('jwt');
      final container = makeContainer();
      await container.read(authControllerProvider.notifier).whenRestored;

      await container
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: 'a-12345678',
            newPassword: 'b-12345678',
          );

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(await store.read(), isNull);
    });

    test('changePassword refusé : session et jeton conservés', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
        'POST /auth/password': const FakeResponse(401, {
          'detail': 'Mot de passe actuel incorrect',
        }),
      });
      store = InMemoryTokenStore('jwt');
      final container = makeContainer();
      await container.read(authControllerProvider.notifier).whenRestored;

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .changePassword(currentPassword: 'faux', newPassword: 'b-12345678'),
        throwsA(isA<ApiException>()),
      );

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedIn,
      );
      expect(await store.read(), 'jwt');
    });

    test('deleteAccount ferme la session locale', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
        'DELETE /auth/me': const FakeResponse(204, {}),
      });
      store = InMemoryTokenStore('jwt');
      final container = makeContainer();
      await container.read(authControllerProvider.notifier).whenRestored;

      await container
          .read(authControllerProvider.notifier)
          .deleteAccount(password: 'x', handle: 'ezreal');

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(await store.read(), isNull);
    });
  });
}
