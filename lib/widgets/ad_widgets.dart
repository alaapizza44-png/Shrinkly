import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config.dart';
import '../services/ad_service.dart';

/// Standard 320x50 banner. Collapses to nothing until an ad has actually loaded,
/// so there is never an empty gap. (AdSize.banner is used because it is stable
/// across all supported google_mobile_ads versions.)
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    if (!AdService.instance.supported) return;
    AdService.instance.readyNotifier.addListener(_maybeLoad);
    _maybeLoad();
  }

  void _maybeLoad() {
    if (!mounted || !AdService.instance.ready || _ad != null) return;
    final ad = BannerAd(
      adUnitId: AdConfig.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (failed, error) {
          failed.dispose();
          _ad = null;
          if (mounted && _attempts < 3) {
            _attempts++;
            Future<void>.delayed(Duration(seconds: 20 * _attempts), _maybeLoad);
          }
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    AdService.instance.readyNotifier.removeListener(_maybeLoad);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: ad.size.height.toDouble(),
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
