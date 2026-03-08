import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../security/encryption_manager.dart';
import 'sqlite_service.dart';

final memoryManagerProvider = Provider<MemoryManager>((ref) {
  final sqliteService = ref.watch(sqliteServiceProvider);
  final encryptionManager = ref.watch(encryptionManagerProvider);
  return MemoryManager(sqliteService, encryptionManager);
});

class MemoryManager {
  final SQLiteService _sqliteService;
  final EncryptionManager _encryptionManager;

  MemoryManager(this._sqliteService, this._encryptionManager);

  Future<void> saveConversation(String role, String content) async {
    final db = await _sqliteService.database;
    final encryptedRole = await _encryptionManager.encryptData(role);
    final encryptedContent = await _encryptionManager.encryptData(content);

    await db.insert('conversation_memory', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'encrypted_role': encryptedRole,
      'encrypted_content': encryptedContent,
    });
  }

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await _sqliteService.database;
    final data = await db.query('conversation_memory', orderBy: 'timestamp ASC');
    
    final result = <Map<String, dynamic>>[];
    for (var row in data) {
      result.add({
        'id': row['id'],
        'timestamp': row['timestamp'],
        'role': await _encryptionManager.decryptData(row['encrypted_role'] as String),
        'content': await _encryptionManager.decryptData(row['encrypted_content'] as String),
      });
    }
    return result;
  }
  
  Future<void> savePreference(String key, String value) async {
    final db = await _sqliteService.database;
    final encryptedValue = await _encryptionManager.encryptData(value);
    
    await db.insert('user_preferences', {
      'key': key,
      'encrypted_value': encryptedValue,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getPreference(String key) async {
    final db = await _sqliteService.database;
    final result = await db.query('user_preferences', where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return null;
    return await _encryptionManager.decryptData(result.first['encrypted_value'] as String);
  }
}
