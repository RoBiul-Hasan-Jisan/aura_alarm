import 'package:flutter/material.dart';
import '../models.dart';
import '../ringtones.dart';
import '../services/ringtone_player.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets.dart';

/// Add (existing == null) or Edit an alarm. Pops `true` when saved.
class AlarmFormScreen extends StatefulWidget {
  final Alarm? existing;
  const AlarmFormScreen({super.key, this.existing});
  @override
  State<AlarmFormScreen> createState() => _AlarmFormScreenState();
}

class _AlarmFormScreenState extends State<AlarmFormScreen> {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final _form = GlobalKey<FormState>();
  late final TextEditingController _label;
  late TimeOfDay _time;
  late Set<int> _days;
  late bool _enabled;
  String? _affirmationId;
  String _ringtone = 'sunrise';
  int _snooze = 5;
  bool _vibrate = true;
  List<Affirmation> _affirmations = [];
  bool _loading = true, _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    final p = (e?.time ?? '07:00').split(':');
    _time = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    _days = {...?e?.repeatDays};
    _enabled = e?.enabled ?? true;
    _affirmationId = e?.affirmationId;
    _ringtone = e?.ringtone ?? 'sunrise';
    _snooze = e?.snoozeMinutes ?? 5;
    _vibrate = e?.vibrate ?? true;
    _loadAffirmations();
  }

  @override
  void dispose() {
    RingtonePlayer.stop();
    _label.dispose();
    super.dispose();
  }

  Future<void> _loadAffirmations() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await ApiService.affirmations();
      if (!mounted) return;
      setState(() {
        _affirmations = list;
        if (!list.any((a) => a.id == _affirmationId)) _affirmationId = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _timeString =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final days = _days.toList()..sort();
      final label = _label.text.trim();
      if (_editing) {
        await ApiService.updateAlarm(widget.existing!.id, label, _timeString, days, _enabled, _affirmationId,
            ringtone: _ringtone, snooze: _snooze, vibrate: _vibrate);
      } else {
        await ApiService.createAlarm(label, _timeString, days, _enabled, _affirmationId,
            ringtone: _ringtone, snooze: _snooze, vibrate: _vibrate);
      }
      if (!mounted) return;
      showSnack(context, _editing ? 'Alarm updated' : 'Alarm added');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit alarm' : 'New alarm')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(message: _error!, onRetry: _loadAffirmations)
                : SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _form,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _pickTime,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              decoration: glassDeco(18),
                              child: Column(children: [
                                GradientText(_time.format(context), serif(48)),
                                const Text('Tap to change time', style: TextStyle(color: muted)),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _label,
                            maxLength: 40,
                            decoration: const InputDecoration(labelText: 'Label (optional)', hintText: 'Morning run'),
                            validator: (v) => (v != null && v.trim().length > 40) ? 'Keep it under 40 characters' : null,
                          ),
                          const SizedBox(height: 8),
                          const Text('Repeat', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(_days.isEmpty ? 'Rings once' : 'Rings on the days selected',
                              style: const TextStyle(color: muted, fontSize: 13)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(7, (i) {
                              final d = i + 1;
                              return FilterChip(
                                label: Text(_dayNames[i]),
                                selected: _days.contains(d),
                                onSelected: (s) => setState(() => s ? _days.add(d) : _days.remove(d)),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String?>(
                            value: _affirmationId,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Linked affirmation'),
                            items: [
                              const DropdownMenuItem<String?>(value: null, child: Text('None')),
                              ..._affirmations.map((a) => DropdownMenuItem<String?>(
                                    value: a.id,
                                    child: Text(a.text, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  )),
                            ],
                            onChanged: (v) => setState(() => _affirmationId = v),
                          ),
                          if (_affirmations.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('You have no affirmations yet. Add one in the Affirmations tab to link it here.',
                                  style: TextStyle(color: muted, fontSize: 13)),
                            ),
                          const SizedBox(height: 20),
                          Text('Ringtone', style: serif(16)),
                          const SizedBox(height: 4),
                          const Text('Tap one to hear it.', style: TextStyle(color: muted, fontSize: 13)),
                          const SizedBox(height: 10),
                          for (final r in ringtones)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  setState(() => _ringtone = r.key);
                                  RingtonePlayer.play(r.key);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: glassDeco(16).copyWith(
                                    border: Border.all(color: _ringtone == r.key ? purple : const Color(0x26FFFFFF), width: _ringtone == r.key ? 1.8 : 1),
                                  ),
                                  child: Row(children: [
                                    Icon(_ringtone == r.key ? Icons.volume_up_rounded : Icons.music_note_rounded,
                                        color: _ringtone == r.key ? purple : muted),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                        Text(r.description, style: const TextStyle(color: muted, fontSize: 12)),
                                      ]),
                                    ),
                                    if (_ringtone == r.key) const Icon(Icons.check_circle, color: purple),
                                  ]),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text('Snooze', style: serif(16)),
                          const SizedBox(height: 8),
                          Wrap(spacing: 8, children: [
                            for (final n in [5, 10, 15])
                              ChoiceChip(
                                label: Text('$n min'),
                                selected: _snooze == n,
                                onSelected: (_) => setState(() => _snooze = n),
                              ),
                          ]),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text('Vibrate'),
                            value: _vibrate,
                            onChanged: (v) => setState(() => _vibrate = v),
                          ),
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                            title: const Text('Alarm on'),
                            value: _enabled,
                            onChanged: (v) => setState(() => _enabled = v),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: _saving
                                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(_editing ? 'Save changes' : 'Add alarm'),
                          ),
                        ]),
                      ),
                    ),
                  ),
      );
}
