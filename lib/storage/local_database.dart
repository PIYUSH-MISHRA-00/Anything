/// Unified local database for Anything v2.
///
/// Manages all persistent storage behind repository abstractions.
/// SharedPreferences for small preferences.
/// SQLite for structured data.
/// FlutterSecureStorage for secrets.
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

/// Unified local database manager.
class AnythingLocalDatabase {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'anything_v2.db');
    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    // Experience metadata
    await db.execute('''
      CREATE TABLE experiences (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_used_at TEXT,
        package_version TEXT,
        is_protected INTEGER DEFAULT 0
      )
    ''');

    // Experience packages (full JSON)
    await db.execute('''
      CREATE TABLE experience_packages (
        experience_id TEXT PRIMARY KEY,
        package_data TEXT NOT NULL,
        integrity_hash TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Intent history
    await db.execute('''
      CREATE TABLE intent_history (
        id TEXT PRIMARY KEY,
        expression TEXT NOT NULL,
        modality TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Activity events
    await db.execute('''
      CREATE TABLE activity_events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        experience_id TEXT,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Data schema versions
    await db.execute('''
      CREATE TABLE data_schema_versions (
        experience_id TEXT PRIMARY KEY,
        schema_version INTEGER NOT NULL,
        initialized_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}

/// Small preferences store (theme, flags).
class AnythingPreferences {
  static const String _themeKey = 'anything_theme_mode';

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'system';
  }
}
