import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adaptive.dart';

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
    AppTab(
      label: 'Profil',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      cupertinoIcon: CupertinoIcons.person,
      cupertinoActiveIcon: CupertinoIcons.person_fill,
    ),
  ];
}

/// Coque à onglets : barre Cupertino sur iOS, NavigationBar Material ailleurs.
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
    if (isCupertino(context)) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            Expanded(child: navigationShell),
            CupertinoTabBar(
              currentIndex: index,
              onTap: _select,
              items: [
                for (final tab in AppTab.values)
                  BottomNavigationBarItem(
                    icon: Icon(tab.cupertinoIcon),
                    activeIcon: Icon(tab.cupertinoActiveIcon),
                    label: tab.label,
                  ),
              ],
            ),
          ],
        ),
      );
    }
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _select,
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
