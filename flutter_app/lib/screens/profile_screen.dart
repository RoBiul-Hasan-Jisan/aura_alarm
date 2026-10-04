import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'register_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final me = await ApiService.me();
      if (mounted) setState(() => _me = me);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _me?['name'] ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(controller: controller, autofocus: true, maxLength: 60, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.length < 2) return;
    try {
      await ApiService.updateName(name);
      await AuthService.currentUser?.updateDisplayName(name);
      if (mounted) showSnack(context, 'Name updated');
      _load();
    } catch (e) {
      if (mounted) showSnack(context, AuthService.message(e), error: true);
    }
  }

  bool get _isGuest => _me?['isGuest'] == true;

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: 'Log out?', body: _isGuest ? 'This is a demo account. If you log out, its sample data is gone for good. Create an account first to keep it.' : 'You’ll need to log in again to see your data.', confirm: 'Log out');
    if (ok) await AuthService.logout(); // AuthGate swaps to the login screen
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: AsyncView(
          loading: _loading,
          error: _error,
          onRetry: _load,
          builder: () {
            final stats = (_me?['stats'] ?? {}) as Map;
            final name = (_me?['name'] ?? '') as String;
            return ListView(padding: const EdgeInsets.all(20), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: glassDeco(22),
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: dawn,
                    child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: serif(24, color: ink)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name.isEmpty ? 'Your name' : name, style: serif(22)),
                      Text(_isGuest ? 'Demo account' : (_me?['email'] ?? ''), style: const TextStyle(color: muted)),
                    ]),
                  ),
                  IconButton(onPressed: _editName, icon: const Icon(Icons.edit_outlined)),
                ]),
              ),
              if (_isGuest) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dawn.withAlpha(35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: dawn.withAlpha(120)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.explore_outlined, color: dawn),
                      const SizedBox(width: 10),
                      Text('You’re exploring the demo', style: serif(15)),
                    ]),
                    const SizedBox(height: 6),
                    const Text('Everything works. Add, edit and delete freely. Create a free account to keep your data.',
                        style: TextStyle(color: muted, fontSize: 13)),
                    const SizedBox(height: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46), backgroundColor: dawn, foregroundColor: ink),
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                        _load();
                      },
                      child: const Text('Create free account'),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                _stat('Affirmations', stats['affirmations']),
                const SizedBox(width: 12),
                _stat('Favorites', stats['favorites']),
                const SizedBox(width: 12),
                _stat('Alarms', stats['alarms']),
              ]),
              const SizedBox(height: 20),
              Text('Mood theme', style: serif(18)),
              const SizedBox(height: 10),
              ValueListenableBuilder<int>(
                valueListenable: ThemeStore.index,
                builder: (_, sel, __) => Row(children: [
                  for (var i = 0; i < quoteThemes.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          ThemeStore.index.value = i;
                          ApiService.updateProfile(theme: i).catchError((_) {});
                        },
                        child: Container(
                          height: 54,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(colors: quoteThemes[i].colors),
                            border: Border.all(color: sel == i ? Colors.white : Colors.transparent, width: 2.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(quoteThemes[i].name, style: const TextStyle(fontSize: 10)),
                        ),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              Text('Followed: ${((_me?['followedCategories'] ?? []) as List).isEmpty ? 'none yet' : ((_me?['followedCategories']) as List).join(', ')}',
                  style: const TextStyle(color: muted)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: const Color(0xFFB3261E),
                  side: const BorderSide(color: Color(0xFFB3261E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ]);
          },
        ),
      );

  Widget _stat(String label, dynamic value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: glassDeco(18),
          child: Column(children: [
            Text('${value ?? 0}', style: serif(28)),
            Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          ]),
        ),
      );
}
