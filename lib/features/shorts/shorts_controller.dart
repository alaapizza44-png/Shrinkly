import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../services/native_bridge.dart';
import 'text_overlay.dart';

enum ShortsMode { fill, fit }

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
  ShortsMode mode = ShortsMode.fill;

  /// 0 = one clip; otherwise the length of each clip in seconds.
  int partSeconds = 0;

  /// Output quality: 720, 480 or 360 (the shorter side of the 9:16 picture).
  int quality = 720;
  String text = '';

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

  int get outWidth => quality;
  int get outHeight => quality == 720 ? 1280 : (quality == 480 ? 848 : 640);
  int get bitrate => quality == 720 ? 5000000 : (quality == 480 ? 2800000 : 1600000);

  /// How many clips the current settings will produce.
  int get plannedParts => _starts().length;

  List<int> _starts() {
    final total = selectedMs;
    if (total < 1000) return <int>[];
    final partMs = partSeconds <= 0 ? total : partSeconds * 1000;
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

  void setMode(ShortsMode m) {
    mode = m;
    notifyListeners();
  }

  void setPartSeconds(int s) {
    partSeconds = s;
    notifyListeners();
  }

  void setQuality(int q) {
    quality = q;
    notifyListeners();
  }

  void setText(String t) {
    text = t;
  }

  Future<void> pick() async {
    if (exporting || picking) return;
    picking = true;
    notifyListeners();
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.video);
      final p = (r == null || r.files.isEmpty) ? null : r.files.first.path;
      if (p == null) return;
      path = p;
      name = p.split('/').last;
      info = null;
      thumb = null;
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
      overlay = await TextOverlay.render(text, outWidth, outHeight);
      final partMs = partSeconds <= 0 ? selectedMs : partSeconds * 1000;
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
          fill: mode == ShortsMode.fill,
          width: outWidth,
          height: outHeight,
          bitrate: bitrate,
          outName: 'Short_${stamp}_${i + 1}.mp4',
          overlayPath: overlay,
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
