import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';
import 'package:riftarium_mobile/features/auth/data/auth_api.dart';

import '../../support/fakes.dart';

void main() {
  AuthApi apiWith(FakeHttpAdapter adapter) => AuthApi(
    createApiClient(
      readToken: () async => null,
      baseUrl: 'https://api.test/api',
      adapter: adapter,
    ),
  );

  group('login', () {
    test(
      'poste e-mail et mot de passe, lit la session avec son jeton',
      () async {
        final adapter = FakeHttpAdapter({
          'POST /auth/login': const FakeResponse(200, sessionJson),
        });

        final session = await apiWith(
          adapter,
        ).login(email: 'ezreal@piltover.re', password: 'secret-12');

        expect(session.handle, 'ezreal');
        expect(session.token, 'jwt-de-test');
        expect(session.isAdmin, isFalse);
        expect(adapter.requests.single.jsonBody, {
          'email': 'ezreal@piltover.re',
          'password': 'secret-12',
        });
      },
    );

    test(
      'identifiants refusés : ApiException 401 avec le message de l’API',
      () async {
        final adapter = FakeHttpAdapter({
          'POST /auth/login': const FakeResponse(401, {
            'detail': 'Identifiants invalides',
          }),
        });

        await expectLater(
          apiWith(adapter).login(email: 'a@b.re', password: 'x'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.message, 'message', 'Identifiants invalides'),
          ),
        );
      },
    );

    test(
      'réponse sans jeton (API sans support mobile) : erreur explicite',
      () async {
        final adapter = FakeHttpAdapter({
          'POST /auth/login': const FakeResponse(200, {
            'handle': 'ezreal',
            'avatar_url': null,
            'is_admin': false,
          }),
        });

        await expectLater(
          apiWith(adapter).login(email: 'a@b.re', password: 'x'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              contains('jeton absent'),
            ),
          ),
        );
      },
    );
  });

  test('register envoie les consentements tels quels', () async {
    final adapter = FakeHttpAdapter({
      'POST /auth/register': const FakeResponse(201, sessionJson),
    });

    final session = await apiWith(adapter).register(
      handle: 'ezreal',
      email: 'ezreal@piltover.re',
      password: 'secret-12',
      acceptTerms: true,
      confirmAge: true,
    );

    expect(session.token, 'jwt-de-test');
    expect(adapter.requests.single.jsonBody, {
      'handle': 'ezreal',
      'email': 'ezreal@piltover.re',
      'password': 'secret-12',
      'accept_terms': true,
      'confirm_age': true,
    });
  });

  test('me lit le profil complet', () async {
    final adapter = FakeHttpAdapter({
      'GET /auth/me': const FakeResponse(200, profileJson),
    });

    final profile = await apiWith(adapter).me();

    expect(profile.id, 7);
    expect(profile.handle, 'ezreal');
    expect(profile.email, 'ezreal@piltover.re');
    expect(profile.emailVerified, isTrue);
    expect(profile.createdAt, DateTime.utc(2026, 8, 1, 10));
    expect(profile.stats, {'decks': 3, 'collection': 120});
  });

  test('logout traduit les erreurs réseau', () async {
    final adapter = FakeHttpAdapter({
      'POST /auth/logout': const FakeResponse.networkError(),
    });

    await expectLater(
      apiWith(adapter).logout(),
      throwsA(
        isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true),
      ),
    );
  });
}
