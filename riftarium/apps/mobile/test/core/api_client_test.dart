import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riftarium_mobile/core/api_client.dart';
import 'package:riftarium_mobile/core/api_exception.dart';

import '../support/fakes.dart';

void main() {
  group('createApiClient', () {
    test(
      'envoie l’en-tête client mobile et le Bearer quand un jeton existe',
      () async {
        final adapter = FakeHttpAdapter({
          'GET /auth/me': const FakeResponse(200, profileJson),
        });
        final dio = createApiClient(
          readToken: () async => 'abc',
          baseUrl: 'https://api.test/api',
          adapter: adapter,
        );

        await dio.get<Map<String, dynamic>>('/auth/me');

        final request = adapter.requests.single;
        expect(request.headers['X-Riftarium-Client'], 'mobile');
        expect(request.headers['Authorization'], 'Bearer abc');
        expect(request.options.uri.toString(), 'https://api.test/api/auth/me');
      },
    );

    test('sans jeton, aucun en-tête Authorization', () async {
      final adapter = FakeHttpAdapter({
        'GET /auth/me': const FakeResponse(200, profileJson),
      });
      final dio = createApiClient(
        readToken: () async => null,
        baseUrl: 'https://api.test/api',
        adapter: adapter,
      );

      await dio.get<Map<String, dynamic>>('/auth/me');

      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });
  });

  group('toApiException', () {
    RequestOptions options() => RequestOptions(path: '/x');

    test('reprend le detail FastAPI et le code HTTP', () {
      final error = DioException.badResponse(
        statusCode: 401,
        requestOptions: options(),
        response: Response(
          requestOptions: options(),
          statusCode: 401,
          data: {'detail': 'Identifiants invalides'},
        ),
      );
      final api = toApiException(error);
      expect(api.message, 'Identifiants invalides');
      expect(api.statusCode, 401);
      expect(api.isUnauthorized, isTrue);
    });

    test('concatène les erreurs de validation Pydantic sans le préfixe', () {
      final error = DioException.badResponse(
        statusCode: 422,
        requestOptions: options(),
        response: Response(
          requestOptions: options(),
          statusCode: 422,
          data: {
            'detail': [
              {'msg': 'Value error, Mot de passe trop courant'},
              {'msg': 'field required'},
            ],
          },
        ),
      );
      expect(
        toApiException(error).message,
        'Mot de passe trop courant\nfield required',
      );
    });

    test('réponse sans detail : message générique avec le code', () {
      final error = DioException.badResponse(
        statusCode: 500,
        requestOptions: options(),
        response: Response(
          requestOptions: options(),
          statusCode: 500,
          data: '<html>oops</html>',
        ),
      );
      expect(toApiException(error).message, 'Erreur du serveur (500).');
    });

    test('erreur de connexion : message réseau, sans code', () {
      final api = toApiException(
        DioException.connectionError(requestOptions: options(), reason: 'x'),
      );
      expect(api.isNetwork, isTrue);
      expect(api.message, 'Pas de connexion. Vérifie ton réseau.');
    });

    test('délai dépassé', () {
      final api = toApiException(
        DioException.connectionTimeout(
          requestOptions: options(),
          timeout: const Duration(seconds: 1),
        ),
      );
      expect(
        api.message,
        'Le serveur ne répond pas. Réessaie dans un instant.',
      );
    });

    test(
      'une ApiException passe inchangée, tout autre objet devient générique',
      () {
        const original = ApiException('déjà traduite', statusCode: 418);
        expect(toApiException(original), same(original));
        expect(toApiException(StateError('?')).message, 'Erreur inattendue.');
      },
    );
  });
}
