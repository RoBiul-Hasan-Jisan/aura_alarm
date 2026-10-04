import 'dart:math';
import 'package:flutter/material.dart';
import '../fx.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'affirmation_form_screen.dart';
import 'quote_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int tab) onOpenTab;
  const HomeScreen({super.key, required this.onOpenTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  String? _error;
  final _burst = GlobalKey<HeartBurstState>();
  Affirmation? _daily;
  Alarm? _next;
  int _alarmCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([ApiService.dailyAffirmation(), ApiService.alarms()]);
      final alarms = (results[1] as List<Alarm>).where((a) => a.enabled).toList();
      if (!mounted) return;
      setState(() {
        _daily = results[0] as Affirmation?;
        _alarmCount = alarms.length;
        _next = _nextAlarm(alarms);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Soonest enabled alarm from now, honouring repeat days.
  Alarm? _nextAlarm(List<Alarm> alarms) {
    final now = DateTime.now();
    Alarm? best;
    Duration? bestIn;
    for (final a in alarms) {
      final p = a.time.split(':');
      for (var add = 0; add < 8; add++) {
        final d = now.add(Duration(days: add));
        final at = DateTime(d.year, d.month, d.day, int.parse(p[0]), int.parse(p[1]));
        if (!at.isAfter(now)) continue;
        if (a.repeatDays.isNotEmpty && !a.repeatDays.contains(at.weekday)) continue;
        final diff = at.difference(now);
        if (bestIn == null || diff < bestIn) { best = a; bestIn = diff; }
        break;
      }
    }
    return best;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
  }

  Future<void> _fav() async {
    final d = _daily;
    if (d == null) return;
    try {
      await ApiService.toggleFavorite(d.id);
      if (!mounted) return;
      haptic();
      setState(() => _daily = Affirmation(id: d.id, text: d.text, category: d.category, isFavorite: !d.isFavorite));
      if (!d.isFavorite) _burst.currentState?.play(); // no reload: the heart just pops
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  /// Double-tap on the card: like it (and always play the heart).
  Future<void> _like() async {
    haptic(strong: true);
    if (_daily?.isFavorite == true) {
      _burst.currentState?.play();
    } else {
      await _fav();
    }
  }

  /// Tap the card: open the full-screen swipe feed, starting at today's quote.
  Future<void> _openFeed() async {
    try {
      final items = await ApiService.affirmations();
      if (items.isEmpty || !mounted) return;
      final start = items.indexWhere((a) => a.id == _daily?.id);
      await Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteViewerScreen(items: items, startIndex: start < 0 ? 0 : start)));
      if (mounted) _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  void _cycleTheme() {
    haptic();
    final next = (ThemeStore.index.value + 1) % quoteThemes.length;
    ThemeStore.index.value = next;
    ApiService.updateProfile(theme: next).catchError((_) {});
  }

  /// Show a random affirmation from the user's library (the daily one returns on refresh).
  Future<void> _shuffle() async {
    try {
      final all = await ApiService.affirmations();
      if (all.isEmpty) return;
      final others = all.where((a) => a.id != _daily?.id).toList();
      final pick = (others.isEmpty ? all : others)[Random().nextInt(others.isEmpty ? all.length : others.length)];
      if (mounted) setState(() => _daily = pick);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _starter() async {
    try {
      final n = await ApiService.starterPack();
      if (mounted) showSnack(context, n == 0 ? 'You already have them all' : 'Added $n affirmations');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (AuthService.currentUser?.displayName ?? '').split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: Text(name.isEmpty ? _greeting : '$_greeting, $name'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/logo.png', height: 36)),
          ),
        ],
      ),
      body: AsyncView(
        loading: _loading,
        error: _error,
        onRetry: _load,
        builder: () => RefreshIndicator(
          color: purple,
          onRefresh: () => _load(silent: true),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
            FadeSlideIn(index: 0, child: _dailyCard()),
            const SizedBox(height: 16),
            FadeSlideIn(index: 3, child: _alarmCard()),
          ]),
        ),
      ),
    );
  }

  Widget _dailyCard() {
    if (_daily == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: glassDeco(28),
        child: EmptyState(
          icon: Icons.auto_awesome,
          title: 'Start your first affirmation',
          message: 'Add the starter pack (99 hand-written affirmations) or write your own. One shows up here each day.',
          actionLabel: 'Add starter pack',
          onAction: _starter,
        ),
      );
    }
    return Column(children: [
      GestureDetector(
        onTap: _openFeed,
        onDoubleTap: _like,
        child: Stack(children: [
          ValueListenableBuilder<int>(
            valueListenable: ThemeStore.index,
            builder: (_, i, __) => QuoteCard(text: _daily!.text, category: _daily!.category, themeIndex: i, height: 400),
          ),
          const Positioned(top: 20, right: 22, child: Icon(Icons.unfold_more_rounded, color: Colors.white70)),
          Positioned.fill(child: IgnorePointer(child: HeartBurst(key: _burst))),
        ]),
      ),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _action(Icons.ios_share_rounded, 'Share', () => shareQuote(context, _daily!.text)),
        _action(_daily!.isFavorite ? Icons.favorite : Icons.favorite_border, 'Favorite', _fav,
            color: _daily!.isFavorite ? pink : Colors.white),
        _action(Icons.shuffle_rounded, 'Shuffle', _shuffle),
        _action(Icons.palette_outlined, 'Theme', _cycleTheme),
        _action(Icons.add_rounded, 'Add', () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AffirmationFormScreen()));
          _load();
        }),
      ]),
    ]);
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color color = Colors.white}) => Pressable(child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          haptic();
          onTap();
        },
        child: Column(children: [
          Container(
            width: 54,
            height: 54,
            decoration: glassDeco(27),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
        ]),
      ));

  Widget _alarmCard() => InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => widget.onOpenTab(2),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: glassDeco(24),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: brandGradient),
              child: const Icon(Icons.alarm_rounded, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _next == null
                  ? const Text('No alarms on. Tap to set one.', style: TextStyle(fontSize: 15))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Next alarm', style: TextStyle(color: muted, fontSize: 12)),
                      GradientText(_next!.prettyTime, serif(26)),
                      Text('${_next!.label.isEmpty ? 'Alarm' : _next!.label} · ${_next!.repeatLabel}',
                          style: const TextStyle(color: muted, fontSize: 12)),
                    ]),
            ),
            Text('$_alarmCount on', style: const TextStyle(color: muted, fontSize: 12)),
          ]),
        ),
      );
}
