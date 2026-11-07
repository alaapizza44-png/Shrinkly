import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Draws the caption. The same code paints the live preview and the PNG that is burned into the
/// video, so what the user sees is what is exported (everything is relative to the frame width).
///
/// Doing this in Flutter (instead of an FFmpeg "drawtext" filter) means Arabic letters are
/// joined and ordered correctly, and any emoji / system font works.
class TextOverlay {
  TextOverlay._();

  static final RegExp _rtl = RegExp(r'[֐-ࣿיִ-﷿ﹰ-﻿]');

  /// Default text size as a fraction of the frame width.
  static const double defaultSize = 0.062;

  /// Faint app-name watermark in the middle of the frame (removed after a rewarded ad).
  static void paintWatermark(Canvas canvas, Size size) {
    final fontSize = size.width * 0.085;
    final painter = TextPainter(
      text: TextSpan(
        text: 'Shorts Maker',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.30),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: fontSize * 0.12,
          shadows: const <Shadow>[
            Shadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 1)),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: size.width * 0.94);
    painter.paint(canvas, Offset((size.width - painter.width) / 2, (size.height - painter.height) / 2));
  }

  /// Paints the caption centred at ([cx], [cy]) (fractions of [size]) with a font size of
  /// [factor] x width. Does nothing for empty text.
  static void paint(Canvas canvas, Size size, String text, double cx, double cy, double factor) {
    final t = text.trim();
    if (t.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final fontSize = w * factor;

    final painter = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          height: 1.25,
          shadows: const <Shadow>[
            Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: _rtl.hasMatch(t) ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 4,
      ellipsis: '…',
    )..layout(maxWidth: w * 0.86);

    final padX = fontSize * 0.7;
    final padY = fontSize * 0.45;
    final boxW = math.min(w * 0.96, painter.width + padX * 2);
    final boxH = painter.height + padY * 2;
    final left = (cx * w - boxW / 2).clamp(0.0, math.max(0.0, w - boxW)).toDouble();
    final top = (cy * h - boxH / 2).clamp(0.0, math.max(0.0, h - boxH)).toDouble();
    final box = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, boxW, boxH), Radius.circular(fontSize * 0.45));
    canvas.drawRRect(box, Paint()..color = const Color(0x8C000000));
    painter.paint(canvas, Offset(left + (boxW - painter.width) / 2, top + padY));
  }

  /// Returns the path of a transparent PNG with exactly the size of the output video, or null
  /// if [text] is empty.
  static Future<String?> render(
      String text, int width, int height, double cx, double cy, double factor,
      {bool watermark = false}) async {
    if (text.trim().isEmpty && !watermark) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final sz = Size(width.toDouble(), height.toDouble());
    if (watermark) paintWatermark(canvas, sz);
    paint(canvas, sz, text, cx, cy, factor);
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final file = File(
        '${Directory.systemTemp.path}/short_caption_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }
}
