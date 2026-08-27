import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/auth/ui/splash_screen.dart';
import '../features/profile/ui/profile_screen.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/connexion';
  static const register = '/inscription';
  static const profile = '/profil';

  static const _public = {login, register};
}

/// Réveille GoRouter quand l'état de session change (redirections).
class _AuthRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.refresh());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      switch (auth.status) {
        case AuthStatus.restoring:
          return location == AppRoutes.splash ? null : AppRoutes.splash;
        case AuthStatus.signedOut:
          return AppRoutes._public.contains(location) ? null : AppRoutes.login;
        case AuthStatus.signedIn:
          final onEntry =
              location == AppRoutes.splash ||
              AppRoutes._public.contains(location);
          return onEntry ? AppRoutes.profile : null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
