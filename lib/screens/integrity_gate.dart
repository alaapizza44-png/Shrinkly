import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n.dart';
import '../services/native_bridge.dart';
import '../theme.dart';

/// Blocks copies of the app that were re-signed with another key (modified / repackaged).
///
/// It only does anything when the build was given the official certificate fingerprints
/// (--dart-define=APP_SIGS=...). Without them, or if the signature cannot be read, the app runs
/// normally, so a legitimate user is never locked out by mistake.
class IntegrityGate extends StatefulWidget {
  const IntegrityGate({super.key, required this.child});

  final Widget child;

  static const String _expected = String.fromEnvironment('APP_SIGS');

  @override
  State<IntegrityGate> createState() => _IntegrityGateState();
}

class _IntegrityGateState extends State<IntegrityGate> {
  bool _tampered = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final allowed = IntegrityGate._expected
        .split(',')
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    if (allowed.isEmpty) return;
    final mine = await NativeBridge.signatures();
    if (mine == null || mine.isEmpty) return; // unknown: do not block
    if (!mine.any(allowed.contains) && mounted) setState(() => _tampered = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_tampered) return widget.child;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(gradient: AppTheme.hero, shape: BoxShape.circle),
                  child: const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 54),
                ),
                const SizedBox(height: 26),
                Text(context.tr('tamper_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(context.tr('tamper_sub'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.45, fontSize: 15)),
                if (AppInfo.storeUrl.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 26),
                  FilledButton.icon(
                    onPressed: NativeBridge.openStore,
                    icon: const Icon(Icons.shop_rounded),
                    label: Text(context.tr('tamper_btn')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
