import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._();
  static final SettingsController instance = SettingsController._();

  SharedPreferences? _p;

  ThemeMode themeMode = ThemeMode.system;

  /// 'system' | 'en' | 'ar'
  String lang = 'system';

  /// Last chosen custom compression as a percentage of the original (0 = auto).
  int targetPercent = 0;

  bool onboarded = false;

  /// Compress tab resolution: 0 = auto, or 720 / 480 / 360.
  int compressRes = 0;

  /// Rating prompt: number of finished jobs, and the count at which to ask next (-1 = never).
  int successes = 0;
  int rateAt = 3;

  /// Until when (ms since epoch) the watermark is switched off after a rewarded ad.
  int watermarkFreeUntil = 0;

  bool get watermarkFree => DateTime.now().millisecondsSinceEpoch < watermarkFreeUntil;

  /// null = follow the device language.
  Locale? get locale => lang == 'system' ? null : Locale(lang);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    final t = p.getInt('theme') ?? 0;
    themeMode = ThemeMode.values[t.clamp(0, ThemeMode.values.length - 1).toInt()];
    final l = p.getString('lang') ?? 'system';
    lang = (l == 'en' || l == 'ar') ? l : 'system';
    onboarded = p.getBool('onboarded') ?? false;
    final cr = p.getInt('compressRes') ?? 0;
    compressRes = (cr == 720 || cr == 480 || cr == 360) ? cr : 0;
    successes = p.getInt('successes') ?? 0;
    rateAt = p.getInt('rateAt') ?? 3;
    watermarkFreeUntil = p.getInt('wmUntil') ?? 0;
    targetPercent = (p.getInt('targetPercent') ?? 0).clamp(0, 90).toInt();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _p?.setInt('theme', m.index);
  }

  Future<void> setLang(String v) async {
    lang = v;
    notifyListeners();
    await _p?.setString('lang', v);
  }

  Future<void> grantWatermarkFree(int hours) async {
    watermarkFreeUntil = DateTime.now().add(Duration(hours: hours)).millisecondsSinceEpoch;
    await _p?.setInt('wmUntil', watermarkFreeUntil);
  }

  Future<void> saveRating() async {
    await _p?.setInt('successes', successes);
    await _p?.setInt('rateAt', rateAt);
  }

  Future<void> setCompressRes(int v) async {
    compressRes = v;
    await _p?.setInt('compressRes', v);
  }

  Future<void> setOnboarded() async {
    onboarded = true;
    await _p?.setBool('onboarded', true);
  }

  Future<void> setTargetPercent(int v) async {
    targetPercent = v.clamp(0, 90).toInt();
    await _p?.setInt('targetPercent', targetPercent);
  }
}
