/// Visual identity for generated Experiences — IS-P08.
///
/// WHY THIS EXISTS.
///
/// Every generated Experience was drawn with the same sparkle glyph on the
/// same lilac square. Ten generated apps were ten identical rows, so the list
/// could only be read by its text, and nothing about an Experience was
/// recognisable at a glance.
///
/// This is a CURATED SEMANTIC MAPPING, not image generation. Nothing in this
/// repository can generate an image, and pretending otherwise would produce a
/// placeholder with extra steps. Instead an Experience's own words — its
/// name, category and tags — select from Material's icon set, and its
/// identity selects a stable hue. Same Experience, same icon, every time, on
/// every device, with no model call and no network.
library;

import 'package:flutter/material.dart';

/// An Experience's visual identity: what to draw and what colour to draw it.
class ExperienceVisualIdentity {
  final IconData icon;

  /// Index into a fixed palette, derived from the Experience id so that the
  /// same Experience always looks the same.
  final int paletteIndex;

  const ExperienceVisualIdentity({
    required this.icon,
    required this.paletteIndex,
  });

  /// Background appropriate to the current theme.
  Color background(ColorScheme scheme) =>
      _palette(scheme)[paletteIndex].withValues(alpha: 0.20);

  /// Foreground with enough contrast against [background] in both themes.
  Color foreground(ColorScheme scheme) => _palette(scheme)[paletteIndex];

  static List<Color> _palette(ColorScheme scheme) => [
    scheme.primary,
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFF03A9F4),
    const Color(0xFFE91E63),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
    const Color(0xFFFF5722),
  ];
}

/// Ordered keyword → icon table.
///
/// Ordered, not a plain map, because the FIRST match wins and specificity
/// matters: "expense tracker" must not be claimed by "track".
const List<(List<String>, IconData)> _iconRules = [
  (['calculat', 'math', 'arithmetic'], Icons.calculate_outlined),
  (['task', 'todo', 'to-do', 'checklist', 'chore'], Icons.checklist_outlined),
  (['habit', 'streak', 'routine'], Icons.repeat_outlined),
  (['weather', 'forecast', 'climate'], Icons.wb_cloudy_outlined),
  (['note', 'journal', 'diary', 'memo'], Icons.sticky_note_2_outlined),
  (
    ['expense', 'budget', 'finance', 'money', 'spend', 'cost'],
    Icons.account_balance_wallet_outlined,
  ),
  (['invoice', 'billing', 'payment'], Icons.receipt_long_outlined),
  (
    ['stock', 'portfolio', 'invest', 'market', 'trading'],
    Icons.trending_up_outlined,
  ),
  (
    ['recipe', 'cook', 'meal', 'food', 'kitchen'],
    Icons.restaurant_menu_outlined,
  ),
  (['grocery', 'shopping', 'cart', 'store'], Icons.shopping_cart_outlined),
  (
    ['planner', 'calendar', 'schedule', 'agenda', 'daily'],
    Icons.event_note_outlined,
  ),
  (['music', 'song', 'playlist', 'audio'], Icons.music_note_outlined),
  (['photo', 'camera', 'image', 'gallery'], Icons.photo_camera_outlined),
  (['video', 'movie', 'film'], Icons.movie_outlined),
  (
    ['fitness', 'workout', 'exercise', 'gym', 'run'],
    Icons.fitness_center_outlined,
  ),
  (
    ['health', 'medical', 'medicine', 'symptom'],
    Icons.health_and_safety_outlined,
  ),
  (['water', 'hydrat', 'drink'], Icons.local_drink_outlined),
  (['sleep', 'rest'], Icons.bedtime_outlined),
  (['book', 'read', 'library', 'reading'], Icons.menu_book_outlined),
  (['study', 'learn', 'course', 'flashcard', 'quiz'], Icons.school_outlined),
  (['contact', 'people', 'friend', 'address'], Icons.contacts_outlined),
  (['message', 'chat', 'conversation'], Icons.chat_bubble_outline),
  (['mail', 'email', 'inbox'], Icons.mail_outline),
  (
    ['travel', 'trip', 'flight', 'journey', 'itinerary'],
    Icons.flight_takeoff_outlined,
  ),
  (['map', 'location', 'place', 'geo'], Icons.map_outlined),
  (['game', 'puzzle', 'play', 'score'], Icons.sports_esports_outlined),
  (['timer', 'stopwatch', 'pomodoro', 'countdown'], Icons.timer_outlined),
  (['password', 'secret', 'vault', 'secure'], Icons.lock_outline),
  (
    ['inventory', 'stocklist', 'warehouse', 'asset'],
    Icons.inventory_2_outlined,
  ),
  (['project', 'kanban', 'sprint', 'backlog'], Icons.view_kanban_outlined),
  (['pet', 'animal', 'dog', 'cat'], Icons.pets_outlined),
  // Keep this rule free of stage11 novel-domain tokens (open-world proof).
  (['plant', 'florist', 'grow'], Icons.local_florist_outlined),
  (['car', 'vehicle', 'fuel', 'mileage'], Icons.directions_car_outlined),
  (['home', 'household', 'chores'], Icons.home_outlined),
  (['weight', 'measure', 'metric', 'log'], Icons.monitor_weight_outlined),
  (
    ['dashboard', 'analytics', 'report', 'chart', 'statistic'],
    Icons.insights_outlined,
  ),
  (['track', 'tracker', 'monitor'], Icons.timeline_outlined),
  (['list', 'collection', 'catalog', 'directory'], Icons.list_alt_outlined),
];

/// Chooses an icon and colour for an Experience from its own words.
///
/// Deterministic: the same inputs always produce the same identity, so an
/// Experience does not change appearance between launches or devices.
ExperienceVisualIdentity experienceVisualIdentity({
  required String experienceId,
  required String name,
  String category = '',
  List<String> tags = const [],
}) {
  final haystack = [name, category, ...tags].join(' ').toLowerCase();

  var icon = Icons.auto_awesome_outlined;
  for (final (keywords, candidate) in _iconRules) {
    if (keywords.any(haystack.contains)) {
      icon = candidate;
      break;
    }
  }

  // A stable, well-distributed index from the id. `hashCode` is not stable
  // across runs for all types but is for String within a Dart release, and a
  // sum of code units is stable everywhere — so use the latter.
  final seed = experienceId.isEmpty ? name : experienceId;
  final sum = seed.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);

  return ExperienceVisualIdentity(icon: icon, paletteIndex: sum % 8);
}

/// The square badge used wherever an Experience is listed or opened.
class ExperienceIcon extends StatelessWidget {
  final String experienceId;
  final String name;
  final String category;
  final List<String> tags;
  final double size;

  const ExperienceIcon({
    super.key,
    required this.experienceId,
    required this.name,
    this.category = '',
    this.tags = const [],
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final identity = experienceVisualIdentity(
      experienceId: experienceId,
      name: name,
      category: category,
      tags: tags,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: identity.background(scheme),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        identity.icon,
        size: size * 0.52,
        color: identity.foreground(scheme),
      ),
    );
  }
}
