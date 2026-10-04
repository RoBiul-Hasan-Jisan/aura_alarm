import 'package:flutter/material.dart';
import '../fx.dart';
import '../models.dart';
import '../services/alarm_scheduler.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'affirmations_screen.dart';
import 'alarms_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Bottom-navigation container. Each tab is rebuilt when selected, so it always shows fresh API data.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    AlarmScheduler.requestPermissions();
    ApiService.alarms().catchError((_) => <Alarm>[]); // schedule this user's alarms on the device
  }

  Future<void> _loadTheme() async {
    try {
      final me = await ApiService.me();
      ThemeStore.index.value = (me['theme'] ?? 0) as int;
    } catch (_) {/* default theme is fine */}
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onOpenTab: (i) => setState(() => _index = i)),
      const AffirmationsScreen(),
      const AlarmsScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(anim), child: child),
        ),
        child: KeyedSubtree(key: ValueKey(_index), child: pages[_index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i != _index) {
            haptic();
            setState(() => _index = i);
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.format_quote_outlined), selectedIcon: Icon(Icons.format_quote_rounded), label: 'Affirmations'),
          NavigationDestination(icon: Icon(Icons.alarm_outlined), selectedIcon: Icon(Icons.alarm_rounded), label: 'Alarms'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
