import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'fx.dart';

// Midnight base + the logo's violet / pink / sunrise-orange glow.
const ink = Color(0xFF0A0916); // near-black indigo (also used for text on bright fills)
const mist = ink;
const purple = Color(0xFF8B5CF6);
const pink = Color(0xFFEC4899);
const dawn = Color(0xFFFF9A3D);
const muted = Color(0xFFA7A3C2);
const surface = Color(0xFF16132B);

const brandGradient = LinearGradient(colors: [purple, pink, dawn]);

/// Frosted-glass look for cards (sits on top of the aurora background).
BoxDecoration glassDeco([double r = 20]) => BoxDecoration(
      color: const Color(0x14FFFFFF),
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: const Color(0x26FFFFFF)),
    );

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark)
      .copyWith(primary: purple, secondary: dawn, surface: surface);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.dark);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    pageTransitionsTheme: PageTransitionsTheme(builders: {
      for (final p in TargetPlatform.values) p: const SmoothTransitionsBuilder(),
    }),
    textTheme: GoogleFonts.soraTextTheme(base.textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.sora(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0x14FFFFFF),
      labelStyle: const TextStyle(color: muted),
      hintStyle: const TextStyle(color: muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0x1FFFFFFF))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: purple, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: purple,
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.sora(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0x14FFFFFF),
      selectedColor: purple,
      side: BorderSide.none,
      labelStyle: const TextStyle(color: Colors.white),
      checkmarkColor: Colors.white,
      shape: const StadiumBorder(),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xF2100E24),
      indicatorColor: purple.withAlpha(110),
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.sora(fontSize: 11, color: Colors.white)),
    ),
  );
}

TextStyle serif(double size, {Color color = Colors.white, FontWeight w = FontWeight.w600}) =>
    GoogleFonts.sora(fontSize: size, color: color, fontWeight: w, height: 1.3);

/// Vivid gradient "mood" themes for quote cards.
class QuoteTheme {
  final String name;
  final List<Color> colors;
  const QuoteTheme(this.name, this.colors);
}

const quoteThemes = [
  QuoteTheme('Aurora', [Color(0xFF7C3AED), Color(0xFFDB2777)]),
  QuoteTheme('Sunrise', [Color(0xFFFF9A3D), Color(0xFFEC4899)]),
  QuoteTheme('Ocean', [Color(0xFF2563EB), Color(0xFF06B6D4)]),
  QuoteTheme('Midnight', [Color(0xFF312E81), Color(0xFF7C3AED)]),
  QuoteTheme('Forest', [Color(0xFF059669), Color(0xFF22D3EE)]),
  QuoteTheme('Ember', [Color(0xFFEF4444), Color(0xFFF59E0B)]),
];

/// Global holder for the user's chosen theme (loaded from the API after login).
class ThemeStore {
  static final index = ValueNotifier<int>(0);
}

IconData categoryIcon(String c) {
  switch (c) {
    case 'Morning': return Icons.wb_sunny_outlined;
    case 'Confidence': return Icons.bolt_rounded;
    case 'Self-Love': return Icons.favorite_border_rounded;
    case 'Gratitude': return Icons.spa_outlined;
    case 'Focus': return Icons.center_focus_strong_outlined;
    case 'Courage': return Icons.shield_outlined;
    case 'Calm': return Icons.self_improvement_rounded;
    case 'Health': return Icons.monitor_heart_outlined;
    case 'Success': return Icons.emoji_events_outlined;
    case 'Sleep': return Icons.bedtime_outlined;
    case 'All': return Icons.auto_awesome_outlined;
    case 'Favorites': return Icons.favorite_rounded;
    default: return Icons.auto_awesome_outlined;
  }
}
