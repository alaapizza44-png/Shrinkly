/// Ad configuration. IDs come from GitHub secrets via --dart-define; without them Google's
/// official TEST ad units are used, so you can never click your own live ads while testing.
class AdConfig {
  AdConfig._();

  static const String _banner = String.fromEnvironment('ADMOB_BANNER_ID');
  static const String _interstitial = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');

  static const String _rewarded = String.fromEnvironment('ADMOB_REWARDED_ID');

  static String get rewardedId =>
      _rewarded.isNotEmpty ? _rewarded : 'ca-app-pub-3940256099942544/5224354917';

  /// How long the watermark stays off after watching a rewarded ad.
  static const int watermarkFreeHours = 24;

  static String get bannerId =>
      _banner.isNotEmpty ? _banner : 'ca-app-pub-3940256099942544/6300978111';

  static String get interstitialId =>
      _interstitial.isNotEmpty ? _interstitial : 'ca-app-pub-3940256099942544/1033173712';

  /// Show an interstitial after every N-th finished compression job ...
  static const int interstitialEveryNJobs = 2;

  /// ... but never more often than this (seconds).
  static const int interstitialMinGapSeconds = 120;
}

/// Shown in the in-app privacy policy.
/// TODO: replace with your real contact e-mail before publishing (also in docs/privacy.html).
class AppInfo {
  AppInfo._();

  static const String contactEmail = 'YOUR_EMAIL@example.com';
  static const String policyDate = 'November 6, 2026';
}
