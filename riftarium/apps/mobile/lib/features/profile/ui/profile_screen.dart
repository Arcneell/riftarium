import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/adaptive.dart';
import '../../../app/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/session.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
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
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AdaptiveFilledButton(label: 'Réessayer', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
