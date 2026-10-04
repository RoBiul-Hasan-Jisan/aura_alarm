import 'package:flutter/material.dart';
import '../fx.dart';
import '../models.dart';
import '../ringtones.dart';
import '../services/alarm_scheduler.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'alarm_form_screen.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});
  @override
  State<AlarmsScreen> createState() => _AlarmsScreenState();
}

class _AlarmsScreenState extends State<AlarmsScreen> {
  bool _loading = true;
  String? _error;
  List<Alarm> _alarms = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final a = await ApiService.alarms();
      if (mounted) setState(() => _alarms = a);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openForm([Alarm? a]) async {
    final saved = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AlarmFormScreen(existing: a)));
    if (saved == true) _load();
  }

  Future<void> _toggle(Alarm a) async {
    try {
      await ApiService.toggleAlarm(a.id);
      _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Alarm a) async {
    final ok = await confirmDialog(context,
        title: 'Delete alarm?', body: 'The ${a.prettyTime} alarm will be removed for good.');
    if (!ok) return;
    try {
      await ApiService.deleteAlarm(a.id);
      if (mounted) showSnack(context, 'Alarm deleted');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Alarms'),
          actions: [
            IconButton(
              tooltip: 'Test ring in 10 seconds',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () async {
                await AlarmScheduler.requestPermissions();
                try {
                  await AlarmScheduler.scheduleTest();
                  if (mounted) showSnack(context, 'Test alarm will ring in 10 seconds. Keep the volume up.');
                } catch (e) {
                  if (mounted) showSnack(context, 'Couldn’t schedule the test: $e', error: true);
                }
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          backgroundColor: dawn,
          foregroundColor: ink,
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
        body: AsyncView(
          loading: _loading,
          error: _error,
          onRetry: _load,
          builder: () => _alarms.isEmpty
              ? EmptyState(
                  icon: Icons.alarm_add_rounded,
                  title: 'No alarms yet',
                  message: 'Set a time and link an affirmation to wake up to.',
                  actionLabel: 'Add alarm',
                  onAction: () => _openForm(),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    itemCount: _alarms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => FadeSlideIn(index: i, child: Builder(builder: (_) {
                      final a = _alarms[i];
                      final off = !a.enabled;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => _openForm(a),
                        onLongPress: () => _delete(a),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
                          decoration: glassDeco(18),
                          child: Row(children: [
                            Expanded(
                              child: Opacity(
                                opacity: off ? 0.45 : 1,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  GradientText(a.prettyTime, serif(32)),
                                  const SizedBox(height: 2),
                                  Text('${a.label.isEmpty ? 'Alarm' : a.label} · ${a.repeatLabel}',
                                      style: const TextStyle(color: muted)),
                                  Text('♪ ${ringtoneByKey(a.ringtone).name}', style: const TextStyle(color: muted, fontSize: 12)),
                                  if (a.affirmationText != null) ...[
                                    const SizedBox(height: 8),
                                    Text('“${a.affirmationText}”',
                                        maxLines: 2, overflow: TextOverflow.ellipsis, style: serif(14, color: Colors.white)),
                                  ],
                                ]),
                              ),
                            ),
                            Switch(
                              value: a.enabled,
                              onChanged: (_) {
                                haptic();
                                _toggle(a);
                              }),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline, color: muted),
                              onPressed: () => _delete(a),
                            ),
                          ]),
                        ),
                      );
                    })),
                  ),
                ),
        ),
      );
}
