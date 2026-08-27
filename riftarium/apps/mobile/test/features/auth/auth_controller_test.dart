import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/core/token_store.dart';
import 'package:riftarium_mobile/features/auth/application/auth_controller.dart';

import '../../support/fakes.dart';

void main() {
  late FakeHttpAdapter adapter;
  late InMemoryTokenStore store;
  late ProviderContainer container;

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

  /// Laisse la restauration lancée par build() se terminer.
  Future<void> settle() =>
      container.read(authControllerProvider.notifier).whenRestored;

  group('restauration au démarrage', () {
    test('sans jeton : déconnecté, aucun appel réseau', () async {
      adapter = FakeHttpAdapter({});
      store = InMemoryTokenStore();
      container = makeContainer();

      expect(container.read(authControllerProvider).isRestoring, isTrue);
      await settle();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(adapter.requests, isEmpty);
    });

    test('jeton valide : profil chargé, session ouverte', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
      });
      store = InMemoryTokenStore('jwt');
      container = makeContainer();
      await settle();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.signedIn);
      expect(state.profile?.handle, 'ezreal');
      expect(adapter.requests.single.headers['Authorization'], 'Bearer jwt');
    });

    test('jeton refusé (401) : jeton effacé, déconnecté', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(401, {
          'detail': 'Jeton invalide ou expiré',
        }),
      });
      store = InMemoryTokenStore('perime');
      container = makeContainer();
      await settle();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(await store.read(), isNull);
    });

    test(
      'hors ligne : session conservée, profil absent, erreur exposée',
      () async {
        adapter = FakeHttpAdapter({
          'GET /auth/me': const FakeResponse.networkError(),
        });
        store = InMemoryTokenStore('jwt');
        container = makeContainer();
        await settle();

        final state = container.read(authControllerProvider);
        expect(state.status, AuthStatus.signedIn);
        expect(state.profile, isNull);
        expect(state.profileError, 'Pas de connexion. Vérifie ton réseau.');
        expect(await store.read(), 'jwt');
      },
    );
  });

  group('connexion', () {
    test('stocke le jeton puis charge le profil', () async {
      adapter = FakeHttpAdapter({
        'POST /auth/login': const FakeResponse(200, sessionJson),
        'GET /auth/me': const FakeResponse(200, profileJson),
      });
      store = InMemoryTokenStore();
      container = makeContainer();
      await settle();

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'ezreal@piltover.re', password: 'secret-12');

      expect(await store.read(), 'jwt-de-test');
      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.signedIn);
      expect(state.profile?.email, 'ezreal@piltover.re');
      // Le profil est demandé avec le jeton fraîchement stocké.
      expect(adapter.requests.last.path, '/auth/me');
      expect(
        adapter.requests.last.headers['Authorization'],
        'Bearer jwt-de-test',
      );
    });

    test('échec : ApiException remontée, état inchangé, rien stocké', () async {
      adapter = FakeHttpAdapter({
        'POST /auth/login': const FakeResponse(401, {
          'detail': 'Identifiants invalides',
        }),
      });
      store = InMemoryTokenStore();
      container = makeContainer();
      await settle();

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .signIn(email: 'a@b.re', password: 'faux'),
        throwsA(isA<ApiException>()),
      );

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(await store.read(), isNull);
    });
  });

  test('inscription : même cycle que la connexion', () async {
    adapter = FakeHttpAdapter({
      'POST /auth/register': const FakeResponse(201, sessionJson),
      'GET /auth/me': const FakeResponse(200, profileJson),
    });
    store = InMemoryTokenStore();
    container = makeContainer();
    await settle();

    await container
        .read(authControllerProvider.notifier)
        .signUp(
          handle: 'ezreal',
          email: 'ezreal@piltover.re',
          password: 'secret-12',
          acceptTerms: true,
          confirmAge: true,
        );

    expect(container.read(authControllerProvider).status, AuthStatus.signedIn);
    expect(await store.read(), 'jwt-de-test');
  });

  group('déconnexion', () {
    test('appelle logout, efface le jeton', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
        'POST /auth/logout': const FakeResponse(204, {}),
      });
      store = InMemoryTokenStore('jwt');
      container = makeContainer();
      await settle();

      await container.read(authControllerProvider.notifier).signOut();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(await store.read(), isNull);
      expect(adapter.requests.last.path, '/auth/logout');
    });

    test('hors ligne : la déconnexion locale aboutit quand même', () async {
      adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
        'POST /auth/logout': const FakeResponse.networkError(),
      });
      store = InMemoryTokenStore('jwt');
      container = makeContainer();
      await settle();

      await container.read(authControllerProvider.notifier).signOut();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.signedOut,
      );
      expect(await store.read(), isNull);
    });
  });

  test('refreshProfile recharge le profil après une erreur réseau', () async {
    adapter = FakeHttpAdapter({
      'GET /auth/me': const FakeResponse.networkError(),
    });
    store = InMemoryTokenStore('jwt');
    container = makeContainer();
    await settle();
    expect(container.read(authControllerProvider).profile, isNull);

    adapter.routes['GET /auth/me'] = const FakeResponse(200, profileJson);
    await container.read(authControllerProvider.notifier).refreshProfile();

    final state = container.read(authControllerProvider);
    expect(state.profile?.handle, 'ezreal');
    expect(state.profileError, isNull);
  });
}
