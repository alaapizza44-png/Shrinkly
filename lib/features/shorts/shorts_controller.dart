import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../l10n.dart';
import '../../services/ad_service.dart';
import '../../services/native_bridge.dart';
import '../../services/rate_prompt.dart';
import '../../services/settings.dart';
import 'text_overlay.dart';

enum ShortsPhase { idle, exporting, done, error }

/// State and logic of the Shorts tab (no widgets in here).
class ShortsController extends ChangeNotifier {
  ShortsController._();
  static final ShortsController instance = ShortsController._();

  // --- the chosen video
  String? path;
  String name = '';
  VideoInfo? info;
  Uint8List? thumb;
  bool picking = false;

  // --- options
  int startMs = 0;
  int endMs = 0;

  /// Where the 9:16 window sits inside the source picture, 0..1 (along the axis that has spare
  /// picture: left-right for a normal horizontal video).
  double pan = 0.5;

  /// 0 = one clip; otherwise the length of each clip in seconds.
  int partSeconds = 0;

  /// Output quality: 0 = Auto (as sharp as the source allows), or 720 / 480 / 360 (the width of
  /// the 9:16 picture). The picture is never enlarged beyond the real source pixels.
  int quality = 0;

  /// Playback speed of the clip: 0.5, 1, 1.5 or 2.
  double speed = 1.0;
  String text = '';

  /// Caption centre (fractions of the frame) and size (fraction of the frame width).
  double textX = 0.5;
  double textY = 0.78;
  double textSize = TextOverlay.defaultSize;

  // --- progress
  ShortsPhase phase = ShortsPhase.idle;
  double progress = 0;
  int part = 0;
  int parts = 0;
  int savedCount = 0;
  String? error;
  bool _cancel = false;

  bool get exporting => phase == ShortsPhase.exporting;
  int get durationMs => info?.durationMs ?? 0;
  int get selectedMs => math.max(0, endMs - startMs);

  /// Length of the result after the speed change.
  int get outputMs => (selectedMs / speed).round();

  // ---- crop window geometry (fractions of the source picture)
  static const double _aspect = 9 / 16;

  double get _srcAspect {
    final i = info;
    if (i == null || i.width <= 0 || i.height <= 0) return 16 / 9;
    return i.width / i.height;
  }

  /// True when the source is wider than 9:16, so the window slides left-right.
  bool get panHorizontal => _srcAspect >= _aspect;

  /// Window size as a fraction of the source width / height.
  double get cropWFrac => panHorizontal ? math.min(1.0, _aspect / _srcAspect) : 1.0;
  double get cropHFrac => panHorizontal ? 1.0 : math.min(1.0, _srcAspect / _aspect);

  double get cropLeft => panHorizontal ? pan * (1 - cropWFrac) : 0.0;
  double get cropTop => panHorizontal ? 0.0 : pan * (1 - cropHFrac);

  /// Real source pixels inside the window.
  double get _cropPxH => (info?.height ?? 0) * cropHFrac;

  static int _even(num v) {
    final i = v.floor();
    return math.max(2, i - (i % 2));
  }

  int get outHeight {
    final want = quality == 720 ? 1280 : (quality == 480 ? 848 : (quality == 360 ? 640 : 1280));
    final src = _cropPxH;
    return _even(src > 0 ? math.min(want.toDouble(), src) : want);
  }

  int get outWidth => _even(outHeight * _aspect);

  int get bitrate {
    final f = (info?.fps ?? 0) <= 0 ? 30.0 : (info!.fps).clamp(24.0, 60.0).toDouble();
    final bps = outWidth * outHeight * f * 0.11;
    return bps.clamp(600000.0, 9000000.0).round();
  }

  /// How many clips the current settings will produce.
  int get plannedParts => _starts().length;

  List<int> _starts() {
    final total = selectedMs;
    if (total < 1000) return <int>[];
    final partMs = partSeconds <= 0 ? total : (partSeconds * 1000 * speed).round();
    final out = <int>[];
    for (var s = startMs; s < endMs; s += partMs) {
      if (endMs - s >= 1000) out.add(s);
    }
    return out;
  }

  void setRange(int start, int end) {
    startMs = start;
    endMs = end;
    notifyListeners();
  }

  /// Rebuild listeners (e.g. after the watermark setting changed).
  void refresh() => notifyListeners();

  void setPan(double v) {
    pan = v.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  void setTextPos(double x, double y) {
    textX = x.clamp(0.0, 1.0).toDouble();
    textY = y.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  void setTextSize(double v) {
    textSize = v.clamp(0.035, 0.12).toDouble();
    notifyListeners();
  }

  void setPartSeconds(int s) {
    partSeconds = s;
    notifyListeners();
  }

  void setSpeed(double v) {
    speed = v;
    notifyListeners();
  }

  void setQuality(int q) {
    quality = q;
    notifyListeners();
  }

  void setText(String t) {
    text = t;
    notifyListeners();
  }

  Future<void> pick() async {
    if (exporting || picking) return;
    picking = true;
    notifyListeners();
    try {
      final r = await NativeBridge.pickVideo();
      if (r == null) return;
      final p = r.uri;
      path = p;
      name = r.name;
      info = null;
      thumb = null;
      pan = 0.5;
      phase = ShortsPhase.idle;
      savedCount = 0;
      error = null;
      notifyListeners();
      info = await NativeBridge.info(p);
      startMs = 0;
      endMs = info?.durationMs ?? 0;
      notifyListeners();
      thumb = await NativeBridge.thumb(p);
    } catch (e) {
      debugPrint('pick failed: $e');
    } finally {
      picking = false;
      notifyListeners();
    }
  }

  Future<void> cancel() async {
    _cancel = true;
    await NativeBridge.cancelExport();
  }

  Future<void> export() async {
    final p = path;
    if (p == null || exporting) return;
    final starts = _starts();
    if (starts.isEmpty) return;

    try {
      await Permission.notification.request();
    } catch (_) {}
    _cancel = false;
    phase = ShortsPhase.exporting;
    progress = 0;
    part = 0;
    parts = starts.length;
    savedCount = 0;
    error = null;
    notifyListeners();

    String? overlay;
    final timer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
      if (!exporting) return;
      progress = await NativeBridge.exportProgress();
      notifyListeners();
    });
    try {
      overlay = await TextOverlay.render(text, outWidth, outHeight, textX, textY, textSize,
          watermark: !SettingsController.instance.watermarkFree);
      final partMs = partSeconds <= 0 ? selectedMs : (partSeconds * 1000 * speed).round();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      for (var i = 0; i < starts.length; i++) {
        if (_cancel) break;
        part = i + 1;
        progress = 0;
        notifyListeners();
        final s = starts[i];
        final r = await NativeBridge.exportShort(
          path: p,
          startMs: s,
          endMs: math.min(endMs, s + partMs),
          cropL: cropLeft,
          cropT: cropTop,
          cropR: cropLeft + cropWFrac,
          cropB: cropTop + cropHFrac,
          width: outWidth,
          height: outHeight,
          bitrate: bitrate,
          outName: 'Short_${stamp}_${i + 1}.mp4',
          overlayPath: overlay,
          speed: speed,
        );
        if (r.cancelled) break;
        if (!r.ok) {
          error = r.message ?? 'error';
          phase = ShortsPhase.error;
          return;
        }
        savedCount++;
      }
      phase = savedCount > 0 ? ShortsPhase.done : ShortsPhase.idle;
      if (savedCount > 0 && !_cancel) {
        AdService.instance.onJobFinished();
        RatePrompt.onSuccess();
        unawaited(NativeBridge.notifyDone(
            L.t('export_notif_title'), L.t('export_done', <String, String>{'n': '$savedCount'})));
      }
    } catch (e) {
      error = e.toString();
      phase = ShortsPhase.error;
    } finally {
      timer.cancel();
      if (overlay != null) {
        try {
          await File(overlay).delete();
        } catch (_) {}
      }
      notifyListeners();
    }
  }
}
