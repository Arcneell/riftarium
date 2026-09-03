import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/auth/ui/register_screen.dart';
import '../features/auth/ui/splash_screen.dart';
import '../features/cards/ui/card_detail_screen.dart';
import '../features/cards/ui/cards_screen.dart';
import '../features/collection/ui/binder_screen.dart';
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
import '../features/profile/ui/edit_profile_screen.dart';
import '../features/profile/ui/profile_screen.dart';
import '../features/rules/ui/advanced_help_screen.dart';
import '../features/rules/ui/advanced_topic_screen.dart';
import '../features/rules/ui/official_rules_screen.dart';
import '../features/rules/ui/rules_screen.dart';
import '../features/scan/ui/scan_screen.dart';
import '../features/social/ui/achievements_screen.dart';
import '../features/social/ui/friends_screen.dart';
import '../features/social/ui/public_profile_screen.dart';
import 'shell.dart';
import 'widgets/not_found_screen.dart';

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
  static const binder = '/collection/classeur';
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

  /// Mon profil : édition, amis, hauts faits.
  static const editProfile = '/profil/modifier';
  static const friends = '/profil/amis';
  static const achievements = '/profil/hauts-faits';

  /// Profil public d'un joueur, lisible sans compte. Le site publie le même
  /// écran sous `/u/:handle` : ce chemin reste servi pour les liens partagés.
  static String player(String handle) => '/joueur/$handle';
  static const webPlayerPrefix = '/u';

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
}

/// Emplacement de départ ; surchargeable dans les tests.
final initialLocationProvider = Provider<String>((ref) => AppRoutes.splash);

class _AuthRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  // Seul le statut change la navigation : le profil qui arrive de `/auth/me`
  // ne doit pas relancer une redirection.
  ref.listen(
    authControllerProvider.select((s) => s.status),
    (_, _) => refresh.refresh(),
  );
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
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
    errorBuilder: (context, state) => NotFoundScreen(location: state.uri.path),
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
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return id == null
                  ? NotFoundScreen(
                      location: state.uri.path,
                      message:
                          'Ce lien de match est invalide : '
                          '« ${state.pathParameters['id']} » n’est pas un '
                          'numéro de match.',
                    )
                  : TrackedMatchScreen(matchId: id);
            },
          ),
        ],
      ),
      // Profil public : atteignable depuis un salon, l'historique ou la
      // recherche, avec ou sans compte. Deux chemins pour un seul écran :
      // celui de l'application et celui du site (`riftarium.re/u/:handle`),
      // qui arrive par lien profond.
      GoRoute(
        path: '/joueur/:handle',
        builder: (context, state) =>
            PublicProfileScreen(handle: state.pathParameters['handle']!),
      ),
      GoRoute(
        path: '${AppRoutes.webPlayerPrefix}/:handle',
        builder: (context, state) =>
            PublicProfileScreen(handle: state.pathParameters['handle']!),
      ),
      // Salon d'attente : le code arrive par saisie ou par lien partagé.
      GoRoute(
        path: '/salon/:code',
        builder: (context, state) =>
            RoomScreen(code: state.pathParameters['code']!.toUpperCase()),
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
                  GoRoute(
                    path: 'classeur',
                    builder: (context, state) => const BinderScreen(),
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
                    builder: (context, state) {
                      final raw = state.pathParameters['id']!;
                      final id = int.tryParse(raw);
                      return id == null
                          ? NotFoundScreen(
                              location: state.uri.path,
                              message:
                                  'Ce lien de deck est invalide : '
                                  '« $raw » n’est pas un numéro de deck.',
                            )
                          : DeckDetailScreen(deckId: id);
                    },
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
          // Profil : onglet (avatar en haut à droite des bannières = même cible).
          StatefulShellBranch(
            routes: [
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
                  GoRoute(
                    path: 'modifier',
                    builder: (context, state) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: 'amis',
                    builder: (context, state) => const FriendsScreen(),
                  ),
                  GoRoute(
                    path: 'hauts-faits',
                    builder: (context, state) => const AchievementsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  // Le routeur retient des écouteurs (refreshListenable, navigateurs des
  // branches) : sans ce dispose, un ProviderScope recréé en fuit un par test.
  ref.onDispose(router.dispose);
  return router;
});
