import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

final sqliteServiceProvider = Provider<SQLiteService>((ref) {
  return SQLiteService();
});

/// Opens and owns the `anything_memory.db` handle.
///
/// LIFETIME AND DISPOSAL (IS-R58 Phase 8). This class is the sole owner of the
/// handle it opens: it creates it lazily on first [database] access and is the
/// only thing that may close it. [close] is that disposal point, and
/// `MemoryManager.close()` — the single consumer — delegates to it.
///
/// WHAT THE R58 AUDIT ACTUALLY FOUND, recorded because it is larger than the
/// missing `close()`. This class is reachable ONLY through
/// `sqliteServiceProvider`, a Riverpod `Provider`, and a Riverpod provider is
/// resolved only inside a `ProviderScope`. There is NO `ProviderScope` anywhere
/// in `lib/` or `test/` — `main.dart` calls `runApp(const AnythingApp())`
/// directly. So nothing constructs this at runtime, no handle is actually
/// leaked today, and the gap was latent rather than live.
///
/// The `close()` below is added anyway: the disposal contract must exist before
/// the chain is ever wired, not after. The unreachable-subsystem finding is
/// recorded as gap G-48 and is deliberately NOT acted on here — deleting a
/// parallel subsystem is a milestone of its own, and IS-R58 changes no
/// architecture.
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

  /// Closes the database handle, if one was opened.
  ///
  /// Idempotent: closing twice is safe, and closing a service that never
  /// opened a handle is a no-op. Sole disposal point for this handle.
  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
