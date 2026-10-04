import 'package:flutter/material.dart';
import '../config.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../widgets.dart';

/// Add (existing == null) or Edit an affirmation. Pops `true` when saved.
class AffirmationFormScreen extends StatefulWidget {
  final Affirmation? existing;
  final String? initialCategory;
  const AffirmationFormScreen({super.key, this.existing, this.initialCategory});
  @override
  State<AffirmationFormScreen> createState() => _AffirmationFormScreenState();
}

class _AffirmationFormScreenState extends State<AffirmationFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _text;
  late String _category;
  late bool _fav;
  bool _saving = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.existing?.text ?? '');
    _category = widget.existing?.category ?? widget.initialCategory ?? 'General';
    _fav = widget.existing?.isFavorite ?? false;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final text = _text.text.trim();
      if (_editing) {
        await ApiService.updateAffirmation(widget.existing!.id, text, _category, _fav);
      } else {
        await ApiService.createAffirmation(text, _category, _fav);
      }
      if (!mounted) return;
      showSnack(context, _editing ? 'Changes saved' : 'Affirmation added');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_editing ? 'Edit affirmation' : 'New affirmation')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _text,
                  maxLines: 4,
                  maxLength: 280,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Your affirmation', hintText: 'I am calm, capable and ready for today.'),
                  validator: (v) {
                    final t = v?.trim() ?? '';
                    if (t.isEmpty) return 'Write an affirmation';
                    if (t.length < 3) return 'Make it at least 3 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'General'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text('Mark as favorite'),
                  value: _fav,
                  onChanged: (v) => setState(() => _fav = v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(_editing ? 'Save changes' : 'Add affirmation'),
                ),
              ]),
            ),
          ),
        ),
      );
}
