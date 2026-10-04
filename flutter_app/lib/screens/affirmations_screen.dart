import 'package:flutter/material.dart';
import '../config.dart';
import '../fx.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'affirmation_form_screen.dart';
import 'affirmation_list_screen.dart';

/// Category grid (like the reference app): counts, follow toggle, tap to open that category.
class AffirmationsScreen extends StatefulWidget {
  const AffirmationsScreen({super.key});
  @override
  State<AffirmationsScreen> createState() => _AffirmationsScreenState();
}

class _AffirmationsScreenState extends State<AffirmationsScreen> {
  bool _loading = true;
  String? _error;
  int _total = 0, _favorites = 0;
  Map<String, int> _counts = {};
  Set<String> _followed = {};
  int _tileIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait([ApiService.categorySummary(), ApiService.me()]);
      final sum = r[0];
      final me = r[1];
      if (!mounted) return;
      setState(() {
        _total = sum['total'] ?? 0;
        _favorites = sum['favorites'] ?? 0;
        _counts = Map<String, int>.from((sum['categories'] as Map).map((k, v) => MapEntry(k as String, v as int)));
        _followed = Set<String>.from(me['followedCategories'] ?? []);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollow(String c) async {
    final was = _followed.contains(c);
    setState(() => was ? _followed.remove(c) : _followed.add(c)); // optimistic
    try {
      await ApiService.updateProfile(followed: _followed.toList());
    } catch (e) {
      if (!mounted) return;
      setState(() => was ? _followed.add(c) : _followed.remove(c));
      showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _open(String title, {String? category, bool favorites = false}) async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => AffirmationListScreen(title: title, category: category, favoritesOnly: favorites)));
    _load();
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
    _tileIndex = 0;
    final tiles = <Widget>[
      _tile('All', 'All', '$_total quotes', 0, () => _open('All affirmations')),
      _tile('Favorites', 'Favorites', '$_favorites saved', 1, () => _open('Favorites', favorites: true)),
      for (var i = 0; i < kCategories.length; i++)
        _tile(kCategories[i], kCategories[i], '${_counts[kCategories[i]] ?? 0} quotes', i + 1,
            () => _open(kCategories[i], category: kCategories[i]),
            followable: true),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Affirmations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AffirmationFormScreen()));
          _load();
        },
        backgroundColor: dawn,
        foregroundColor: ink,
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: AsyncView(
        loading: _loading,
        error: _error,
        onRetry: _load,
        builder: () => RefreshIndicator(
          onRefresh: () => _load(silent: true),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 96), children: [
            if (_total == 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: glassDeco(22),
                child: Row(children: [
                  const Icon(Icons.auto_awesome, color: dawn),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Your library is empty. Add a ready-made starter pack?')),
                  TextButton(onPressed: _starter, child: const Text('Add')),
                ]),
              ),
            Text('Follow the themes you need. Your daily affirmation is drawn from them.',
                style: const TextStyle(color: muted)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.98,
              children: tiles,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tile(String key, String title, String subtitle, int themeIdx, VoidCallback onTap, {bool followable = false}) {
    final colors = quoteThemes[themeIdx % quoteThemes.length].colors;
    final following = _followed.contains(key);
    return FadeSlideIn(index: _tileIndex++, child: Pressable(child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        haptic();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          boxShadow: [BoxShadow(color: colors.first.withAlpha(70), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(alignment: Alignment.topRight, child: Icon(categoryIcon(key), color: Colors.white70, size: 28)),
          const Spacer(),
          Text(title, style: serif(16, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          if (followable) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                haptic();
                _toggleFollow(key);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: following ? Colors.white : Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(following ? Icons.check_circle : Icons.add, size: 14, color: following ? ink : Colors.white),
                  const SizedBox(width: 4),
                  Text(following ? 'Following' : 'Follow',
                      style: TextStyle(fontSize: 11, color: following ? ink : Colors.white, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
          ],
        ]),
      ),
    )));
  }
}
