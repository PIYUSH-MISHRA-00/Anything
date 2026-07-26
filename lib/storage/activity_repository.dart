/// Activity Repository — local persistence for meaningful user events.
library;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// An activity event record.
class ActivityEvent {
  final String id;
  final String type;
  final String? experienceId;
  final String experienceName;
  final String message;
  final DateTime timestamp;

  const ActivityEvent({
    required this.id,
    required this.type,
    this.experienceId,
    required this.experienceName,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'experienceId': experienceId,
    'experienceName': experienceName,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) {
    return ActivityEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      experienceId: json['experienceId'] as String?,
      experienceName: json['experienceName'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Activity repository using SharedPreferences.
class ActivityRepository {
  static const String _storageKey = 'anything_activity';
  static const int _maxEvents = 200;

  /// Record an activity event.
  Future<void> record(ActivityEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await list();
    events.insert(0, event);
    if (events.length > _maxEvents) {
      events.removeRange(_maxEvents, events.length);
    }
    final jsonList = events.map((e) => e.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }

  /// List activity events.
  Future<List<ActivityEvent>> list({int limit = 50}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_storageKey);
    if (jsonStr == null) return [];
    final List<dynamic> jsonList = jsonDecode(jsonStr);
    return jsonList
        .map((j) => ActivityEvent.fromJson(j as Map<String, dynamic>))
        .take(limit)
        .toList();
  }

  /// Clear all activity.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
