import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/tts/raven_model_manager.dart';
import '../../../../core/tts/raven_tts_engine.dart';
import '../../../../core/tts/tts_engine.dart';
import '../../../../core/tts/tts_synthesis_request.dart';
import '../../../../core/tts/tts_synthesis_result.dart';
import '../../domain/entities/narration_prep_progress.dart';

part 'tts_providers.g.dart';

/// Downloads/locates the on-device Raven model (from the guten-speak release
/// area only). Raven is the app's sole narration engine at runtime (int8,
/// 4-step flow, temperature 0.20 — the winning production config).
@Riverpod(keepAlive: true)
RavenModelManager ravenModelManager(Ref ref) => RavenModelManager();

/// Whether the Raven model is already installed, so the UI can show "Prepare"
/// vs a ready state without kicking off a download.
@riverpod
Future<bool> modelInstalled(Ref ref) =>
    ref.watch(ravenModelManagerProvider).isInstalled();

/// Drives the opt-in model download + engine load that gates narration, and
/// exposes its progress. [prepare] is idempotent and resumable; [cancel] aborts
/// an in-flight download (partial bytes are kept for a later resume).
@Riverpod(keepAlive: true)
class NarrationEngine extends _$NarrationEngine {
  bool _cancelRequested = false;

  /// The active TTS engine (owns the native handle in a background isolate).
  /// Built once the model paths are known and disposed with the provider.
  TtsEngine? _engine;

  @override
  NarrationPrepProgress build() {
    ref.onDispose(() => unawaited(_engine?.dispose()));
    return const NarrationPrepProgress.idle();
  }

  /// Ensures the Raven model is downloaded/extracted and loaded. Returns true
  /// once the engine is ready to synthesize.
  Future<bool> prepare() async {
    if (state.isReady && (_engine?.isReady ?? false)) return true;
    if (state.phase.isBusy) return false;

    _cancelRequested = false;
    try {
      final engine = await _ensureEngine();

      state = const NarrationPrepProgress.loading();
      if (!engine.isReady) {
        await engine.initialize();
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

  /// Downloads (if needed) and constructs the Raven engine, reusing an
  /// already-built instance.
  Future<TtsEngine> _ensureEngine() async {
    final existing = _engine;
    if (existing != null) return existing;

    final paths = await ref
        .read(ravenModelManagerProvider)
        .ensureModel(
          onStatus: _onManagerStatus,
          onProgress: _onManagerProgress,
          isCancelled: () => _cancelRequested,
        );
    final engine = RavenTtsEngine(
      paths: paths,
      modelManifestSha: RavenModelManager.modelManifestSha,
    );
    _engine = engine;
    return engine;
  }

  void _onManagerStatus(String message) {
    if (message.contains('Extract')) {
      state = const NarrationPrepProgress.extracting();
    }
  }

  void _onManagerProgress(double? fraction) {
    if (state.phase != NarrationPrepPhase.extracting) {
      state = NarrationPrepProgress.downloading(fraction);
    }
  }

  /// Requests cancellation of an in-flight download.
  void cancel() => _cancelRequested = true;

  /// The 64-char synthesis profile id of the active engine, used to key the
  /// narration cache. Must only be read after [prepare] completes.
  String get synthesisProfileId {
    final engine = _engine;
    if (engine == null) {
      throw StateError(
        'NarrationEngine.prepare() must complete before synthesisProfileId.',
      );
    }
    return engine.synthesisProfile.id;
  }

  /// Synthesizes [text] in the [voiceId] reference voice at [referenceWavPath],
  /// writing a validated WAV to [outputWavPath]. The engine must already be
  /// [prepare]d.
  Future<TtsSynthesisResult> synthesize({
    required String text,
    required String voiceId,
    required String referenceWavPath,
    required String outputWavPath,
  }) {
    final engine = _engine;
    if (engine == null || !engine.isReady) {
      throw StateError(
        'NarrationEngine.prepare() must complete before synthesize().',
      );
    }
    return engine.synthesize(
      TtsSynthesisRequest(
        requestId: '${DateTime.now().microsecondsSinceEpoch}',
        text: text,
        voiceId: voiceId,
        referenceWavPath: referenceWavPath,
        outputWavPath: outputWavPath,
      ),
    );
  }
}
