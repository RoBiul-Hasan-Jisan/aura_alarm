import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.of(context).replace(oldRoute: ModalRoute.of(context)!, newRoute: MaterialPageRoute(builder: (_) => widget.next));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: 0.9 + 0.1 * v, child: child)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [BoxShadow(color: dawn.withAlpha(90), blurRadius: 60)],
                ),
                child: ClipRRect(borderRadius: BorderRadius.circular(40), child: Image.asset('assets/logo.png', height: 150)),
              ),
              const SizedBox(height: 28),
              GradientText('Aura Alarm', serif(34, w: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Wake up to something kind.', style: TextStyle(color: muted)),
            ]),
          ),
        ),
      );
}
