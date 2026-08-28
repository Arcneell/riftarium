import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/design/banners.dart';
import '../../../../app/design/components.dart';
import '../../../../app/design/page_banner.dart';
import '../../../../app/design/reveal.dart';
import '../../../../app/router.dart';
import '../../../../app/theme.dart';
import '../../../../app/widgets/profile_action.dart';

/// Invitation à ouvrir une session, habillée comme les onglets connectés :
/// même bannière d'inventaire, puis un panneau parchemin avec l'action or.
class CollectionSignIn extends StatelessWidget {
  const CollectionSignIn({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.message,
    required this.returnTo,
    this.expandedHeight = 220,
  });

  final String title;
  final String eyebrow;
  final String message;

  /// Chemin où revenir une fois la session ouverte.
  final String returnTo;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          PageBanner(
            title: title,
            eyebrow: eyebrow,
            art: RiftBanners.collection,
            expandedHeight: expandedHeight,
            actions: const [ProfileAction()],
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 32),
            sliver: SliverToBoxAdapter(
              child: Reveal(
                child: RiftPanel(
                  raised: true,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const GoldRule(),
                      const SizedBox(height: 14),
                      Text(message, style: text.small),
                      const SizedBox(height: 18),
                      GoldButton(
                        label: 'Se connecter',
                        icon: Icons.login_outlined,
                        onPressed: () =>
                            context.push(AppRoutes.loginFrom(returnTo)),
                      ),
                      const SizedBox(height: 4),
                      Center(
                        child: TextButton(
                          onPressed: () => context.push(AppRoutes.register),
                          child: const Text('Créer un compte'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
