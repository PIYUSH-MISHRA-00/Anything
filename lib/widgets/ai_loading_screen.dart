import 'package:flutter/material.dart';
import 'dart:async';

class AILoadingScreen extends StatefulWidget {
  const AILoadingScreen({super.key});

  @override
  State<AILoadingScreen> createState() => _AILoadingScreenState();
}

class _AILoadingScreenState extends State<AILoadingScreen>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  final List<_LoadingStage> _stages = [
    _LoadingStage(Icons.search, 'Analyzing request...'),
    _LoadingStage(Icons.build, 'Selecting tools...'),
    _LoadingStage(Icons.dashboard_customize, 'Preparing workspace...'),
    _LoadingStage(Icons.auto_awesome, 'Generating interface...'),
    _LoadingStage(Icons.check_circle_outline, 'Finalizing layout...'),
  ];

  Timer? _timer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _fadeController.forward();

    _timer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (_currentStep < _stages.length - 1) {
        _fadeController.reverse().then((_) {
          if (mounted) {
            setState(() => _currentStep++);
            _fadeController.forward();
          }
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_stages.length, (index) {
                final isActive = index <= _currentStep;
                final isCurrent = index == _currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isCurrent ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.blueAccent
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 48),

            // Animated icon
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _stages[_currentStep].icon,
                  size: 40,
                  color: Colors.blueAccent,
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Stage label
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                _stages[_currentStep].label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Subtle progress indicator
            SizedBox(
              width: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentStep + 1) / _stages.length,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  minHeight: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingStage {
  final IconData icon;
  final String label;
  const _LoadingStage(this.icon, this.label);
}
