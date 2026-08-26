import 'package:sqflite/sqflite.dart';

import '../../../../core/storage/app_database.dart';
import '../../domain/entities/narration_progress.dart';

/// sqflite CRUD over the `narration_progress` table (one row per book) that
/// records where narrated playback should resume.
class NarrationProgressDataSource {
  const NarrationProgressDataSource(this._db);

  final Database _db;

  Future<NarrationProgress?> get(int bookId) async {
    final rows = await _db.query(
      Db.narrationProgress,
      where: '${Db.narrationBookId} = ?',
      whereArgs: <Object?>[bookId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> save(NarrationProgress progress) async {
    await _db.insert(Db.narrationProgress, <String, Object?>{
      Db.narrationBookId: progress.bookId,
      Db.narrationVoiceId: progress.voiceId,
      Db.narrationUnitIndex: progress.unitIndex,
      Db.narrationPositionMs: progress.positionMs,
      Db.narrationUpdatedAt: progress.updatedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(int bookId) async {
    await _db.delete(
      Db.narrationProgress,
      where: '${Db.narrationBookId} = ?',
      whereArgs: <Object?>[bookId],
    );
  }

  NarrationProgress _fromRow(Map<String, Object?> row) {
    return NarrationProgress(
      bookId: row[Db.narrationBookId]! as int,
      voiceId: row[Db.narrationVoiceId]! as String,
      unitIndex: row[Db.narrationUnitIndex]! as int,
      positionMs: row[Db.narrationPositionMs]! as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row[Db.narrationUpdatedAt]! as int,
      ),
    );
  }
}
