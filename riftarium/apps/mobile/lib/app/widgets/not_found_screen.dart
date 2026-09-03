import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../design/banners.dart';
import '../design/components.dart';
import '../design/page_banner.dart';
import '../design/reveal.dart';
import '../router.dart';
import '../theme.dart';

/// Écran de secours : lien profond inconnu (`errorBuilder` du routeur) ou
/// identifiant illisible dans l'URL. Le site sait peut-être ouvrir la page :
/// on propose de l'y suivre plutôt que de laisser l'utilisateur bloqué.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, this.location, this.message});

  /// Chemin demandé, tel qu'il a été reçu (`/cartes/xyz`).
  final String? location;

  /// Explication, quand elle est plus précise que « page introuvable ».
  final String? message;

  /// URL du site pour le même chemin, quand il y en a un.
  Uri? get _webUri {
    final path = location;
    if (path == null || !path.startsWith('/')) return null;
    return Uri.parse('${AppConfig.webBaseUrl}$path');
  }

  Future<void> _openOnSite(BuildContext context) async {
    final uri = _webUri;
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le navigateur.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final uri = _webUri;
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          PageBanner(
            title: 'Page introuvable',
            eyebrow: 'Rift égaré',
            art: RiftBanners.home,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            sliver: SliverToBoxAdapter(
              child: Reveal(
                child: RiftPanel(
                  raised: true,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message ??
                            'Ce lien ne mène à aucun écran de '
                                'l’application.',
                        style: text.body,
                      ),
                      if (location != null) ...[
                        const SizedBox(height: 10),
                        Text(location!, style: text.mono),
                      ],
                      const SizedBox(height: 18),
                      GoldButton(
                        label: 'Retour à l’accueil',
                        icon: Icons.home_outlined,
                        onPressed: () => context.go(AppRoutes.home),
                      ),
                      if (uri != null) ...[
                        const SizedBox(height: 10),
                        GhostButton(
                          label: 'Ouvrir sur le site',
                          icon: Icons.open_in_new,
                          onPressed: () => _openOnSite(context),
                        ),
                      ],
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
