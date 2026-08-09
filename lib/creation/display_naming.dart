/// Human-readable names for generated Experiences — IS-P08.
///
/// WHY THIS EXISTS.
///
/// Generated Experiences reached the user carrying their internal
/// identifiers: an app called `task_manager`, whose screens were labelled
/// `task_list` and `task_detail`. Those are perfectly good ids and terrible
/// names. The model is asked for human wording and sometimes supplies it, but
/// a product cannot depend on that — the display layer needs a name it can
/// show whatever the model returned.
///
/// This module is pure and deterministic. It converts; it never invents. If
/// the model already returned "Daily Planner" it is passed through unchanged,
/// because second-guessing good input is how you turn it into bad output.
library;

/// Turns an identifier-shaped string into a title-cased label.
///
/// `task_list` → `Task List`, `taskList` → `Task List`, `Daily Planner` →
/// `Daily Planner`. Returns the input unchanged when it is already prose.
String humanLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  // Already prose: contains a space and no separator/camel-case shape.
  final looksLikeIdentifier =
      trimmed.contains('_') ||
      trimmed.contains('-') ||
      (!trimmed.contains(' ') && _hasInnerCapital(trimmed));
  if (!looksLikeIdentifier) {
    return _capitaliseFirst(trimmed);
  }

  final spaced = trimmed
      .replaceAll(RegExp(r'[_\-]+'), ' ')
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), (_) => ' ');

  return spaced
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map(_capitaliseWord)
      .join(' ');
}

/// The name shown to the user for a whole Experience.
///
/// Prefers a human name the model supplied. Falls back to the user's own
/// words, because "Todo List To Track My Tasks" is a worse title than
/// "Task Manager" but a far better one than `task_manager`, and it is at
/// least recognisably the thing they asked for.
String experienceDisplayName({
  required String generatedName,
  String? userIntent,
}) {
  final fromModel = humanLabel(generatedName);
  if (fromModel.isNotEmpty && !_isPlaceholder(fromModel)) return fromModel;

  final fromIntent = _titleFromIntent(userIntent ?? '');
  return fromIntent.isNotEmpty ? fromIntent : 'New App';
}

/// Names that carry no meaning and should never reach a user.
bool _isPlaceholder(String name) {
  final n = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return n.isEmpty ||
      const {
        'app',
        'app1',
        'newapp',
        'generatedapp',
        'myapp',
        'untitled',
        'generated',
        'experience',
      }.contains(n);
}

/// A short title from a raw request like "a todo list to track my tasks".
String _titleFromIntent(String intent) {
  var words = intent
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();

  // Drop a leading article; "A Todo List" reads worse than "Todo List".
  if (words.isNotEmpty &&
      const {'a', 'an', 'the'}.contains(words.first.toLowerCase())) {
    words = words.sublist(1);
  }
  // Everything from "to"/"that"/"for" onward is a clause, not a name.
  final clause = words.indexWhere(
    (w) =>
        const {'to', 'that', 'for', 'which', 'with'}.contains(w.toLowerCase()),
  );
  if (clause > 0) words = words.sublist(0, clause);

  return words.take(4).map(_capitaliseWord).join(' ');
}

bool _hasInnerCapital(String s) => RegExp(r'(?<=[a-z0-9])[A-Z]').hasMatch(s);

String _capitaliseWord(String w) =>
    w.length <= 1 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1);

String _capitaliseFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
