import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

final sqliteServiceProvider = Provider<SQLiteService>((ref) {
  return SQLiteService();
});

class SQLiteService {
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('anything_memory.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_preferences(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        encrypted_value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE conversation_memory(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        encrypted_role TEXT NOT NULL,
        encrypted_content TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE intent_patterns(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encrypted_pattern TEXT NOT NULL,
        frequency INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workflow_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        encrypted_workspace_data TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE security_settings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');
  }
}
