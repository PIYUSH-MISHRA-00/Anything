import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../memory/memory_manager.dart';
import 'app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _personalContextLearning = false;

  final List<Map<String, String>> _pages = [
    {
      'title': 'Welcome to Anything',
      'subtitle': 'The AI-first computing interface where you express intent, not click buttons.',
      'icon': 'hub',
    },
    {
      'title': 'Ask for what you want',
      'subtitle': 'Simply ask "Plan my trip" or "Show my tasks" and watch the interface assemble itself.',
      'icon': 'chat_bubble_outline',
    },
    {
      'title': 'AI-generated workspaces',
      'subtitle': 'Anything dynamically brings you the charts, tables, and tools you need.',
      'icon': 'dashboard',
    },
    {
      'title': 'Privacy and encryption',
      'subtitle': 'Your data is secured locally using Kaalka time-key encryption. No cloud storage.',
      'icon': 'lock_outline',
    },
  ];

  void _finishOnboarding() async {
    final memoryManager = ref.read(memoryManagerProvider);
    await memoryManager.savePreference('personal_context_learning_enabled', _personalContextLearning.toString());
    await memoryManager.savePreference('onboarding_completed', 'true');
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getIcon(_pages[index]['icon']!),
                          size: 100,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(height: 40),
                        Text(
                          _pages[index]['title']!,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _pages[index]['subtitle']!,
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        if (index == 3) ...[
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                            ),
                            child: SwitchListTile(
                              title: const Text('Enable Personal Context Learning', style: TextStyle(color: Colors.white)),
                              subtitle: const Text('Allows system to learn preferred tools and workflows locally.', style: TextStyle(color: Colors.white54)),
                              value: _personalContextLearning,
                              onChanged: (val) {
                                setState(() {
                                  _personalContextLearning = val;
                                });
                              },
                              activeThumbColor: Colors.blueAccent,
                            ),
                          )
                        ]
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index ? Colors.blueAccent : Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage == _pages.length - 1) {
                        _finishOnboarding();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(_currentPage == _pages.length - 1 ? 'Get Started' : 'Next', style: const TextStyle(fontSize: 16)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'hub': return Icons.hub;
      case 'chat_bubble_outline': return Icons.chat_bubble_outline;
      case 'dashboard': return Icons.dashboard;
      case 'lock_outline': return Icons.lock_outline;
      default: return Icons.star;
    }
  }
}
