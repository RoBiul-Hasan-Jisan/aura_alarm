import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Light vibration on supported phones (does nothing on web/desktop).
void haptic({bool strong = false}) {
  try {
    strong ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
  } catch (_) {}
}

/// Fades and slides a child up. [index] staggers list items.
class FadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;
  final double dy;
  const FadeSlideIn({super.key, this.index = 0, required this.child, this.dy = 22});
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: math.min(widget.index, 8) * 60), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (_, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, (1 - _a.value) * widget.dy), child: child),
        ),
        child: widget.child,
      );
}

/// Gives anything a soft "press in" feel (taps still go to the child).
class Pressable extends StatefulWidget {
  final Widget child;
  final double scale;
  const Pressable({super.key, required this.child, this.scale = 0.96});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Sweeping highlight used by skeleton loaders.
class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (_, child) => ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (r) => LinearGradient(
            begin: Alignment(-2 + 4 * _c.value, -0.3),
            end: Alignment(-1 + 4 * _c.value, 0.3),
            colors: const [Color(0x00FFFFFF), Color(0x55FFFFFF), Color(0x00FFFFFF)],
          ).createShader(r),
          child: child,
        ),
      );
}

/// Placeholder cards shown while data loads (smoother than a spinner).
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) => Shimmer(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (_, i) => Container(
            height: i == 0 ? 190 : 92,
            decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(24)),
          ),
        ),
      );
}

/// Big heart + little hearts, like double-tap-to-like. Call `key.currentState?.play()`.
class HeartBurst extends StatefulWidget {
  const HeartBurst({super.key});
  @override
  State<HeartBurst> createState() => HeartBurstState();
}

class HeartBurstState extends State<HeartBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));

  void play() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          if (t == 0 || t == 1) return const SizedBox.shrink();
          final pop = Curves.elasticOut.transform(math.min(1.0, t * 1.5));
          final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Stack(alignment: Alignment.center, children: [
              for (var i = 0; i < 7; i++)
                Transform.translate(
                  offset: Offset.fromDirection(-math.pi / 2 + (i - 3) * 0.55, 30 + 120 * Curves.easeOut.transform(t)),
                  child: Icon(Icons.favorite, size: 14 + (i % 3) * 6, color: i.isEven ? const Color(0xFFEC4899) : Colors.white),
                ),
              Transform.scale(
                scale: 0.3 + pop * 0.9,
                child: const Icon(Icons.favorite, size: 120, color: Colors.white,
                    shadows: [Shadow(blurRadius: 34, color: Color(0xFFEC4899))]),
              ),
            ]),
          );
        },
      );
}

/// Every screen change: soft fade + tiny rise + settle (all platforms, including web).
class SmoothTransitionsBuilder extends PageTransitionsBuilder {
  const SmoothTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.05), end: Offset.zero).animate(curved),
        child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(curved), child: child),
      ),
    );
  }
}
