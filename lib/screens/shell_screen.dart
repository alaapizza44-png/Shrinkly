import 'package:flutter/material.dart';

import '../features/shorts/shorts_screen.dart';
import '../l10n.dart';
import 'home_screen.dart';

/// Bottom navigation: Shorts (main) and Compress.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[ShortsScreen(), HomeScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.smartphone_outlined),
            selectedIcon: const Icon(Icons.smartphone_rounded),
            label: context.tr('tab_shorts'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.compress_outlined),
            selectedIcon: const Icon(Icons.compress_rounded),
            label: context.tr('tab_compress'),
          ),
        ],
      ),
    );
  }
}
