import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'fx.dart';
import 'theme.dart';

/// Midnight background with soft violet and orange glows that drift slowly. Applied once in MaterialApp.builder.
class AuraBackground extends StatefulWidget {
  final Widget child;
  const AuraBackground({super.key, required this.child});
  @override
  State<AuraBackground> createState() => _AuraBackgroundState();
}

class _AuraBackgroundState extends State<AuraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _glow(Color c, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [c.withAlpha(105), c.withAlpha(0)]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final glowA = _glow(purple, 420), glowB = _glow(dawn, 400), glowC = _glow(pink, 300);
    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: ink)),
      AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = Curves.easeInOut.transform(_c.value);
          return Stack(children: [
            Positioned(top: -140 + 50 * t, left: -120 + 70 * t, child: glowA),
            Positioned(bottom: -160 + 60 * (1 - t), right: -140 + 60 * t, child: glowB),
            Positioned(top: 260 - 80 * t, right: -200 + 60 * (1 - t), child: Opacity(opacity: .55, child: glowC)),
          ]);
        },
      ),
      Positioned.fill(child: widget.child),
    ]);
  }
}

/// Text filled with the violet → pink → orange brand gradient.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  const GradientText(this.text, this.style, {super.key});

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => brandGradient.createShader(r),
        child: Text(text, style: style.copyWith(color: Colors.white)),
      );
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? const Color(0xFFB3261E) : const Color(0xFF2A2548),
    ));
}

Future<bool> confirmDialog(BuildContext context,
    {required String title, required String body, String confirm = 'Delete'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(color: muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(96, 44), backgroundColor: const Color(0xFFE5484D)),
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: brandGradient),
              child: Icon(icon, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text(title, style: serif(20), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
            if (actionLabel != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(190, 48)),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ]),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn’t load this',
        message: message,
        actionLabel: 'Try again',
        onAction: onRetry,
      );
}

/// Shows spinner / error / content.
class AsyncView<T> extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final Widget Function() builder;
  const AsyncView({super.key, required this.loading, required this.error, required this.onRetry, required this.builder});

  @override
  Widget build(BuildContext context) {
    if (loading) return const SkeletonList();
    if (error != null) return ErrorState(message: error!, onRetry: onRetry);
    return builder();
  }
}

/// Big glowing gradient quote card – the signature element.
class QuoteCard extends StatelessWidget {
  final String text;
  final String category;
  final int themeIndex;
  final double? height;
  const QuoteCard({super.key, required this.text, required this.category, required this.themeIndex, this.height});

  @override
  Widget build(BuildContext context) {
    final t = quoteThemes[themeIndex % quoteThemes.length];
    final size = text.length < 45 ? 32.0 : (text.length < 90 ? 27.0 : 22.0);
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: t.colors),
        boxShadow: [BoxShadow(color: t.colors.first.withAlpha(110), blurRadius: 40, offset: const Offset(0, 18))],
      ),
      child: Stack(children: [
        Positioned(top: -4, left: -2, child: Text('“', style: serif(96, color: Colors.white30))),
        Column(children: [
          const SizedBox(height: 26),
          Expanded(
            child: Center(
              child: TweenAnimationBuilder<double>(
                key: ValueKey(text), // new quote -> text fades up again
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 750),
                curve: Curves.easeOutCubic,
                builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: c)),
                child: Text(text, textAlign: TextAlign.center, style: serif(size, w: FontWeight.w700)),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
            child: Text(category.toUpperCase(),
                style: const TextStyle(fontSize: 11, letterSpacing: 1.6, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }
}

/// Share a quote. Falls back to copying it when the browser/device has no share sheet.
Future<void> shareQuote(BuildContext context, String text) async {
  final msg = '“$text”\n— Aura Alarm';
  try {
    await Share.share(msg);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: msg));
    if (context.mounted) showSnack(context, 'Copied to clipboard');
  }
}
