import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n.dart';
import 'screens/intro_screen.dart';
import 'services/ad_service.dart';
import 'services/compress_queue.dart';
import 'services/rate_prompt.dart';
import 'services/settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsController.instance.load();
  CompressQueue.instance.percent =
      SettingsController.instance.targetPercent == 0 ? null : SettingsController.instance.targetPercent;
  // Restore the list (e.g. after the app was closed while compressing in the background).
  await CompressQueue.instance.restore();
  runApp(const ShrinklyApp());
  unawaited(AdService.instance.init());
}

class ShrinklyApp extends StatelessWidget {
  const ShrinklyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsController.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: RatePrompt.navKey,
        title: 'Shorts Maker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: SettingsController.instance.themeMode,
        locale: SettingsController.instance.locale,
        supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Arabic devices get Arabic, everything else gets English.
        localeResolutionCallback: (locale, supported) =>
            (locale != null && locale.languageCode == 'ar') ? const Locale('ar') : const Locale('en'),
        builder: (context, child) {
          L.code = Localizations.localeOf(context).languageCode;
          return child ?? const SizedBox.shrink();
        },
        home: const IntroGate(),
      ),
    );
  }
}
