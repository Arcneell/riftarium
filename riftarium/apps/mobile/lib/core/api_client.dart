import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'config.dart';

/// Lecture asynchrone du jeton de session (stockage sécurisé). Null = anonyme.
typedef TokenReader = Future<String?> Function();

/// Appelé quand l'API refuse le jeton courant (expiré, révoqué) : la session
/// locale doit être fermée. Le jeton est déjà oublié quand ce rappel s'exécute.
typedef UnauthorizedHandler = Future<void> Function();

/// Client HTTP de l'API Riftarium.
///
/// - `X-Riftarium-Client: mobile` sur chaque requête (voir [AppConfig]).
/// - `Authorization: Bearer <jeton>` ajouté quand une session est ouverte.
/// - Les cookies ne sont jamais utilisés : la session mobile vit dans le jeton.
/// - Un 401 sur une route qui exige une session déclenche [onUnauthorized].
Dio createApiClient({
  required TokenReader readToken,
  String baseUrl = AppConfig.apiBaseUrl,
  HttpClientAdapter? adapter,
  UnauthorizedHandler? onUnauthorized,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'User-Agent': AppConfig.userAgent,
        AppConfig.clientHeader: AppConfig.clientHeaderValue,
      },
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  dio.interceptors.add(_BearerInterceptor(readToken, onUnauthorized));
  return dio;
}

class _BearerInterceptor extends Interceptor {
  _BearerInterceptor(this._readToken, this._onUnauthorized);

  final TokenReader _readToken;
  final UnauthorizedHandler? _onUnauthorized;

  /// Champs dont la présence dans le corps fait du 401 un « mot de passe
  /// refusé » et non une session périmée : connexion, inscription, changement
  /// de mot de passe, modification ou suppression du compte
  /// (`_require_password` dans `auth_routes.py`). Le critère est le corps et
  /// non la route : un PATCH /auth/me sans mot de passe (portrait,
  /// confidentialité) qui reçoit 401 est bien un jeton révoqué.
  static const _passwordFields = {'password', 'current_password'};

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

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isRevokedToken(err)) {
      // Rappel non attendu : l'erreur continue son chemin et l'écran affiche
      // son message ; la session, elle, est fermée en arrière-plan.
      _onUnauthorized?.call();
    }
    handler.next(err);
  }

  bool _isRevokedToken(DioException err) {
    if (_onUnauthorized == null) return false;
    if (err.response?.statusCode != 401) return false;
    final options = err.requestOptions;
    // Sans en-tête Authorization, le 401 vise une route publique : rien à
    // révoquer côté appareil.
    if (options.headers['Authorization'] == null) return false;
    final data = options.data;
    if (data is Map && data.keys.any(_passwordFields.contains)) return false;
    return true;
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
      // `badResponse` suppose une réponse, déjà traitée plus haut : il n'arrive
      // ici que sans corps lisible, comme `unknown`.
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
