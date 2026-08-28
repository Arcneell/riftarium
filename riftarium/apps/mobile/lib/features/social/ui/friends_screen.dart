import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/ui/login_screen.dart' show AuthError, BannerBackButton;
import '../../play/application/play_providers.dart';
import '../../play/data/play_api.dart';
import '../application/social_providers.dart';
import '../domain/public_profile.dart';
import 'widgets/invite_sheet.dart';
import 'widgets/social_widgets.dart';

/// Mes amis : ceux que je suis, ceux qui me suivent, et de quoi en trouver
/// d'autres. Un suivi est unilatéral (un carnet d'adresses), sans messagerie :
/// on l'ouvre pour retrouver un adversaire et l'inviter dans un salon.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// Recherche réellement envoyée à l'API (après [userSearchDelay]).
  String _query = '';
  bool _followers = false;
  bool _inviting = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(userSearchDelay, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _open(String handle) => context.push(AppRoutes.player(handle));

  /// Crée un salon de duel (ou reprend celui qui est déjà ouvert) et propose
  /// d'en partager le code.
  Future<void> _invite(SocialUser user) async {
    if (_inviting) return;
    setState(() {
      _inviting = true;
      _error = null;
    });
    try {
      final code = await _roomCode(ref.read(playApiProvider));
      ref.invalidate(currentPlayProvider);
      if (!mounted) return;
      await showRoomInviteSheet(context, code: code, handle: user.handle);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  /// Le code du salon où inviter : un salon neuf, ou celui qui est déjà
  /// ouvert (l'API n'en accepte qu'un seul à la fois).
  Future<String> _roomCode(PlayApi api) async {
    try {
      return (await api.createRoom(mode: 'duel')).code;
    } on ApiException {
      final existing = await _existingRoom(api);
      if (existing == null) rethrow;
      return existing;
    }
  }

  Future<String?> _existingRoom(PlayApi api) async {
    try {
      final current = await api.current();
      final room = current.room;
      return room != null && room.isOpen ? room.code : null;
    } on ApiException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(
      authControllerProvider.select((state) => state.isSignedIn),
    );
    if (!signedIn) {
      return const SignInRequired(
        title: 'Amis',
        eyebrow: 'Mon profil',
        message:
            'Connecte-toi pour suivre des joueurs et les inviter dans un '
            'salon.',
        returnTo: AppRoutes.friends,
      );
    }

    final follows = ref.watch(followsProvider);
    final searching = _search.text.trim().length >= userSearchMinLength;
    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () async => ref.invalidate(followsProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            PageBanner(
              title: 'Amis',
              eyebrow: 'Mon profil',
              art: RiftBanners.community,
              expandedHeight: 190,
              leading: context.canPop()
                  ? BannerBackButton(onPressed: context.pop)
                  : null,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _search,
                  onChanged: _onSearch,
                  autocorrect: false,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Chercher un joueur par son pseudo',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
            if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(child: AuthError(message: _error!)),
              ),
            if (searching) ..._searchResults() else ..._followLists(follows),
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  List<Widget> _searchResults() {
    final results = ref.watch(userSearchProvider(_query));
    return [
      const SliverToBoxAdapter(
        child: SectionTitle(eyebrow: 'Recherche', title: 'Résultats'),
      ),
      ...results.when(
        loading: () => const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: LoadingView(),
            ),
          ),
        ],
        error: (error, _) => [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverToBoxAdapter(
              child: AuthError(message: socialErrorMessage(error)),
            ),
          ),
        ],
        data: (users) => users.isEmpty
            ? [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'Aucun joueur ne porte ce pseudo.',
                      style: riftText(context).small,
                    ),
                  ),
                ),
              ]
            : [_UserList(users: users, onOpen: _open)],
      ),
    ];
  }

  List<Widget> _followLists(AsyncValue<FollowLists> follows) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        sliver: SliverToBoxAdapter(
          child: SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(
                  'Suivis (${follows.valueOrNull?.following.length ?? 0})',
                ),
              ),
              ButtonSegment(
                value: true,
                label: Text(
                  'Abonnés (${follows.valueOrNull?.followers.length ?? 0})',
                ),
              ),
            ],
            selected: {_followers},
            onSelectionChanged: (value) =>
                setState(() => _followers = value.first),
          ),
        ),
      ),
      ...follows.when(
        loading: () => const [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: LoadingView(),
            ),
          ),
        ],
        error: (error, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: ErrorView(
              message: socialErrorMessage(
                error,
                fallback: 'Tes amis n’ont pas pu être chargés.',
              ),
              onRetry: () => ref.invalidate(followsProvider),
            ),
          ),
        ],
        data: (lists) {
          final users = _followers ? lists.followers : lists.following;
          if (users.isEmpty) {
            return [
              SliverPadding(
                padding: const EdgeInsets.only(top: 24),
                sliver: SliverToBoxAdapter(
                  child: EmptyView(
                    title: _followers
                        ? 'Personne ne te suit encore'
                        : 'Tu ne suis personne',
                    detail: _followers
                        ? 'Partage ton pseudo : tes adversaires te retrouveront '
                              'depuis la recherche.'
                        : 'Cherche le pseudo d’un adversaire et suis-le : tu le '
                              'retrouveras ici pour l’inviter.',
                    icon: Icons.group_outlined,
                  ),
                ),
              ),
            ];
          }
          return [
            SliverPadding(
              padding: const EdgeInsets.only(top: 14),
              sliver: _UserList(
                users: users,
                onOpen: _open,
                onInvite: _followers ? null : _invite,
                inviting: _inviting,
              ),
            ),
          ];
        },
      ),
    ];
  }
}

class _UserList extends StatelessWidget {
  const _UserList({
    required this.users,
    required this.onOpen,
    this.onInvite,
    this.inviting = false,
  });

  final List<SocialUser> users;
  final void Function(String handle) onOpen;
  final Future<void> Function(SocialUser user)? onInvite;
  final bool inviting;

  @override
  Widget build(BuildContext context) {
    final invite = onInvite;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverList.separated(
        itemCount: users.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final user = users[index];
          return Reveal(
            index: index,
            child: SocialUserRow(
              user: user,
              onOpen: () => onOpen(user.handle),
              trailing: invite == null
                  ? null
                  : TextButton.icon(
                      onPressed: inviting ? null : () => invite(user),
                      icon: const Icon(Icons.wifi_tethering_rounded, size: 17),
                      label: const Text('Inviter'),
                    ),
            ),
          );
        },
      ),
    );
  }
}
