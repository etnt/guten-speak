# Guten-Speak — Proof of Concept (PoC)

**Goal:** Prove the hard part in isolation. A minimal Flutter **Android** app that
can (1) clone a voice from a short recording and (2) speak arbitrary typed text
in that voice — **entirely on-device**, with **no Project Gutenberg involvement**.

This is the Phase 0 spike. If it succeeds, the full app is low-risk. If it
fails or performs poorly, we learn that before building any real UI.

---

## 1. Scope

### In scope
- Record (or import) a 6–15 s voice sample on the phone.
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
2. A voice recorded on the phone is **cloned** and audibly resembles the user.
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
[ Record voice ]   (6–15 s)      → status: "voice ready"
[ TextField: type what to say ]
[ Speak ]                        → plays generated audio
   real-time factor / latency shown for measurement
```

---

## 6. Likely Flutter dependencies

- `record` or `flutter_sound` — mic capture.
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
