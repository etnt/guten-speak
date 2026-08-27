import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/app_database.dart';
import '../../domain/entities/synth_cache_entry.dart';

/// sqflite CRUD over the `synth_cache` index table. One row per rendered
/// narration unit `(book_id, voice_id, unit_index)`.
class SynthCacheDataSource {
  const SynthCacheDataSource(this._db);

  final Database _db;

  Future<SynthCacheEntry?> get(
    int bookId,
    String voiceId,
    int unitIndex,
  ) async {
    final rows = await _db.query(
      Db.synthCache,
      where:
          '${Db.synthBookId} = ? AND ${Db.synthVoiceId} = ? '
          'AND ${Db.synthUnitIndex} = ?',
      whereArgs: <Object?>[bookId, voiceId, unitIndex],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> upsert(SynthCacheEntry entry) async {
    await _db.insert(Db.synthCache, <String, Object?>{
      Db.synthBookId: entry.bookId,
      Db.synthVoiceId: entry.voiceId,
      Db.synthUnitIndex: entry.unitIndex,
      Db.synthUnitHash: entry.unitHash,
      Db.synthFile: entry.file,
      Db.synthBytes: entry.bytes,
      Db.synthCreatedAt: entry.createdAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(int bookId, String voiceId, int unitIndex) async {
    await _db.delete(
      Db.synthCache,
      where:
          '${Db.synthBookId} = ? AND ${Db.synthVoiceId} = ? '
          'AND ${Db.synthUnitIndex} = ?',
      whereArgs: <Object?>[bookId, voiceId, unitIndex],
    );
  }

  /// Unit indices cached for `(bookId, voiceId)` that fall outside `[lo, hi]`.
  Future<List<int>> indicesOutside(
    int bookId,
    String voiceId,
    int lo,
    int hi,
  ) async {
    final rows = await _db.query(
      Db.synthCache,
      columns: <String>[Db.synthUnitIndex],
      where:
          '${Db.synthBookId} = ? AND ${Db.synthVoiceId} = ? '
          'AND (${Db.synthUnitIndex} < ? OR ${Db.synthUnitIndex} > ?)',
      whereArgs: <Object?>[bookId, voiceId, lo, hi],
    );
    return rows.map((row) => row[Db.synthUnitIndex]! as int).toList();
  }

  Future<void> deleteOutside(int bookId, String voiceId, int lo, int hi) async {
    await _db.delete(
      Db.synthCache,
      where:
          '${Db.synthBookId} = ? AND ${Db.synthVoiceId} = ? '
          'AND (${Db.synthUnitIndex} < ? OR ${Db.synthUnitIndex} > ?)',
      whereArgs: <Object?>[bookId, voiceId, lo, hi],
    );
  }

  Future<void> deleteBook(int bookId) async {
    await _db.delete(
      Db.synthCache,
      where: '${Db.synthBookId} = ?',
      whereArgs: <Object?>[bookId],
    );
  }

  /// All cached file paths for a voice across every book (for voice-level
  /// invalidation, e.g. when a voice is deleted from the library).
  Future<List<String>> filesForVoice(String voiceId) async {
    final rows = await _db.query(
      Db.synthCache,
      columns: <String>[Db.synthFile],
      where: '${Db.synthVoiceId} = ?',
      whereArgs: <Object?>[voiceId],
    );
    return rows.map((row) => row[Db.synthFile]! as String).toList();
  }

  Future<void> deleteVoice(String voiceId) async {
    await _db.delete(
      Db.synthCache,
      where: '${Db.synthVoiceId} = ?',
      whereArgs: <Object?>[voiceId],
    );
  }

  /// Removes every cached-clip row (used to clear all narrated audio).
  Future<void> deleteAll() async {
    await _db.delete(Db.synthCache);
  }

  SynthCacheEntry _fromRow(Map<String, Object?> row) {
    return SynthCacheEntry(
      bookId: row[Db.synthBookId]! as int,
      voiceId: row[Db.synthVoiceId]! as String,
      unitIndex: row[Db.synthUnitIndex]! as int,
      unitHash: row[Db.synthUnitHash]! as String,
      file: row[Db.synthFile]! as String,
      bytes: row[Db.synthBytes]! as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row[Db.synthCreatedAt]! as int,
      ),
    );
  }
}
