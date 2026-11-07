import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../l10n.dart';
import '../../screens/settings_screen.dart';
import '../../services/native_bridge.dart';
import '../../theme.dart';
import 'shorts_controller.dart';
import 'text_overlay.dart';

/// The Shorts tab: pick a long video, scrub it live to choose the shot, slide the 9:16 frame,
/// drag a caption anywhere, and export one or many vertical clips.
class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  double _baseSize = TextOverlay.defaultSize;
  VideoPlayerController? _vp;
  String? _vpPath;
  int? _pendingSeek;
  bool _seeking = false;

  @override
  void dispose() {
    _vp?.dispose();
    super.dispose();
  }

  /// Opens the chosen video in the live preview player (once per picked file).
  void _ensureVideo(ShortsController c) {
    final path = c.path;
    if (path == _vpPath) return;
    _vpPath = path;
    final old = _vp;
    _vp = null;
    old?.dispose();
    if (path == null) return;
    final vp = VideoPlayerController.file(File(path));
    _vp = vp;
    vp.initialize().then((_) {
      if (!mounted || _vp != vp) return;
      vp.setLooping(false);
      vp.addListener(_tick);
      vp.seekTo(Duration(milliseconds: ShortsController.instance.startMs));
      setState(() {});
    }).catchError((Object e) {
      debugPrint('preview failed: $e');
    });
  }

  /// Keeps playback inside the chosen part.
  void _tick() {
    final vp = _vp;
    if (vp == null || !vp.value.isInitialized) return;
    final c = ShortsController.instance;
    if (vp.value.isPlaying && c.endMs > 0 && vp.value.position.inMilliseconds >= c.endMs) {
      vp.pause();
      vp.seekTo(Duration(milliseconds: c.startMs));
    }
  }

  /// Live scrubbing: only the newest requested position is kept while a seek is running.
  Future<void> _seek(int ms) async {
    final vp = _vp;
    if (vp == null || !vp.value.isInitialized) return;
    _pendingSeek = ms;
    if (_seeking) return;
    _seeking = true;
    try {
      while (_pendingSeek != null) {
        final t = _pendingSeek!;
        _pendingSeek = null;
        await vp.seekTo(Duration(milliseconds: t));
      }
    } finally {
      _seeking = false;
    }
  }

  /// Add / edit / remove the caption. The caption itself is then dragged and pinched on the preview.
  Future<void> _editText(BuildContext context, ShortsController c) async {
    final ctrl = TextEditingController(text: c.text);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('text_title')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(hintText: ctx.tr('text_hint')),
        ),
        actions: <Widget>[
          if (c.text.isNotEmpty)
            TextButton(onPressed: () => Navigator.pop(ctx, ''), child: Text(ctx.tr('remove'))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: Text(ctx.tr('ok'))),
        ],
      ),
    );
    ctrl.dispose();
    if (r != null) c.setText(r);
  }

  Future<void> _togglePlay(ShortsController c) async {
    final vp = _vp;
    if (vp == null || !vp.value.isInitialized) return;
    if (vp.value.isPlaying) {
      await vp.pause();
      return;
    }
    final pos = vp.value.position.inMilliseconds;
    if (pos < c.startMs || pos >= c.endMs - 200) {
      await vp.seekTo(Duration(milliseconds: c.startMs));
    }
    await vp.play();
  }

  static String _clock(int ms) {
    final s = (ms / 1000).round();
    final m = s ~/ 60;
    final ss = s % 60;
    return '$m:${ss.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !ShortsController.instance.exporting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) NativeBridge.moveToBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('shorts_title')),
          actions: <Widget>[
            IconButton(
              tooltip: context.tr('settings'),
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListenableBuilder(
                  listenable: ShortsController.instance,
                  builder: (context, _) {
                    final c = ShortsController.instance;
                    return c.path == null ? _empty(context, c) : _editor(context, c);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ empty state

  Widget _empty(BuildContext context, ShortsController c) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          decoration: BoxDecoration(gradient: AppTheme.hero, borderRadius: BorderRadius.circular(26)),
          child: Column(
            children: <Widget>[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
                child: const Icon(Icons.smartphone_rounded, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('shorts_intro'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.3),
              ),
              const SizedBox(height: 20),
              c.picking
                  ? Column(
                      children: <Widget>[
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 10),
                        Text(context.tr('preparing'), style: TextStyle(color: cs.onPrimary)),
                      ],
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.tealDeep,
                      ),
                      onPressed: c.pick,
                      icon: const Icon(Icons.video_library_rounded),
                      label: Text(context.tr('pick_video'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ editor

  Widget _preview(BuildContext context, ShortsController c) {
    final cs = Theme.of(context).colorScheme;
    final vp = _vp;
    final ready = vp != null && vp.value.isInitialized;
    final screenH = MediaQuery.of(context).size.height;
    return LayoutBuilder(
      builder: (context, box) {
        final h = math.min(box.maxWidth * 16 / 9, screenH * 0.6);
        final w = h * 9 / 16;
        final align = c.panHorizontal
            ? Alignment(c.pan * 2 - 1, 0)
            : Alignment(0, c.pan * 2 - 1);
        Widget picture;
        if (ready) {
          picture = FittedBox(
            fit: BoxFit.cover,
            alignment: align,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: vp.value.size.width,
              height: vp.value.size.height,
              child: VideoPlayer(vp),
            ),
          );
        } else if (c.thumb != null) {
          picture = Image.memory(c.thumb!, fit: BoxFit.cover, alignment: align, gaplessPlayback: true);
        } else {
          picture = const Center(child: CircularProgressIndicator());
        }
        return Center(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: c.exporting ? null : () => _editText(context, c),
              onScaleStart: (_) => _baseSize = c.textSize,
              onScaleUpdate: c.text.trim().isEmpty || c.exporting
                  ? null
                  : (d) {
                      c.setTextPos(c.textX + d.focalPointDelta.dx / w, c.textY + d.focalPointDelta.dy / h);
                      if (d.pointerCount > 1) c.setTextSize(_baseSize * d.scale);
                    },
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  picture,
                  CustomPaint(
                    painter: _CaptionPainter(c.text, c.textX, c.textY, c.textSize),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _editor(BuildContext context, ShortsController c) {
    _ensureVideo(c);
    final cs = Theme.of(context).colorScheme;
    final busy = c.exporting;
    final dur = c.durationMs;
    final loadingInfo = c.info == null;
    final canPan = c.cropWFrac < 0.999 || c.cropHFrac < 0.999;
    final vp = _vp;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: <Widget>[
        // file name + change
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                c.info == null
                    ? c.name
                    : '${c.name}\n${c.info!.durationLabel}  ·  ${c.info!.resolutionLabel}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, height: 1.35),
              ),
            ),
            TextButton(
              onPressed: busy ? null : c.pick,
              child: Text(context.tr('change_video')),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // live preview (9:16 window)
        _preview(context, c),
        const SizedBox(height: 8),
        if (vp != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: vp,
            builder: (context, v, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton.filledTonal(
                  onPressed: (busy || !v.isInitialized) ? null : () => _togglePlay(c),
                  icon: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
                const SizedBox(width: 12),
                Text(_clock(v.position.inMilliseconds),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: busy ? null : () => _editText(context, c),
                  icon: const Icon(Icons.text_fields_rounded),
                  label: Text(context.tr(c.text.isEmpty ? 'text_add' : 'text_edit')),
                ),
              ],
            ),
          ),
        if (c.text.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(context.tr('text_drag_hint'),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
          ),
        const SizedBox(height: 12),

        // trim (live: the preview jumps to the handle you move)
        _Section(
          icon: Icons.content_cut_rounded,
          title: context.tr('trim_title'),
          child: loadingInfo || dur <= 0
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    RangeSlider(
                      values: RangeValues(
                        c.startMs.toDouble().clamp(0, dur.toDouble()).toDouble(),
                        c.endMs.toDouble().clamp(0, dur.toDouble()).toDouble(),
                      ),
                      min: 0,
                      max: dur.toDouble(),
                      onChanged: busy
                          ? null
                          : (v) {
                              final startMoved = (v.start.round() - c.startMs).abs() >=
                                  (v.end.round() - c.endMs).abs();
                              _vp?.pause();
                              c.setRange(v.start.round(), v.end.round());
                              _seek(startMoved ? v.start.round() : v.end.round());
                            },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(context.tr('start_label', <String, String>{'t': _clock(c.startMs)})),
                        Text(context.tr('end_label', <String, String>{'t': _clock(c.endMs)})),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('selected_len', <String, String>{'t': _clock(c.selectedMs)}),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),

        // frame position
        if (canPan) ...<Widget>[
          _Section(
            icon: Icons.open_with_rounded,
            title: context.tr('frame_title'),
            child: Slider(
              value: c.pan,
              onChanged: busy ? null : c.setPan,
            ),
            footer: context.tr('frame_sub'),
          ),
          const SizedBox(height: 12),
        ],

        // clip length + quality: compact, small, side by side
        _CompactRow(
          label: context.tr('split_title'),
          chips: <Widget>[
            _smallChip(context.tr('split_whole'), c.partSeconds == 0, busy ? null : () => c.setPartSeconds(0)),
            for (final s in const <int>[30, 60, 90])
              _smallChip(context.tr('split_n', <String, String>{'n': '$s'}), c.partSeconds == s,
                  busy ? null : () => c.setPartSeconds(s)),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Text(context.tr('split_count', <String, String>{'n': '${c.plannedParts}'}),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5)),
        ),
        _CompactRow(
          label: context.tr('quality_title'),
          chips: <Widget>[
            _smallChip(context.tr('quality_auto'), c.quality == 0, busy ? null : () => c.setQuality(0)),
            _smallChip('720p', c.quality == 720, busy ? null : () => c.setQuality(720)),
          ],
        ),
        if (!loadingInfo)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${context.tr('out_size', <String, String>{'w': '${c.outWidth}', 'h': '${c.outHeight}'})}'
              '${(c.info!.height < 720) ? '\n${context.tr('quality_note')}' : ''}',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11.5),
            ),
          ),
        const SizedBox(height: 14),

        // action / progress
        if (busy)
          _progressCard(context, c)
        else ...<Widget>[
          if (c.phase == ShortsPhase.done)
            _note(context, Icons.check_circle_rounded, AppTheme.mint,
                context.tr('export_done', <String, String>{'n': '${c.savedCount}'})),
          if (c.phase == ShortsPhase.error)
            _note(context, Icons.error_rounded, cs.error,
                context.tr('export_error', <String, String>{'e': c.error ?? ''})),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (c.plannedParts == 0 || loadingInfo)
                  ? null
                  : () {
                      _vp?.pause();
                      c.export();
                    },
              icon: const Icon(Icons.movie_creation_rounded),
              label: Text(context.tr('export_btn'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _note(BuildContext context, IconData icon, Color color, String msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35))),
        ],
      ),
    );
  }

  Widget _progressCard(BuildContext context, ShortsController c) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.tr('exporting_part', <String, String>{'i': '${c.part}', 'n': '${c.parts}'}),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: c.progress <= 0 ? null : c.progress,
                minHeight: 8,
                color: AppTheme.mint,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(c.progress * 100).round()}%',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            const SizedBox(height: 6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: c.cancel,
                icon: const Icon(Icons.stop_rounded),
                label: Text(context.tr('stop')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child, this.footer});

  final IconData icon;
  final String title;
  final Widget child;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ],
            ),
            const SizedBox(height: 10),
            child,
            if (footer != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(footer!, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaptionPainter extends CustomPainter {
  _CaptionPainter(this.text, this.x, this.y, this.factor);

  final String text;
  final double x;
  final double y;
  final double factor;

  @override
  void paint(Canvas canvas, Size size) => TextOverlay.paint(canvas, size, text, x, y, factor);

  @override
  bool shouldRepaint(_CaptionPainter old) =>
      old.text != text || old.x != x || old.y != y || old.factor != factor;
}

Widget _smallChip(String label, bool selected, VoidCallback? onTap) {
  return ChoiceChip(
    label: Text(label, style: const TextStyle(fontSize: 12)),
    selected: selected,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const EdgeInsets.symmetric(horizontal: 2),
    onSelected: onTap == null ? null : (_) => onTap(),
  );
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.label, required this.chips});

  final String label;
  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 0,
      children: <Widget>[
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: cs.onSurface)),
        ...chips,
      ],
    );
  }
}
