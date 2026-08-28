import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/banners.dart';
import '../../../app/design/components.dart';
import '../../../app/design/page_banner.dart';
import '../../../app/design/reveal.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../app/widgets/card_image.dart';
import '../../../app/widgets/profile_action.dart';
import '../../auth/application/auth_controller.dart';
import '../../cards/data/cards_api.dart';
import '../../cards/domain/card.dart';

/// Une carte au hasard à chaque ouverture : le geste du site (« la
/// cartothèque complète ») ramené à un seul visuel qui brille.
final randomCardProvider = FutureProvider.autoDispose<RiftCard?>((ref) async {
  final page = await ref
      .read(cardsApiProvider)
      .list(filters: const CardFilters(sort: 'random'), size: 1);
  return page.items.isEmpty ? null : page.items.first;
});

/// Accueil : bannière cinématique, raccourcis vers ce qu'on fait le plus
/// souvent (scanner, communauté, guides), carte du moment, état du compte.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final text = riftText(context);
    final profile = auth.profile;
    final signedIn = auth.isSignedIn;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          PageBanner(
            title: signedIn && profile != null
                ? 'Bonjour ${profile.handle}'
                : 'Vos cartes, vos decks, vos règles.',
            eyebrow: 'Riftarium',
            subtitle: signedIn
                ? null
                : 'Le compagnon de Riftbound, dans ta poche.',
            art: RiftBanners.home,
            expandedHeight: 260,
            focus: const Alignment(0.3, -0.2),
            actions: const [ProfileAction()],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            sliver: SliverToBoxAdapter(
              child: Reveal(
                index: 0,
                child: GoldButton(
                  label: 'Scanner une carte',
                  icon: Icons.center_focus_strong_outlined,
                  onPressed: () => context.push(AppRoutes.scan),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _QuickTile(
                  index: 1,
                  icon: Icons.groups_2_outlined,
                  eyebrow: 'Communauté',
                  title: 'Decks partagés',
                  color: RiftColors.hex,
                  onTap: () => context.go(AppRoutes.community),
                ),
                _QuickTile(
                  index: 2,
                  icon: Icons.sports_esports_outlined,
                  eyebrow: 'À la table',
                  title: 'Compteur de partie',
                  color: RiftColors.mind,
                  onTap: () => context.push(AppRoutes.game),
                ),
                _QuickTile(
                  index: 3,
                  icon: Icons.bolt_outlined,
                  eyebrow: 'En pleine partie',
                  title: 'Aide avancée',
                  color: RiftColors.order,
                  onTap: () => context.go(AppRoutes.advancedHelp),
                ),
                _QuickTile(
                  index: 4,
                  icon: Icons.style_outlined,
                  eyebrow: 'Cartothèque',
                  title: 'Toutes les cartes',
                  color: RiftColors.fury,
                  onTap: () => context.go(AppRoutes.cards),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionTitle(eyebrow: 'Au hasard', title: 'Carte du moment'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            sliver: SliverToBoxAdapter(child: _RandomCard()),
          ),
          if (signedIn && profile != null && profile.stats.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SectionTitle(
                eyebrow: 'Mon compte',
                title: 'En un coup d’œil',
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    _Stat(
                      label: 'Cartes',
                      value: profile.stats['unique_cards'] ?? 0,
                      onTap: () => context.go(AppRoutes.collection),
                    ),
                    const SizedBox(width: 12),
                    _Stat(
                      label: 'Exemplaires',
                      value: profile.stats['total_cards'] ?? 0,
                      onTap: () => context.go(AppRoutes.collection),
                    ),
                    const SizedBox(width: 12),
                    _Stat(
                      label: 'Decks',
                      value: profile.stats['decks'] ?? 0,
                      onTap: () => context.go(AppRoutes.decks),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!signedIn)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
              sliver: SliverToBoxAdapter(
                child: RiftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ta collection te suit partout',
                        style: text.displaySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Un compte gratuit pour compter tes cartes, construire '
                        'tes decks et les partager. Le même que sur le site.',
                        style: text.small,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: GhostButton(
                              label: 'Se connecter',
                              onPressed: () => context.push(
                                AppRoutes.loginFrom(AppRoutes.home),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextButton(
                              onPressed: () => context.push(AppRoutes.register),
                              child: const Text('Créer un compte'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.index,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final String eyebrow;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Reveal(
      index: index,
      child: RiftPanel(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(RiftRadius.sm),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              eyebrow.toUpperCase(),
              style: text.eyebrow.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: text.displaySmall.copyWith(fontSize: 17),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RandomCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = riftText(context);
    final random = ref.watch(randomCardProvider);
    return random.when(
      loading: () => const SizedBox(
        height: 190,
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (_, _) => RiftPanel(
        child: Row(
          children: [
            Expanded(
              child: Text(
                'La cartothèque ne répond pas pour le moment.',
                style: text.small,
              ),
            ),
            TextButton(
              onPressed: () => ref.invalidate(randomCardProvider),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
      data: (card) {
        if (card == null) return const SizedBox.shrink();
        return Reveal(
          index: 5,
          child: RiftPanel(
            onTap: () => context.go(AppRoutes.card(card.id)),
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardImage(
                  card: card,
                  width: 112,
                  foil: card.foil,
                  heroTag: 'card-${card.id}',
                  shadow: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MonoBadge(label: card.displayCode),
                      const SizedBox(height: 8),
                      Text(card.name, style: text.displaySmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final domain in card.domains)
                            DomainChip(domain: domain, compact: true),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${card.type}${card.rarity.isEmpty ? '' : ' · ${card.rarity}'}',
                        style: text.small,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => ref.invalidate(randomCardProvider),
                            child: const Text('Une autre'),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.onTap});

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Expanded(
      child: RiftPanel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: text.displayMedium.copyWith(color: RiftColors.gold),
            ),
            Text(
              label.toUpperCase(),
              style: text.eyebrow.copyWith(color: text.muted),
            ),
          ],
        ),
      ),
    );
  }
}
