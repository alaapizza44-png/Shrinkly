import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Draws the caption as a transparent PNG with exactly the size of the output video.
///
/// Doing this in Flutter (instead of an FFmpeg "drawtext" filter) means Arabic letters are
/// joined and ordered correctly, and any emoji / system font works.
class TextOverlay {
  TextOverlay._();

  static final RegExp _rtl = RegExp(r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]');

  /// Returns the path of the PNG, or null if [text] is empty.
  static Future<String?> render(String text, int width, int height) async {
    final t = text.trim();
    if (t.isEmpty) return null;

    final w = width.toDouble();
    final h = height.toDouble();
    final rtl = _rtl.hasMatch(t);
    final fontSize = w * 0.062;

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
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      maxLines: 4,
      ellipsis: '…',
    )..layout(maxWidth: w * 0.82);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    // Centred horizontally, bottom of the box at about 80% of the height (lower third).
    final padX = fontSize * 0.7;
    final padY = fontSize * 0.45;
    final boxW = math.min(w * 0.92, painter.width + padX * 2);
    final boxH = painter.height + padY * 2;
    final left = (w - boxW) / 2;
    final top = h * 0.80 - boxH;
    final box = RRect.fromRectAndRadius(Rect.fromLTWH(left, top, boxW, boxH), Radius.circular(fontSize * 0.45));
    canvas.drawRRect(box, Paint()..color = const Color(0x8C000000));
    painter.paint(canvas, Offset(left + (boxW - painter.width) / 2, top + padY));

    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    final file = File('${Directory.systemTemp.path}/short_caption_${DateTime.now().microsecondsSinceEpoch}.png');
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return file.path;
  }
}
