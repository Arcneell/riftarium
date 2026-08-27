import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/adaptive.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/common.dart';
import '../../../core/api_exception.dart';
import '../../../core/config.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';
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

  Future<void> _open(BuildContext context, String path) async {
    final uri = Uri.parse('${AppConfig.webBaseUrl}$path');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      await showAdaptiveMessage(
        context,
        title: 'Ouverture impossible',
        message: uri.toString(),
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
    return AdaptiveScaffold(
      title: 'Profil',
      trailing: AdaptiveTextButton(
        label: 'Déconnexion',
        onPressed: () => _signOut(context, ref),
      ),
      body: profile == null
          ? _ProfileUnavailable(
              message: auth.profileError ?? 'Profil indisponible.',
              onRetry: () =>
                  ref.read(authControllerProvider.notifier).refreshProfile(),
            )
          : RefreshIndicator.adaptive(
              onRefresh: () =>
                  ref.read(authControllerProvider.notifier).refreshProfile(),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _ProfileHeader(profile: profile),
                  const SizedBox(height: 24),
                  _InfoTile(
                    label: 'E-mail',
                    value: profile.email,
                    badge: profile.emailVerified ? 'vérifié' : 'non vérifié',
                    badgeOk: profile.emailVerified,
                  ),
                  if (!profile.emailVerified)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AdaptiveTextButton(
                        label: "Renvoyer l'e-mail de vérification",
                        onPressed: () => _resendVerification(context, ref),
                      ),
                    ),
                  if (profile.createdAt != null)
                    _InfoTile(
                      label: 'Membre depuis',
                      value: _formatDate(profile.createdAt!),
                    ),
                  if (profile.isAdmin)
                    const _InfoTile(label: 'Rôle', value: 'Administration'),
                  if (profile.stats.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Statistiques',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _StatsGrid(stats: profile.stats),
                  ],
                  if (auth.profileError != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      auth.profileError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    'Compte',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _ActionTile(
                    icon: Icons.lock_reset_outlined,
                    label: 'Changer le mot de passe',
                    onTap: () => showChangePasswordDialog(context, ref),
                  ),
                  _ActionTile(
                    icon: Icons.download_outlined,
                    label: 'Exporter mes données (RGPD)',
                    onTap: () => _export(context, ref),
                  ),
                  _ActionTile(
                    icon: Icons.delete_forever_outlined,
                    label: 'Supprimer mon compte',
                    destructive: true,
                    onTap: () =>
                        showDeleteAccountDialog(context, ref, profile.handle),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'À propos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _ActionTile(
                    icon: Icons.public,
                    label: 'Ouvrir riftarium.re',
                    onTap: () => _open(context, '/'),
                  ),
                  _ActionTile(
                    icon: Icons.gavel_outlined,
                    label: 'Mentions légales',
                    onTap: () => _open(context, '/mentions-legales'),
                  ),
                  _ActionTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Politique de confidentialité',
                    onTap: () => _open(context, '/confidentialite'),
                  ),
                  _ActionTile(
                    icon: Icons.description_outlined,
                    label: "Conditions d'utilisation",
                    onTap: () => _open(context, '/cgu'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Projet fan-made à but non lucratif, non affilié à Riot Games.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile.avatarUrl;
    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: kRiftariumGold.withValues(alpha: 0.2),
          foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
          child: Text(
            profile.handle.isEmpty ? '?' : profile.handle[0].toUpperCase(),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: kRiftariumGold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.handle,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (profile.bio.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(profile.bio, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    this.badge,
    this.badgeOk = true,
  });

  final String label;
  final String value;
  final String? badge;
  final bool badgeOk;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: badgeOk
                    ? scheme.primaryContainer
                    : scheme.errorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 12,
                  color: badgeOk
                      ? scheme.onPrimaryContainer
                      : scheme.onErrorContainer,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Theme.of(context).colorScheme.error : null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final entry in stats.entries)
          Container(
            width: 150,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.value}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: kRiftariumGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _statLabels[entry.key] ?? entry.key,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      ErrorView(message: message, onRetry: onRetry);
}
