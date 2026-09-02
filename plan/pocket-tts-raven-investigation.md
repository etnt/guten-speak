# Pocket TTS Raven for Android narration

**Status:** Investigation complete; Android proof of concept recommended  
**Date:** 2026-08-29  
**Raven revision reviewed:** [`abd26158ab50f954616eaf42296b09c4856489d7`](https://github.com/pkalogiros/pocket-tts-raven/tree/abd26158ab50f954616eaf42296b09c4856489d7)

## Executive recommendation

Pocket TTS Raven **can plausibly replace the current sherpa-onnx synthesis backend
without replacing Guten-Speak's narration, scheduling, caching, or playback architecture**.
Its public C API is suitable for Dart FFI, it emits the same sample rate and channel layout
(24 kHz mono float32 PCM, which can be encoded into the app's WAV format), and its per-engine
threading constraints fit the app's existing serial worker pattern.

It should **not replace sherpa-onnx in production yet**. Raven has no checked-in Android
build, no published Android library, and no native Android benchmark. Its headline figures
are from an Apple M4 Max, desktop browsers, and an iPhone browser. Android can use several
important optimizations, but not the Apple-only optimized decoder. Raven also changes the
model from the current January 2026 fp32 export to an April 2026 int8 export and changes
the default synthesis settings from 28 solver steps at temperature 0.20 to one step at 0.70.
A speed comparison would therefore also be a model and quality comparison.

The recommended decision is:

1. Keep sherpa-onnx as the production engine and rollback path.
2. Build a time-boxed, arm64-v8a Android Raven proof of concept.
3. Preserve the current per-reading-unit WAV workflow for the first comparison;
   do not add direct streaming playback yet.
4. Use separate engine/model/cache fingerprints so no Raven output can be mistaken
   for sherpa output.
5. Adopt Raven only if it passes the speed, quality, stability, memory, and sustained-load
   gates in this document on real Android devices.

**Expected upside:** a materially smaller model download and a credible chance of faster synthesis.  
**Confidence in Android speedup:** medium-low until measured.  
**Confidence in architectural fit:** high.  
**Production readiness today:** low.

## Scope and evidence

This investigation compared:

- The current Flutter implementation under [`app/`](../app/).
- The local Raven checkout and the pinned source revision above.
- Raven's runtime, C API, graph-preparation scripts, portable custom attention implementation,
  benchmark notes, and third-party notices.
- Current official Pocket TTS model metadata and terms.
- Official ONNX Runtime Android packaging/build guidance.

No Android Raven binary was built and no Android Raven benchmark was run as part of this
investigation. Performance conclusions are therefore hypotheses to test, not forecasts.

## Current Guten-Speak baseline

### Architecture

The existing narration stack already separates synthesis from playback well:

| Area                       | Current implementation | Reuse with Raven |
|----------------------------|------------------------|------------------|
| Model acquisition          | [`model_manager.dart`](../app/lib/core/tts/model_manager.dart) downloads and extracts the sherpa-specific bundle | Replace or generalize |
| Synthesis process          | [`tts_service.dart`](../app/lib/core/tts/tts_service.dart) owns a persistent sherpa engine in a worker isolate | Replace engine internals; retain the worker/RPC concept |
| Provider boundary          | [`tts_providers.dart`](../app/lib/features/narration/presentation/providers/tts_providers.dart) prepares the engine and exposes synthesis | Natural engine-selection boundary |
| Look-ahead generation      | [`look_ahead_scheduler.dart`](../app/lib/features/narration/domain/services/look_ahead_scheduler.dart) generates reading units serially and replans after seeks | Retain |
| Synthesized audio cache    | [`synth_cache.dart`](../app/lib/features/narration/data/repositories/synth_cache.dart) stores one WAV per book/voice/unit | Retain after adding engine/profile identity |
| Playback and media session | [`narration_audio_handler.dart`](../app/lib/features/narration/presentation/services/narration_audio_handler.dart) loads WAVs into just_audio and manages buffering/background controls | Retain for the PoC and likely production |
| Storage reporting/deletion | [`storage_manager.dart`](../app/lib/features/storage/data/storage_manager.dart) accounts for model and synthesized audio | Extend for Raven models and voice caches |

The high-level flow is:

```text
reading unit -> look-ahead scheduler -> synthesis worker -> WAV file
                                                     |
                                                     v
                                   synth cache -> just_audio -> audio_service
```

This is a good migration boundary. Raven does not require a rewrite of book parsing,
navigation, bookmarks, progress, background audio, or the rolling look-ahead policy.

### Current engine and settings

The current worker uses:

- `sherpa_onnx` 1.13.6.
- Pocket TTS `sherpa-onnx-pocket-tts-2026-01-26` fp32 models.
- Approximately 441 MB compressed and 470 MB extracted model storage.
- 28 flow-matching steps.
- Temperature 0.20.
- Seed 1234.
- Six inference threads in the current source.
- A persistent model in a dedicated Dart isolate.
- Defensive retry and text splitting when output appears to run away or miss its stop token.
- Complete WAV generation before a reading unit becomes playable.

The implementation calculates real-time factor as:

$$
\mathrm{RTF} = \frac{\text{synthesis elapsed time}}{\text{generated audio duration}}
$$

Lower is better; an RTF below 1 means faster-than-realtime synthesis. Existing project
notes contain a Pixel 10 Pro run with an average RTF around 1.12 and describe typical
values around 1.2–2.0. Those numbers must not be treated as a controlled baseline:
the old notes mention four threads while current source uses six, and the timing currently
logged inside the worker is not persisted for benchmark analysis.

### Current bottleneck as experienced by the user

For initial playback and post-seek playback, Guten-Speak waits for a complete reading
unit to be synthesized, written, registered in the cache, and loaded into just_audio.
The relevant user-visible metric is therefore **time to first playable unit**, not
merely time to Raven's first PCM chunk.

Once narration is under way, the important metric becomes whether synthesis remains
far enough ahead of playback to prevent buffering. For book reading, sustained 
throughput and thermal behavior matter at least as much as a short-prompt first-audio number.

## What Raven does differently

Raven is a C++17 driver around stock ONNX Runtime, SentencePiece, and Pocket TTS ONNX graphs.
It exposes a documented C ABI in [`pocket_tts.h`](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/include/pocket_tts.h), which makes
it callable from Dart FFI without embedding Python.

### Runtime pipeline

The portable int8 runtime uses:

1. A SentencePiece tokenizer.
2. `text_conditioner.onnx` for text conditioning.
3. `mimi_encoder.onnx` to encode a reference voice.
4. An autoregressive main model that predicts one latent frame at a time.
5. A flow model that turns the prediction into a Mimi latent.
6. `mimi_decoder_delta_int8.onnx` to decode latents to 24 kHz mono float32 PCM.

The inspected preparation script starts from the approximately 165 MB `english_2026-04` int8 ONNX bundle,
verifies every source file by SHA-256, and applies deterministic graph rewrites.
This is a different and newer model export than Guten-Speak currently uses.

### Important optimizations

Raven's speed is not just the result of changing C++ compilers. Its main gains
come from changing the model/runtime contract:

- **Delta-KV output:** AR and decoder graphs return only new key/value cache slices instead of copying full caches each step.
- **Persistent cache buffers:** C++ updates preallocated full caches with those slices.
- **Shape/KV plumbing removal:** graph rewrites remove repeated work that was only deriving known dimensions.
- **Cross-layer deduplication:** shared positional/mask computations are performed once.
- **Merged one-step flow:** when `lsd_steps == 1`, the flow operation is folded into the main graph, removing an ONNX Runtime call per generated frame.
- **Portable custom attention:** `AttentionTail` computes only the newest-token attention needed by the hot AR loop. It has scalar, x86 SIMD, and ARM NEON paths.
- **AR/decoder pipeline:** generation and decoding use bounded queues and separate native threads.
- **Voice caches:** `.emb` avoids re-encoding the source voice and `.kv` restores post-conditioning transformer state. Raven reports warm KV restoration in roughly 4 ms on its development platform.
- **Low-latency onset gating:** configurable trimming can emit useful speech earlier while rejecting leading noise bursts.

Raven's own optimization notes also show that several intuitive changes did not help:
bigger decoder batches regressed performance, allocator replacement greatly increased memory,
and removing generic graph nodes did not necessarily improve compute-bound stages.
Android tuning must therefore be measured rather than based on core count alone.

### C API fit and caveats

The relevant lifecycle is:

```text
ptt_configure_pool (global, before first engine)
ptt_create / ptt_create_ex
ptt_warmup (optional)
ptt_stream_start
ptt_stream_read or ptt_stream_poll
ptt_free_audio for every returned chunk
ptt_stream_stop (optional cancellation)
ptt_stream_end
ptt_destroy
```

Positive fit:

- Audio is 24 kHz mono float32 and can be converted/encoded into a standard WAV for the current player.
- Voice arguments can be absolute paths, so existing app-private voice files can be used.
- One persistent Raven handle in one serial worker fits the documented “thread-compatible, not thread-safe per handle” constraint.
- The API supports graceful stream cancellation and offers deferred/encoder-only modes that could avoid keeping the voice encoder loaded after embeddings are prepared.

Caveats:

- `ptt_stream_read()` blocks. Calling it synchronously in the current worker loop prevents
  that isolate from receiving a cancellation message until the call returns. Production
  cancellation needs non-blocking polling with periodic Dart event-loop yields or a small
  native wrapper with a dedicated thread and atomic abort flag.
- The C API reports status codes and writes detailed diagnostics to stderr; it has no
  rich `last_error` API. A production wrapper should translate native failures into stable
  Dart error codes/messages.
- Every chunk, stream, and engine has explicit ownership. Exception paths must still free
  audio, end the stream, and destroy the engine.
- Killing a Dart isolate while it is inside Raven FFI is not equivalent to killing a pure
  Dart worker. Native Raven/ONNX threads may still own memory. The current timeout strategy
  must be changed to stop and join native work before worker termination.
- `ptt_configure_pool()` is process-global and must run before the first engine is created.
  Engine initialization must be centralized.

## Android feasibility

### What Android can use

The current app already targets only `arm64-v8a`, which removes the need to prove four
Android ABIs initially. An Android arm64 build can use:

- The int8 model set.
- Delta-KV AR and decoder graphs.
- Persistent cache buffers and KV snapshots.
- Merged one-step flow.
- Portable `AttentionTail` custom operations.
- The ARM NEON custom-attention path.
- AR/decoder native-thread pipelining.
- Low-latency onset trimming.

These are substantial parts of Raven's optimized path.

### What Android cannot use

Raven's fastest native decoder graph uses custom ConvTranspose/Accelerate operations that
are compiled only for Apple platforms. Android must use the portable
`mimi_decoder_delta_int8.onnx` path. It does not get:

- Apple Accelerate.
- The Apple-only fused ConvTranspose decoder graph.
- Apple-specific matrix acceleration.

The iPhone result in Raven's README is a **browser/WASM** measurement, not a native mobile
measurement. It is encouraging because that route also uses the portable decoder, but it
does not predict Android native performance: browser scheduling, WASM SIMD, mobile CPU
topology, memory bandwidth, and thermal policies differ.

### Missing Android work

The reviewed Raven revision has no Gradle module, Android NDK toolchain integration,
Android CI, Android test app, or published `.so`/AAR. The native CMake build fetches
desktop ONNX Runtime distributions rather than consuming the Android package.

This is solvable. ONNX Runtime officially publishes `com.microsoft.onnxruntime:onnxruntime-android`,
and its C/C++ guidance explicitly supports extracting headers and the matching `libonnxruntime.so`
from the AAR for an NDK target. Version 1.23.2—the native version pinned by Raven—is
available from Maven Central.

The Android plugin should:

- Build Raven as C++17 with the Android NDK for arm64-v8a.
- Link to the headers and arm64 `libonnxruntime.so` from the exact pinned Android AAR.
- Build SentencePiece without its CLI/tests, or vendor only the tokenizer runtime needed by Raven.
- Compile the portable attention implementation with NEON enabled.
- Use hidden symbol visibility and export only the Raven C ABI.
- Use NDK r28 or later and verify 16 KB ELF/ZIP alignment for every packaged native library.
- Add a release-mode smoke/instrumentation test; debug-only success is insufficient.

Phase one should use ONNX Runtime's CPU execution provider. ONNX Runtime recommends
starting with CPU for quantized models. NNAPI or QNN can be investigated only after
the CPU path works; Raven's custom operators, dynamic state, and many small sequential
runs may partition poorly and make an accelerator slower.

### ONNX Runtime coexistence hazard

The current sherpa Android package already contributes a native library named `libonnxruntime.so`;
the inspected arm64 binary identifies itself as ONNX Runtime 1.27.1. Raven's native build
pins 1.23.2. Android cannot safely package two different files with the same path/SONAME
and let each engine assume its own ABI.

For the PoC, use **separate benchmark builds/branches**:

- Baseline build: current sherpa packages and their ONNX Runtime 1.27.1.
- Raven build: sherpa native packages removed, Raven linked to the official Android ONNX Runtime 1.23.2 AAR.

This gives a clean performance comparison and avoids Gradle duplicate-library resolution
silently selecting one runtime. A final app that offers both engines would first need
to prove both against one pinned ONNX Runtime build, or isolate/rename one complete
native dependency stack. A compile-time experimental build is safer than a runtime feature
flag until this is resolved.

## Expected benefits and uncertainty

### Model size

The current extracted fp32 bundle is approximately 470 MB. Raven's source int8 ONNX bundle
is approximately 165 MB before its local graph rewrite. The exact production download and
extracted footprint depends on which source graphs are removed after preparation, compression
format, whether the 38 MB-class voice encoder is downloaded lazily, and which ONNX Runtime
binaries are already present.

A reduction of hundreds of megabytes is plausible, but the final artifact manifest must
be measured rather than inferred from the repository headline.

### Synthesis speed

Raven reports approximately:

- 33× realtime and around 30 ms first audio on an M4 Max native build.
- 14× realtime and around 70 ms first audio in a desktop browser.
- 3–4× realtime and under 250 ms first audio in an iPhone browser.

These figures use speed factor $\text{audio duration}/\text{compute time}$, the inverse
of Guten-Speak's RTF. A 4× speed factor is RTF 0.25.

No responsible Android number can be derived from those claims. Reasons include:

- Android loses Raven's fastest Apple decoder.
- The target CPU's memory bandwidth, core classes, scheduler, and thermal envelope differ.
- Raven's headline path uses one solver step and temperature 0.70.
- Guten-Speak uses 28 steps and temperature 0.20.
- Raven uses the April 2026 int8 export; Guten-Speak uses the January 2026 fp32 export.
- Guten-Speak's initial wait is a complete reading-unit WAV, while Raven's first-audio result is a first PCM chunk.

A meaningful improvement remains plausible because the portable Android path retains delta-KV,
merged flow, int8 weights, custom NEON attention, persistent buffers, and pipeline parallelism.
It is not guaranteed.

### Quality

It is unsafe to assume either that one Raven step is adequate or that 28 steps are necessary.
Solver steps, sampling temperature, quantization, graph version, trimming, and text normalization
all affect the result. Raven falls back to the standalone flow model for `lsd_steps > 1`, losing
the merged-flow optimization but permitting a quality/speed sweep.

The PoC must compare at least:

- Current sherpa: 28 steps, temperature 0.20, six threads.
- Raven speed profile: one step, temperature 0.70.
- Raven low-variation profile: one step, temperature 0.20.
- Raven quality candidate(s): a small sweep such as 2 and 4 steps at the preferred temperature.

The winning configuration must be selected by blinded narration listening tests, not by speed alone.

### Perceived latency

Phase one deliberately aggregates Raven chunks into the same per-unit WAVs used today.
This isolates engine performance and preserves reliable seeking/background playback.
It will improve perceived latency only if Raven completes a unit faster.

Direct playback of the first chunk could later reduce startup latency further, but it introduces
a second project: a custom buffered audio source, back-pressure, partial-file semantics,
interruption handling, seek cancellation, media-session behavior, and cache finalization.
It should not be mixed into the engine adoption decision.

## Recommended integration design

### Engine abstraction

Introduce an internal synthesis contract above both engines with operations equivalent to:

- `prepare(modelDirectory, voiceDirectory, profile)`
- `synthesizeToWav(text, voicePath, outputPath)` returning duration, sample count, and timing metrics
- `cancelCurrentSynthesis()`
- `dispose()`

Keep `SpeakResult`-style data at this boundary so the scheduler and cache do not know
which native engine produced the file.

Implement:

- `SherpaTtsEngine` by adapting the current service.
- `RavenTtsEngine` behind a dedicated Flutter FFI plugin/native module.

Do not place raw FFI calls in presentation providers. The plugin should own generated bindings,
C++ build rules, Raven source revision, third-party notices, and native lifecycle tests.

### Worker behavior

Retain one long-lived Dart worker isolate and one Raven handle. All synthesis for that
handle remains serial, matching both Raven's contract and the existing scheduler.

For each request:

1. Resolve the app-private, uniquely named voice source.
2. Start a Raven stream.
3. Read/poll chunks until completion while collecting float samples.
4. Check cancellation between polls/chunks.
5. Clamp/convert the returned float32 PCM as required and write a temporary 24 kHz mono
   WAV in an encoding verified with the current Android player.
6. Validate its header, finite samples, duration, and maximum duration.
7. Atomically rename it to the requested output path.
8. Return duration plus cold/warm/init/first-chunk/complete timings.
9. In `finally`, free outstanding audio and end the stream.

On shutdown, stop the active stream, wait for native pipeline threads, end it,
destroy the Raven handle, and only then terminate the isolate.

### Engine-specific synthesis profile

The audio cache currently keys content by book, voice, reading-unit index, and text hash.
That is insufficient after introducing a second engine. Add a stable synthesis-profile
fingerprint containing at least:

```text
engine ID
engine/runtime revision
model manifest SHA-256
voice source/content fingerprint
precision
solver steps
temperature
seed/EOS settings
text normalization version
leading/trailing trim version
sample rate
```

Include this fingerprint in both the database key and file path, for example:

```text
audio/<profile-fingerprint>/<book>/<voice>/unit_<index>.wav
```

This also fixes stale-cache risk when settings or model files change within the same engine.

### Voice caches

Raven puts `.emb` and `.kv` files under the configured voice directory's `.cache`.
Configure a private, model-fingerprinted location such as:

```text
tts/raven/<model-fingerprint>/voices/<voice-uuid>.wav
tts/raven/<model-fingerprint>/voices/.cache/
```

Do not point Raven at a user-browsable import directory and do not key cached voices
only by the original filename. Copy or normalize the selected reference into a stable
file named by Guten-Speak's voice UUID/content hash. This prevents two imported files
named `voice.wav` from sharing the wrong embedding.

Deleting a voice must delete its Raven embedding/KV artifacts. Deleting or upgrading
the Raven model must invalidate all Raven voice KV caches and synthesized audio with
the old model fingerprint.

### Model preparation and delivery

Do not run Raven's Python graph-rewrite pipeline on the phone. Run it in a controlled
release/CI process at the pinned Raven revision, verify equivalence checks, and publish
only the exact Android runtime model set in a versioned archive.

The manifest should contain:

- Source repository and source model revision.
- Raven revision and preparation script revision.
- Every output filename, size, and SHA-256.
- Archive size/hash and extracted-size requirement.
- Runtime/model licenses and attribution text.
- Minimum compatible app/native ABI version.

Use a different installation directory from the sherpa bundle. Keep both model directories
during the trial so rollback does not require another large download; expose the extra
storage clearly and allow deleting either engine's assets.

## Expected code impact

| Existing area                         | Expected change |
|---------------------------------------|--------------------|
| [`pubspec.yaml`](../app/pubspec.yaml) | Add the local/native Raven plugin and FFI/code-generation dependencies as needed |
| [`tts_service.dart`](../app/lib/core/tts/tts_service.dart) | Extract the engine contract; retain sherpa implementation; add metrics and graceful native shutdown semantics |
| [`model_manager.dart`](../app/lib/core/tts/model_manager.dart) | Support engine-specific manifests, hashes, install directories, and cleanup |
| [`tts_providers.dart`](../app/lib/features/narration/presentation/providers/tts_providers.dart) | Select/prepare an engine without exposing raw FFI details |
| [`synth_cache.dart`](../app/lib/features/narration/data/repositories/synth_cache.dart) | Add synthesis-profile identity to lookup, registration, eviction, and paths |
| Database schema/migrations | Add profile/engine identity to the synthesized-audio cache key |
| [`storage_manager.dart`](../app/lib/features/storage/data/storage_manager.dart) | Account for Raven model, embedding/KV, and engine-specific audio storage |
| [`look_ahead_scheduler.dart`](../app/lib/features/narration/domain/services/look_ahead_scheduler.dart) | Ideally no behavior change; consume the common engine result |
| [`narration_audio_handler.dart`](../app/lib/features/narration/presentation/services/narration_audio_handler.dart) | No phase-one playback change; optionally expose benchmark buffering/underrun metrics |
| [`app/build.gradle.kts`](../app/android/app/build.gradle.kts) | Integrate the native module/AAR, arm64 packaging, release rules, and 16 KB checks |
| Tests | Add fake-engine contract tests, cache-fingerprint migrations, native smoke tests, cancellation/lifecycle tests, and long-run integration tests |

Most implementation risk is below the provider boundary. The narration UI and audio-service
behavior should not need an engine-specific fork.

## Time-boxed Android PoC

Estimated effort is roughly **two to three engineering weeks**, with an early stop
if a hard gate fails.

### Stage 0 — Re-establish the baseline (1–2 days)

- Add structured metrics to the current sherpa engine: model initialization,
  request-to-first-sample if available, complete WAV time, audio duration, RTF, peak RSS/PSS, and errors.
- Benchmark a fixed corpus in release mode on the Pixel 10 Pro and at least one slower supported arm64 device.
- Record cold process, warm model/cold voice, warm voice, continuous narration, and post-seek cases.
- Record exact current app commit, model hashes, device build, charge/thermal state, thread count, and power mode.

**Stop condition:** none; this baseline is needed regardless of Raven.

### Stage 1 — Native Android Raven harness (2–4 days)

- Build a small arm64-v8a native Android target with NDK r28+.
- Consume ONNX Runtime Android 1.23.2 headers and arm64 library.
- Compile the portable Raven graph path and SentencePiece.
- Generate WAVs from the same text/voice fixtures outside Flutter.
- Test cold/warm voice caches, one and multi-step flow, cancellation, malformed model sets, and repeated create/destroy.
- Verify 16 KB ELF alignment, release symbols/dependencies, and operation on a 16 KB Android environment.

**Stop condition:** no deterministic release-mode output, crashes/corruption,
unavailable required custom operations, or model initialization beyond the device memory budget.

### Stage 2 — Flutter FFI worker (2–4 days)

- Create a dedicated native plugin and generated C bindings.
- Wrap Raven in a worker isolate with explicit lifecycle/error handling.
- Aggregate PCM chunks into atomic per-unit WAV files.
- Use a private, fingerprinted voice cache.
- Produce a Raven-only benchmark build so the sherpa ONNX Runtime cannot mask an ABI mismatch.

**Stop condition:** native work cannot be cancelled/shut down safely, memory grows across requests,
or release builds fail reproducibly.

### Stage 3 — Narration integration (1–2 days)

- Connect the common engine interface to existing providers and scheduler.
- Add engine/profile identity to the synthesized-audio cache.
- Preserve current just_audio/audio_service file playback.
- Exercise play, pause, seek, rapid repeated seeks, voice changes, background/foreground
  transitions, process restart, and model deletion.

### Stage 4 — Controlled comparison (2–3 days)

- Run the benchmark matrix below with a fixed release build and repeated trials.
- Run blinded listening tests before looking at engine labels/timings.
- Run at least 30 minutes of uncached continuous narration per candidate profile.
- Document all failures as well as medians; do not report only the fastest prompt.

## Benchmark matrix

### Corpus

Use at least 100 real reading units sampled from the app's EPUBs, stratified by:

- Short, median, and near-maximum unit length.
- Dialogue, smart quotes, commas, em dashes, abbreviations, numbers, names, and sentence boundaries.
- Short units that exercise the model's padding behavior.
- At least three consented/bundled voice samples with different pitch and recording characteristics.

Use a larger automated soak corpus of at least 1,000 units for stability.
Store text and expected maximum durations so a missed EOS cannot run indefinitely.

### Cases

Measure each profile for:

1. Cold process and cold model.
2. Warm model and uncached voice embedding.
3. Warm model and cached voice/KV state.
4. First reading unit.
5. Steady-state serial reading units.
6. Seek to an uncached unit while another unit is generating.
7. Rapid seek/cancel/replan.
8. Thirty-minute uncached continuous narration.
9. Recovery after background/foreground and audio interruptions.

Report median, p90, p95, maximum, and failure count. RTF must be duration-weighted as well
as reported per unit so many short clips do not distort the result.

## Adoption gates

Raven should replace sherpa only if **all** mandatory gates pass with the same Raven profile.

| Dimension             | Mandatory gate |
|-----------------------|-------------------|
| Complete-unit latency | Median at least 30% lower than remeasured sherpa baseline and p95 no worse than baseline |
| Sustained synthesis | Duration-weighted RTF ≤ 0.75 and at least 30% lower than baseline on the primary device |
| Narration continuity | No synthesis-caused playback underruns in a 30-minute uncached run at normal playback speed |
| Quality | Blinded listeners find intelligibility, naturalness, voice similarity, pronunciation, and artifact/truncation rates non-inferior to the current engine for the selected profile |
| Correctness | Zero hangs, runaways, invalid WAVs, non-finite samples, or wrong-voice cache hits in the 1,000-unit soak |
| Lifecycle | Zero crashes/leaks across 100 create/synthesize/cancel/destroy cycles and rapid-seek tests |
| Memory | Peak app PSS no more than 10% above baseline; no upward trend after warm-up across the soak |
| Thermal | No severe thermal state; final-decile RTF degradation under 20% relative to first decile in the 30-minute run |
| Storage | Extracted Raven model set below 200 MB, with verified download/extract hashes and adequate free-space checks |
| Device coverage | All gates pass on the Pixel 10 Pro; correctness, RTF < 1, and safe memory behavior pass on the slower support device |
| Release build | Signed/release-mode app passes native smoke, background narration, and 16 KB page-size tests |
| Licensing | Weight redistribution/download route, attribution, consent UX, and prohibited-use handling receive explicit project approval |

A 30% speed gate prevents accepting a complex native migration for a difference users are unlikely to notice. If Raven is much faster but quality needs enough extra solver steps to miss the gate, keep sherpa and re-evaluate later model/runtime revisions.

## Risks and mitigations

| Risk                        | Impact        | Mitigation |
|-----------------------------|---------------|--------------|
| No maintained Android build | High | Keep Android integration in a small plugin, pin revisions/hashes, add release CI and a native smoke test |
| Apple decoder unavailable | High for performance | Benchmark portable decoder first; do not extrapolate M4 native numbers |
| Two ONNX Runtime versions in one APK | Critical | Use separate PoC builds; final dual-engine support requires one proven shared ORT or fully isolated native stacks |
| Quality regression from int8/one-step/default temperature | High | Blind profile sweep; require one profile to pass both quality and speed gates |
| Native lifetime/cancellation bugs | Critical | Explicit ownership, non-blocking poll/native abort wrapper, graceful join before isolate death, lifecycle soak tests |
| Model graph mismatch or partial download | Critical | Versioned all-file manifest, atomic install, per-file SHA-256, load-time compatibility check, maximum output duration |
| Stale/wrong voice embeddings | High | Private voice UUID paths; model/content fingerprints; engine-specific `.emb`/`.kv` directories |
| Stale synthesized WAVs | High | Add synthesis-profile fingerprint to database key and file path |
| Memory/thermal degradation during books | High | Long uncached release-mode runs, relative memory gate, tune AR/decoder threads instead of maximizing them |
| Upstream API churn/single-project dependency | Medium-high | Pin a reviewed commit, vendor notices, keep adapter narrow, retain sherpa rollback until Raven is proven in releases |
| Larger temporary trial storage | Medium | Show storage by engine and allow deleting either model/cache independently |
| Android 16 KB incompatibility | High | NDK r28+, modern AGP, verify every `.so`, APK/AAB alignment, and test on a 16 KB environment |
| Model terms or attribution missed | Critical | Legal/project review before distribution; surface attribution and consent/prohibited-use language in-product |

## Licensing and responsible use

This section records technical findings, not legal advice.

- Raven's runtime is MIT licensed.
- ONNX Runtime is MIT licensed.
- SentencePiece is Apache-2.0.
- Raven uses dr_libs under public-domain/MIT-0 terms.
- Any bundled voice sample has its own license and attribution requirements.
- The current official `kyutai/pocket-tts` Hugging Face metadata labels the model **CC-BY-4.0** and
  gates access on prohibited-use terms. The terms prohibit unlawful/harmful/deceptive activity and
  voice cloning without explicit lawful consent, among other uses.
- Raven's preparation script downloads a hash-pinned mirror of the official April 2026 ONNX web bundle.
  Hash verification protects integrity; it does not by itself establish a right to redistribute or
  bypass upstream access conditions.

Several existing Guten-Speak documents state that Pocket TTS weights are “non-commercial.” 
That statement no longer matches the current official metadata reviewed on 2026-08-29. 
It should be corrected in a separate documentation/legal pass, especially in
[`README.md`](../README.md), [`implementation-plan.md`](implementation-plan.md), and
[`tts-options.md`](tts-options.md). Do not replace it with an unconditional claim that every
distribution/commercial scenario is permitted: verify the exact weight source, model revision,
gated terms, attribution, and bundled voice licenses first.

Before release, Guten-Speak should:

- Require users to confirm that they own a voice or have explicit lawful consent to clone it.
- Explain that generated speech is synthetic and prohibit impersonation, deception, fraud, harassment, and privacy-invasive use.
- Keep voice processing local as it does now.
- Include Raven, Pocket TTS, ONNX Runtime, SentencePiece, model, and bundled-voice notices in the app and distribution materials.
- Decide whether models are redistributed, downloaded from an approved endpoint, or obtained by the user, and document that decision.

## Rollback and rollout

1. Develop Raven behind the common engine contract but use separate benchmark builds while ONNX Runtime versions differ.
2. Never overwrite sherpa model files, voice files, or WAV caches with Raven artifacts.
3. Keep the sherpa adapter and model manager working until Raven has passed the gates and at least one real-world release soak.
4. If one-runtime dual-engine packaging is proven, enable Raven through an internal/local feature flag first; default existing users to sherpa.
5. Preserve both synthesis-profile caches during a limited trial so switching back is immediate.
6. On Raven crash, corruption, repeated runaway, or failed model verification, disable Raven for the session and offer sherpa rather than repeatedly recreating the native engine.
7. Remove sherpa dependencies and its ONNX Runtime only after Raven is the accepted default and rollback release artifacts remain available.

## Final assessment

Raven is **a strong PoC candidate, not a drop-in dependency**.

Its model/runtime design directly addresses work that matters to autoregressive Pocket TTS:
full KV-cache copying, repeated shape/KV plumbing, per-frame flow dispatch, attention-tail
computation, voice conditioning, and AR/decoder overlap. Android arm64 can use most of these
improvements, including NEON attention, but cannot use the fastest Apple decoder.
The existing Guten-Speak scheduler/cache/player architecture is unusually well suited
to testing it with limited upper-layer change.

The most important unknown is not whether the C API can be called from Flutter—it can.
It is whether the portable int8 path, with an acceptable listening profile, is faster
and thermally stable enough on real Android hardware to justify owning a custom NDK/FFI/model
pipeline. The time-boxed PoC and gates above answer that question while protecting the working
sherpa implementation.

## Sources

### Raven, pinned revision

- [Repository README and claimed performance](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/README.md)
- [Public C API](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/include/pocket_tts.h)
- [C++ runtime](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/src/pocket_tts.cpp)
- [Portable custom attention](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/src/pocket_tts_custom_attention.hpp)
- [Native CMake build](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/CMakeLists.txt)
- [Model preparation and pinned source hashes](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/tools/prepare_models.sh)
- [Optimization notes](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/docs/OPTIMIZATION_NOTES.md)
- [Third-party notices](https://github.com/pkalogiros/pocket-tts-raven/blob/abd26158ab50f954616eaf42296b09c4856489d7/THIRD_PARTY_NOTICES.md)

### Platform and model

- [ONNX Runtime install guide, including Android C/C++ AAR usage](https://onnxruntime.ai/docs/install/)
- [ONNX Runtime Android build guide](https://onnxruntime.ai/docs/build/android.html)
- [ONNX Runtime mobile guidance](https://onnxruntime.ai/docs/tutorials/mobile/)
- [ONNX Runtime Android 1.23.2 artifact](https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/1.23.2/)
- [Android 16 KB page-size guidance](https://developer.android.com/guide/practices/page-sizes)
- [Official Pocket TTS model card and current access terms](https://huggingface.co/kyutai/pocket-tts)
- [Creative Commons Attribution 4.0](https://creativecommons.org/licenses/by/4.0/)
