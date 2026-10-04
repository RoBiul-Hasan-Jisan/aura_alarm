import 'package:flutter/material.dart';
import '../fx.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'affirmation_form_screen.dart';
import 'quote_viewer_screen.dart';

/// Quotes in one category / favorites / all. Tap a card to open the swipeable viewer.
class AffirmationListScreen extends StatefulWidget {
  final String title;
  final String? category;
  final bool favoritesOnly;
  const AffirmationListScreen({super.key, required this.title, this.category, this.favoritesOnly = false});
  @override
  State<AffirmationListScreen> createState() => _AffirmationListScreenState();
}

class _AffirmationListScreenState extends State<AffirmationListScreen> {
  bool _loading = true;
  String? _error;
  List<Affirmation> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final items = await ApiService.affirmations(category: widget.category, favoritesOnly: widget.favoritesOnly);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add([Affirmation? a]) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AffirmationFormScreen(existing: a, initialCategory: widget.category)));
    _load();
  }

  Future<void> _view(int i) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => QuoteViewerScreen(items: _items, startIndex: i)));
    _load();
  }

  Future<void> _toggleFav(Affirmation a) async {
    try {
      await ApiService.toggleFavorite(a.id);
      _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _delete(Affirmation a) async {
    final ok = await confirmDialog(context,
        title: 'Delete affirmation?', body: 'Alarms using it will keep working but won’t show an affirmation.');
    if (!ok) return;
    try {
      await ApiService.deleteAffirmation(a.id);
      if (mounted) showSnack(context, 'Affirmation deleted');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _add(),
          backgroundColor: dawn,
          foregroundColor: ink,
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
        body: AsyncView(
          loading: _loading,
          error: _error,
          onRetry: _load,
          builder: () => _items.isEmpty
              ? EmptyState(
                  icon: Icons.format_quote_rounded,
                  title: widget.favoritesOnly ? 'No favorites yet' : 'Nothing here yet',
                  message: widget.favoritesOnly
                      ? 'Tap the heart on a quote to keep it here.'
                      : 'Write a few kind sentences to start your mornings with.',
                  actionLabel: widget.favoritesOnly ? null : 'Add affirmation',
                  onAction: () => _add(),
                )
              : RefreshIndicator(
                  onRefresh: () => _load(silent: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => FadeSlideIn(index: i, child: Builder(builder: (_) {
                      final a = _items[i];
                      final colors = quoteThemes[i % quoteThemes.length].colors;
                      return Dismissible(
                        key: ValueKey(a.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async { await _delete(a); return false; },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(color: const Color(0xFFB3261E), borderRadius: BorderRadius.circular(22)),
                          child: const Icon(Icons.delete_outline, color: Colors.white),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _view(i),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(a.text, style: serif(17)),
                                  const SizedBox(height: 10),
                                  Text(a.category, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                ]),
                              ),
                              IconButton(
                                tooltip: a.isFavorite ? 'Remove favorite' : 'Add favorite',
                                onPressed: () {
                                  haptic();
                                  _toggleFav(a);
                                },
                                icon: Icon(a.isFavorite ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                              ),
                            ]),
                          ),
                        ),
                      );
                    })),
                  ),
                ),
        ),
      );
}
