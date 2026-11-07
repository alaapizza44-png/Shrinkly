import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';

/// Owns the Mobile Ads SDK: consent (GDPR/UMP), initialisation and the interstitial.
///
/// Revenue design (deliberately gentle):
///  * one small banner at the bottom of the home screen,
///  * an interstitial after every Nth FINISHED compression (frequency-capped by time),
///    never while a job is running.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  bool _initStarted = false;
  bool _ready = false;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  RewardedAd? _rewarded;
  bool _loadingRewarded = false;
  int _jobsFinished = 0;
  DateTime _lastShown = DateTime.fromMillisecondsSinceEpoch(0);

  /// Widgets listen to this so they can request their ad once the SDK is initialised.
  final ValueNotifier<bool> readyNotifier = ValueNotifier<bool>(false);

  bool get ready => _ready;

  bool get supported => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (_initStarted || !supported) return;
    _initStarted = true;
    try {
      await _gatherConsent();
      await MobileAds.instance.initialize();
      _ready = true;
      readyNotifier.value = true;
      _loadInterstitial();
      _loadRewarded();
    } catch (e) {
      debugPrint('AdService.init failed: $e');
    }
  }

  /// Google UMP consent flow. Required to serve ads to users in the EEA / UK.
  /// It only shows a form if you created a consent message in AdMob > Privacy & messaging.
  Future<void> _gatherConsent() async {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((FormError? _) => finish());
        } catch (_) {
          finish();
        }
      },
      (FormError _) => finish(),
    );
    await done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  Future<bool> privacyOptionsRequired() async {
    try {
      final s = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return s == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? _) {});
    } catch (_) {}
  }

  void _loadInterstitial() {
    if (!_ready || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (err) {
          _loadingInterstitial = false;
          debugPrint('Interstitial failed: ${err.message}');
        },
      ),
    );
  }

  void _loadRewarded() {
    if (!_ready || _loadingRewarded || _rewarded != null) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: AdConfig.rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (err) {
          _loadingRewarded = false;
          debugPrint('Rewarded failed: ${err.message}');
        },
      ),
    );
  }

  /// Shows a rewarded ad. Completes with true only if the user watched it and earned the reward.
  /// Completes with false when no ad is available (the caller must NOT grant the reward then).
  Future<bool> showRewarded() async {
    if (!_ready) return false;
    var ad = _rewarded;
    if (ad == null) {
      _loadRewarded();
      // Give a just-started load a few seconds to finish.
      for (var i = 0; i < 8 && _rewarded == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      ad = _rewarded;
      if (ad == null) return false;
    }
    _rewarded = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        a.dispose();
        _loadRewarded();
        if (!done.isCompleted) done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return done.future;
  }

  /// Call when a compression batch has finished successfully.
  void onJobFinished() {
    _jobsFinished++;
    if (_jobsFinished % AdConfig.interstitialEveryNJobs != 0) return;
    if (DateTime.now().difference(_lastShown).inSeconds < AdConfig.interstitialMinGapSeconds) {
      return;
    }
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    _lastShown = DateTime.now();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, err) {
        a.dispose();
        _loadInterstitial();
      },
    );
    // Small delay so the result list has been drawn first.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      ad.show();
    });
  }
}
