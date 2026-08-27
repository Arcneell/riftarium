import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'config.dart';

/// Lecture asynchrone du jeton de session (stockage sécurisé). Null = anonyme.
typedef TokenReader = Future<String?> Function();

/// Client HTTP de l'API Riftarium.
///
/// - `X-Riftarium-Client: mobile` sur chaque requête (voir [AppConfig]).
/// - `Authorization: Bearer <jeton>` ajouté quand une session est ouverte.
/// - Les cookies ne sont jamais utilisés : la session mobile vit dans le jeton.
Dio createApiClient({
  required TokenReader readToken,
  String baseUrl = AppConfig.apiBaseUrl,
  HttpClientAdapter? adapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        AppConfig.clientHeader: AppConfig.clientHeaderValue,
      },
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(_BearerInterceptor(readToken));
  return dio;
}

class _BearerInterceptor extends Interceptor {
  _BearerInterceptor(this._readToken);

  final TokenReader _readToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _readToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

/// Traduit une erreur Dio en [ApiException] avec un message affichable.
///
/// Le `detail` de FastAPI est repris tel quel (les messages de l'API sont déjà
/// en français) ; les erreurs de validation Pydantic (liste) sont concaténées.
ApiException toApiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final response = error.response;
    if (response != null) {
      final status = response.statusCode;
      return ApiException(
        _detailOf(response.data) ?? 'Erreur du serveur ($status).',
        statusCode: status,
      );
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          'Le serveur ne répond pas. Réessaie dans un instant.',
        );
      case DioExceptionType.connectionError:
        return const ApiException('Pas de connexion. Vérifie ton réseau.');
      case DioExceptionType.badCertificate:
        return const ApiException('Connexion au serveur non sécurisée.');
      case DioExceptionType.cancel:
        return const ApiException('Requête annulée.');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return const ApiException('Erreur réseau.');
    }
  }
  return const ApiException('Erreur inattendue.');
}

String? _detailOf(Object? data) {
  if (data is! Map) return null;
  final detail = data['detail'];
  if (detail is String && detail.isNotEmpty) return detail;
  if (detail is List) {
    final messages = detail
        .whereType<Map>()
        .map((item) => item['msg'])
        .whereType<String>()
        .map((msg) => msg.replaceFirst(RegExp(r'^Value error, '), ''))
        .toList();
    if (messages.isNotEmpty) return messages.join('\n');
  }
  return null;
}
