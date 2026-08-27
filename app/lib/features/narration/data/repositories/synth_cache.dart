import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../../core/utils/narration_segmenter.dart';
import '../../domain/entities/synth_cache_entry.dart';
import '../../domain/repositories/narration_audio_cache.dart';
import '../datasources/synth_cache_data_source.dart';
import '../text_hash.dart';

/// Disk-backed narration audio cache: rendered per-unit WAV clips under
/// `<audioRoot>/<bookId>/<voiceId>/unit_<index>.wav`, indexed in sqflite via
/// [SynthCacheDataSource].
///
/// A cached clip is reused across sessions (a book narrated once in a voice
/// replays instantly and offline) as long as its stored text hash still matches
/// the current unit text; otherwise it is treated as a miss and re-rendered.
class SynthCache implements NarrationAudioCache {
  SynthCache(this._data, this._audioRoot);

  final SynthCacheDataSource _data;
  final Directory _audioRoot;

  File _fileFor(int bookId, String voiceId, int unitIndex) {
    return File(
      p.join(_audioRoot.path, '$bookId', voiceId, 'unit_$unitIndex.wav'),
    );
  }

  @override
  Future<String?> cachedPath(
    int bookId,
    String voiceId,
    NarrationUnit unit,
  ) async {
    final row = await _data.get(bookId, voiceId, unit.index);
    if (row == null) return null;

    // Stale text (book changed under this index) → re-render.
    if (row.unitHash != stableTextHash(unit.text)) {
      await _deleteRowAndFile(bookId, voiceId, unit.index);
      return null;
    }

    final file = _fileFor(bookId, voiceId, unit.index);
    if (!file.existsSync()) {
      // Index points at a file that no longer exists → drop the row.
      await _deleteRowAndFile(bookId, voiceId, unit.index);
      return null;
    }
    return file.path;
  }

  @override
  Future<String> reservePath(int bookId, String voiceId, int unitIndex) async {
    final file = _fileFor(bookId, voiceId, unitIndex);
    await file.parent.create(recursive: true);
    return file.path;
  }

  @override
  Future<void> record(int bookId, String voiceId, NarrationUnit unit) async {
    final file = _fileFor(bookId, voiceId, unit.index);
    final bytes = file.existsSync() ? file.lengthSync() : 0;
    await _data.upsert(
      SynthCacheEntry(
        bookId: bookId,
        voiceId: voiceId,
        unitIndex: unit.index,
        unitHash: stableTextHash(unit.text),
        file: file.path,
        bytes: bytes,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> evictOutsideWindow(
    int bookId,
    String voiceId, {
    required int lo,
    required int hi,
  }) async {
    final stale = await _data.indicesOutside(bookId, voiceId, lo, hi);
    for (final index in stale) {
      final file = _fileFor(bookId, voiceId, index);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    await _data.deleteOutside(bookId, voiceId, lo, hi);
  }

  /// Invalidates every cached clip for a book (all voices) — used when the book
  /// text is re-downloaded or the book is removed from the library.
  Future<void> invalidateBook(int bookId) async {
    await _data.deleteBook(bookId);
    final dir = Directory(p.join(_audioRoot.path, '$bookId'));
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }

  /// Invalidates every cached clip rendered in a voice (all books) — used when
  /// a voice is deleted from the library.
  Future<void> invalidateVoice(String voiceId) async {
    final files = await _data.filesForVoice(voiceId);
    await _data.deleteVoice(voiceId);
    for (final path in files) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }

  /// Removes every cached clip for all books and voices — used by the storage
  /// manager's "clear all narrated audio" action.
  Future<void> clearAll() async {
    await _data.deleteAll();
    if (_audioRoot.existsSync()) {
      await for (final entity in _audioRoot.list(followLinks: false)) {
        await entity.delete(recursive: true);
      }
    }
  }

  /// On-disk bytes of cached clips grouped by book id, computed by walking the
  /// audio tree (`<audioRoot>/<bookId>/…`). Directories whose name isn't an
  /// integer book id are ignored.
  Future<Map<int, int>> bytesPerBook() async {
    final result = <int, int>{};
    if (!_audioRoot.existsSync()) return result;
    await for (final entity in _audioRoot.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final bookId = int.tryParse(p.basename(entity.path));
      if (bookId == null) continue;
      var total = 0;
      await for (final file in entity.list(
        recursive: true,
        followLinks: false,
      )) {
        if (file is File) {
          total += await file.length();
        }
      }
      result[bookId] = total;
    }
    return result;
  }

  Future<void> _deleteRowAndFile(
    int bookId,
    String voiceId,
    int unitIndex,
  ) async {
    await _data.delete(bookId, voiceId, unitIndex);
    final file = _fileFor(bookId, voiceId, unitIndex);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}
