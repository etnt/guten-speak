# Pocket TTS Raven Android implementation plan

**Status:** In progress — Phase 2 complete; Phase 3 partial (worker, bindings, WAV pipeline done; installer + voice artifacts pending)  
**Date:** 2026-08-31 (updated 2026-09-02)  
**Depends on:** [Pocket TTS Raven investigation](pocket-tts-raven-investigation.md)  
**Upstream revision:** [`abd26158ab50f954616eaf42296b09c4856489d7`](https://github.com/pkalogiros/pocket-tts-raven/tree/abd26158ab50f954616eaf42296b09c4856489d7)

## 1. Objective

Prove and, only if the evidence supports it, replace Guten-Speak's current
sherpa-onnx Pocket TTS backend with Pocket TTS Raven on Android arm64.

The implementation must preserve the working narration experience:

- Book segmentation and navigation remain unchanged.
- Narration still prepares one WAV per reading unit.
- The existing rolling look-ahead scheduler remains serial.
- just_audio and audio_service continue to own playback and background controls.
- Existing reading progress, bookmarks, voices, and sherpa audio remain recoverable.
- Raven is not released until it passes the investigation's performance, quality,
  memory, thermal, stability, and licensing gates.

This plan covers the Android proof of concept, controlled comparison, and conditional
production cutover. It does not assume that Raven will pass the adoption gates.

## 2. Non-goals

The first implementation will not:

- Stream partial PCM directly into just_audio.
- Add iOS, x86, x86_64, or armeabi-v7a support.
- Add NNAPI or Qualcomm QNN acceleration.
- Generate or rewrite ONNX models on the phone.
- Package two incompatible ONNX Runtime libraries in one APK.
- Expose an end-user engine selector before native-runtime coexistence is solved.
- Change paragraph segmentation, playback speed behavior, or narration progress semantics.
- Upload voice samples, generated speech, or benchmark data.

Direct streaming and additional execution providers are separate follow-up projects after
Raven's complete-unit path is proven.

## 3. Current baseline

The implementation starts from these verified constraints:

| Concern | Current state |
|---|---|
| TTS worker | [`TtsService`](../app/lib/core/tts/tts_service.dart) owns sherpa in a persistent Dart isolate |
| Current profile | January 2026 fp32 model, 28 steps, temperature 0.20, seed 1234, six threads |
| Model installation | [`ModelManager`](../app/lib/core/tts/model_manager.dart) downloads and extracts one sherpa-specific archive |
| Scheduling | [`LookAheadScheduler`](../app/lib/features/narration/domain/services/look_ahead_scheduler.dart) runs one synthesis job at a time |
| Playback | [`NarrationAudioHandler`](../app/lib/features/narration/presentation/services/narration_audio_handler.dart) plays complete per-unit WAV files |
| Audio cache | [`SynthCache`](../app/lib/features/narration/data/repositories/synth_cache.dart) keys by book, voice, and unit plus a text hash |
| Database | [`Db.version`](../app/lib/core/storage/app_database.dart) is 5; `synth_cache` has no engine/profile column |
| Voices | [`VoiceLibrary`](../app/lib/features/voices/data/datasources/voice_library_data_source.dart) stores stable built-in filenames and UUID-like user filenames |
| Android | [`build.gradle.kts`](../app/android/app/build.gradle.kts) targets arm64-v8a and delegates the NDK version to Flutter |
| Native runtime | The current sherpa package contributes `libonnxruntime.so` identifying itself as 1.27.1 |
| Raven runtime | The reviewed native Raven build pins ONNX Runtime 1.23.2 and has no Android build target |

The PoC must first remeasure the current app. Historical RTF figures were gathered under
settings that no longer exactly match the source and are not a controlled baseline.

## 4. Target architecture

### 4.1 Stable app-side boundary

Introduce a small engine contract under `app/lib/core/tts/`:

```text
TtsEngine
  engineId
  synthesisProfile
  initialize()
  synthesize(request)
  cancelCurrentSynthesis()
  dispose()
```

Proposed files:

```text
app/lib/core/tts/tts_engine.dart
app/lib/core/tts/tts_synthesis_request.dart
app/lib/core/tts/tts_synthesis_result.dart
app/lib/core/tts/synthesis_profile.dart
app/lib/core/tts/tts_text_processing.dart
```

Configuration is supplied when an engine is constructed. `initialize()` therefore does not
need to accept a sherpa-specific or Raven-specific model-path type.

`TtsSynthesisRequest` contains text, voice ID, reference WAV path, output WAV path, and a
request ID. `TtsSynthesisResult` retains the current sample rate, audio duration, and RTF
surface and adds enough timing information to compare the complete pipeline:

- Request-to-first-chunk time, nullable for sherpa.
- Native generation/stream time.
- Audio post-processing time.
- WAV write time.
- Request-to-complete-file time.
- Generated sample count and sample rate.
- Whether Raven's voice/KV cache was warm, when it can be determined reliably.
- Engine/profile identifiers and a structured failure category.

Report both native-compute RTF and complete-pipeline RTF. User-visible latency is measured
to a validated, atomically published WAV, not merely Raven's first callback.

### 4.2 Engine adapters

For the baseline, adapt the existing [`TtsService`](../app/lib/core/tts/tts_service.dart)
to the interface without changing its output. Keep its current isolate, retry splitting,
quote normalization, reference conditioning, trim/fade behavior, and defaults.

Raven lives in a local Flutter FFI plugin:

```text
app/packages/pocket_tts_raven/
  pubspec.yaml
  android/
  lib/
  src/
  CMakeLists.txt
  THIRD_PARTY_NOTICES.md
  UPSTREAM_REVISION
```

Generate the package from the Flutter version currently used by the project with the
`plugin_ffi` template, then adapt that generated layout rather than hand-creating stale
Flutter plugin boilerplate.

The plugin owns:

- The reviewed Raven C++ source snapshot and any small Android patch set.
- Generated, checked-in Dart bindings.
- Android CMake/Gradle integration.
- ONNX Runtime and SentencePiece integration.
- Raven handle, stream, and returned-audio ownership.
- Native status/error translation.

The app owns:

- Model installation and verified paths.
- Stable voice IDs and reference files.
- Text safety policy and maximum duration.
- WAV validation and atomic publication.
- Scheduling, cache indexing, playback, storage UX, and benchmark reporting.

### 4.3 Runtime data flow

```text
NarrationAudioHandler
  -> LookAheadScheduler
    -> TtsEngine.synthesize
      -> engine worker isolate
        -> Raven C API stream
          -> float32 chunks
        -> validate, trim/fade, encode WAV.tmp
      -> atomic rename to reserved cache path
    -> SynthCache.record
  -> just_audio
```

The scheduler remains unaware of native implementation details. Its constructor gains only a
synthesis-profile ID so every cache operation is scoped to the exact engine configuration.

## 5. Reproducible native build

### 5.1 Source pinning

Vendor a minimal, reviewable Raven source snapshot inside the local plugin rather than
requiring the developer's sibling checkout at build time. Record:

- Upstream repository and full commit SHA.
- Files copied and local modifications.
- Raven's MIT license and third-party notices.
- A patch-series directory for Android/error-reporting changes.

Do not silently track Raven's main branch. Updating Raven is a separate reviewed change that
regenerates models, bindings if required, and benchmark results.

Pin SentencePiece v0.2.1 and dr_libs to the revisions recorded by Raven. Avoid unpinned network
fetches during CMake configuration; use checked hashes or reviewed vendored source.

### 5.2 ONNX Runtime Android

Use the official `com.microsoft.onnxruntime:onnxruntime-android:1.23.2` AAR for the Raven
PoC because it matches the reviewed native Raven build. Gradle should resolve the AAR, and a
repeatable build task should expose its headers and arm64-v8a `libonnxruntime.so` to CMake as
an imported library.

Do not copy sherpa's 1.27.1 library into the Raven build and assume ABI compatibility. A later
experiment may rebuild/test Raven against the same ONNX Runtime as sherpa, but that result is
not a PoC prerequisite.

The final Raven APK must contain exactly one `libonnxruntime.so`. Add an artifact inspection
step that fails when the APK contains sherpa native libraries or more than the expected Raven
native dependency set.

### 5.3 Android toolchain

- Pin an installed NDK r28 or newer instead of relying indefinitely on an implicit Flutter
  default.
- Build C++17 for arm64-v8a only during the PoC.
- Compile the portable `AttentionTail` implementation with ARM NEON available.
- Use the portable `mimi_decoder_delta_int8.onnx`; exclude Apple-only decoder graphs.
- Hide native symbols by default and export only the public bridge API.
- Strip release symbols while retaining separately archived symbols for crash diagnosis.
- Verify ELF and APK/AAB 16 KB alignment for every `.so`.
- Run one smoke test on an Android 16 KB page-size environment.

Start with ONNX Runtime's CPU execution provider. NNAPI/QNN investigation begins only if the
CPU implementation is correct but misses performance targets and profiling indicates a
realistic benefit.

### 5.4 Native error contract

The reviewed Raven stream thread catches an exception, prints it to stderr, marks the stream
finished, and makes `ptt_stream_poll()` look like normal completion. The app cannot reliably
distinguish a failed stream from successful end-of-stream using the current public C API.

Carry a minimal patch, preferably submitted upstream, that:

- Stores a terminal error code and bounded UTF-8 message on the stream context.
- Exposes an error query/copy function that is valid before `ptt_stream_end()`.
- Distinguishes “no chunk yet,” successful completion, cancellation, and failure.
- Never lets a C++ exception cross the C ABI.
- Adds native tests for missing models, invalid voices, malformed audio, allocation failure
  where practical, cancellation, and successful completion.

This is a blocking correctness requirement, not optional diagnostic polish.

## 6. Model artifact and installation

### 6.1 Offline release pipeline

Add a repository tool such as `tools/build_raven_android_model_bundle.sh`. It runs on a
controlled developer/CI machine, never on the phone:

1. Check out the pinned Raven revision.
2. Download the exact `english_2026-04` source bundle.
3. Verify Raven's pinned source hashes.
4. Run the deterministic delta-KV, custom-attention, deduplication, merged-flow, and portable
   decoder rewrites.
5. Run Raven's equivalence checks.
6. Select only the Android runtime files:
   - `tokenizer.model`
   - `text_conditioner.onnx`
   - `mimi_encoder.onnx`
   - `flow_lm_main_delta_attn_flow_int8.onnx`
   - `flow_lm_flow_int8.onnx` for multi-step comparison/fallback
   - `mimi_decoder_delta_int8.onnx`
   - `bos_before_voice.npy`
7. Produce a deterministic archive.
8. Produce a signed/reviewed manifest containing every filename, byte size, SHA-256, source
   revision, Raven revision, preparation revision, licenses, and extracted-size requirement.
9. Verify the archive by extracting it into a clean directory and loading all candidate
   profiles with the Android/native harness.

The archive is not published until the exact weight source, transformed-weight distribution,
attribution, and upstream gated terms have passed project/legal review.

### 6.2 App installer

Generalize [`ModelManager`](../app/lib/core/tts/model_manager.dart) around an immutable
`TtsModelDescriptor`, or split it into `SherpaModelManager` and `RavenModelManager` behind a
small `TtsModelManager` interface.

Raven installation must:

- Use a separate directory such as `models/raven/<model-manifest-sha>/`.
- Resume downloads into `.part` as the current manager does.
- Verify the archive SHA-256 before extraction.
- Preflight free disk space using the manifest's archive and extracted sizes.
- Extract in a background isolate into a `.staging` directory.
- Reject absolute paths and `..` traversal entries.
- Verify every extracted file against the manifest.
- Write the installed marker only after all checks pass.
- Atomically promote `.staging` to the final directory.
- Remove incomplete staging data after failure while retaining a valid resumable `.part`.
- Treat any manifest/model mismatch as “not installed.”

For the PoC, ship the complete required model set. Deferring the voice encoder download is a
later storage/startup optimization and would complicate comparison and error handling.

Do not let `deleteFromDisk()` remove every engine under the shared `models` root. Model usage
and deletion become engine/model-specific.

## 7. Synthesis profile and cache migration

### 7.1 Canonical profile

Create a versioned canonical `SynthesisProfile`. Serialize a fixed-key map in deterministic
order and hash it with SHA-256. Store the 64-character profile ID in cache paths and SQLite.
Avoid delimiter-based strings and raw floating-point formatting.

The canonical data includes:

- Profile schema version.
- Engine ID and engine/native revision.
- ONNX Runtime version.
- Model manifest SHA-256.
- Precision.
- Solver-step count.
- Temperature represented as a scaled integer.
- Seed and EOS/max-frame settings.
- Raven comma-softening setting.
- Text-normalization/retry-policy version.
- Audio trim/fade/WAV-encoding version.
- Sample rate.
- Voice content SHA-256.

The human-readable profile is included in benchmark output and logs; the hash is the cache
identity.

### 7.2 Database v5 to v6

Update [`app_database.dart`](../app/lib/core/storage/app_database.dart):

- Increment `Db.version` from 5 to 6.
- Add `synthesis_profile_id TEXT NOT NULL` to `synth_cache`.
- Change the primary key to `(book_id, voice_id, unit_index, synthesis_profile_id)`.
- Recreate the table in a transaction because SQLite cannot alter a primary key in place.
- Migrate current rows to a constant legacy sherpa profile representing the exact current
  January 2026 settings.
- Preserve each migrated row's existing `file` path and metadata.
- Drop the old table only after row-count and required-column checks succeed.

Add `Db.synthProfileId` and update [`SynthCacheEntry`](../app/lib/features/narration/domain/entities/synth_cache_entry.dart)
and every query in [`SynthCacheDataSource`](../app/lib/features/narration/data/datasources/synth_cache_data_source.dart).

All unit-level lookups, deletes, and rolling-window evictions must include the profile ID.
Book deletion and voice deletion intentionally remove rows across all profiles.

### 7.3 File paths

Use this path for newly synthesized files:

```text
<audioRoot>/<bookId>/<voiceId>/<profileId>/unit_<index>.wav
```

Keeping the book ID first preserves the current `bytesPerBook()` traversal and makes book
cleanup cheap. Existing legacy files remain in their current path and are reused through the
migrated row's stored `file` value.

Change cache lookup to validate `row.file` rather than recomputing the current path. Reserve
and record new files through the profile-aware path builder. Write to
`unit_<index>.wav.tmp-<requestId>`, validate it, then rename atomically; a cancelled or failed
request must never leave a cacheable final path.

### 7.4 App API propagation

Add `synthesisProfileId` to:

- [`NarrationAudioCache`](../app/lib/features/narration/domain/repositories/narration_audio_cache.dart)
  operations.
- [`LookAheadScheduler`](../app/lib/features/narration/domain/services/look_ahead_scheduler.dart)
  construction and cache calls.
- [`NarrationAudioHandler.load`](../app/lib/features/narration/presentation/services/narration_audio_handler.dart)
  and its same-session identity check.

Narration progress remains keyed by book and voice. A profile change should resume at the same
reading unit but synthesize/cache audio under the new profile.

## 8. Raven voice artifacts

Raven derives cache names from the reference filename stem and validates them mainly by
modification time. Do not let arbitrary imported names share Raven's cache namespace.

For each Raven model/profile:

```text
<appSupport>/tts/raven/<modelManifestSha>/voices/<voiceId>.wav
<appSupport>/tts/raven/<modelManifestSha>/voices/.cache/<voiceId>.emb
<appSupport>/tts/raven/<modelManifestSha>/voices/.cache/<voiceId>.kv
```

Before first use:

1. Hash the source voice bytes.
2. Copy the source to a temporary file named from the stable Guten-Speak voice ID.
3. Validate it with [`wav_io.dart`](../app/lib/core/tts/wav_io.dart).
4. Atomically replace the Raven-private reference if its content hash changed.
5. Remove the old `.emb` and `.kv` before generating new artifacts.

Do not rely only on modification time for app-level validity. Maintain a small sidecar/manifest
mapping voice ID to content SHA-256 and model manifest SHA-256.

Extend voice deletion in
[`voice_providers.dart`](../app/lib/features/voices/presentation/providers/voice_providers.dart)
to remove Raven-private references and all matching `.emb`/`.kv` files after the original
voice and synthesized clips are removed. Model deletion removes only that model's Raven voice
artifacts.

For the initial PoC, allow Raven to encode on first use. Deferred/encoder-only modes may be
used later to precompute embeddings, but only after lifecycle and memory measurements justify
the extra path.

## 9. Worker, cancellation, and WAV publication

### 9.1 Responsive isolate protocol

Use one long-lived Raven handle in one dedicated isolate. Never drive the same handle from two
Dart requests concurrently.

Do not use a single `await for` handler that waits for the entire synthesis before receiving
control messages. Instead:

- A receive-port callback dispatches synthesis without blocking message dispatch.
- The worker rejects a second synthesis while one is active.
- The worker drains `ptt_stream_poll()`, which returns immediately, then yields to the Dart
  event loop when no chunk is ready.
- A cancel message can therefore call `ptt_stream_stop()` on the active stream.
- Disposal sets a closing state, stops the stream, awaits completion, calls
  `ptt_stream_end()`, destroys the engine, closes ports, and only then acknowledges shutdown.

On native Android, `ptt_configure_pool()` is a no-op in the reviewed Raven source; its
“before create” requirement applies to the WASM path. Android thread tuning is supplied through
Raven's create-time thread budget and measured AR/decoder behavior.

### 9.2 Ownership rules

For every request:

- A non-null stream is ended exactly once.
- Every returned float buffer is copied/drained and freed exactly once.
- `ptt_stream_end()` runs in `finally`, after error inspection.
- The engine handle is destroyed exactly once after no stream remains.
- The isolate is never force-killed while Raven or ONNX Runtime threads may still be running.
- A watchdog first requests stop and waits for a bounded graceful teardown. If teardown hangs,
  record a hard failure for the PoC; do not pretend an immediate isolate kill is safe.

Add state-machine assertions in debug/test builds for created, active, stopping, disposed, and
failed states.

### 9.3 Output safety

Drain float32 chunks into a bounded sample builder. Abort when output exceeds the same
text-length plausibility rule or absolute maximum used by the current engine. Reject:

- Empty audio.
- A sample rate other than 24 kHz.
- NaN or infinite samples.
- Values outside the permitted range before clamping.
- Implausible duration or missing terminal success.

Reuse the current trim/fade policy where it is meaningful. Clamp/encode into a WAV format
verified with Android just_audio, write to a temporary path, reopen and validate the WAV, then
rename it atomically.

Keep the current shorter-phrase retry strategy for runaways, but version it in the synthesis
profile. Cancellation does not retry.

## 10. Benchmark build isolation

### 10.1 Why Gradle flavors alone are insufficient

Both Flutter plugins listed in `pubspec.yaml` contribute native libraries before an app
product flavor is selected. Merely adding `benchmarkSherpa` and `benchmarkRaven` flavors does
not guarantee that the unwanted plugin or its `libonnxruntime.so` disappears from the APK.
Gradle `pickFirst` would hide the collision rather than solve it.

### 10.2 PoC build strategy

Use two pinned Git worktrees/branches from the same benchmark-harness commit:

- **Sherpa baseline worktree:** retains `sherpa_onnx`; does not depend on the Raven plugin.
- **Raven candidate worktree:** removes `sherpa_onnx` and its ABI helper packages from the
  dependency graph; depends on the local Raven plugin and ORT 1.23.2.

The engine-independent benchmark corpus, metrics schema, profile logic, and report generator
must be identical between worktrees. Keep the engine adapter/provider wiring as the minimal
branch delta.

Give benchmark APKs distinct application ID suffixes so their model, voice, cache, and result
sandboxes cannot contaminate one another. If side-by-side installation proves awkward, install
sequentially but clear and recreate only the benchmark app sandbox, never the developer's
normal app data.

Add `tools/inspect_tts_apk.sh` to assert:

- Expected application ID and engine marker.
- Exactly one arm64 `libonnxruntime.so`.
- Sherpa libraries absent from the Raven APK.
- Raven library absent from the sherpa APK.
- Only arm64-v8a native payloads.
- 16 KB ZIP/ELF alignment.
- Recorded SHA-256 for APK, native libraries, and model manifest.

The benchmark report is invalid if artifact inspection fails.

### 10.3 Conditional production strategy

After Raven passes all adoption gates, choose one of two explicitly reviewed paths:

1. **Raven-only replacement (preferred):** remove sherpa dependencies and ship one runtime.
   Rollback is an app release built from the retained sherpa branch/tag.
2. **Single-APK dual engine:** allowed only after both engines pass their full test suites
   against one exact ONNX Runtime binary and APK inspection confirms one runtime. Do not use
   renamed duplicate ONNX Runtime libraries or `pickFirst` as a shortcut.

Until path 2 is proven, there is no production runtime feature flag that can switch native
engines safely. Internal Raven beta distribution uses a separate APK/application ID.

## 11. Benchmark harness

### 11.1 Device-local runner

Add a dedicated benchmark entry point/runner rather than treating a heavyweight on-device
model benchmark as a host `flutter_test`:

```text
app/lib/benchmark/tts_benchmark_runner.dart
app/integration_test/tts_engine_smoke_test.dart
app/test/fixtures/tts_benchmark_corpus.json
tools/run_android_tts_benchmark.sh
```

The runner writes versioned JSONL/JSON into app-private storage and emits only stable progress
markers to logcat. The script records device/build state and pulls the result file. No voice or
text is uploaded.

Record:

- App Git commit and dirty state.
- Engine, native-library, ORT, model-manifest, and synthesis-profile IDs.
- APK SHA-256 and build mode.
- Device model, OS build, CPU/core count, available memory, battery level, charging state,
  power mode, and thermal status.
- Cold model load and warm-up time.
- Per-unit first-chunk, generation, post-process, write, complete-file, audio duration, native
  RTF, and pipeline RTF.
- Cancellation latency and outcome.
- Process PSS/RSS before load, after load, peak, and after teardown.
- Playback underruns and synthesis failures.

Use profile or release-equivalent artifacts; debug measurements are diagnostic only.

### 11.2 Corpus and profiles

Use the corpus and cases defined in the investigation:

- At least 100 representative reading units and three consented/bundled voices.
- At least 1,000 units for correctness soak testing.
- Short, median, and near-limit units with dialogue, punctuation, numbers, names, and smart
  quotes.
- Cold process/model, cold voice, warm voice/KV, steady state, seek, rapid cancellation,
  background/foreground, and 30-minute uncached narration cases.

Compare:

- Sherpa baseline: 28 steps, temperature 0.20, seed 1234, six threads.
- Raven: one step/0.70.
- Raven: one step/0.20.
- Raven: selected two- and four-step profiles at the preferred temperature.
- Raven thread-budget candidates determined by a short sweep; freeze the winner before the
  full comparison.
- Raven comma-softening on/off if the listening panel finds prose pauses materially different.

Do not tune on the final evaluation subset. Use a small tuning subset, freeze configuration,
then evaluate the held-out corpus.

### 11.3 Measurement protocol

- Run on Pixel 10 Pro and one slower supported arm64 device.
- Use the same device state, corpus order, voices, and number of repetitions per engine.
- Randomize engine/profile order for listening tests.
- Report median, p90, p95, maximum, and failures; include duration-weighted RTF.
- Separate model initialization, first-unit, and steady-state results.
- Use `dumpsys meminfo`/Perfetto and Android thermal status alongside app timings.
- Run at least 30 minutes uncached after configuration is frozen.
- Preserve raw benchmark output and a concise Markdown summary in `plan/`.

## 12. Work plan

The PoC is estimated at 8–15 engineering days. Conditional production hardening adds roughly
3–5 days, excluding legal review or upstream turnaround.

### Phase 0 — Freeze inputs and legal route (0.5–1 day)

**Tasks**

- [ ] Record the Guten-Speak baseline commit and Raven commit.
- [ ] Decide whether Raven source is vendored as a reviewed snapshot or another equally
  reproducible mechanism; this plan recommends a snapshot.
- [ ] Confirm the Android ORT 1.23.2 artifact and NDK r28+ availability.
- [ ] Decide the authorized model download/distribution route.
- [ ] Verify model and bundled-voice attribution requirements.
- [ ] Define the two benchmark application IDs and worktree branches.

**Deliverables**

- Locked revisions and dependency hashes.
- Written model-distribution decision.
- Benchmark branch/worktree instructions.

**Stop gate**

Do not publish transformed weights or a public Raven build without an approved model route and
required attribution. Local technical work may continue with lawfully obtained artifacts.

### Phase 1 — Baseline abstraction and instrumentation (1–2 days)

**Tasks**

- [x] Add the engine request/result/profile types.
- [x] Adapt `TtsService` to the engine interface without changing current audio behavior.
- [x] Extract/version shared text normalization, retry splitting, and post-processing.
- [x] Add first-unit/complete-file and stage timings.
- [x] Add the device-local benchmark runner, corpus schema, and result schema.
- [ ] Benchmark the unmodified sherpa profile on both devices.

**Tests**

- Unit tests for text normalization, retry boundaries, metrics/RTF, and deterministic profile
  serialization.
- Existing narration scheduler and playback tests remain green.
- Baseline output spot-check against pre-refactor WAV duration/hash or a documented
  sample-tolerance comparison.

**Exit gate**

A reproducible sherpa baseline report exists, and refactoring has no measurable behavior or
quality regression.

### Phase 2 — Native Raven Android harness (2–4 days)

**Tasks**

- [x] Create the local FFI plugin from the current Flutter template.
- [x] Vendor Raven and dependency sources/revisions.
- [x] Integrate ORT Android 1.23.2 and SentencePiece for arm64.
- [x] Add the stream terminal-error patch/API.
- [x] Build the portable attention and decoder paths.
- [x] Generate/install the verified model bundle locally.
- [x] Add a minimal on-device native/plugin smoke harness.
- [x] Add APK/native-library and 16 KB alignment inspection.

**Tests**

- Create/warm/destroy.
- Valid built-in and imported voices.
- Missing model, mismatched graph set, malformed voice, and invalid argument failures.
- One-step and multi-step generation.
- Stream poll, stop, error query, end, and buffer-free ownership.
- 100 create/synthesize/cancel/destroy cycles under sanitizers where available and on device.

**Stop gate**

Stop before Flutter narration integration if release-mode generation crashes, hides stream
errors, cannot cancel/join safely, fails 16 KB checks, produces invalid audio, or exceeds the
agreed device-memory ceiling.

### Phase 3 — Raven installer and worker (2–4 days)

**Tasks**

- [x] Implement Raven model descriptor, manifest verification, staging, and atomic install.
  <br/>Archive SHA-256 pinned + verified before extraction; tar path-traversal
  guard; extract to `.staging-<name>` then atomic rename to `modelDir`. Disk
  preflight deferred (no pure-Dart free-space API).
- [ ] Implement Raven-private voice references and `.emb`/`.kv` invalidation.
- [x] Generate/check in FFI bindings.
- [x] Implement responsive polling, cancellation, ownership, and graceful disposal.
- [x] Implement bounded sample validation, trim/fade, WAV encoding, and atomic rename.
- [x] Return the common metrics/result type.
- [ ] Build the Raven-only benchmark APK and prove artifact isolation.

**Tests**

- Installer resume, cancel, hash failure, path traversal, low disk, incomplete staging, and
  model upgrade.
- Worker rejects overlap and remains responsive to cancel/dispose.
- Cancelled/failed requests leave no final WAV or cache row.
- WAVs reopen with [`readWavAsFloat32`](../app/lib/core/tts/wav_io.dart) and play through
  just_audio on Android.
- Repeated warm voice use hits valid Raven artifacts; replacing source content rebuilds them.
- No upward memory trend across lifecycle loops.

**Exit gate**

The Raven-only APK synthesizes and plays validated per-unit WAVs, exposes failures accurately,
and shuts down without force-killing live native work.

### Phase 4 — Profile-aware app integration (1–3 days)

**Tasks**

- [x] Implement database v6 migration and profile-aware cache queries/paths.
- [x] Propagate `synthesisProfileId` through cache, scheduler, and audio handler.
- [x] Wire [`tts_providers.dart`](../app/lib/features/narration/presentation/providers/tts_providers.dart)
  to the branch's engine/model manager. `NarrationEngine` is now engine-agnostic
  over `TtsEngine`; `SelectedTtsEngine` defaults to **Raven**; `RavenModelManager`
  downloads the int8 bundle (guten-speak release area only) and shares the
  resume/isolate-extract logic with sherpa via `archive_download.dart`. The Raven
  voice reuses `VoiceLibrary`'s `<appSupport>/voices/` dir (also its writable
  `.cache`), so no separate voice download is needed.
- [x] Extend storage usage/deletion for per-engine models. `StorageUsage` now
  exposes `List<ModelUsage> models` (id/label/installed/bytes) with `modelsBytes`
  + `anyModelInstalled`; `StorageManager` computes usage for both the Raven and
  sherpa managers and `deleteModel(engineId)` routes to the matching manager. The
  storage screen renders one row per installed model with a per-row, size-aware
  delete confirmation (no hardcoded ~470 MB text). Raven voice artifacts still
  live under `VoiceLibrary`'s `<appSupport>/voices/` (excluded from model bytes,
  managed by the Voices section).
- [x] Extend voice deletion cleanup. `VoiceLibrary.remove` now also deletes the
  Raven engine's per-voice cache artifacts (`<voicesDir>/.cache/{stem}.emb` and
  `{stem}.kv`) alongside the `.wav`. The cache-path derivation is a pure,
  host-tested helper `ravenVoiceCachePaths(voicesDir, voiceWavPath)` mirroring the
  native `get_cache_path` (stem = wav filename without extension).
- [x] Host the Raven `raven-int8-2026-01.tar.bz2` archive at the `etnt/guten-speak`
  `tts-models` release (packaged by `tools/pack_raven_model.sh`), then exercise
  the real in-app download path on-device via
  `integration_test/raven_download_smoke_test.dart`: downloads ~80 MB, extracts to
  165 MB, loads the engine, and synthesizes non-silent audio (download+extract
  ~18.7 s). Added the `INTERNET` permission to the **main** Android manifest so
  release builds (not just debug/profile) can download the model.

**Tests**

- Fresh v6 database schema.
- v5-to-v6 migration recreates the profile-aware `synth_cache` (pre-release: no
  rows preserved).
- Two profiles for the same book/voice/unit never collide.
- One profile's rolling eviction never removes another profile's row/file.
- Book and voice deletion remove all intended profiles.
- Storage bytes remain correctly grouped by book and model.
- Same book/voice with a changed profile creates a new audio-handler session.
- Existing scheduler tests updated with a profile and remain behaviorally unchanged.

**Exit gate**

No stale cross-engine cache hit is possible, and the end-to-end Raven narration flow behaves
like the current file-based flow.

### Phase 5 — Controlled comparison and decision (2–3 days)

**Tasks**

- [ ] Freeze candidate profiles after tuning subset results.
- [ ] Run the full automated corpus on both benchmark worktrees/devices.
- [ ] Run rapid-seek/cancel and 1,000-unit correctness soaks.
- [ ] Run 30-minute uncached narration with memory/thermal capture.
- [ ] Conduct blinded listening tests.
- [ ] Compare results against every mandatory gate.
- [ ] Store raw-result references and a decision summary in `plan/`.

**Go decision**

Proceed only when one Raven profile passes every adoption gate in the investigation, including:

- At least 30% lower median complete-unit latency.
- Duration-weighted RTF no greater than 0.75 and at least 30% below baseline.
- p95 complete-unit latency no worse than sherpa.
- Non-inferior blinded quality.
- No underruns in the continuous narration run.
- No hangs, runaways, invalid WAVs, wrong voices, or lifecycle failures.
- Peak PSS no more than 10% above baseline and no upward trend.
- Thermal degradation below the defined 20% limit.
- Extracted model payload below 200 MB.
- Correctness and faster-than-realtime synthesis on the slower device.
- Release, 16 KB, attribution, consent, and model-distribution approval.

**No-go action**

Keep sherpa production code, archive the Raven branch and benchmark evidence, and record which
upstream/runtime change would justify retesting. Do not weaken gates after seeing results.

### Phase 6 — Conditional production cutover (3–5 days)

This phase starts only after a go decision.

**Tasks**

- [ ] Choose Raven-only replacement or prove one-runtime dual-engine compatibility.
- [ ] For the preferred Raven-only path, remove sherpa packages and verify no sherpa/duplicate
  ORT library remains.
- [ ] Add in-app model/runtime/bundled-voice notices.
- [ ] Add explicit lawful-consent acknowledgment to voice import/creation UX.
- [ ] Update storage UI for Raven model and voice-cache deletion.
- [ ] Preserve legacy sherpa cache rows/files and model files through the initial rollout unless
  the user explicitly removes them.
- [ ] Produce an internal beta APK with a distinct application ID.
- [ ] Run final release, upgrade, background-audio, process-death, and 16 KB tests.
- [ ] Update [`README.md`](../README.md), the main
  [`implementation-plan.md`](implementation-plan.md), and
  [`tts-options.md`](tts-options.md) with the measured decision and current licensing facts.

**Exit gate**

The signed release artifact contains the intended single native runtime, all notices and consent
UX are present, upgrade/rollback data is preserved, and release-candidate soak testing passes.

## 13. Test inventory

### Pure Dart/unit

- Canonical profile serialization and SHA-256 stability.
- Profile changes for every output-affecting setting.
- Text normalization, retry splitting, duration bounds, float validation, and RTF calculations.
- Profile-aware cache repository/data-source behavior.
- Model manifest parsing and validation.
- Worker protocol state machine with a fake native API.
- Storage aggregation across model/profile directories.

### Database

- Fresh v6 creation.
- v5 migration preserving legacy path and row count.
- Migration rollback on injected failure.
- Composite profile key and scoped eviction/delete queries.
- Foreign-key cascade after table recreation.

Use `sqflite_common_ffi` for repeatable host migration tests if it accurately matches the SQL
path, plus one Android upgrade integration test against a copied v5 database.

### Native/plugin

- Binding ABI sizes/signatures.
- Missing/malformed input errors.
- Stream success/error/cancel terminal states.
- Returned-buffer ownership and leak checks.
- Voice `.emb`/`.kv` cold/warm behavior.
- One/multi-step graphs and portable custom op registration.
- Release stripping and symbol exports.
- 16 KB alignment.

### Flutter integration

- Model prepare/cancel/resume/error UI states.
- First narration and warm restart.
- Head-start preparation and continue flow.
- Seek during synthesis and rapid repeated seek.
- Voice change and source-content replacement.
- Pause/resume, background/foreground, notification controls, audio interruption, and process
  restart.
- Model/audio/voice-cache deletion while idle; block destructive deletion while the engine is
  active.
- Existing imported voice and legacy sherpa audio after v5-to-v6 upgrade.

### Manual quality

- At least three lawful/consented voices.
- Dialogue, narration, names, abbreviations, punctuation, numbers, short fragments, and long
  units.
- Blind comparison of naturalness, intelligibility, voice similarity, pronunciation, pauses,
  onset artifacts, truncation, and noise tails.

## 14. Observability and failure policy

Keep benchmark diagnostics device-local. Use structured categories rather than parsing stderr:

```text
model_invalid
voice_invalid
native_init_failed
native_stream_failed
cancelled
output_too_long
invalid_samples
wav_write_failed
wav_validation_failed
shutdown_timeout
```

Production logs must not include book text, voice paths, or raw audio. They may include engine,
profile, request ID, stage durations, sample count, and failure category.

On a failed synthesis:

- Stop and end the current stream.
- Delete temporary output.
- Do not record a cache entry.
- Surface one user-safe narration error.
- Stop the scheduler pump to avoid a tight retry loop.
- Allow explicit retry/reprepare after the engine is known idle.

On model verification failure, mark Raven unprepared and require repair/re-download. On native
shutdown timeout, treat the PoC run as failed; do not immediately create another handle in the
same process.

## 15. Storage and deletion behavior

Extend [`StorageUsage`](../app/lib/features/storage/domain/entities/storage_usage.dart) from one
model summary to per-engine/model entries. Account separately for:

- Sherpa model and partial archive.
- Raven model and partial/staging archive.
- Raven voice references, `.emb`, and `.kv` caches.
- Narrated WAVs, still grouped by book and optionally broken down by profile.
- Imported source voices.

Deletion rules:

- Deleting a Raven model first disposes Raven, then removes that model directory and associated
  Raven voice artifacts; synthesized WAVs may remain reusable only while their profile/model is
  reinstallable and identical.
- Deleting a voice removes source, Raven artifacts, and synthesized audio across profiles.
- Deleting book audio removes every profile for that book.
- Clearing all narrated audio does not remove source voices or models.
- Never recursively delete the shared models root when only one engine was selected.

## 16. Licensing, notices, and responsible use

This plan does not replace legal review.

Before any distributed Raven build:

- Verify the exact source and terms for the April 2026 ONNX weights and transformed artifacts.
- Decide whether the app may redistribute the optimized model or must download it through an
  approved/gated route.
- Attribute Pocket TTS under the current CC-BY-4.0 metadata and comply with additional gated
  prohibited-use terms.
- Include Raven (MIT), ONNX Runtime (MIT), SentencePiece (Apache-2.0), dr_libs, model, and
  bundled-voice notices.
- Add a root `THIRD_PARTY_NOTICES.md` if the project does not yet have one, and expose relevant
  notices in the app.
- Require explicit lawful consent/ownership acknowledgment before importing a cloning voice.
- State that generated speech is synthetic and prohibit impersonation, deception, fraud,
  harassment, and privacy-invasive use.
- Correct outdated “non-commercial” statements only after confirming the exact distributed
  artifacts and terms; do not replace them with an unconditional commercial-use claim.

## 17. Rollback

### During the PoC

The normal application remains on sherpa. Raven uses a separate worktree, application ID, model
directory, and app sandbox. A failed Raven experiment cannot corrupt normal narration data.

### During initial production rollout

`guten-speak` has not shipped a release yet, so there is no on-device sherpa
cache to preserve: the v6 migration simply drops and recreates `synth_cache`
with the profile-aware key, and any pre-v6 audio is re-synthesized on demand.

The additive-migration and rollback-readability concerns below only become
relevant **once a real sherpa release has shipped**. Revisit them before the
first cutover, not before then:

- Tag the final sherpa release and retain its build environment and model manifest.
- Switch the v6 migration from recreate-empty to additive (preserve legacy
  sherpa rows/files under a backfilled profile id).
- Leave an existing sherpa model on disk through the first Raven release unless
  the user chooses to remove it.
- Keep database v6 readable by both the Raven release and a prepared sherpa
  rollback release.

## 18. Definition of done

The work is complete only when one of these outcomes is documented:

### Accepted

- Raven passes every mandatory adoption gate.
- The selected production native-runtime strategy is explicit.
- Model installation, cache migration, voice artifacts, cancellation, errors, and teardown are
  covered by automated tests.
- Release APK inspection, 16 KB checks, device soak, and blinded quality review pass.
- Licensing route, notices, and consent UX are approved.
- A tested sherpa rollback release remains available.

### Rejected/deferred

- Raven fails one or more mandatory gates.
- The PoC branch, exact artifacts, raw results, and failure analysis are archived.
- Production remains on sherpa without partial Raven dependencies or user-facing switches.
- A concrete retest trigger is recorded, such as an upstream Android target, shared ORT support,
  model-quality improvement, or verified performance fix.
