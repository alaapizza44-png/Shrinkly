import 'dart:async';

import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n.dart';
import '../theme.dart';
import 'native_bridge.dart';
import 'settings.dart';

/// Optional "rate us" card shown after a few successful jobs.
/// "Later" asks again after 5 more jobs; "Rate" or "No thanks" never asks again.
class RatePrompt {
  RatePrompt._();

  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();
  static bool _showing = false;

  /// Call after every successfully finished export / compression.
  static void onSuccess() {
    if (AppInfo.storeUrl.isEmpty) return; // not published in a store yet
    final s = SettingsController.instance;
    s.successes++;
    s.saveRating();
    if (s.rateAt < 0 || s.successes < s.rateAt) return;
    // Let the result (and a possible ad) settle first.
    Future<void>.delayed(const Duration(seconds: 3), _show);
  }

  static Future<void> _show() async {
    final ctx = navKey.currentContext;
    if (ctx == null || _showing) return;
    final s = SettingsController.instance;
    if (s.rateAt < 0 || s.successes < s.rateAt) return;
    _showing = true;
    final r = await showModalBottomSheet<String>(
      context: ctx,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(gradient: AppTheme.hero, shape: BoxShape.circle),
              child: const Icon(Icons.star_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 14),
            Text(c.tr('rate_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(c.tr('rate_sub'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(c).colorScheme.onSurfaceVariant, height: 1.4)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(c, 'rate'),
                child: Text(c.tr('rate_yes')),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                TextButton(onPressed: () => Navigator.pop(c, 'later'), child: Text(c.tr('rate_later'))),
                TextButton(onPressed: () => Navigator.pop(c, 'no'), child: Text(c.tr('rate_no'))),
              ],
            ),
          ],
        ),
      ),
    );
    _showing = false;
    if (r == 'rate') {
      s.rateAt = -1;
      await NativeBridge.openStore();
    } else if (r == 'no') {
      s.rateAt = -1;
    } else {
      // Later, or the sheet was dismissed.
      s.rateAt = s.successes + 5;
    }
    await s.saveRating();
  }
}
