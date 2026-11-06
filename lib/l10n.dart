import 'package:flutter/widgets.dart';

/// Lightweight English / Arabic strings (no code generation needed).
///
/// * In widgets use `context.tr('key')` - it also rebuilds the widget when the language changes.
/// * In services (no BuildContext) use `L.t('key')`.
/// * `{name}` placeholders are filled from the optional params map.
class L {
  L._();

  /// Current language code, kept in sync by the app root (see main.dart).
  static String code = 'en';

  static String t(String key, [Map<String, String>? params]) => tc(code, key, params);

  static String tc(String lang, String key, [Map<String, String>? params]) {
    final table = lang == 'ar' ? _ar : _en;
    var s = table[key] ?? _en[key] ?? key;
    if (params != null) {
      params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    }
    return s;
  }

  static const Map<String, String> _en = <String, String>{
    'app_name': 'Shrinkly',
    'tagline': 'Shrink videos to the size you need',
    'choose_videos': 'Choose videos',
    'add_more': 'Add more',
    'private_note': 'Everything happens on your phone. Nothing is uploaded.',
    'bg_note': 'You can leave the app while it works.',
    'target_title': 'Target size',
    'target_auto': 'Auto (balanced)',
    'target_custom': 'Custom',
    'mb_n': '{n} MB',
    'custom_title': 'Custom size',
    'custom_hint': 'Size in MB',
    'custom_err': 'Enter a number from 1 to 5000',
    'ok': 'OK',
    'cancel': 'Cancel',
    'compress_one': 'Compress video',
    'compress_n': 'Compress {n} videos',
    'compressing': 'Compressing {i} of {n}',
    'stop': 'Stop',
    'st_waiting': 'Waiting',
    'st_skipped': 'Already smaller than the target - not changed',
    'st_failed': 'Could not compress this video',
    'st_cancelled': 'Cancelled',
    'reduced': '{a} → {b}  ·  {p}% smaller',
    'close_miss': 'Closest size reached (the target was too small for this video)',
    'saved_in': 'Saved in your Movies folder',
    'saved_total': 'Saved {s} in total',
    'clear_list': 'Clear list',
    'remove': 'Remove',
    'pick_error': 'Could not open the file picker.',
    'notif_title': 'Shrinkly is compressing your video',
    'settings': 'Settings',
    'language': 'Language',
    'lang_system': 'Device',
    'lang_en': 'English',
    'lang_ar': 'العربية',
    'appearance': 'Appearance',
    'theme_auto': 'Auto',
    'theme_light': 'Light',
    'theme_dark': 'Dark',
    'privacy': 'Privacy',
    'ad_privacy': 'Ad privacy options',
    'privacy_policy': 'Privacy policy',
    'about': 'About',
    'feat1':'Pick the size','feat1_sub':'10, 25, 50, 100 MB or your own number',
    'feat2':'Stays private','feat2_sub':'Nothing leaves your phone',
    'feat3':'Works in background','feat3_sub':'Leave the app while it compresses',
    'low_quality':'Very small target for this video - quality will drop',
    'about_text': 'Shrinkly 1.0.0\nCompress your own videos so they are easy to send and store. Processing happens on your device.',
  };

  static const Map<String, String> _ar = <String, String>{
    'app_name': 'Shrinkly',
    'tagline': 'صغّر حجم الفيديو للمقاس اللي تحتاجه',
    'choose_videos': 'اختر فيديوهات',
    'add_more': 'إضافة المزيد',
    'private_note': 'كل شيء يتم على هاتفك. لا يُرفع أي شيء.',
    'bg_note': 'يمكنك مغادرة التطبيق أثناء العمل.',
    'target_title': 'الحجم المطلوب',
    'target_auto': 'تلقائي (متوازن)',
    'target_custom': 'مخصص',
    'mb_n': '{n} م.ب',
    'custom_title': 'حجم مخصص',
    'custom_hint': 'الحجم بالميجابايت',
    'custom_err': 'أدخل رقمًا من 1 إلى 5000',
    'ok': 'حسنًا',
    'cancel': 'إلغاء',
    'compress_one': 'اضغط الفيديو',
    'compress_n': 'اضغط {n} فيديوهات',
    'compressing': 'جارٍ الضغط {i} من {n}',
    'stop': 'إيقاف',
    'st_waiting': 'في الانتظار',
    'st_skipped': 'حجمه أصغر من المطلوب أصلًا - لم يتغير',
    'st_failed': 'تعذّر ضغط هذا الفيديو',
    'st_cancelled': 'تم الإلغاء',
    'reduced': '{a} ← {b}  ·  أصغر بنسبة {p}%',
    'close_miss': 'أقرب حجم ممكن (الحجم المطلوب صغير جدًا لهذا الفيديو)',
    'saved_in': 'تم الحفظ في مجلد الأفلام',
    'saved_total': 'تم توفير {s} إجمالًا',
    'clear_list': 'مسح القائمة',
    'remove': 'إزالة',
    'pick_error': 'تعذّر فتح منتقي الملفات.',
    'notif_title': 'Shrinkly يضغط الفيديو الخاص بك',
    'settings': 'الإعدادات',
    'language': 'اللغة',
    'lang_system': 'لغة الجهاز',
    'lang_en': 'English',
    'lang_ar': 'العربية',
    'appearance': 'المظهر',
    'theme_auto': 'تلقائي',
    'theme_light': 'فاتح',
    'theme_dark': 'داكن',
    'privacy': 'الخصوصية',
    'ad_privacy': 'خيارات خصوصية الإعلانات',
    'privacy_policy': 'سياسة الخصوصية',
    'about': 'حول التطبيق',
    'feat1':'اختر الحجم','feat1_sub':'10 أو 25 أو 50 أو 100 ميجا أو رقمك',
    'feat2':'خصوصية كاملة','feat2_sub':'لا شيء يغادر هاتفك',
    'feat3':'يعمل في الخلفية','feat3_sub':'اترك التطبيق أثناء الضغط',
    'low_quality':'الحجم المطلوب صغير جدًا لهذا الفيديو - ستنخفض الجودة',
    'about_text': 'Shrinkly 1.0.0\nاضغط فيديوهاتك الخاصة ليسهل إرسالها وتخزينها. تتم المعالجة على جهازك.',
  };
}

extension TrX on BuildContext {
  /// Translates [key] using this context's locale (and subscribes to locale changes).
  String tr(String key, [Map<String, String>? params]) =>
      L.tc(Localizations.localeOf(this).languageCode, key, params);
}
