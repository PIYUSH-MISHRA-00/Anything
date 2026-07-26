import 'package:flutter/material.dart';
import '../widgets/custom_hub_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../memory/memory_manager.dart';
import 'onboarding_screen.dart';
import 'app_shell.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    // Give the splash animation time to display
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Check if onboarding has been completed
    try {
      final memoryManager = ref.read(memoryManagerProvider);
      final onboardingCompleted = await memoryManager.getPreference(
        'onboarding_completed',
      );

      if (!mounted) return;

      if (onboardingCompleted == 'true') {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const AppShell()));
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      }
    } catch (e) {
      // If the database isn't ready or any error, default to onboarding
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Deep slate background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Colors.blueAccent, Colors.transparent],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blueAccent.withValues(alpha: 0.5),
                          blurRadius: 40 * _animation.value,
                          spreadRadius: 10 * _animation.value,
                        ),
                      ],
                    ),
                    child: const CustomHubLogo(size: 50),
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            const Text(
              'Anything',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Turn AI into your interface',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
