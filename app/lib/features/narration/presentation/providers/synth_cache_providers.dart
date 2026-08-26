import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/app_database.dart';
import '../../data/datasources/synth_cache_data_source.dart';
import '../../data/repositories/synth_cache.dart';

part 'synth_cache_providers.g.dart';

/// `<appDocuments>/audio`, created on first access. Rendered narration clips
/// live under `<audio>/<bookId>/<voiceId>/unit_<index>.wav`.
@Riverpod(keepAlive: true)
Future<Directory> narrationAudioDirectory(Ref ref) async {
  final documents = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(documents.path, 'audio'));
  await dir.create(recursive: true);
  return dir;
}

/// The disk-backed narration synthesis cache (per-unit clips + sqflite index).
@Riverpod(keepAlive: true)
Future<SynthCache> synthCache(Ref ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  final audioDir = await ref.watch(narrationAudioDirectoryProvider.future);
  return SynthCache(SynthCacheDataSource(db), audioDir);
}
