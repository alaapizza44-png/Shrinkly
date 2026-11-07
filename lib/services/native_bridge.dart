
import 'package:flutter/services.dart';

/// Basic facts about a video, read natively (see tool/android_templates/MainActivity.kt.tpl).
class VideoInfo {
  const VideoInfo({
    required this.durationMs,
    required this.width,
    required this.height,
    required this.bitrate,
    required this.fps,
  });

  final int durationMs;
  final int width;
  final int height;

  /// Overall bitrate in bits per second (0 if unknown).
  final int bitrate;
  final double fps;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'd': durationMs,
        'w': width,
        'h': height,
        'b': bitrate,
        'f': fps,
      };

  factory VideoInfo.fromJson(Map<String, dynamic> m) => VideoInfo(
        durationMs: (m['d'] as num?)?.toInt() ?? 0,
        width: (m['w'] as num?)?.toInt() ?? 0,
        height: (m['h'] as num?)?.toInt() ?? 0,
        bitrate: (m['b'] as num?)?.toInt() ?? 0,
        fps: (m['f'] as num?)?.toDouble() ?? 0,
      );

  String get durationLabel {
    final s = (durationMs / 1000).round();
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final ss = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(ss)}' : '$m:${two(ss)}';
  }

  /// "1080p", "720p"... based on the short side; empty when unknown.
  String get resolutionLabel {
    final short = width < height ? width : height;
    return short > 0 ? '${short}p' : '';
  }
}

/// Result of one Shorts export call.
class ExportOutcome {
  const ExportOutcome(this.status, [this.message]);

  /// 'ok' | 'cancelled' | 'error'
  final String status;
  final String? message;

  bool get ok => status == 'ok';
  bool get cancelled => status == 'cancelled';
}

class NativeBridge {
  NativeBridge._();

  static const MethodChannel _ch = MethodChannel('shrinkly/native');

  /// Sends the app to the background (like Home) instead of closing it.
  static Future<void> moveToBack() async {
    try {
      await _ch.invokeMethod<void>('toBack');
    } catch (_) {}
  }

  /// Exports one 9:16 clip with Media3 and saves it to Movies/Shrinkly.
  static Future<ExportOutcome> exportShort({
    required String path,
    required int startMs,
    required int endMs,
    required double cropL,
    required double cropT,
    required double cropR,
    required double cropB,
    required int width,
    required int height,
    required int bitrate,
    required String outName,
    String? overlayPath,
  }) async {
    try {
      final r = await _ch.invokeMethod<dynamic>('exportShort', <String, dynamic>{
        'path': path,
        'startMs': startMs,
        'endMs': endMs,
        'cl': cropL,
        'ct': cropT,
        'cr': cropR,
        'cb': cropB,
        'width': width,
        'height': height,
        'bitrate': bitrate,
        'outName': outName,
        'overlay': overlayPath,
      });
      if (r is Map) {
        return ExportOutcome((r['status'] as String?) ?? 'error', r['message'] as String?);
      }
      return const ExportOutcome('error', 'no answer');
    } catch (e) {
      return ExportOutcome('error', e.toString());
    }
  }

  /// 0..1 progress of the running Shorts export.
  static Future<double> exportProgress() async {
    try {
      return ((await _ch.invokeMethod<dynamic>('exportProgress')) as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> cancelExport() async {
    try {
      await _ch.invokeMethod<void>('cancelExport');
    } catch (_) {}
  }

  /// True while the plugin's background compression service is running.
  static Future<bool> compressionActive() async {
    try {
      return (await _ch.invokeMethod<bool>('active')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Size in bytes of [name] in the Movies folder if it was added after [sinceMs], else null.
  static Future<int?> findOutput(String name, int sinceMs) async {
    try {
      final r = await _ch.invokeMethod<dynamic>(
          'findOutput', <String, dynamic>{'name': name, 'since': sinceMs});
      return (r as num?)?.toInt();
    } catch (_) {
      return null;
    }
  }

  /// System video picker without copying the file. Returns (uri, name) or null if cancelled.
  static Future<({String uri, String name})?> pickVideo() async {
    try {
      final r = await _ch.invokeMethod<dynamic>('pickVideo');
      if (r is! Map) return null;
      final u = r['uri'] as String?;
      if (u == null) return null;
      return (uri: u, name: (r['name'] as String?) ?? 'video');
    } catch (_) {
      return null;
    }
  }

  /// Clips saved by the app, newest first.
  static Future<List<Work>> listWorks() async {
    try {
      final r = await _ch.invokeMethod<dynamic>('listWorks');
      if (r is! List) return <Work>[];
      return <Work>[
        for (final e in r)
          if (e is Map && e['uri'] is String)
            Work(
              uri: e['uri'] as String,
              name: (e['name'] as String?) ?? '',
              size: (e['size'] as num?)?.toInt() ?? 0,
              durationMs: (e['durationMs'] as num?)?.toInt() ?? 0,
              addedSec: (e['added'] as num?)?.toInt() ?? 0,
            ),
      ];
    } catch (_) {
      return <Work>[];
    }
  }

  static Future<bool> _bool(String m, String uri) async {
    try {
      return (await _ch.invokeMethod<bool>(m, <String, dynamic>{'uri': uri})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openVideo(String uri) => _bool('openVideo', uri);
  static Future<bool> shareVideo(String uri) => _bool('shareVideo', uri);
  static Future<bool> deleteWork(String uri) => _bool('deleteWork', uri);

  static Future<VideoInfo?> info(String path) async {
    try {
      final r = await _ch.invokeMethod<dynamic>('info', <String, dynamic>{'path': path});
      if (r is! Map) return null;
      int i(String k) => (r[k] as num?)?.toInt() ?? 0;
      return VideoInfo(
        durationMs: i('durationMs'),
        width: i('width'),
        height: i('height'),
        bitrate: i('bitrate'),
        fps: (r['fps'] as num?)?.toDouble() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> thumb(String path) async {
    try {
      return await _ch.invokeMethod<Uint8List>('thumb', <String, dynamic>{'path': path});
    } catch (_) {
      return null;
    }
  }
}

/// A finished clip in the gallery.
class Work {
  const Work({
    required this.uri,
    required this.name,
    required this.size,
    required this.durationMs,
    required this.addedSec,
  });

  final String uri;
  final String name;
  final int size;
  final int durationMs;
  final int addedSec;
}
