import 'package:flutter/material.dart';
import '../services/alarm_scheduler.dart';
import '../theme.dart';
import '../widgets.dart';

/// Full-screen "wake up" screen shown when an alarm rings.
class RingScreen extends StatefulWidget {
  final RingInfo info;
  const RingScreen({super.key, required this.info});
  @override
  State<RingScreen> createState() => _RingScreenState();
}

class _RingScreenState extends State<RingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  bool _busy = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String get _time {
    final n = DateTime.now();
    final h = n.hour % 12 == 0 ? 12 : n.hour % 12;
    return '$h:${n.minute.toString().padLeft(2, '0')} ${n.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _act(Future<void> Function(RingInfo) fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn(widget.info);
    } catch (_) {}
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    return PopScope(
      canPop: false, // only Stop or Snooze can close it
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 84 + 12 * _pulse.value,
                  height: 84 + 12 * _pulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: brandGradient,
                    boxShadow: [BoxShadow(color: dawn.withAlpha((90 + 80 * _pulse.value).round()), blurRadius: 40)],
                  ),
                  child: const Icon(Icons.alarm_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(height: 18),
              GradientText(_time, serif(54, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(info.label, style: const TextStyle(color: muted, fontSize: 16)),
              const SizedBox(height: 18),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: ThemeStore.index,
                  builder: (_, i, __) => QuoteCard(
                    text: info.text ?? 'Rise and shine. Today is yours.',
                    category: info.category ?? 'Good morning',
                    themeIndex: i,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _busy ? null : () => _act(AlarmScheduler.snoozeRing),
                    child: Text('Snooze ${info.snooze} min'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(58),
                      backgroundColor: dawn,
                      foregroundColor: ink,
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _busy ? null : () => _act(AlarmScheduler.stopRing),
                    child: const Text('Stop'),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
