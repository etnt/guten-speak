import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/storage/app_database.dart';
import '../../data/datasources/narration_progress_data_source.dart';
import '../../domain/entities/narration_playback.dart';
import '../services/narration_audio_handler.dart';
import 'synth_cache_providers.dart';
import 'tts_providers.dart';

part 'narration_player_providers.g.dart';

/// The singleton background narration player, initialized inside
/// `audio_service` so it survives backgrounding and drives the media
/// notification. Created lazily on first listen and disposed with the app.
@Riverpod(keepAlive: true)
Future<NarrationAudioHandler> narrationAudioHandler(Ref ref) async {
  final cache = await ref.watch(synthCacheProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  final engine = ref.watch(narrationEngineProvider.notifier);

  final handler = await AudioService.init(
    builder: () => NarrationAudioHandler(
      cache: cache,
      progress: NarrationProgressDataSource(db),
      synthesize: engine.synthesize,
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'se.kruskakli.guten_speak.narration',
      androidNotificationChannelName: 'Narration',
      androidNotificationOngoing: true,
    ),
  );

  ref.onDispose(handler.shutdown);
  return handler;
}

/// The live playback snapshot for UI (player screen + mini-player). Seeds with
/// the handler's current state, then follows its updates.
@riverpod
Stream<NarrationPlaybackState> narrationPlayback(Ref ref) async* {
  final handler = await ref.watch(narrationAudioHandlerProvider.future);
  yield handler.state;
  yield* handler.stateStream;
}

/// How many "head start" sections (units) the user wants pre-rendered before
/// playback begins. Larger = longer wait up front but smoother, longer-lasting
/// playback before it needs to catch up. Read once when starting a session.
final headStartChunksProvider = StateProvider<int>((ref) => 8);
