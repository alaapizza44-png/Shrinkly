/// Ad configuration. A GitHub secret passed via --dart-define overrides the built-in IDs.
class AdConfig {
  AdConfig._();

  static const String _banner = String.fromEnvironment('ADMOB_BANNER_ID');
  static const String _interstitial = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');

  static const String _rewarded = String.fromEnvironment('ADMOB_REWARDED_ID');

  static String get rewardedId =>
      _rewarded.isNotEmpty ? _rewarded : 'ca-app-pub-3442559127752747/3352192610';

  /// How long the watermark stays off after watching a rewarded ad.
  static const int watermarkFreeHours = 24;

  static String get bannerId =>
      _banner.isNotEmpty ? _banner : 'ca-app-pub-3940256099942544/6300978111';

  static String get interstitialId =>
      _interstitial.isNotEmpty ? _interstitial : 'ca-app-pub-3442559127752747/8745934180';

  /// Show an interstitial after every N-th finished compression job ...
  static const int interstitialEveryNJobs = 2;

  /// ... but never more often than this (seconds).
  static const int interstitialMinGapSeconds = 120;
}

/// Shown in the in-app privacy policy.
/// TODO: replace with your real contact e-mail before publishing (also in docs/privacy.html).
class AppInfo {
  AppInfo._();

  /// Link to the app's page in the store it is published on (for "Rate" / "Share" and the
  /// rating prompt). Leave empty until the app is live: the rating prompt and the Rate button are
  /// hidden while it is empty. Example (Google Play):
  /// https://play.google.com/store/apps/details?id=com.shrinkly.shrinkly
  static const String storeUrl = String.fromEnvironment('STORE_URL');

  static const String _email = String.fromEnvironment('CONTACT_EMAIL');

  /// Set the repository VARIABLE CONTACT_EMAIL (Settings > Secrets and variables > Actions >
  /// Variables) and it is used here and on the privacy policy page automatically.
  static String get contactEmail => _email.isNotEmpty ? _email : 'YOUR_EMAIL@example.com';
  static const String policyDate = 'November 6, 2026';
}
