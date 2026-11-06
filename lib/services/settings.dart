import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._();
  static final SettingsController instance = SettingsController._();

  SharedPreferences? _p;

  ThemeMode themeMode = ThemeMode.system;

  /// 'system' | 'en' | 'ar'
  String lang = 'system';

  /// Last chosen target size in MB (0 = auto).
  int targetMb = 25;

  /// null = follow the device language.
  Locale? get locale => lang == 'system' ? null : Locale(lang);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    final t = p.getInt('theme') ?? 0;
    themeMode = ThemeMode.values[t.clamp(0, ThemeMode.values.length - 1).toInt()];
    final l = p.getString('lang') ?? 'system';
    lang = (l == 'en' || l == 'ar') ? l : 'system';
    targetMb = (p.getInt('targetMb') ?? 25).clamp(0, 5000).toInt();
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

  Future<void> setTargetMb(int v) async {
    targetMb = v.clamp(0, 5000).toInt();
    await _p?.setInt('targetMb', targetMb);
  }
}
