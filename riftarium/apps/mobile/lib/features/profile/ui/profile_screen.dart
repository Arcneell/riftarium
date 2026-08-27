import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/adaptive.dart';
import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';
import '../../auth/ui/login_screen.dart'
    show AuthError, BannerBackButton, openWebPage;
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
    final banner = PageBanner(
      title: profile?.handle ?? 'Profil',
      eyebrow: 'Mon compte',
      art: RiftBanners.home,
      expandedHeight: 200,
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
                onRetry: refresh,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            banner,
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              sliver: SliverToBoxAdapter(
                child: Reveal(child: _Identity(profile: profile)),
              ),
            ),
            if (!profile.emailVerified)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 2, 18, 0),
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
            if (profile.stats.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: SectionTitle(
                  eyebrow: 'En un coup d’œil',
                  title: 'Statistiques',
                ),
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

/// Médaillon, pseudo vérifié ou non, adresse et ancienneté : la carte
/// d'identité du compte, posée sous la bannière.
class _Identity extends StatelessWidget {
  const _Identity({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(profile: profile),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  MonoBadge(
                    label: profile.emailVerified ? 'vérifié' : 'non vérifié',
                    color: profile.emailVerified
                        ? RiftColors.hex
                        : RiftColors.fury,
                  ),
                  const SizedBox(height: 8),
                  Text(profile.email, style: text.mono.copyWith(fontSize: 13)),
                  const SizedBox(height: 4),
                  if (profile.createdAt != null)
                    Text(
                      'Membre depuis ${_formatDate(profile.createdAt!)}',
                      style: text.small,
                    ),
                  if (profile.isAdmin) ...[
                    const SizedBox(height: 6),
                    const MonoBadge(label: 'Administration'),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(profile.bio, style: text.body),
        ],
      ],
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

/// Avatar 72 px : visuel de carte choisi par le joueur, sinon l'initiale sur
/// dégradé or. Anneau parchemin pour le détacher de la bannière.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatarUrl;
    final initial = profile.handle.isEmpty
        ? '?'
        : profile.handle[0].toUpperCase();
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatar == null ? RiftColors.goldGradient : null,
        color: avatar == null ? null : Theme.of(context).colorScheme.surface,
        border: Border.all(color: RiftColors.goldSoft, width: 2),
        boxShadow: RiftShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatar == null
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: RiftFonts.display,
                  fontSize: 30,
                  color: Colors.white,
                ),
              ),
            )
          : CachedNetworkImage(
              imageUrl: avatar,
              cacheManager: riftImageCache,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.person_outline, color: RiftColors.gold),
              ),
            ),
    );
  }
}

/// Trois compteurs par rangée, chiffre en Marcellus or.
class _Stats extends StatelessWidget {
  const _Stats({required this.stats});

  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    const gap = 12.0;
    const perRow = 3;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (index, entry) in stats.entries.indexed)
              SizedBox(
                width: width,
                child: Reveal(
                  index: index,
                  child: RiftPanel(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.value}',
                          style: text.displayMedium.copyWith(
                            color: RiftColors.gold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _statLabels[entry.key] ?? entry.key,
                          style: text.small.copyWith(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
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
