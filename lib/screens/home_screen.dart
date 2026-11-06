import 'package:flutter/material.dart';

import '../l10n.dart';
import '../services/compress_queue.dart';
import '../services/settings.dart';
import '../theme.dart';
import '../widgets/ad_widgets.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pick(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final msg = context.tr('pick_error');
    try {
      await CompressQueue.instance.pick();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('app_name')),
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
                listenable: CompressQueue.instance,
                builder: (context, _) {
                  final q = CompressQueue.instance;
                  return q.jobs.isEmpty
                      ? _Empty(onPick: () => _pick(context))
                      : _Workspace(onPick: () => _pick(context));
                },
              ),
            ),
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
              decoration: BoxDecoration(
                gradient: AppTheme.hero,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.compress_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('tagline'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.tealDeep,
                    ),
                    onPressed: onPick,
                    icon: const Icon(Icons.video_library_rounded),
                    label: Text(context.tr('choose_videos'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.lock_outline_rounded, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(context.tr('private_note'),
                      style: TextStyle(color: cs.onSurfaceVariant, height: 1.35)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Workspace extends StatelessWidget {
  const _Workspace({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final q = CompressQueue.instance;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            children: <Widget>[
              _TargetCard(enabled: !q.running),
              const SizedBox(height: 12),
              for (final j in q.jobs) ...<Widget>[
                _JobTile(job: j, locked: q.running),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        _ActionBar(onPick: onPick),
      ],
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.enabled});

  final bool enabled;

  static const List<int> _presets = <int>[10, 25, 50, 100];

  Future<void> _custom(BuildContext context) async {
    final ctrl = TextEditingController();
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) {
        String? err;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(ctx.tr('custom_title')),
            content: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(hintText: ctx.tr('custom_hint'), errorText: err),
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'))),
              FilledButton(
                onPressed: () {
                  final n = int.tryParse(ctrl.text.trim());
                  if (n == null || n < 1 || n > 5000) {
                    setState(() => err = ctx.tr('custom_err'));
                    return;
                  }
                  Navigator.pop(ctx, n);
                },
                child: Text(ctx.tr('ok')),
              ),
            ],
          ),
        );
      },
    );
    if (v != null) _set(v);
  }

  void _set(int? mb) {
    CompressQueue.instance.setTarget(mb);
    SettingsController.instance.setTargetMb(mb ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = CompressQueue.instance.targetMb;
    final isCustom = t != null && !_presets.contains(t);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.track_changes_rounded, color: cs.primary),
                const SizedBox(width: 8),
                Text(context.tr('target_title'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                ChoiceChip(
                  label: Text(context.tr('target_auto')),
                  selected: t == null,
                  onSelected: enabled ? (_) => _set(null) : null,
                ),
                for (final p in _presets)
                  ChoiceChip(
                    label: Text(context.tr('mb_n', <String, String>{'n': '$p'})),
                    selected: t == p,
                    onSelected: enabled ? (_) => _set(p) : null,
                  ),
                ChoiceChip(
                  label: Text(isCustom
                      ? context.tr('mb_n', <String, String>{'n': '$t'})
                      : context.tr('target_custom')),
                  selected: isCustom,
                  onSelected: enabled ? (_) => _custom(context) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  const _JobTile({required this.job, required this.locked});

  final Job job;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final j = job;

    IconData icon;
    Color color;
    switch (j.state) {
      case JobState.done:
        icon = Icons.check_circle_rounded;
        color = AppTheme.mint;
        break;
      case JobState.failed:
        icon = Icons.error_rounded;
        color = cs.error;
        break;
      case JobState.skipped:
        icon = Icons.info_rounded;
        color = AppTheme.coral;
        break;
      case JobState.running:
        icon = Icons.autorenew_rounded;
        color = cs.primary;
        break;
      case JobState.cancelled:
      case JobState.waiting:
        icon = Icons.movie_rounded;
        color = cs.onSurfaceVariant;
        break;
    }

    Widget sub;
    switch (j.state) {
      case JobState.running:
        sub = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: j.progress <= 0 ? null : j.progress,
                minHeight: 8,
                color: AppTheme.mint,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(j.progress * 100).round()}%',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
          ],
        );
        break;
      case JobState.done:
        sub = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context.tr('reduced', <String, String>{
                'a': fmtBytes(j.originalBytes),
                'b': fmtBytes(j.outBytes),
                'p': '${j.savedPercent}',
              }),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              j.targetMissed ? context.tr('close_miss') : context.tr('saved_in'),
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
            ),
          ],
        );
        break;
      case JobState.skipped:
        sub = Text(context.tr('st_skipped'), style: TextStyle(color: cs.onSurfaceVariant));
        break;
      case JobState.failed:
        sub = Text(context.tr('st_failed'), style: TextStyle(color: cs.error));
        break;
      case JobState.cancelled:
        sub = Text(context.tr('st_cancelled'), style: TextStyle(color: cs.onSurfaceVariant));
        break;
      case JobState.waiting:
        sub = Text(fmtBytes(j.originalBytes), style: TextStyle(color: cs.onSurfaceVariant));
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(j.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  sub,
                ],
              ),
            ),
            if (!locked)
              IconButton(
                tooltip: context.tr('remove'),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => CompressQueue.instance.remove(j),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = CompressQueue.instance;
    final n = q.pendingCount;

    Widget content;
    if (q.running) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.tr('compressing', <String, String>{
                    'i': '${q.runningIndex == 0 ? 1 : q.runningIndex}',
                    'n': '${q.jobs.length}',
                  }),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: q.cancel,
                icon: const Icon(Icons.stop_rounded),
                label: Text(context.tr('stop')),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(context.tr('bg_note'), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (q.anyDone && n == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.savings_rounded, color: AppTheme.mint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('saved_total', <String, String>{'s': fmtBytes(q.savedBytes)}),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          if (n > 0)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: q.start,
                icon: const Icon(Icons.compress_rounded),
                label: Text(
                  n == 1
                      ? context.tr('compress_one')
                      : context.tr('compress_n', <String, String>{'n': '$n'}),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(context.tr('add_more')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: q.clear,
                  icon: const Icon(Icons.delete_sweep_rounded),
                  label: Text(context.tr('clear_list')),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: content,
    );
  }
}
