import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/settings.dart';
import '../theme.dart';
import 'offline_gate.dart';
import 'shell_screen.dart';

/// Animated splash, then (first launch only) a short onboarding, then the app.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key});

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool _splash = true;
  bool _onboarding = !SettingsController.instance.onboarded;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _splash = false);
    });
  }

  void _finish() {
    SettingsController.instance.setOnboarded();
    setState(() => _onboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _splash
          ? const _Splash(key: ValueKey<int>(0))
          : (_onboarding
              ? _Onboarding(key: const ValueKey<int>(1), onDone: _finish)
              : const OfflineGate(key: ValueKey<int>(2), child: ShellScreen())),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.hero),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, v, child) => Opacity(
              opacity: v.clamp(0.0, 1.0).toDouble(),
              child: Transform.scale(scale: v, child: child),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 66),
                ),
                const SizedBox(height: 18),
                Text(context.tr('app_name'),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(context.tr('tagline'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Page {
  const _Page(this.icon, this.title, this.sub);
  final IconData icon;
  final String title;
  final String sub;
}

class _Onboarding extends StatefulWidget {
  const _Onboarding({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<_Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<_Onboarding> {
  final PageController _pc = PageController();
  int _i = 0;

  static const List<_Page> _pages = <_Page>[
    _Page(Icons.smartphone_rounded, 'ob1_t', 'ob1_s'),
    _Page(Icons.touch_app_rounded, 'ob2_t', 'ob2_s'),
    _Page(Icons.compress_rounded, 'ob3_t', 'ob3_s'),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final last = _i == _pages.length - 1;
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -90,
            right: -70,
            child: _Blob(color: AppTheme.bright.withValues(alpha: 0.22), size: 260),
          ),
          Positioned(
            bottom: -110,
            left: -80,
            child: _Blob(color: AppTheme.teal.withValues(alpha: 0.22), size: 300),
          ),
          SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: widget.onDone,
                child: Text(context.tr('ob_skip')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                onPageChanged: (i) => setState(() => _i = i),
                children: <Widget>[
                  for (final p in _pages)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _Illustration(index: _pages.indexOf(p)),
                          const SizedBox(height: 36),
                          Text(context.tr(p.title),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 12),
                          Text(context.tr(p.sub),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 15.5, height: 1.45, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var d = 0; d < _pages.length; d++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: d == _i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: d == _i ? cs.primary : cs.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () {
                    if (last) {
                      widget.onDone();
                    } else {
                      _pc.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    }
                  },
                  child: Text(context.tr(last ? 'ob_start' : 'ob_next'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: <Color>[color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

/// Small drawn illustrations for the three onboarding pages.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.index});

  final int index;

  Widget _phone({required Widget child}) {
    return Container(
      width: 120,
      height: 214,
      decoration: BoxDecoration(
        gradient: AppTheme.hero,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
        boxShadow: <BoxShadow>[
          BoxShadow(color: AppTheme.teal.withValues(alpha: 0.4), blurRadius: 34, offset: const Offset(0, 16)),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget art;
    if (index == 0) {
      art = _phone(
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 58),
            Positioned(
              bottom: 26,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Aa',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    } else if (index == 1) {
      art = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _phone(
            child: const Center(child: Icon(Icons.touch_app_rounded, color: Colors.white, size: 54)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 190,
            height: 22,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Positioned(
                  left: 48,
                  right: 40,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(gradient: AppTheme.hero, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                Positioned(left: 40, child: _handle()),
                Positioned(right: 32, child: _handle()),
              ],
            ),
          ),
        ],
      );
    } else {
      Widget bar(double w, Color c, String t) => Container(
            width: w,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
            child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          );
      art = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          bar(200, cs.onSurfaceVariant.withValues(alpha: 0.55), '350 MB'),
          const SizedBox(height: 10),
          Icon(Icons.keyboard_double_arrow_down_rounded, color: cs.primary, size: 36),
          const SizedBox(height: 10),
          Container(
            width: 70,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(gradient: AppTheme.hero, borderRadius: BorderRadius.circular(14)),
            child: const Text('45 MB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      );
    }
    return SizedBox(height: 270, child: Center(child: art));
  }

  Widget _handle() => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.teal, width: 3),
        ),
      );
}
