/// First-launch onboarding — Implementation Specification IS-P05 finding 11.
///
/// Before this, first launch dropped straight onto an empty Home screen. A new
/// user saw a text field, no explanation of what an Experience is, and — with
/// no AI key configured — a `ProviderRequired` dead end. Every audit since the
/// Master Repository Audit called the first-run path the weakest part of the
/// product.
///
/// DESIGN NOTES.
///
/// Five screens, skippable, and REPLAYABLE from Settings (finding 12) — a
/// walkthrough you cannot see again is a walkthrough you have to get right on
/// the first read.
///
/// It says what is NOT built, in the same voice the rest of the project uses.
/// A new user who is told the truth early forgives a gap; one who discovers it
/// alone does not.
library;

import 'package:flutter/material.dart';

import '../../storage/durable_collection_store.dart';

/// Remembers whether onboarding has been seen.
///
/// Uses `DurableCollectionStore` — the ONE `SharedPreferences` owner
/// (IS-R56) — rather than opening a second preferences path.
class OnboardingState {
  static const String storageKey = 'anything.onboarding_completed';
  final DurableCollectionStore store;

  const OnboardingState({this.store = const DurableCollectionStore()});

  Future<bool> hasCompleted() async => (await store.read(storageKey)) == 'true';

  Future<void> markCompleted() =>
      store.update<void>(storageKey, (_) => (value: 'true', result: null));

  /// Lets the user replay the walkthrough (finding 12).
  Future<void> reset() => store.clear(storageKey);
}

class _Page {
  final IconData icon;
  final String title;
  final String body;
  final String? caveat;

  const _Page({
    required this.icon,
    required this.title,
    required this.body,
    this.caveat,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const List<_Page> _pages = [
    _Page(
      icon: Icons.auto_awesome,
      title: 'Describe what you need',
      body:
          'Most apps are a fixed set of screens someone decided on in advance. '
          'Anything inverts that: say what you want in your own words, and it '
          'designs and runs a real app to do it.',
    ),
    _Page(
      icon: Icons.widgets_outlined,
      title: 'You get an Experience',
      body:
          'Not a chat reply and not a file you now maintain. An Experience is '
          'a validated package with its own screens, behaviour and memory, '
          'which Anything runs natively. You can revise it, protect it, export '
          'it, or remove it completely.',
    ),
    _Page(
      icon: Icons.psychology_outlined,
      title: 'You bring the AI key',
      body:
          'Anything uses your own AI provider key, stored in the phone '
          'keystore. Nothing is uploaded and there is no account.',
      caveat:
          'Only Groq is supported today. Without a key, Anything runs but '
          'cannot create anything — Settings shows you where to add one.',
    ),
    _Page(
      icon: Icons.shield_outlined,
      title: 'Your device, and only your device',
      body:
          'Your apps, your knowledge and your keys stay here. There is no '
          'server and no sync. Protection uses Kaalka, which encrypts an app '
          'with a time key rather than a password you have to remember.',
      caveat:
          'Because nothing is in the cloud, losing the phone loses the apps. '
          'Export from My Apps is how you keep a copy.',
    ),
    _Page(
      icon: Icons.explore_outlined,
      title: 'Finding your way around',
      body:
          'Home is where you describe things. My Apps holds what you have '
          'made, and is where you protect, export and import. Activity is the '
          'history. Settings holds appearance, your AI provider and '
          'diagnostics.',
      caveat:
          'Anything is pre-release. Some things are deliberately unfinished, '
          'and it will say so rather than pretend otherwise.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await const OnboardingState().markCompleted();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: _finish, child: const Text('Skip')),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final page = _pages[i];
                  // Scrollable so large system font sizes cannot clip the
                  // content — the same defect IS-P03 found and fixed in the
                  // empty state.
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        ExcludeSemantics(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withAlpha(51),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Icon(
                              page.icon,
                              size: 42,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            letterSpacing: -0.5,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.body,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (page.caveat != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ExcludeSemantics(
                                  child: Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    page.caveat!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
              child: Row(
                children: [
                  Row(
                    children: List.generate(_pages.length, (i) {
                      final active = i == _index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        width: active ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: active
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant.withAlpha(77),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: isLast
                        ? _finish
                        : () => _controller.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                          ),
                    child: Text(isLast ? 'Get started' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
