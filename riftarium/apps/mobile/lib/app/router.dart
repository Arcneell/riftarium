import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/auth/ui/splash_screen.dart';
import '../features/cards/ui/card_detail_screen.dart';
import '../features/cards/ui/cards_screen.dart';
import '../features/collection/ui/collection_screen.dart';
import '../features/collection/ui/wishlist_screen.dart';
import '../features/decks/ui/community_screen.dart';
import '../features/decks/ui/deck_detail_screen.dart';
import '../features/decks/ui/decks_screen.dart';
import '../features/game/ui/game_screen.dart';
import '../features/home/ui/home_screen.dart';
import '../features/play/ui/history_screen.dart';
import '../features/play/ui/room_screen.dart';
import '../features/play/ui/stats_screen.dart';
import '../features/play/ui/tracked_match_screen.dart';
import '../features/play/ui/tracked_play_screen.dart';
import '../features/profile/ui/profile_screen.dart';
import '../features/rules/ui/advanced_help_screen.dart';
import '../features/rules/ui/advanced_topic_screen.dart';
import '../features/rules/ui/official_rules_screen.dart';
import '../features/rules/ui/rules_screen.dart';
import '../features/scan/ui/scan_screen.dart';
import 'shell.dart';

/// Chemins de l'application. Alignés sur le site quand un équivalent existe
/// (liens profonds `riftarium.re/cartes/:id`, `/decks/:id`, `/regles/...`).
abstract final class AppRoutes {
  static const splash = '/demarrage';
  static const login = '/connexion';
  static const register = '/inscription';

  static const home = '/';
  static const cards = '/cartes';
  static String card(String id) => '/cartes/$id';
  static const collection = '/collection';
  static const wishlist = '/collection/wishlist';
  static const decks = '/decks';
  static String deck(int id) => '/decks/$id';
  static const community = '/decks/communaute';
  static const rules = '/regles';
  static const advancedHelp = '/regles/avancee';
  static String advancedTopic(String slug) => '/regles/avancee/$slug';
  static const officialRules = '/regles/officielles';
  static const profile = '/profil';

  /// Mes parties suivies : historique et statistiques.
  static const history = '/profil/historique';
  static const playStats = '/profil/statistiques';

  static const scan = '/scan';
  static const game = '/partie';

  /// Partie suivie : création ou entrée dans un salon.
  static const trackedPlay = '/partie/suivie';

  /// Salon d'attente. Même chemin que sur le site : `riftarium.re/salon/CODE`.
  static String room(String code) => '/salon/$code';
  static String trackedMatch(int id) => '/partie/match/$id';

  /// Connexion avec retour vers `from` une fois la session ouverte.
  static String loginFrom(String from) =>
      Uri(path: login, queryParameters: {'from': from}).toString();

  static const _entry = {splash, login, register};

  /// Préfixes réservés aux comptes connectés.
  static const _gatedPrefixes = [
    collection,
    decks,
    profile,
    scan,
    trackedPlay,
    '/salon',
  ];

  static bool isGated(String location) =>
      _gatedPrefixes.any((p) => location == p || location.startsWith('$p/'));
}

/// Emplacement de départ ; surchargeable dans les tests.
final initialLocationProvider = Provider<String>((ref) => AppRoutes.splash);

class _AuthRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.listen(authControllerProvider, (_, _) => refresh.refresh());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: ref.read(initialLocationProvider),
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final rawFrom = state.uri.queryParameters['from'];
      final from = (rawFrom != null && rawFrom.startsWith('/'))
          ? rawFrom
          : null;
      switch (auth.status) {
        case AuthStatus.restoring:
          // Tout passe par l'écran d'attente ; la destination (lien profond,
          // onglet) est conservée dans `from` pour y revenir ensuite.
          if (location == AppRoutes.splash) return null;
          return Uri(
            path: AppRoutes.splash,
            queryParameters: {'from': state.uri.toString()},
          ).toString();
        case AuthStatus.signedOut:
          if (location == AppRoutes.splash) return from ?? AppRoutes.home;
          // Les onglets réservés affichent eux-mêmes l'invite de connexion ;
          // seul le scanner (plein écran) renvoie vers la connexion.
          if (location == AppRoutes.scan) {
            return AppRoutes.loginFrom(AppRoutes.scan);
          }
          return null;
        case AuthStatus.signedIn:
          if (!AppRoutes._entry.contains(location)) return null;
          return from ?? AppRoutes.home;
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
        path: AppRoutes.scan,
        builder: (context, state) => const ScanScreen(),
      ),
      // Compteur de partie : plein écran, utilisable sans compte. La partie
      // suivie et le match qui en sort exigent, eux, une session.
      GoRoute(
        path: AppRoutes.game,
        builder: (context, state) => const GameScreen(),
        routes: [
          GoRoute(
            path: 'suivie',
            builder: (context, state) => const TrackedPlayScreen(),
          ),
          GoRoute(
            path: 'match/:id',
            builder: (context, state) => TrackedMatchScreen(
              matchId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
      // Salon d'attente : le code arrive par saisie ou par lien partagé.
      GoRoute(
        path: '/salon/:code',
        builder: (context, state) =>
            RoomScreen(code: state.pathParameters['code']!.toUpperCase()),
      ),
      // Le profil se pousse par-dessus les onglets (avatar en haut à droite).
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
        routes: [
          GoRoute(
            path: 'historique',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: 'statistiques',
            builder: (context, state) => const PlayStatsScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.cards,
                builder: (context, state) => const CardsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        CardDetailScreen(cardId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.collection,
                builder: (context, state) => const CollectionScreen(),
                routes: [
                  GoRoute(
                    path: 'wishlist',
                    builder: (context, state) => const WishlistScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.decks,
                builder: (context, state) => const DecksScreen(),
                routes: [
                  GoRoute(
                    path: 'communaute',
                    builder: (context, state) => const CommunityScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => DeckDetailScreen(
                      deckId: int.tryParse(state.pathParameters['id']!) ?? 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.rules,
                builder: (context, state) => const RulesScreen(),
                routes: [
                  GoRoute(
                    path: 'avancee',
                    builder: (context, state) => const AdvancedHelpScreen(),
                    routes: [
                      GoRoute(
                        path: ':slug',
                        builder: (context, state) => AdvancedTopicScreen(
                          slug: state.pathParameters['slug']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'officielles',
                    builder: (context, state) => const OfficialRulesScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
