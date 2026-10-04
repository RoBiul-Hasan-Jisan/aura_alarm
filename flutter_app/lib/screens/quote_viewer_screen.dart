import 'package:flutter/material.dart';
import '../fx.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'affirmation_form_screen.dart';

/// Reels-style feed: swipe up/down through quotes. Double-tap to like, share, edit, delete, pick a mood theme.
class QuoteViewerScreen extends StatefulWidget {
  final List<Affirmation> items;
  final int startIndex;
  const QuoteViewerScreen({super.key, required this.items, required this.startIndex});
  @override
  State<QuoteViewerScreen> createState() => _QuoteViewerScreenState();
}

class _QuoteViewerScreenState extends State<QuoteViewerScreen> {
  late final PageController _pc;
  late List<Affirmation> _items;
  final _burst = GlobalKey<HeartBurstState>();
  int _page = 0;
  bool _hint = true;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
    _page = widget.startIndex;
    _pc = PageController(initialPage: widget.startIndex);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _hint = false);
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Affirmation get _cur => _items[_page];

  Future<void> _fav() async {
    final a = _cur;
    final idx = _page;
    try {
      await ApiService.toggleFavorite(a.id);
      if (!mounted) return;
      setState(() => _items[idx] = Affirmation(id: a.id, text: a.text, category: a.category, isFavorite: !a.isFavorite));
      if (!a.isFavorite) _burst.currentState?.play();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _like() async {
    haptic(strong: true);
    if (_cur.isFavorite) {
      _burst.currentState?.play(); // already liked: just the animation
    } else {
      await _fav();
    }
  }

  Future<void> _edit() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AffirmationFormScreen(existing: _cur)));
    if (mounted) Navigator.pop(context); // list screen reloads and shows the change
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete affirmation?', body: 'Alarms using it will keep working but won’t show an affirmation.');
    if (!ok) return;
    try {
      await ApiService.deleteAffirmation(_cur.id);
      if (!mounted) return;
      showSnack(context, 'Affirmation deleted');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  void _setTheme(int i) {
    haptic();
    ThemeStore.index.value = i;
    ApiService.updateProfile(theme: i).catchError((_) {});
  }

  void _go(int delta) {
    haptic();
    _pc.animateToPage((_page + delta).clamp(0, _items.length - 1),
        duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text('${_page + 1} of ${_items.length}', style: const TextStyle(fontSize: 16)),
          actions: [
            IconButton(tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
            IconButton(tooltip: 'Delete', onPressed: _delete, icon: const Icon(Icons.delete_outline)),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: Stack(children: [
                ValueListenableBuilder<int>(
                  valueListenable: ThemeStore.index,
                  builder: (_, themeIdx, __) => PageView.builder(
                    controller: _pc,
                    scrollDirection: Axis.vertical,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    onPageChanged: (i) {
                      haptic();
                      setState(() => _page = i);
                    },
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _pc,
                      builder: (_, child) {
                        var page = _page.toDouble();
                        if (_pc.hasClients && _pc.position.haveDimensions) page = _pc.page ?? page;
                        final d = (page - i).abs().clamp(0.0, 1.0); // cards shrink and fade as they leave
                        return Opacity(opacity: 1 - 0.55 * d, child: Transform.scale(scale: 1 - 0.08 * d, child: child));
                      },
                      child: GestureDetector(
                        onDoubleTap: _like,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: QuoteCard(text: _items[i].text, category: _items[i].category, themeIndex: themeIdx),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: IgnorePointer(child: HeartBurst(key: _burst))),
                Positioned(
                  bottom: 22,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _hint ? 1 : 0,
                      duration: const Duration(milliseconds: 500),
                      child: const Text('Double-tap to like · swipe for more',
                          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ),
                  ),
                ),
              ]),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < quoteThemes.length; i++)
                GestureDetector(
                  onTap: () => _setTheme(i),
                  child: ValueListenableBuilder<int>(
                    valueListenable: ThemeStore.index,
                    builder: (_, sel, __) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      width: sel == i ? 36 : 30,
                      height: sel == i ? 36 : 30,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: quoteThemes[i].colors),
                        border: Border.all(color: sel == i ? Colors.white : Colors.white24, width: 2.5),
                      ),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _btn(Icons.keyboard_arrow_up_rounded, 'Prev', () => _go(-1)),
              _btn(Icons.ios_share_rounded, 'Share', () => shareQuote(context, _cur.text)),
              _btn(_cur.isFavorite ? Icons.favorite : Icons.favorite_border, 'Favorite', () {
                haptic();
                _fav();
              }, color: _cur.isFavorite ? pink : purple),
              _btn(Icons.keyboard_arrow_down_rounded, 'Next', () => _go(1)),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      );

  Widget _btn(IconData icon, String label, VoidCallback onTap, {Color color = purple}) => Pressable(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(icon, key: ValueKey('$icon$color'), color: color, size: 28),
              ),
              Text(label, style: const TextStyle(fontSize: 12, color: muted)),
            ]),
          ),
        ),
      );
}
