import 'package:flutter/material.dart';

import '../app_state.dart';
import 'home_screen.dart';
import 'rezepte_screen.dart';

/// Hauptansicht mit den Reitern „Einkaufsliste“ und „Rezepte“.
class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.state});
  final AppState state;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        HomeScreen(state: widget.state),
        RezepteScreen(state: widget.state),
      ]),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'Einkaufsliste'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Rezepte'),
        ],
      ),
    );
  }
}
