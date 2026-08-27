import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../domain/session.dart';

/// Appels `/api/auth/*`. Chaque erreur Dio ressort en [ApiException].
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Session> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return Session.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<Session> register({
    required String handle,
    required String email,
    required String password,
    required bool acceptTerms,
    required bool confirmAge,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/register',
        data: {
          'handle': handle,
          'email': email,
          'password': password,
          'accept_terms': acceptTerms,
          'confirm_age': confirmAge,
        },
      );
      return Session.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  Future<Profile> me() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/me');
      return Profile.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Côté serveur, ne fait qu'effacer le cookie : pour le mobile, l'oubli du
  /// jeton suffit. Appelé quand même pour garder la trace de la déconnexion.
  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}
