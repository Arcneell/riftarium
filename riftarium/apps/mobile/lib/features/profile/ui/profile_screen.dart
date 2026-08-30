import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../app/widgets/rift_avatar.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../../auth/ui/login_screen.dart'
    show AuthError, BannerBackButton, openWebPage;
import '../../play/application/play_providers.dart';
import '../../social/application/social_providers.dart';
import '../../social/ui/widgets/achievement_widgets.dart';
import 'account_dialogs.dart';

/// Libellés des compteurs de `user_stats` (`app/profiles.py`). Une clé inconnue
/// est affichée telle quelle : l'API peut en ajouter sans casser l'écran.
const _statLabels = {
  'unique_cards': 'Cartes différentes',
  'total_cards': 'Cartes au total',
  'decks': 'Decks',
  'public_decks': 'Decks publics',
  'likes_received': 'Likes reçus',
};

/// Nombre de médaillons montrés sur le profil avant le « +n ».
const _achievementPreview = 6;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAdaptiveMessage(
      context,
      title: 'Se déconnecter ?',
      message: 'Ta session sur cet appareil sera fermée.',
      closeLabel: 'Annuler',
      confirmLabel: 'Se déconnecter',
      destructive: true,
    );
    if (confirmed) await ref.read(authControllerProvider.notifier).signOut();
  }

  Future<void> _resendVerification(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).resendVerification();
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'E-mail envoyé',
        message: 'Regarde ta boîte de réception (et les indésirables).',
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Envoi impossible',
        message: error.message,
      );
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final data = await ref
          .read(authControllerProvider.notifier)
          .exportAccount();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await SharePlus.instance.share(
        ShareParams(text: json, subject: 'Export Riftarium (RGPD)'),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      await showAdaptiveMessage(
        context,
        title: 'Export impossible',
        message: error.message,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.isSignedIn) {
      return const SignInRequired(
        title: 'Profil',
        message:
            'Connecte-toi pour retrouver ton compte, ta collection et tes decks.',
      );
    }
    final profile = auth.profile;
    final refresh = ref.read(authControllerProvider.notifier).refreshProfile;
    final banner = _ProfileBanner(profile: profile);

    if (profile == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            banner,
            SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorView(
                message: auth.profileError ?? 'Profil indisponible.',
                onRetry: refresh,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(myAchievementsProvider);
          ref.invalidate(followsProvider);
          ref.invalidate(playStatsProvider);
          await refresh();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            banner,
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Reveal(child: _Identity(profile: profile)),
              ),
            ),
            if (!profile.emailVerified)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _resendVerification(context, ref),
                      icon: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 18,
                      ),
                      label: const Text("Renvoyer l'e-mail de vérification"),
                    ),
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              sliver: SliverToBoxAdapter(
                child: GoldButton(
                  label: 'Modifier le profil',
                  icon: Icons.edit_outlined,
                  onPressed: () => context.push(AppRoutes.editProfile),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _AchievementsPreview()),
            const SliverToBoxAdapter(child: SectionTitle(title: 'Mes parties')),
            const SliverToBoxAdapter(child: _DuelStats()),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: _ActionPanel(
                  actions: [
                    _Action(
                      icon: Icons.history_rounded,
                      label: 'Historique des parties',
                      onTap: () => context.push(AppRoutes.history),
                    ),
                    _Action(
                      icon: Icons.insights_outlined,
                      label: 'Statistiques de jeu',
                      onTap: () => context.push(AppRoutes.playStats),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _FriendsPanel()),
            if (profile.stats.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: SectionTitle(title: 'Statistiques'),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                sliver: SliverToBoxAdapter(child: _Stats(stats: profile.stats)),
              ),
            ],
            if (auth.profileError != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
                sliver: SliverToBoxAdapter(
                  child: AuthError(message: auth.profileError!),
                ),
              ),
            const SliverToBoxAdapter(
              child: SectionTitle(eyebrow: 'Réglages', title: 'Compte'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: _ActionPanel(
                  actions: [
                    _Action(
                      icon: Icons.lock_reset_outlined,
                      label: 'Changer le mot de passe',
                      onTap: () => showChangePasswordDialog(context, ref),
                    ),
                    _Action(
                      icon: Icons.download_outlined,
                      label: 'Exporter mes données (RGPD)',
                      onTap: () => _export(context, ref),
                    ),
                    _Action(
                      icon: Icons.delete_forever_outlined,
                      label: 'Supprimer mon compte',
                      destructive: true,
                      onTap: () =>
                          showDeleteAccountDialog(context, ref, profile.handle),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionTitle(eyebrow: 'Riftarium', title: 'À propos'),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: _ActionPanel(
                  actions: [
                    _Action(
                      icon: Icons.public,
                      label: 'Ouvrir riftarium.re',
                      onTap: () => openWebPage(context, '/'),
                    ),
                    _Action(
                      icon: Icons.gavel_outlined,
                      label: 'Mentions légales',
                      onTap: () => openWebPage(context, '/mentions-legales'),
                    ),
                    _Action(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Politique de confidentialité',
                      onTap: () => openWebPage(context, '/confidentialite'),
                    ),
                    _Action(
                      icon: Icons.description_outlined,
                      label: "Conditions d'utilisation",
                      onTap: () => openWebPage(context, '/cgu'),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 8),
              sliver: SliverToBoxAdapter(
                child: GhostButton(
                  label: 'Se déconnecter',
                  icon: Icons.logout_outlined,
                  onPressed: () => _signOut(context, ref),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Projet fan-made à but non lucratif, non affilié à Riot Games.',
                  textAlign: TextAlign.center,
                  style: riftText(context).small,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bannière du profil : l'illustration de lancement, le médaillon de 84 px
/// posé à cheval sur le fondu, et le pseudo en Marcellus juste à côté.
class _ProfileBanner extends StatelessWidget {
  const _ProfileBanner({required this.profile});

  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final paper = Theme.of(context).scaffoldBackgroundColor;
    final handle = profile?.handle ?? 'Profil';
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: 216,
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: text.ink),
      leading: context.canPop()
          ? BannerBackButton(onPressed: context.pop)
          : null,
      automaticallyImplyLeading: false,
      title: LayoutBuilder(
        builder: (context, constraints) {
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final collapsed =
              settings != null &&
              settings.currentExtent <= settings.minExtent + 12;
          return AnimatedOpacity(
            duration: RiftMotion.quick,
            opacity: collapsed ? 1 : 0,
            child: Text(handle, style: text.displaySmall),
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: RiftBanners.home,
              fit: BoxFit.cover,
              alignment: const Alignment(0.3, -0.2),
              fadeInDuration: RiftMotion.slow,
              placeholder: (context, url) =>
                  Container(color: RiftColors.inkStrong),
              errorWidget: (context, url, error) =>
                  Container(color: RiftColors.inkStrong),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    RiftColors.inkStrong.withValues(alpha: 0.35),
                    RiftColors.inkStrong.withValues(alpha: 0.05),
                    paper.withValues(alpha: 0),
                    paper,
                  ],
                  stops: const [0, 0.35, 0.6, 1],
                ),
              ),
            ),
            Positioned(
              left: RiftSpace.page.left,
              right: RiftSpace.page.right,
              bottom: 8,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RiftAvatar(
                    url: profile?.avatarUrl,
                    initial: handle,
                    size: 84,
                    borderColor: RiftColors.goldSoft,
                    shadow: true,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('MON COMPTE', style: text.eyebrow),
                        const SizedBox(height: 4),
                        Text(
                          handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.displayLarge.copyWith(fontSize: 28),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adresse, vérification, ancienneté et biographie : la carte d'identité du
/// compte, posée sous la bannière.
class _Identity extends StatelessWidget {
  const _Identity({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MonoBadge(
              label: profile.emailVerified ? 'vérifié' : 'non vérifié',
              color: profile.emailVerified ? RiftColors.hex : RiftColors.fury,
            ),
            if (profile.isAdmin) const MonoBadge(label: 'Administration'),
            Text(profile.email, style: text.mono.copyWith(fontSize: 13)),
          ],
        ),
        if (profile.createdAt != null) ...[
          const SizedBox(height: 6),
          Text(
            'Membre depuis le ${formatSocialDate(profile.createdAt!)}',
            style: text.small,
          ),
        ],
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(profile.bio, style: text.body),
        ],
      ],
    );
  }
}

/// Les hauts faits débloqués, en médaillons. La section disparaît tant que
/// l'API n'a rien à en dire (hors ligne, catalogue vide).
class _AchievementsPreview extends ConsumerWidget {
  const _AchievementsPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final items = ref.watch(myAchievementsProvider).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final unlocked = items.where((item) => item.isUnlocked).toList();
    final shown = unlocked.take(_achievementPreview).toList();
    final rest = unlocked.length - shown.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          eyebrow: 'Palmarès',
          title: 'Hauts faits',
          trailing: Text(
            '${unlocked.length} / ${items.length}',
            style: text.monoStrong,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: RiftPanel(
            raised: true,
            onTap: () => context.push(AppRoutes.achievements),
            child: unlocked.isEmpty
                ? Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aucun haut fait débloqué.',
                          style: text.small,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: RiftColors.gold,
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final achievement in shown)
                        AchievementMedallion(
                          achievement: achievement,
                          size: 44,
                        ),
                      if (rest > 0) Text('+$rest', style: text.monoStrong),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// Bilan des parties suivies : quatre chiffres, et rien de plus (le détail
/// vit dans « Statistiques de jeu »).
class _DuelStats extends ConsumerWidget {
  const _DuelStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final stats = ref.watch(playStatsProvider).valueOrNull;
    if (stats == null || stats.isEmpty) return const SizedBox.shrink();
    final totals = stats.totals;
    final cells = <(String, String)>[
      ('${totals.played}', 'parties'),
      ('${totals.won}', 'victoires'),
      (totals.winRateLabel, 'de réussite'),
      ('${totals.bestStreak}', 'série'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: RiftPanel(
        child: Row(
          children: [
            for (final (index, cell) in cells.indexed) ...[
              if (index > 0) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      cell.$1,
                      maxLines: 1,
                      style: text.displaySmall.copyWith(color: RiftColors.gold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cell.$2,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: text.small.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mes amis : deux compteurs et l'entrée vers la liste.
class _FriendsPanel extends ConsumerWidget {
  const _FriendsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final follows = ref.watch(followsProvider).valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(eyebrow: 'Mon cercle', title: 'Amis'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: RiftPanel(
            raised: true,
            onTap: () => context.push(AppRoutes.friends),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    follows == null
                        ? 'Suivis, abonnés, invitations.'
                        : '${follows.following.length} suivis · '
                              '${follows.followers.length} abonnés',
                    style: follows == null ? text.small : text.bodyStrong,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: RiftColors.gold,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Trois compteurs par rangée, chiffre en Marcellus or. Les tuiles d'une même
/// rangée partagent leur hauteur : pas de marche d'escalier quand un libellé
/// passe sur deux lignes, et la dernière rangée se répartit la largeur.
class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final Map<String, int> stats;

  static const _gap = 12.0;
  static const _perRow = 3;

  @override
  Widget build(BuildContext context) {
    final entries = stats.entries.toList();
    final rows = <List<int>>[];
    for (var start = 0; start < entries.length; start += _perRow) {
      final end = (start + _perRow).clamp(0, entries.length);
      rows.add([for (var index = start; index < end; index++) index]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (rowIndex, row) in rows.indexed) ...[
          if (rowIndex > 0) const SizedBox(height: _gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (cell, index) in row.indexed) ...[
                  if (cell > 0) const SizedBox(width: _gap),
                  Expanded(
                    child: Reveal(
                      index: index,
                      child: _StatTile(entry: entries[index]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Une tuile de compteur : le chiffre en or, le libellé sur deux lignes au plus.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.entry});

  final MapEntry<String, int> entry;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return RiftPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${entry.value}',
            style: text.displayMedium.copyWith(color: RiftColors.gold),
          ),
          const SizedBox(height: 2),
          Text(
            _statLabels[entry.key] ?? entry.key,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.small.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _Action {
  const _Action({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
}

/// Une section d'actions : panneau parchemin, une ligne par action, filets or
/// entre elles.
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.actions});

  final List<_Action> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = riftText(context);
    return RiftPanel(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final (index, action) in actions.indexed) ...[
            if (index > 0)
              Divider(height: 1, indent: 52, color: theme.colorScheme.outline),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              minLeadingWidth: 24,
              leading: Icon(
                action.icon,
                size: 22,
                color: action.destructive ? RiftColors.fury : RiftColors.hex,
              ),
              title: Text(
                action.label,
                style: text.body.copyWith(
                  color: action.destructive ? RiftColors.furyText : text.ink,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: action.onTap,
            ),
          ],
        ],
      ),
    );
  }
}
