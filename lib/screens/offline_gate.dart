import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../features/shorts/shorts_controller.dart';
import '../l10n.dart';
import '../services/compress_queue.dart';
import '../theme.dart';

/// Shows the app only while the phone has internet (the app is supported by ads).
/// Never interrupts a running export / compression: it only blocks when the app is idle.
class OfflineGate extends StatefulWidget {
  const OfflineGate({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineGate> createState() => _OfflineGateState();
}

class _OfflineGateState extends State<OfflineGate> with WidgetsBindingObserver {
  bool _online = true;
  bool _checking = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  bool get _busy => ShortsController.instance.exporting || CompressQueue.instance.running;

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    var ok = false;
    try {
      final r = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      ok = r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      ok = false;
    }
    _checking = false;
    if (mounted && ok != _online) setState(() => _online = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_online || _busy) return widget.child;
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
                  child: const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 54),
                ),
                const SizedBox(height: 26),
                Text(context.tr('offline_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Text(context.tr('offline_sub'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.45, fontSize: 15)),
                const SizedBox(height: 26),
                FilledButton.icon(
                  onPressed: _check,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(context.tr('offline_retry')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
