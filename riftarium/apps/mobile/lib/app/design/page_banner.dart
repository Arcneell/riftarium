import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// En-tête de page comme sur le site : illustration officielle qui se fond dans
/// le parchemin, sur-titre en capitales, titre Marcellus. Sliver : se rétracte
/// au défilement, l'image s'étire au tirage (iOS) et glisse en parallaxe.
class PageBanner extends StatelessWidget {
  const PageBanner({
    super.key,
    required this.title,
    required this.art,
    this.eyebrow,
    this.subtitle,
    this.actions = const [],
    this.expandedHeight = 220,
    this.focus = Alignment.center,
    this.leading,
  });

  final String title;
  final String art;
  final String? eyebrow;
  final String? subtitle;
  final List<Widget> actions;
  final double expandedHeight;

  /// Point d'intérêt de l'illustration (l'équivalent de `--banner-x/--banner-y`).
  final Alignment focus;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final paper = Theme.of(context).scaffoldBackgroundColor;
    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      backgroundColor: paper,
      surfaceTintColor: Colors.transparent,
      leading: leading,
      automaticallyImplyLeading: leading != null,
      actions: [...actions, const SizedBox(width: 6)],
      iconTheme: IconThemeData(color: text.ink),
      title: LayoutBuilder(
        builder: (context, constraints) {
          // Le titre n'apparaît dans la barre qu'une fois la bannière repliée.
          final settings = context
              .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
          final collapsed =
              settings != null &&
              settings.currentExtent <= settings.minExtent + 12;
          return AnimatedOpacity(
            duration: RiftMotion.quick,
            opacity: collapsed ? 1 : 0,
            child: Text(title, style: text.displaySmall),
          );
        },
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        stretchModes: const [StretchMode.zoomBackground],
        background: _BannerBackground(
          art: art,
          focus: focus,
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }
}

class _BannerBackground extends StatelessWidget {
  const _BannerBackground({
    required this.art,
    required this.focus,
    required this.title,
    this.eyebrow,
    this.subtitle,
  });

  final String art;
  final Alignment focus;
  final String title;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final paper = Theme.of(context).scaffoldBackgroundColor;
    final topPadding = MediaQuery.paddingOf(context).top;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: art,
          fit: BoxFit.cover,
          alignment: focus,
          fadeInDuration: RiftMotion.slow,
          placeholder: (context, url) => Container(color: RiftColors.inkStrong),
          errorWidget: (context, url, error) =>
              Container(color: RiftColors.inkStrong),
        ),
        // Voile encre en haut (lisibilité de la barre), parchemin en bas.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                RiftColors.inkStrong.withValues(alpha: 0.35),
                RiftColors.inkStrong.withValues(alpha: 0.05),
                paper.withValues(alpha: 0.0),
                paper,
              ],
              stops: const [0, 0.35, 0.62, 1],
            ),
          ),
        ),
        Positioned(
          left: RiftSpace.page.left,
          right: RiftSpace.page.right,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!.toUpperCase(), style: text.eyebrow),
                const SizedBox(height: 6),
              ],
              Text(title, style: text.displayLarge.copyWith(fontSize: 30)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: text.small),
              ],
            ],
          ),
        ),
        SizedBox(height: topPadding),
      ],
    );
  }
}
