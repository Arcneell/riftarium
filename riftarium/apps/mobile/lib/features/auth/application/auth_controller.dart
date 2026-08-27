import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import '../../../core/token_store.dart';
import '../data/auth_api.dart';
import '../domain/session.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(tokenStoreProvider);
  return createApiClient(readToken: store.read);
});

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

enum AuthStatus {
  /// Lecture du jeton stocké et vérification auprès de l'API au démarrage.
  restoring,
  signedOut,
  signedIn,
}

class AuthState {
  const AuthState._(this.status, {this.profile, this.profileError});

  const AuthState.restoring() : this._(AuthStatus.restoring);
  const AuthState.signedOut() : this._(AuthStatus.signedOut);

  /// Session ouverte. `profile` peut être null si `/auth/me` n'a pas répondu
  /// (hors ligne) : la session reste valide, l'écran affiche `profileError`.
  const AuthState.signedIn({Profile? profile, String? profileError})
    : this._(AuthStatus.signedIn, profile: profile, profileError: profileError);

  final AuthStatus status;
  final Profile? profile;
  final String? profileError;

  bool get isSignedIn => status == AuthStatus.signedIn;
  bool get isRestoring => status == AuthStatus.restoring;
}

/// Cycle de vie de la session : restauration au démarrage, connexion,
/// inscription, déconnexion. Le jeton vit dans [TokenStore] ; le client HTTP
/// le relit à chaque requête, donc aucun état à synchroniser ici.
class AuthController extends Notifier<AuthState> {
  late final Future<void> _restored;

  @override
  AuthState build() {
    // Restauration hors du build (pas d'effet de bord synchrone dans build()).
    _restored = Future.microtask(restore);
    return const AuthState.restoring();
  }

  /// Terminé quand la restauration initiale a rendu son verdict.
  Future<void> get whenRestored => _restored;

  TokenStore get _store => ref.read(tokenStoreProvider);
  AuthApi get _api => ref.read(authApiProvider);

  Future<void> restore() async {
    final token = await _store.read();
    if (token == null) {
      state = const AuthState.signedOut();
      return;
    }
    await _loadProfile();
  }

  Future<void> signIn({required String email, required String password}) async {
    final session = await _api.login(email: email, password: password);
    await _store.write(session.token);
    await _loadProfile();
  }

  Future<void> signUp({
    required String handle,
    required String email,
    required String password,
    required bool acceptTerms,
    required bool confirmAge,
  }) async {
    final session = await _api.register(
      handle: handle,
      email: email,
      password: password,
      acceptTerms: acceptTerms,
      confirmAge: confirmAge,
    );
    await _store.write(session.token);
    await _loadProfile();
  }

  Future<void> signOut() async {
    try {
      await _api.logout();
    } on ApiException {
      // Le jeton disparaît de l'appareil quoi qu'il arrive : la déconnexion
      // locale ne dépend pas du réseau.
    }
    await _store.clear();
    state = const AuthState.signedOut();
  }

  /// Recharge `/auth/me` (après une erreur réseau ou une modification).
  Future<void> refreshProfile() => _loadProfile();

  Future<void> _loadProfile() async {
    try {
      final profile = await _api.me();
      state = AuthState.signedIn(profile: profile);
    } on ApiException catch (error) {
      if (error.isUnauthorized) {
        // Jeton expiré ou révoqué (changement de mot de passe) : on repart de zéro.
        await _store.clear();
        state = const AuthState.signedOut();
        return;
      }
      state = AuthState.signedIn(
        profile: state.profile,
        profileError: error.message,
      );
    }
  }
}
