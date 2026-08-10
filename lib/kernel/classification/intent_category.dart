/// Intent classification types for Anything.
///
/// Typed categories that the Kernel uses to route intent processing.
library;

/// Categories of user intent.
enum IntentCategory {
  /// User wants to create a new Experience.
  create,

  /// User wants to open an existing Experience.
  open,

  /// User wants to modify an existing Experience.
  modify,

  /// User wants to continue working on something.
  continueAction,

  /// User is asking a question.
  ask,

  /// User wants research or information gathering.
  research,

  /// User wants to transform data or content.
  transform,

  /// User wants to automate a task.
  automate,

  /// System-level action (settings, preferences, etc.).
  systemAction,

  /// Intent could not be classified.
  unknown,
}

/// Classifies a raw expression into an [IntentCategory].
///
/// Uses deterministic heuristics first, then falls back to
/// model-assisted classification when needed.
class IntentClassifier {
  /// Classify a raw expression into a category.
  ///
  /// Returns the most likely category based on heuristics.
  /// Model-assisted classification can override this when available.
  IntentCategory classify(String expression) {
    final lower = expression.toLowerCase().trim();

    // Explicit creation verbs win over incidental feature words
    // ("update repair status", "edit forms") that appear inside a create ask.
    if (_matchesPattern(lower, [
      'create a',
      'create an',
      'build a',
      'build an',
      'make a new',
      'generate a',
      'generate an',
    ])) {
      return IntentCategory.create;
    }

    // Open patterns
    if (_matchesPattern(lower, ['open', 'show me', 'go to', 'launch'])) {
      return IntentCategory.open;
    }

    // Modify patterns
    if (_matchesPattern(lower, [
      'change',
      'modify',
      'update',
      'edit',
      'make it',
      'adjust',
      'configure',
    ])) {
      return IntentCategory.modify;
    }

    // Ask patterns
    if (_matchesPattern(lower, [
      'what is',
      'what are',
      'how do',
      'how does',
      'why',
      'when',
      'where',
      'who',
      'explain',
      'tell me about',
    ])) {
      return IntentCategory.ask;
    }

    // Research patterns
    if (_matchesPattern(lower, [
      'research',
      'investigate',
      'find out',
      'look into',
      'survey',
    ])) {
      return IntentCategory.research;
    }

    // Transform patterns
    if (_matchesPattern(lower, [
      'summarize',
      'convert',
      'transform',
      'translate',
      'extract',
      'parse',
    ])) {
      return IntentCategory.transform;
    }

    // Automate patterns
    if (_matchesPattern(lower, [
      'automate',
      'schedule',
      'remind',
      'alert',
      'notify',
      'trigger',
    ])) {
      return IntentCategory.automate;
    }

    // System patterns
    if (_matchesPattern(lower, [
      'settings',
      'preferences',
      'theme',
      'provider',
      'configure',
    ])) {
      return IntentCategory.systemAction;
    }

    // Continue patterns
    if (_matchesPattern(lower, [
      'continue',
      'resume',
      'go back to',
      'keep working',
    ])) {
      return IntentCategory.continueAction;
    }

    // Default: likely a creation intent
    return IntentCategory.create;
  }

  bool _matchesPattern(String text, List<String> patterns) {
    return patterns.any((p) => text.startsWith(p) || text.contains(p));
  }
}
