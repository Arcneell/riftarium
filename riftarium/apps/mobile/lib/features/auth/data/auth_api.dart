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

  /// Légendes proposées comme avatar (sélecteur de l'écran « Modifier »).
  Future<List<AvatarOption>> avatars() async {
    try {
      final response = await _dio.get<dynamic>('/auth/avatars');
      return AvatarOption.listFrom(response.data);
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Modifie le profil. Seuls les champs fournis partent : l'API refuse un
  /// corps vide, et exige le mot de passe courant pour changer le pseudo.
  Future<Profile> updateMe({
    String? handle,
    String? bio,
    String? avatarCardId,
    bool? showStats,
    bool? showCollection,
    bool? showDecks,
    bool? showAchievements,
    String? currentPassword,
  }) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/auth/me',
        data: {
          'handle': ?handle,
          'bio': ?bio,
          'avatar_card_id': ?avatarCardId,
          'show_stats': ?showStats,
          'show_collection': ?showCollection,
          'show_decks': ?showDecks,
          'show_achievements': ?showAchievements,
          'current_password': ?currentPassword,
        },
      );
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

  /// Change le mot de passe. L'API incrémente `token_version` : tous les jetons
  /// (dont celui de l'appareil) sont révoqués, il faut se reconnecter.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/auth/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Renvoie l'e-mail de vérification d'adresse.
  Future<void> resendVerification() async {
    try {
      await _dio.post<void>('/auth/resend-verification');
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Export RGPD : toutes les données du compte, en JSON.
  Future<Map<String, dynamic>> exportAccount() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/auth/export');
      return response.data ?? const {};
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }

  /// Suppression définitive du compte : mot de passe et pseudo exigés.
  Future<void> deleteAccount({
    required String password,
    required String handle,
  }) async {
    try {
      await _dio.delete<void>(
        '/auth/me',
        data: {'password': password, 'handle': handle},
      );
    } on DioException catch (error) {
      throw toApiException(error);
    }
  }
}
