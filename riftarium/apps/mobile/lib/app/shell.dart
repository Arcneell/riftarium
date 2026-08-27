import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive.dart';
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
}

/// Coque à onglets : barre translucide parchemin, filet or sur l'onglet actif.
/// Cupertino sur iOS, NavigationBar Material ailleurs.
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
    final index = navigationShell.currentIndex;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final barColor = (dark ? RiftColors.darkPaper2 : const Color(0xFFFDFAF2))
        .withValues(alpha: 0.94);

    if (isCupertino(context)) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            Expanded(child: navigationShell),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outline),
                ),
              ),
              child: CupertinoTabBar(
                currentIndex: index,
                onTap: _select,
                backgroundColor: barColor,
                activeColor: RiftColors.goldDeep,
                inactiveColor: theme.colorScheme.onSurfaceVariant,
                border: null,
                items: [
                  for (final tab in AppTab.values)
                    BottomNavigationBarItem(
                      icon: Icon(tab.cupertinoIcon),
                      activeIcon: Icon(tab.cupertinoActiveIcon),
                      label: tab.label,
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: theme.colorScheme.outline)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _select,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final tab in AppTab.values)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.activeIcon),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }
}
