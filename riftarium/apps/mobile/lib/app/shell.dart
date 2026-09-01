import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive.dart';
import 'design/reveal.dart';
import 'router.dart';
import 'theme.dart';

/// Onglets de l'application, dans l'ordre des branches du StatefulShellRoute
/// (voir router.dart). Un onglet = une pile de navigation indépendante.
class AppTab {
  const AppTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.cupertinoIcon,
    required this.cupertinoActiveIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final IconData cupertinoIcon;
  final IconData cupertinoActiveIcon;

  static const values = [
    AppTab(
      label: 'Accueil',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      cupertinoIcon: CupertinoIcons.house,
      cupertinoActiveIcon: CupertinoIcons.house_fill,
    ),
    AppTab(
      label: 'Cartes',
      icon: Icons.style_outlined,
      activeIcon: Icons.style,
      cupertinoIcon: CupertinoIcons.rectangle_stack,
      cupertinoActiveIcon: CupertinoIcons.rectangle_stack_fill,
    ),
    AppTab(
      label: 'Collection',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      cupertinoIcon: CupertinoIcons.archivebox,
      cupertinoActiveIcon: CupertinoIcons.archivebox_fill,
    ),
    AppTab(
      label: 'Decks',
      icon: Icons.layers_outlined,
      activeIcon: Icons.layers,
      cupertinoIcon: CupertinoIcons.square_stack_3d_up,
      cupertinoActiveIcon: CupertinoIcons.square_stack_3d_up_fill,
    ),
    AppTab(
      label: 'Règles',
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book,
      cupertinoIcon: CupertinoIcons.book,
      cupertinoActiveIcon: CupertinoIcons.book_fill,
    ),
  ];

  /// Onglet Profil (branche 5 du routeur).
  static const AppTab profile = AppTab(
    label: 'Profil',
    icon: Icons.person_outline,
    activeIcon: Icons.person,
    cupertinoIcon: CupertinoIcons.person,
    cupertinoActiveIcon: CupertinoIcons.person_fill,
  );

  /// Barre : deux onglets, « Jouer » au centre, deux onglets. Collection (2) et
  /// Decks (3) restent des branches (tuiles de l'accueil, liens), sans onglet :
  /// le téléphone sert d'abord à jouer, le site à construire.
  static const barSlots = <int?>[0, 1, null, 4, 5];
}

/// Tous les onglets indexés comme les branches du routeur.
List<AppTab> get _allTabs => [...AppTab.values, AppTab.profile];

/// Coque à onglets : barre translucide parchemin, quatre onglets (Accueil,
/// Cartes · Règles, Profil) et, exactement au centre, le bouton « Jouer »
/// surélevé (dégradé or, liseré parchemin) qui ouvre le compteur de partie.
/// Icônes Cupertino sur iOS, Material ailleurs.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    // Retaper l'onglet courant ramène à la racine de sa pile.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final bar = _RiftBottomBar(
      currentIndex: navigationShell.currentIndex,
      onSelect: _select,
      onPlay: () => context.push(AppRoutes.game),
      cupertino: isCupertino(context),
    );
    if (isCupertino(context)) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            Expanded(child: navigationShell),
            bar,
          ],
        ),
      );
    }
    return Scaffold(body: navigationShell, bottomNavigationBar: bar);
  }
}

class _RiftBottomBar extends StatelessWidget {
  const _RiftBottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.onPlay,
    required this.cupertino,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onPlay;
  final bool cupertino;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = RiftColors.paper2.withValues(alpha: 0.96);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final tabs = _allTabs;
    final slots = <Widget>[
      for (final index in AppTab.barSlots)
        Expanded(
          child: index == null
              ? _PlayButton(onTap: onPlay)
              : _TabItem(
                  tab: tabs[index],
                  selected: index == currentIndex,
                  cupertino: cupertino,
                  onTap: () => onSelect(index),
                ),
        ),
    ];

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: barColor,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: SizedBox(
        height: 64,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: slots),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.tab,
    required this.selected,
    required this.cupertino,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final bool cupertino;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    final color = selected ? RiftColors.goldDeep : text.muted;
    final icon = cupertino
        ? (selected ? tab.cupertinoActiveIcon : tab.cupertinoIcon)
        : (selected ? tab.activeIcon : tab.icon);
    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightColor: RiftColors.gold.withValues(alpha: 0.08),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: RiftMotion.quick,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? RiftColors.gold.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(RiftRadius.full),
                ),
                child: Icon(icon, size: 23, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                tab.label,
                style: text.small.copyWith(
                  fontSize: 11,
                  color: color,
                  fontVariations: RiftFonts.weight(selected ? 600 : 500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton central « Jouer » : médaillon or surélevé, liseré parchemin,
/// ombre dorée. Se distingue des onglets sans casser leur rythme.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = riftText(context);
    return Semantics(
      button: true,
      label: 'Jouer : compteur de partie',
      child: PressScale(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Le médaillon fait 54 px mais n'occupe que 40 px de hauteur :
              // il déborde au-dessus de la barre sans faire déborder la colonne.
              SizedBox(
                height: 40,
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: 54,
                  maxHeight: 54,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RiftColors.goldGradient,
                      border: Border.all(color: RiftColors.paper2, width: 3),
                      boxShadow: RiftShadows.glowGold,
                    ),
                    child: const Icon(
                      Icons.sports_esports_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Jouer',
                style: text.small.copyWith(
                  fontSize: 11,
                  color: RiftColors.goldDeep,
                  fontVariations: RiftFonts.weight(600),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
