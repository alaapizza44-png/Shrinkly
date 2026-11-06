import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:light_compressor_v2/light_compressor_v2.dart';
import 'package:permission_handler/permission_handler.dart';

import '../l10n.dart';
import 'ad_service.dart';
import 'native_bridge.dart';

enum JobState { waiting, running, done, skipped, failed, cancelled }

class Job {
  Job(this.path, this.originalBytes);

  final String path;
  final int originalBytes;
  JobState state = JobState.waiting;
  double progress = 0;
  int outBytes = 0;
  bool targetMissed = false;

  /// Filled in shortly after the video is added (duration, size, thumbnail).
  VideoInfo? info;
  Uint8List? thumb;

  /// Video bitrate (bits/s) needed to land near [targetMb]; null if the duration is unknown.
  double? plannedVideoBps(int targetMb) {
    final i = info;
    if (i == null || i.durationMs <= 0) return null;
    final seconds = i.durationMs / 1000.0;
    final totalBits = targetMb * 8.0 * 1024 * 1024 * 0.93; // small safety margin
    var v = totalBits / seconds - 160000; // leave room for the audio track
    if (i.bitrate > 0 && v > i.bitrate * 0.9) v = i.bitrate * 0.9;
    return v < 150000 ? 150000 : v;
  }

  /// Bits per pixel per frame the plan would give (H.264 looks poor below roughly 0.04).
  double? plannedDensity(int targetMb) {
    final i = info;
    final v = plannedVideoBps(targetMb);
    if (i == null || v == null || i.width <= 0 || i.height <= 0) return null;
    final fps = i.fps > 0 ? i.fps : 30.0;
    return v / (i.width * i.height * fps);
  }

  bool lowQuality(int targetMb) => (plannedDensity(targetMb) ?? 1) < 0.04;

  String get name => path.split('/').last;

  bool get pending =>
      state == JobState.waiting || state == JobState.failed || state == JobState.cancelled;

  /// 0-100, how much smaller the result is.
  int get savedPercent {
    if (originalBytes <= 0 || outBytes <= 0) return 0;
    return ((1 - outBytes / originalBytes) * 100).round().clamp(0, 99).toInt();
  }
}

String fmtBytes(num b) {
  if (b < 1024) return '${b.toInt()} B';
  const units = <String>['KB', 'MB', 'GB', 'TB'];
  var v = b / 1024.0;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// Holds the list of videos and compresses them one after another.
class CompressQueue extends ChangeNotifier {
  CompressQueue._();
  static final CompressQueue instance = CompressQueue._();

  final List<Job> jobs = <Job>[];

  /// Target size in MB, or null for "auto" (balanced quality).
  int? targetMb = 25;

  bool running = false;
  bool _cancel = false;
  Job? _current;

  int get pendingCount => jobs.where((j) => j.pending).length;

  int get runningIndex => jobs.indexWhere((j) => j.state == JobState.running) + 1;

  int get savedBytes => jobs
      .where((j) => j.state == JobState.done)
      .fold<int>(0, (a, j) => a + (j.originalBytes - j.outBytes).clamp(0, j.originalBytes).toInt());

  bool get anyDone => jobs.any((j) => j.state == JobState.done);

  void setTarget(int? mb) {
    targetMb = mb;
    notifyListeners();
  }

  /// Opens the system picker. Returns false if nothing was added.
  Future<bool> pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video, allowMultiple: true);
    if (r == null) return false;
    var added = false;
    for (final f in r.files) {
      final p = f.path;
      if (p == null || jobs.any((j) => j.path == p)) continue;
      final job = Job(p, f.size);
      jobs.add(job);
      unawaited(_enrich(job));
      added = true;
    }
    if (added) notifyListeners();
    return added;
  }

  Future<void> _enrich(Job j) async {
    final info = await NativeBridge.info(j.path);
    j.info = info;
    notifyListeners();
    j.thumb = await NativeBridge.thumb(j.path);
    notifyListeners();
  }

  void remove(Job j) {
    if (running) return;
    jobs.remove(j);
    notifyListeners();
  }

  Future<void> clear() async {
    if (running) return;
    jobs.clear();
    notifyListeners();
    await clearPickerCache();
  }

  /// The picker copies chosen videos into the app cache; remove those copies.
  static Future<void> clearPickerCache() async {
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {}
  }

  Future<void> cancel() async {
    _cancel = true;
    try {
      await LightCompressor().cancelCompression();
    } catch (_) {}
  }

  Future<void> start() async {
    if (running) return;
    running = true;
    _cancel = false;
    for (final j in jobs) {
      if (j.pending) {
        j.state = JobState.waiting;
        j.progress = 0;
      }
    }
    notifyListeners();

    try {
      await Permission.notification.request();
    } catch (_) {}

    final lc = LightCompressor();
    final sub = lc.onProgressUpdated.listen((p) {
      final j = _current;
      if (j == null) return;
      j.progress = (p / 100.0).clamp(0.0, 1.0).toDouble();
      notifyListeners();
    });

    var finishedAny = false;
    for (final j in List<Job>.of(jobs)) {
      if (_cancel) break;
      if (!j.pending) continue;

      final t = targetMb;
      if (t != null && j.originalBytes > 0 && j.originalBytes <= t * 1024 * 1024) {
        j.state = JobState.skipped;
        notifyListeners();
        continue;
      }

      _current = j;
      j.state = JobState.running;
      j.progress = 0;
      notifyListeners();
      try {
        final dot = j.name.lastIndexOf('.');
        final base = dot > 0 ? j.name.substring(0, dot) : j.name;
        // One pass with a bitrate computed from the duration is much faster than asking the
        // plugin to hit a size itself (which may encode more than once). Falls back to the
        // plugin's own target-size mode when the duration could not be read.
        final bps = t == null ? null : j.plannedVideoBps(t);
        final Video video;
        var quality = VideoQuality.medium;
        if (t != null && bps != null) {
          video = Video(
            videoName: '${base}_shrunk.mp4',
            videoBitrateInMbps: double.parse((bps / 1000000).toStringAsFixed(3)),
          );
          // Very small targets look blocky at full size; a smaller picture is faster and cleaner.
          if (j.lowQuality(t)) quality = VideoQuality.low;
        } else {
          video = Video(videoName: '${base}_shrunk.mp4', targetSizeMb: t);
        }
        final r = await lc.compressVideo(
          path: j.path,
          videoQuality: quality,
          isMinBitrateCheckEnabled: false,
          video: video,
          android: AndroidConfig(isSharedStorage: true, saveAt: SaveAt.Movies),
          ios: IOSConfig(saveInGallery: false),
          background: BackgroundConfig(notificationTitle: L.t('notif_title')),
        );
        if (r is OnSuccess) {
          j.state = JobState.done;
          j.progress = 1;
          j.outBytes = (r.compressedSize as num).toInt();
          j.targetMissed = t != null && j.outBytes > t * 1024 * 1024 * 1.1;
          finishedAny = true;
        } else if (r is OnCancelled) {
          j.state = JobState.cancelled;
        } else {
          j.state = JobState.failed;
        }
      } catch (e) {
        debugPrint('compress failed: $e');
        j.state = _cancel ? JobState.cancelled : JobState.failed;
      }
      _current = null;
      notifyListeners();
    }

    await sub.cancel();
    _current = null;
    for (final j in jobs) {
      if (j.state == JobState.running) j.state = JobState.cancelled;
    }
    running = false;
    notifyListeners();
    if (finishedAny && !_cancel) AdService.instance.onJobFinished();
  }
}
