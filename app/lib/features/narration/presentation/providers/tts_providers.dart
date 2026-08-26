import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/tts/model_manager.dart';
import '../../../../core/tts/tts_service.dart';
import '../../domain/entities/narration_prep_progress.dart';

part 'tts_providers.g.dart';

/// Downloads/locates the on-device PocketTTS model.
@Riverpod(keepAlive: true)
ModelManager modelManager(Ref ref) => ModelManager();

/// The persistent TTS worker (owns the native engine in a background isolate).
/// Created lazily and disposed with the provider.
@Riverpod(keepAlive: true)
TtsService ttsService(Ref ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
}

/// Whether the model is already installed, so the UI can show "Prepare" vs a
/// ready state without kicking off a download.
@riverpod
Future<bool> modelInstalled(Ref ref) {
  return ref.watch(modelManagerProvider).isInstalled();
}

/// Drives the opt-in model download + engine load that gates narration, and
/// exposes its progress. [prepare] is idempotent and resumable; [cancel] aborts
/// an in-flight download (partial bytes are kept for a later resume).
@Riverpod(keepAlive: true)
class NarrationEngine extends _$NarrationEngine {
  bool _cancelRequested = false;

  @override
  NarrationPrepProgress build() => const NarrationPrepProgress.idle();

  /// Ensures the model is downloaded/extracted and loaded into the worker.
  /// Returns true once the engine is ready to synthesize.
  Future<bool> prepare() async {
    final tts = ref.read(ttsServiceProvider);
    if (state.isReady && tts.isReady) return true;
    if (state.phase.isBusy) return false;

    _cancelRequested = false;
    try {
      final manager = ref.read(modelManagerProvider);
      final paths = await manager.ensureModel(
        onStatus: (message) {
          if (message.contains('Extract')) {
            state = const NarrationPrepProgress.extracting();
          }
        },
        onProgress: (fraction) {
          if (state.phase != NarrationPrepPhase.extracting) {
            state = NarrationPrepProgress.downloading(fraction);
          }
        },
        isCancelled: () => _cancelRequested,
      );

      state = const NarrationPrepProgress.loading();
      if (!tts.isReady) {
        await tts.init(paths);
      }
      ref.invalidate(modelInstalledProvider);
      state = const NarrationPrepProgress.ready();
      return true;
    } on ModelDownloadCancelled {
      state = const NarrationPrepProgress.idle();
      return false;
    } catch (error) {
      state = NarrationPrepProgress.error(error.toString());
      return false;
    }
  }

  /// Requests cancellation of an in-flight download.
  void cancel() => _cancelRequested = true;

  /// Synthesizes [text] in the reference voice at [referenceWavPath], writing a
  /// WAV to [outputWavPath]. The engine must already be [prepare]d.
  Future<SpeakResult> synthesize({
    required String text,
    required String referenceWavPath,
    required String outputWavPath,
  }) {
    final tts = ref.read(ttsServiceProvider);
    return tts.speak(
      text: text,
      referenceWavPath: referenceWavPath,
      outputWavPath: outputWavPath,
    );
  }
}
