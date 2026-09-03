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
  return createApiClient(
    readToken: store.read,
    // Jeton refusé par l'API (expiré, révoqué ailleurs) : le jeton est oublié
    // et la session locale se ferme, sinon l'application resterait « connectée »
    // avec un jeton mort. `ref.read` est différé au moment de l'erreur : le
    // contrôleur dépend de ce provider, le lire ici tout de suite ferait un
    // cycle.
    onUnauthorized: () async {
      await store.clear();
      ref.read(authControllerProvider.notifier).forceSignOut();
    },
  );
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
    try {
      final token = await _store.read();
      if (token == null) {
        state = const AuthState.signedOut();
        return;
      }
      await _loadProfile();
    } catch (_) {
      // Stockage sécurisé illisible (Keystore réinitialisé, plugin absent) :
      // on repart déconnecté plutôt que de rester sur l'écran d'attente.
      state = const AuthState.signedOut();
    }
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

  /// Change le mot de passe puis ferme la session locale : le jeton de
  /// l'appareil est révoqué par l'API (`token_version`), il faut se reconnecter.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    await _store.clear();
    state = const AuthState.signedOut();
  }

  /// Supprime le compte puis ferme la session locale.
  Future<void> deleteAccount({
    required String password,
    required String handle,
  }) async {
    await _api.deleteAccount(password: password, handle: handle);
    await _store.clear();
    state = const AuthState.signedOut();
  }

  /// Ferme la session sans appel réseau : le jeton vient d'être refusé par
  /// l'API (voir `onUnauthorized` de [createApiClient]).
  void forceSignOut() {
    if (state.status != AuthStatus.signedOut) {
      state = const AuthState.signedOut();
    }
  }

  Future<void> resendVerification() => _api.resendVerification();

  Future<Map<String, dynamic>> exportAccount() => _api.exportAccount();

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
