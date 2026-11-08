import 'package:flutter/material.dart';

import '../features/shorts/shorts_screen.dart';
import '../l10n.dart';
import 'home_screen.dart';
import 'works_screen.dart';

/// Bottom navigation: Shorts (main) and Compress.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  /// Switch tab from anywhere (0 Shorts, 1 Compress, 2 My clips).
  static final ValueNotifier<int> tab = ValueNotifier<int>(0);

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    ShellScreen.tab.addListener(_onTab);
  }

  @override
  void dispose() {
    ShellScreen.tab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (ShellScreen.tab.value != _index) {
      setState(() => _index = ShellScreen.tab.value);
      if (_index == 2) WorksScreen.refresh.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[ShortsScreen(), HomeScreen(), WorksScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          ShellScreen.tab.value = i;
          if (i == 2) WorksScreen.refresh.value++;
        },
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
          NavigationDestination(
            icon: const Icon(Icons.video_library_outlined),
            selectedIcon: const Icon(Icons.video_library_rounded),
            label: context.tr('tab_works'),
          ),
        ],
      ),
    );
  }
}
