# Guten-Speak — Proof of Concept (PoC)

**Goal:** Prove the hard part in isolation. A minimal Flutter **Android** app that
can (1) clone a voice from an imported voice sample and (2) speak arbitrary typed
text in that voice — **entirely on-device**, with **no Project Gutenberg involvement**.

This is the Phase 0 spike. If it succeeds, the full app is low-risk. If it
fails or performs poorly, we learn that before building any real UI.

---

## 1. Scope

### In scope
- Import a 6–15 s voice sample (upload a `.wav`) — **no in-app recording**.
- Clone that voice on-device (`pocket-tts-raven` Mimi encoder → embedding).
- Type/paste a short text, tap **Speak**, hear it in the cloned voice.
- Native `pocket-tts-raven` `.so` (arm64-v8a) called via **Dart FFI**.
- Run on a **real Android arm64 device**.

### Explicitly out of scope
- No Gutendex / no book search / no downloads.
- No background playback, no lock-screen controls, no chapter caching.
- No fancy UI, no state management framework, no offline library.
- No iOS.
- No Play Store packaging.

---

## 2. Success criteria (go/no-go gate)

The PoC "passes" if, on a mid-range Android arm64 phone:

1. The native lib **builds and loads** via FFI (no crashes, no missing symbols).
2. An **imported** voice sample is **cloned** and audibly resembles the source.
3. A typed sentence is spoken back in that voice with **acceptable quality**.
4. Synthesis runs at **≥ ~1× real time** (measure the real-time factor).
5. Peak **RAM stays within** what a mid-range phone tolerates (record the number).

Capture the measured real-time factor and RAM in this doc after the run.

---

## 3. The main technical unknowns to resolve

0. **Can `sherpa-onnx` (prebuilt Flutter libs) run a cloning-capable model
   on-device well enough?** If so, most of the unknowns below disappear.
1. **Cross-compiling `pocket-tts-raven` + ONNX Runtime for Android arm64**
   via the NDK (this is the crux — CMake + custom-op registration).
2. **FFI surface**: mapping the C API (`ptt_create`, `ptt_stream_start`,
   `ptt_stream_read`, `ptt_free_audio`, `ptt_destroy`) into Dart.
3. **Mic capture** producing a clip the encoder accepts (mono, correct
   sample rate — engine works in mono float32 @ 24 kHz).
4. **Playback** of the generated float32 PCM chunks.
5. **Model files** shipped to / downloaded into app storage (~80–165 MB).

---

## 4. Suggested build order (de-risk hardest-first)

0. **Cheaper-path spike: `sherpa-onnx` first (time-boxed ~1 day).**
   Before doing any custom NDK work, try the **`sherpa_onnx` pub.dev package**,
   which ships **prebuilt Android native libraries** and Dart FFI bindings. Check
   whether a **cloning-capable** model can run on-device with acceptable quality
   and speed.
   - **If yes** → this is the lowest-effort path; build the PoC on `sherpa_onnx`
     and **skip steps 1–2** (no custom cross-compile needed).
   - **If no** (no good zero-shot cloning model available, or quality/speed
     insufficient) → fall through to step 1 and build the `pocket-tts-raven`
     engine as originally planned.
   See [tts-options.md](tts-options.md) for the rationale.
1. **Native build spike (no Flutter yet).**
   Cross-compile `pocket-tts-raven` for `arm64-v8a` with the NDK. Push the CLI
   (or a tiny test harness) to a device via `adb` and confirm it synthesizes a
   wav from the bundled sample voice. *This is the make-or-break step.*
2. **FFI binding.**
   Wrap `libpocket_tts.so` in a Flutter Android project (`android/.../jniLibs/`
   or `externalNativeBuild`). Bind the C API with `dart:ffi` (or `ffigen`).
   Hardcode a bundled sample voice + fixed text; get audio out to a file.
3. **Playback.**
   Play the generated audio with `just_audio` (feed a temp WAV) or a raw PCM
   player. Confirm end-to-end: button → synth → sound.
4. **Mic + cloning.**
   Add `record` (or `flutter_sound`) to capture 6–15 s. Feed that clip as the
   voice argument; confirm the output adopts the recorded voice.
5. **Text box.**
   Replace fixed text with a `TextField`. Done.

---

## 5. Minimal UI

A single screen:

```
[ Import voice (.wav) ]          → status: "voice ready"
[ TextField: type what to say ]
[ Speak ]                        → plays generated audio
   real-time factor / latency shown for measurement
```

---

## 6. Likely Flutter dependencies

- `file_picker` — import a `.wav` voice sample (no in-app recording).
- `just_audio` — playback (or a small custom PCM player).
- `ffi` + `ffigen` — C API bindings.
- `path_provider` — app storage for models / temp audio.

Native side: Android NDK, CMake, ONNX Runtime (Android build), the
`pocket-tts-raven` sources.

---

## 7. Known risks specific to the PoC

- **NDK build friction** is the top risk — custom ops + ONNX Runtime for Android
  may need build-flag tuning. Budget the most time here.
- **Model weight license** must permit redistribution — confirm before bundling
  (use the ungated CC-BY-4.0 weights and attribute).
- **Performance variance**: a flagship may pass while a low-end phone struggles.
  Test on a realistic mid-range device, not just the best phone available.
- **Mic format mismatch**: ensure the recorded clip is resampled to what the
  encoder expects.

---

## 8. Outcome → next step

- **`sherpa-onnx` spike passes** → build the PoC on it (lowest effort); the
  custom native build may be unnecessary.
- **Pass** → proceed to Phase 1 (Gutendex catalog + reader) and reuse the FFI
  TTS service unchanged.
- **Struggles on mid-range devices** → keep the PoC engine for capable phones
  but plan a `flutter_tts` fallback path for v1.
- **Fail (build/quality)** → reassess the engine choice (e.g. Piper/Sherpa-ONNX
  without cloning) before investing further.

---

## 9. Spike results — macOS iteration (2026-08-25)

Iterating on **macOS desktop** for speed before touching Android. Engine =
`sherpa_onnx` 1.13.6 pub package (prebuilt native libs, Dart FFI) running
**PocketTTS** (zero-shot cloning, no reference transcript needed, model runs
internally at 24 kHz).

### What works
- `sherpa_onnx` PocketTTS **clones a voice and speaks typed text on-device** —
  the Step-0 hard part is proven on macOS. End-to-end: record/import → clone →
  synthesize → play.
- **Full-precision (fp32) model clones faithfully.** Good result on the
  `Reginald-Ashworth` reference at **Steps = 28, Temp = 0.20, seed = 1234**.

### Key findings / gotchas
- **int8 vs fp32 quality:** the int8 model
  (`sherpa-onnx-pocket-tts-int8-2026-01-26`) introduced audible **distortion**
  at low temperature / high step counts. Switching to the **full-precision
  model** (`sherpa-onnx-pocket-tts-2026-01-26`) removed it. Cost: **~470 MB on
  disk** (`lm_main.onnx` alone is 302 MB) vs ~200 MB for int8 — a real
  size/quality tradeoff to weigh for the Android build.
- **Reference-audio level is critical.** A quiet recording (mic far / low gain,
  RMS ≈ −35 dBFS with ~63% near-silence) produced unstable, "spooky" multi-voice
  clones — peak-normalization amplifies the noise floor and the speaker
  embedding is computed over mostly noise. A **loud, close, continuous** sample
  (RMS ≈ −18 dBFS) clones cleanly.
- **`record_macos` ignores the requested sample rate** for WAV file recording —
  it uses the hardware input device rate (yielded 16 kHz / 24 kHz on this Mac).
  Android's `record` honors the requested rate. 16 kHz references still clone
  fine, so this was a red herring for quality.
- **`sherpa_onnx` `readWave` is fragile** — it rejects `WAVE_FORMAT_EXTENSIBLE`
  (fmt size 40, as macOS `record` emits) and hard-crashes. We use a **tolerant
  custom WAV parser** (`_readWavAsFloat32`) that skips JUNK chunks, resolves the
  extensible SubFormat GUID, and downmixes/normalizes.
- **numSteps** trades quality for speed; **very high** step counts (≈32) can
  over-run into noise. **Low temperature** exposes model artifacts (hence the
  int8 distortion above).

### Still open
- **Real-time factor (RTF) and peak RAM** on macOS not yet formally recorded;
  fp32 is slower than int8 — capture the RTF number next.
- **Android:** not yet built/run (licenses not accepted). The size/speed of the
  fp32 model on a mid-range arm64 device is the next real gate.
- **License flag:** PocketTTS (`kyutai/pocket-tts`) model weights are
  **NON-COMMERCIAL** — fine for a free personal app, but blocks any commercial
  path. See [viability.md](viability.md).

## 10. Spike results — Android on-device (Pixel 10 Pro, 2026-08-25)

First real on-device run on a **Pixel 10 Pro (Google Tensor G5, arm64-v8a,
Android 17 / API 37)**. Same engine and fp32 model as §9.

### Result — Step 0 works end-to-end on Android ✅
Record → clone → synthesize → play all run on-device with acceptable quality.

| Metric | Value |
| --- | --- |
| Reference clip | **built-in sample** (`test_wavs/bria.wav`), *not* a live recording |
| Generated audio | **5.54 s @ 24 000 Hz** |
| Generation time | **7 733 ms** |
| **Real-time factor** | **1.40×** (slower than real time) |
| Settings | Steps = 28, Temp = 0.20, seed = 1234, fp32, `numThreads = 2` |

### Update — default sample voice + `numThreads = 4` (2026-08-25)
Two changes since the run above: the default sample voice was swapped from the
tarball's `bria.wav` to a bundled clean, loud clip (`Reginald-Ashworth.wav`,
44.1 kHz mono, resampled to 24 kHz by sherpa-onnx at load), and the worker
isolate now uses `numThreads = 4`. Re-measured with the sample voice:

| Metric | Value |
| --- | --- |
| Reference clip | **bundled sample** (`assets/reginald-ashworth.wav`) |
| Generated audio | **4.15 s @ 24 000 Hz** |
| Generation time | **4 657 ms** |
| **Real-time factor** | **1.12×** (down from 1.40×) |
| Settings | Steps = 28, Temp = 0.20, seed = 1234, fp32, `numThreads = 4` |

> `numThreads = 2 → 4` closes most of the gap to real time (1.40× → 1.12×) on
> the Tensor G5 with no quality loss observed. Still just above 1×; fewer
> `numSteps` or int8 would push it under on this device (a mid-range phone
> would still be slower).


> ⚠️ This measurement used the **bundled sample voice**. Cloning the user's
> **own on-device recording** currently **fails**: after a **long** stall (UI
> grayed out) synthesis eventually runs, but the output is **only white
> noise** — no usable clone. So end-to-end with the *real* target input is
> **not yet proven** on Android. See "Still open" below.

### go/no-go read
- Criteria **1–3 pass** (loads via FFI, clones audibly, speaks with acceptable
  quality). Criterion **5 (RAM)** not yet formally captured.
- Criterion **4 (≥ ~1× real time) is NOT met at these settings**: **RTF 1.40×**
  means ~7.7 s of compute for ~5.5 s of audio. And this is on a **flagship**
  Tensor G5 — a mid-range phone (the actual target) would be slower still.
- Verdict: **functionally proven, but too slow for real-time as configured.**
  Usable for a "type → wait a few seconds → hear it" flow; not for streaming.

### Speed levers to try (in order of effort)
1. **More threads** — the run used only `numThreads = 2` on an 8-core SoC.
   Raising it (e.g. 4) is the cheapest likely win; re-measure RTF.
2. **Fewer `numSteps`** — trades quality for speed (28 → 16/12).
3. **int8 model** — faster + ~270 MB smaller, at the quality cost noted in §9.
4. **`pocket-tts-raven` optimized ONNX export** — the reserve "speed lever"
   (delta-KV cache, merged flow, custom-op injection). See
   [tts-options.md](tts-options.md).

### Android-specific engineering findings
- **All heavy native work must run off the UI thread.** Doing model
  extraction, model load, and synthesis on the UI isolate froze the app long
  enough to trigger Android's **ANR ("application doesn't respond")** dialog
  repeatedly. Fixed by moving extraction to a one-shot `Isolate.run` and
  hosting the `OfflineTts` in a **persistent background isolate** (see
  `tts_service.dart`, `model_manager.dart`).
- **`extractFileToDisk` fails on Android.** It decompresses `.tar.bz2` via the
  platform temp dir (`code_cache`) and threw `PathNotFoundException` on the
  intermediate `temp.tar`. Replaced with a **low-disk** extractor that decodes
  the bz2 in RAM, **deletes the archive before writing files**, then untars —
  disk peak ≈ the 470 MB payload instead of archive + tar + files at once.
- **Storage headroom matters.** The test device was ~99% full (~1 GB free);
  the 165 MB debug APK + ~470 MB model + transient extraction space initially
  hit `INSTALL_FAILED_INSUFFICIENT_STORAGE`. Needs a few GB free.
- **API 37 toolchain gap:** a transitive plugin (`permission_handler_android`)
  requires `compileSdk = 37`, and the SDK installs the platform as
  `android-37.0` while Gradle looks for `android-37` (symlinked as a workaround).

### Still open
- **Own-voice recording → runaway white noise (the real blocker).** The 1.40×
  run above worked from the bundled `bria.wav`. Using a **phone-recorded**
  reference (`record` → `<temp>/reference.wav`) behaves very differently: a
  **long** stall (UI grays out — not a crash, no ANR, the process stays alive)
  and then synthesis produces **only white noise**. Measured on the same
  one-sentence prompt that yields ~5.5 s from `bria.wav`:

  | Metric | Own recording (noise) | Bundled sample (good) |
  | --- | --- | --- |
  | Generated audio | **80.00 s** (runaway) | 5.54 s |
  | Generation time | **109 457 ms** | 7 733 ms |
  | Real-time factor | 1.37× | 1.40× |

  So the bad embedding doesn't just *sound* like noise — the model **runs away
  to ~80 s** (looks like a hard max-length cap) instead of the ~5.5 s the same
  text produces from a clean reference, which is why it takes ~110 s.

  Root cause is the **recorded reference itself** (pulled and analyzed):
  format is fine (24 kHz mono 16-bit PCM, 9.76 s) but the level is far too
  low — **RMS ≈ −34.8 dBFS, peak −15 dBFS, 53.8% near-silence**. The speaker
  embedding is computed over mostly noise floor, and peak-normalization just
  multiplies that noise up ~5×. This is the same "quiet reference → garbage
  clone" failure seen on macOS in §9.

  **✅ Resolved by design (2026-08-26): in-app recording is dropped.** On this
  device AGC is unavailable ("Auto gain effect is not available") and
  post-gain can't fix SNR, so mic capture is unreliable. Importing a clean,
  loud `.wav` clones well and was confirmed on-device. Voice input is now
  **file upload only** — see §11.

- **Re-measure RTF with `numThreads = 4`** — ✅ done (see "Update" above):
  1.40× → **1.12×** on the Tensor G5, no quality loss observed.
- **Peak RAM** not yet captured (fp32 `lm_main.onnx` is 302 MB; expect the
  worker isolate to hold ~0.5 GB+).
- Confirm behavior on an actual **mid-range** arm64 device, not just the
  flagship Tensor G5.

## 11. Decision — drop recording, adopt a named voice library (2026-08-26)

The PoC hard part is proven end-to-end on Android (clone → speak, RTF 1.12× at
`numThreads = 4`). Based on the on-device findings, the voice-input design is
revised:

- **In-app recording is dropped.** The phone mic path was unreliable: no
  hardware AGC on the test device, quiet captures (RMS ≈ −35 dBFS) produced
  runaway white-noise clones, and post-gain can't recover SNR (§9, §10).
- **Voice input = file upload.** Users import a `.wav` sample (proven to clone
  cleanly on-device). MP3 import is deferred (needs a native decoder such as
  `flutter_soloud`; not required for v1).
- **Voices are stored and named = a reusable voice library.** Each imported
  sample is copied into app storage with a user-given name, so a voice can be
  picked again later without re-importing. The bundled sample
  (`Reginald-Ashworth.wav`) ships as a built-in default entry.

### What this means for the main app
- **Voice library screen:** list of saved voices (name + built-in default),
  **Add voice** (file picker → name → store), select/delete. Persist the list
  (e.g. a small JSON index in app support) alongside the copied `.wav` files.
- **Reader integration:** the book player gets a **voice picker** that reads
  from this library; the selected voice's stored `.wav` is passed to the TTS
  service as the reference clip.
- **Dependencies:** keep `file_picker`; **drop `record`**. Add lightweight
  persistence for the voice index (plain `dart:io` + JSON is enough).

This unblocks moving on to the main project (Phase 1: Gutendex catalog + reader,
reusing the existing on-device TTS service unchanged).


