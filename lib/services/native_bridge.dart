import 'dart:typed_data';

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

class NativeBridge {
  NativeBridge._();

  static const MethodChannel _ch = MethodChannel('shrinkly/native');

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
