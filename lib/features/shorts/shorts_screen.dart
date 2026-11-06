import 'package:flutter/material.dart';

import '../../l10n.dart';
import '../../screens/settings_screen.dart';
import '../../services/native_bridge.dart';
import '../../theme.dart';
import '../../widgets/ad_widgets.dart';
import 'shorts_controller.dart';

/// The Shorts tab: pick a long video, choose the part, the picture mode, an optional caption,
/// and export one or many vertical 9:16 clips.
class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final TextEditingController _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.text = ShortsController.instance.text;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
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
              const BannerAdWidget(),
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

  Widget _editor(BuildContext context, ShortsController c) {
    final cs = Theme.of(context).colorScheme;
    final busy = c.exporting;
    final dur = c.durationMs;
    final loadingInfo = c.info == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: <Widget>[
        // preview + name
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 112,
                    height: 68,
                    child: c.thumb != null
                        ? Image.memory(c.thumb!, fit: BoxFit.cover, gaplessPlayback: true)
                        : Container(
                            color: cs.primary.withValues(alpha: 0.12),
                            child: Icon(Icons.movie_rounded, color: cs.primary),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(c.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      if (c.info != null)
                        Text(
                          '${c.info!.durationLabel}  ·  ${c.info!.resolutionLabel}',
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : c.pick,
                  child: Text(context.tr('change_video')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // trim
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
                      onChanged: busy ? null : (v) => c.setRange(v.start.round(), v.end.round()),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(context.tr('start_label', <String, String>{'t': _clock(c.startMs)})),
                        Text(context.tr('end_label', <String, String>{'t': _clock(c.endMs)})),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('selected_len', <String, String>{'t': _clock(c.selectedMs)}),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),

        // picture mode
        _Section(
          icon: Icons.crop_portrait_rounded,
          title: context.tr('mode_title'),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ShortsMode>(
              segments: <ButtonSegment<ShortsMode>>[
                ButtonSegment<ShortsMode>(
                  value: ShortsMode.fill,
                  icon: const Icon(Icons.fullscreen_rounded),
                  label: Text(context.tr('mode_fill')),
                ),
                ButtonSegment<ShortsMode>(
                  value: ShortsMode.fit,
                  icon: const Icon(Icons.fit_screen_rounded),
                  label: Text(context.tr('mode_fit')),
                ),
              ],
              selected: <ShortsMode>{c.mode},
              onSelectionChanged: busy ? null : (v) => c.setMode(v.first),
            ),
          ),
          footer: context.tr(c.mode == ShortsMode.fill ? 'mode_fill_sub' : 'mode_fit_sub'),
        ),
        const SizedBox(height: 12),

        // split
        _Section(
          icon: Icons.splitscreen_rounded,
          title: context.tr('split_title'),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: Text(context.tr('split_whole')),
                selected: c.partSeconds == 0,
                onSelected: busy ? null : (_) => c.setPartSeconds(0),
              ),
              for (final s in const <int>[30, 60, 90])
                ChoiceChip(
                  label: Text(context.tr('split_n', <String, String>{'n': '$s'})),
                  selected: c.partSeconds == s,
                  onSelected: busy ? null : (_) => c.setPartSeconds(s),
                ),
            ],
          ),
          footer: context.tr('split_count', <String, String>{'n': '${c.plannedParts}'}),
        ),
        const SizedBox(height: 12),

        // quality
        _Section(
          icon: Icons.high_quality_rounded,
          title: context.tr('quality_title'),
          child: Wrap(
            spacing: 8,
            children: <Widget>[
              for (final q in const <int>[720, 480, 360])
                ChoiceChip(
                  label: Text('${q}p'),
                  selected: c.quality == q,
                  onSelected: busy ? null : (_) => c.setQuality(q),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // caption
        _Section(
          icon: Icons.title_rounded,
          title: context.tr('text_title'),
          child: TextField(
            controller: _text,
            enabled: !busy,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: context.tr('text_hint')),
            onChanged: c.setText,
          ),
        ),
        const SizedBox(height: 16),

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
              onPressed: (c.plannedParts == 0 || loadingInfo) ? null : c.export,
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
