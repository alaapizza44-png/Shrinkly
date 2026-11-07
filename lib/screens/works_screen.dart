import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/compress_queue.dart' show fmtBytes;
import '../services/native_bridge.dart';
import '../theme.dart';
import 'settings_screen.dart';

/// "My clips": the Shorts exported by the app, with play / share / delete.
class WorksScreen extends StatefulWidget {
  const WorksScreen({super.key});

  /// Bump to reload the list (e.g. when the tab is opened).
  static final ValueNotifier<int> refresh = ValueNotifier<int>(0);

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  List<Work>? _works;

  @override
  void initState() {
    super.initState();
    WorksScreen.refresh.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    WorksScreen.refresh.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final w = await NativeBridge.listWorks();
    if (mounted) setState(() => _works = w);
  }

  Future<void> _delete(Work w) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('w_delete')),
        content: Text(ctx.tr('w_delete_q')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('w_delete'))),
        ],
      ),
    );
    if (ok == true) {
      await NativeBridge.deleteWork(w.uri);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final works = _works;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('tab_works')),
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
      body: works == null
          ? const Center(child: CircularProgressIndicator())
          : works.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.video_library_outlined, size: 64, color: cs.primary.withValues(alpha: 0.6)),
                        const SizedBox(height: 14),
                        Text(context.tr('works_empty'),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Text(context.tr('works_empty_sub'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4)),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.56,
                    ),
                    itemCount: works.length,
                    itemBuilder: (context, i) => _WorkCard(
                      work: works[i],
                      onDelete: () => _delete(works[i]),
                    ),
                  ),
                ),
    );
  }
}

class _WorkCard extends StatefulWidget {
  const _WorkCard({required this.work, required this.onDelete});

  final Work work;
  final VoidCallback onDelete;

  @override
  State<_WorkCard> createState() => _WorkCardState();
}

class _WorkCardState extends State<_WorkCard> {
  Uint8List? _thumb;

  @override
  void initState() {
    super.initState();
    NativeBridge.thumb(widget.work.uri).then((t) {
      if (mounted) setState(() => _thumb = t);
    });
  }

  static String _clock(int ms) {
    final s = (ms / 1000).round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final w = widget.work;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: InkWell(
              onTap: () => NativeBridge.openVideo(w.uri),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _thumb != null
                      ? Image.memory(_thumb!, fit: BoxFit.cover, gaplessPlayback: true)
                      : Container(color: cs.primary.withValues(alpha: 0.1)),
                  const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44)),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_clock(w.durationMs),
                          style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 4),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(fmtBytes(w.size),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr('w_share'),
                  icon: Icon(Icons.share_rounded, color: AppTheme.teal, size: 20),
                  onPressed: () => NativeBridge.shareVideo(w.uri),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr('w_delete'),
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error, size: 20),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
