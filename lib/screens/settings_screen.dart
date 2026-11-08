import 'dart:io';

import 'package:flutter/material.dart';

import '../config.dart';
import '../l10n.dart';
import '../features/shorts/shorts_controller.dart';
import '../services/ad_service.dart';
import '../services/compress_queue.dart';
import '../services/native_bridge.dart';
import '../services/settings.dart';
import 'privacy_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: ListenableBuilder(
        listenable: SettingsController.instance,
        builder: (context, _) {
          final s = SettingsController.instance;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: <Widget>[
              _Header(context.tr('language')),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: <ButtonSegment<String>>[
                    ButtonSegment<String>(value: 'system', label: Text(context.tr('lang_system'))),
                    ButtonSegment<String>(value: 'en', label: Text(context.tr('lang_en'))),
                    ButtonSegment<String>(value: 'ar', label: Text(context.tr('lang_ar'))),
                  ],
                  selected: <String>{s.lang},
                  onSelectionChanged: (v) => s.setLang(v.first),
                ),
              ),
              const SizedBox(height: 20),
              _Header(context.tr('appearance')),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: const Icon(Icons.brightness_auto_rounded),
                        label: Text(context.tr('theme_auto'))),
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: const Icon(Icons.light_mode_rounded),
                        label: Text(context.tr('theme_light'))),
                    ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: const Icon(Icons.dark_mode_rounded),
                        label: Text(context.tr('theme_dark'))),
                  ],
                  selected: <ThemeMode>{s.themeMode},
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                ),
              ),
              const SizedBox(height: 20),
              _Header(context.tr('privacy')),
              FutureBuilder<bool>(
                future: AdService.instance.privacyOptionsRequired(),
                builder: (context, snap) {
                  if (snap.data != true) return const SizedBox.shrink();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: Text(context.tr('ad_privacy')),
                    onTap: AdService.instance.showPrivacyOptions,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.policy_outlined),
                title: Text(context.tr('privacy_policy')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
                ),
              ),
              _Header(context.tr('support')),
              if (AppInfo.storeUrl.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star_outline_rounded),
                  title: Text(context.tr('rate_app')),
                  onTap: NativeBridge.openStore,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_outlined),
                title: Text(context.tr('share_app')),
                onTap: () => NativeBridge.shareApp(context.tr('share_text')),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cleaning_services_outlined),
                title: Text(context.tr('clear_cache')),
                subtitle: Text(context.tr('clear_cache_sub')),
                onTap: () => _clearCache(context),
              ),
              _Header(context.tr('about')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    context.tr('about_text'),
                    style: TextStyle(color: cs.onSurfaceVariant, height: 1.45),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<void> _clearCache(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  if (CompressQueue.instance.jobs.isNotEmpty ||
      CompressQueue.instance.running ||
      ShortsController.instance.exporting) {
    messenger.showSnackBar(SnackBar(content: Text(L.t('clear_cache_busy'))));
    return;
  }
  var freed = 0;
  try {
    await for (final e in Directory.systemTemp.list()) {
      try {
        if (e is File) {
          freed += await e.length();
          await e.delete();
        } else if (e is Directory) {
          await for (final f in e.list(recursive: true)) {
            if (f is File) freed += await f.length();
          }
          await e.delete(recursive: true);
        }
      } catch (_) {}
    }
  } catch (_) {}
  messenger.showSnackBar(SnackBar(
      content: Text(L.t('clear_cache_done', <String, String>{'s': fmtBytes(freed)}))));
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.4)),
    );
  }
}
