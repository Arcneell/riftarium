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
import '../../../app/widgets/rift_avatar.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../../auth/ui/login_screen.dart' show AuthError, BannerBackButton;

/// Longueur maximale de la biographie (`ProfilePatch.bio`, côté API).
const int kBioMaxLength = 280;

/// Longueur minimale d'un pseudo (`ProfilePatch.handle`).
const int kHandleMinLength = 3;

/// Légendes proposées comme avatar (`GET /api/auth/avatars`).
final avatarOptionsProvider = FutureProvider.autoDispose<List<AvatarOption>>((
  ref,
) async {
  final signedIn = ref.watch(
    authControllerProvider.select((state) => state.isSignedIn),
  );
  if (!signedIn) return const [];
  return ref.watch(authApiProvider).avatars();
});

/// Modifier mon profil : pseudo, biographie, avatar et confidentialité.
///
/// Tout part en un seul `PATCH /auth/me`, et seuls les champs modifiés sont
/// envoyés : l'API refuse un corps vide, et exige le mot de passe courant pour
/// changer de pseudo.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  final _password = TextEditingController();

  bool _loaded = false;
  bool _saving = false;
  String? _error;

  String? _avatarCardId;
  late bool _showStats;
  late bool _showCollection;
  late bool _showDecks;
  late bool _showAchievements;

  @override
  void dispose() {
    _handle.dispose();
    _bio.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Premier profil reçu : il remplit le formulaire une seule fois, pour ne
  /// pas écraser une saisie en cours à chaque rafraîchissement.
  void _load(Profile profile) {
    if (_loaded) return;
    _loaded = true;
    _handle.text = profile.handle;
    _bio.text = profile.bio;
    _avatarCardId = profile.avatarCardId;
    _showStats = profile.showStats;
    _showCollection = profile.showCollection;
    _showDecks = profile.showDecks;
    _showAchievements = profile.showAchievements;
  }

  Future<void> _save(Profile profile) async {
    final handle = _handle.text.trim();
    final bio = _bio.text.trim();
    final handleChanged = handle != profile.handle;

    if (handleChanged && handle.length < kHandleMinLength) {
      setState(
        () => _error = 'Un pseudo fait au moins $kHandleMinLength caractères.',
      );
      return;
    }
    if (handleChanged && _password.text.isEmpty) {
      setState(
        () => _error =
            'Ton mot de passe actuel est demandé pour changer de pseudo.',
      );
      return;
    }

    final bioChanged = bio != profile.bio;
    final avatarChanged =
        _avatarCardId != null && _avatarCardId != profile.avatarCardId;
    final privacyChanged =
        _showStats != profile.showStats ||
        _showCollection != profile.showCollection ||
        _showDecks != profile.showDecks ||
        _showAchievements != profile.showAchievements;

    if (!handleChanged && !bioChanged && !avatarChanged && !privacyChanged) {
      setState(
        () => _error = 'Rien à enregistrer : ton profil est déjà à jour.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authApiProvider)
          .updateMe(
            handle: handleChanged ? handle : null,
            bio: bioChanged ? bio : null,
            avatarCardId: avatarChanged ? _avatarCardId : null,
            showStats: privacyChanged ? _showStats : null,
            showCollection: privacyChanged ? _showCollection : null,
            showDecks: privacyChanged ? _showDecks : null,
            showAchievements: privacyChanged ? _showAchievements : null,
            currentPassword: handleChanged ? _password.text : null,
          );
      await ref.read(authControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isSignedIn) {
      return const SignInRequired(
        title: 'Modifier le profil',
        eyebrow: 'Mon compte',
        message: 'Connecte-toi pour modifier ton profil.',
        returnTo: AppRoutes.editProfile,
      );
    }
    final profile = auth.profile;
    final banner = PageBanner(
      title: 'Modifier le profil',
      eyebrow: 'Mon compte',
      art: RiftBanners.home,
      expandedHeight: 170,
      focus: const Alignment(0.3, -0.2),
      leading: context.canPop()
          ? BannerBackButton(onPressed: context.pop)
          : null,
    );
    if (profile == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            banner,
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: auth.profileError ?? 'Profil indisponible.',
                onRetry: ref
                    .read(authControllerProvider.notifier)
                    .refreshProfile,
              ),
            ),
          ],
        ),
      );
    }
    _load(profile);

    final handleChanged = _handle.text.trim() != profile.handle;
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          banner,
          const SliverToBoxAdapter(
            child: SectionTitle(eyebrow: 'Identité', title: 'Pseudo et bio'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverToBoxAdapter(
              child: Reveal(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _handle,
                      autocorrect: false,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Pseudo'),
                    ),
                    if (handleChanged) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Mot de passe actuel',
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: _bio,
                      maxLength: kBioMaxLength,
                      maxLines: 4,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Biographie',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionTitle(eyebrow: 'Portrait', title: 'Avatar'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverToBoxAdapter(
              child: _AvatarPicker(
                selected: _avatarCardId,
                onSelect: (id) => setState(() => _avatarCardId = id),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionTitle(
              eyebrow: 'Ce que les autres voient',
              title: 'Confidentialité',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverToBoxAdapter(
              child: RiftPanel(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    _PrivacySwitch(
                      title: 'Mes statistiques de duels',
                      detail: 'Visibles sur mon profil public.',
                      value: _showStats,
                      onChanged: (value) => setState(() => _showStats = value),
                    ),
                    _PrivacySwitch(
                      title: 'Ma collection',
                      detail:
                          'Les autres joueurs peuvent parcourir les cartes que '
                          'je possède.',
                      value: _showCollection,
                      onChanged: (value) =>
                          setState(() => _showCollection = value),
                    ),
                    _PrivacySwitch(
                      title: 'Mes decks publics',
                      detail: 'Visibles sur mon profil public.',
                      value: _showDecks,
                      onChanged: (value) => setState(() => _showDecks = value),
                    ),
                    _PrivacySwitch(
                      title: 'Mes hauts faits',
                      detail: 'Visibles sur mon profil public.',
                      value: _showAchievements,
                      onChanged: (value) =>
                          setState(() => _showAchievements = value),
                      last: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
              sliver: SliverToBoxAdapter(child: AuthError(message: _error!)),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 36),
            sliver: SliverToBoxAdapter(
              child: GoldButton(
                label: 'Enregistrer',
                icon: Icons.check_rounded,
                loading: _saving,
                onPressed: _saving ? null : () => _save(profile),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une grille de légendes : le portrait choisi porte un anneau or.
class _AvatarPicker extends ConsumerWidget {
  const _AvatarPicker({required this.selected, required this.onSelect});

  final String? selected;
  final void Function(String cardId) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final avatars = ref.watch(avatarOptionsProvider);
    return RiftPanel(
      child: avatars.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LoadingView(),
        ),
        error: (error, _) =>
            Text('Les légendes n’ont pas pu être chargées.', style: text.small),
        data: (options) => options.isEmpty
            ? Text(
                'Aucune légende disponible pour le moment.',
                style: text.small,
              )
            : Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final option in options)
                    SizedBox(
                      width: 64,
                      child: Semantics(
                        button: true,
                        selected: option.id == selected,
                        label: option.name,
                        child: PressScale(
                          onTap: () => onSelect(option.id),
                          child: Column(
                            children: [
                              RiftAvatar(
                                url: option.imageUrl,
                                initial: option.name,
                                size: 56,
                                borderWidth: option.id == selected ? 3 : 1.5,
                                borderColor: option.id == selected
                                    ? RiftColors.gold
                                    : null,
                                shadow: option.id == selected,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                option.name,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: text.small.copyWith(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// Un réglage de confidentialité : ce qu'il ouvre, dit en une phrase.
class _PrivacySwitch extends StatelessWidget {
  const _PrivacySwitch({
    required this.title,
    required this.detail,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  final String title;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      children: [
        SwitchListTile.adaptive(
          value: value,
          onChanged: onChanged,
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: text.bodyStrong),
          subtitle: Text(detail, style: text.small.copyWith(fontSize: 12)),
        ),
        if (!last)
          Divider(height: 1, color: Theme.of(context).colorScheme.outline),
      ],
    );
  }
}
