# Guten-Speak — Viability Assessment

_A Flutter mobile app that searches Project Gutenberg, downloads books, and reads
them aloud with a user-cloned narrator voice._

> **Target platform: Android first.** iOS is a possible later port; all
> decisions below prioritize Android (NDK builds, per-ABI `.so`, Play Store
> constraints). iOS notes are kept only as forward-looking context.

**Verdict: Viable, with one hard part.** The catalog + download side is trivial.
The on-device TTS/voice-cloning side is the real engineering challenge, but a
working path exists via Flutter FFI against `pocket-tts-raven`'s C API.

---

## 1. What the app needs to do

| Capability | Difficulty | Notes |
|---|---|---|
| Search catalog (author/title) | Easy | Gutendex REST API, no auth |
| Download book text | Easy | Direct `.txt.utf-8` URLs |
| Clean/segment text | Medium | Strip Gutenberg boilerplate, split into sentences |
| Text-to-speech | Hard | On-device neural TTS engine |
| Voice cloning | Hard | Same engine; 6–15 s reference clip |
| Audio playback + controls | Medium | Background play, seek, resume |

---

## 2. Catalog & download (low risk)

- **Gutendex** (`https://gutendex.com/books`) gives clean JSON, no API key,
  supports `search=`, `topic=`, `languages=`, and ID lookup. Straightforward
  `http`/`dio` calls in Dart.
- **Text retrieval**: the `formats` object exposes a
  `text/plain; charset=us-ascii` (or UTF-8) URL. Direct download works.
- **Caveats**:
  - Gutendex is a free community service — no SLA. Mitigate by caching results
    and falling back to Gutenberg's predictable direct URLs
    (`https://www.gutenberg.org/ebooks/{id}.txt.utf-8`).
  - Plain-text files carry a Gutenberg license header/footer that must be
    stripped before narration (well-known `*** START/END OF THE PROJECT
    GUTENBERG EBOOK ***` markers).
  - Respect Gutenberg's automated-access etiquette (reasonable rate limits,
    a descriptive User-Agent). Bulk scraping is discouraged; per-user on-demand
    downloads are fine.

**Risk: Low.**

---

## 3. Text-to-speech + voice cloning (the crux)

The README proposes `pocket-tts-raven` (Kyutai Pocket TTS on ONNX Runtime).
Assessment of fit for a Flutter mobile app:

### What's promising
- **On-device, no cloud**: cloning and synthesis run locally; nothing is
  uploaded. Great for privacy and the "clone your own favorite voice" pitch,
  and it sidesteps server costs.
- **Real-time capable on mobile**: the project reports the same WASM build
  running **~3–4× real time on an iPhone (<250 ms latency)** in-browser. A
  **native ARM** build compiled with the NDK/Xcode toolchain should meet or beat
  that, so real-time narration is realistic.
- **Clean integration surface**: it ships a **C API (FFI)** —
  `ptt_create`, `ptt_stream_start`, `ptt_stream_read`, `ptt_free_audio`,
  `ptt_destroy`, etc. Audio is mono **float32 @ 24 kHz**. This maps directly onto
  Dart's `dart:ffi`, which is the standard way to call C from Flutter.
- **Streaming output**: `ptt_stream_read` yields chunks as they generate, so
  playback can start before a sentence finishes — good for perceived latency.
- **Voice cloning is implicit**: cloning *is* synthesis — pass any 6–15 s
  wav/mp3 as the voice argument; embeddings are cached (`.emb`) and KV
  snapshots (`.kv`) restore in ~4 ms.

### What's hard / risky
1. **Building the native lib for Android.**
   - It's a C++17 / CMake project depending on **ONNX Runtime** plus custom ops.
     For Android you must produce a `.so` per ABI — **arm64-v8a** at minimum
     (covers the vast majority of modern devices); optionally **armeabi-v7a** for
     older/cheaper hardware and **x86_64** for the emulator. Flutter's Android
     Gradle + CMake/NDK toolchain (`externalNativeBuild`) is the standard path,
     and ONNX Runtime ships an official Android AAR/build. Wiring the custom-op
     registration into the NDK build is the non-trivial, first-time-only work.
   - The reported headline speeds use Apple-silicon-specific fused ops; generic
     ARM (Android arm64) will be somewhat slower (still expected to be
     > real time, but this **must be measured on real mid-range Android phones**,
     not just flagships). Consider ONNX Runtime's **NNAPI** execution provider to
     offload to the device NPU/DSP where available.
   - _iOS (later):_ would additionally need a static lib/`.framework` for arm64.
2. **Model size & delivery.**
   - The model bundle is **~165 MB raw** (web set ~65–67 MB compressed + ~14 MB
     encoder). Bundling in the app binary is too large for store limits/UX;
     **download-on-first-run** into app storage is the right approach.
3. **Battery / thermals.**
   - Long-form narration (a whole book) is sustained CPU load. Mitigate by
     **pre-generating audio per chapter/section** to a cache file, then playing
     back the cached WAV/compressed audio (near-zero ongoing cost, offline
     replay, scrubbing). This also decouples playback smoothness from synthesis.
4. **Licensing of the model weights.**
   - The `pocket-tts-raven` *runtime* is MIT, but the **Kyutai Pocket TTS model
     weights carry their own license and prohibited-use terms**. Ungated
     CC-BY-4.0 weights exist, but you must **verify the license permits
     redistribution/commercial use** and provide attribution. This is a
     go/no-go item to confirm before committing.
5. **Voice-cloning consent & abuse.**
   - The engine can clone arbitrary voices. Even though clones are "only for
     yourself," ship clear consent UX ("only clone voices you own or have
     permission to use") and avoid features that ease impersonation.

### Alternatives / fallbacks
- **Fallback TTS**: platform TTS via `flutter_tts` (Android/iOS system voices).
  No cloning and lower quality, but guarantees a shippable v1 while the neural
  engine is integrated. Good to de-risk the roadmap.
- **Other on-device engines** (e.g. Piper/Sherpa-ONNX) exist with mature mobile
  bindings but **lack instant voice cloning**, which is guten-speak's
  differentiator.

**Risk: Medium-High, but tractable.** The FFI + native-build step is the main
schedule risk.

---

## 4. Playback & app plumbing (medium risk)

- **Audio**: `just_audio` + `audio_service` for background playback, lock-screen
  controls, seek, and resume — standard, well-supported Flutter stack.
- **Reading position**: persist book ID, chapter, and character/sentence offset
  so narration resumes where the user left off.
- **Storage**: cached book text, generated audio, and voice embeddings in app
  documents dir; add a cache-size manager.
- **State/architecture**: Riverpod or Bloc; a repository layer over Gutendex; an
  isolate or the FFI stream thread for synthesis so the UI never blocks.

---

## 5. Recommended architecture

```
Flutter UI (search, library, player, voice manager)
        │
        ├── Catalog repo ──► Gutendex API / Gutenberg direct URLs
        │
        ├── Text pipeline ─► download → strip boilerplate → sentence split
        │
        ├── TTS service ───► dart:ffi ─► libpocket_tts.so (Android arm64)
        │                                   ├── voice clone (.emb/.kv cache)
        │                                   └── streaming float32 @ 24kHz
        │
        └── Player ────────► just_audio + audio_service (plays cached audio)
```

**Key design choice:** synthesize **ahead** (per chapter) into cached audio
files rather than strictly real-time during playback. This maximizes battery
life, enables offline listening, and makes scrubbing smooth.

---

## 6. Suggested phased plan

1. **Phase 0 — Spike (highest-risk-first).** Prove `pocket-tts-raven` builds
   (NDK, arm64-v8a) and runs via FFI on a **real Android arm64 device**. Measure
   real-time factor and RAM on a mid-range phone; try the NNAPI EP. *Go/no-go
   gate.* (iOS deferred.)
2. **Phase 1 — Catalog + reading.** Gutendex search, book detail, text download
   and cleanup, simple reader. Ship with `flutter_tts` fallback voice.
3. **Phase 2 — Neural narration.** Integrate the FFI engine, chapter-ahead
   synthesis + caching, `just_audio`/`audio_service` playback.
4. **Phase 3 — Voice cloning UX.** Record/import reference clip, manage voices,
   consent flow.
5. **Phase 4 — Polish.** Offline library, downloads manager, resume position,
   settings (speed, temperature).

---

## 7. Open questions to resolve before committing

- Does the chosen **Pocket TTS weight license** permit redistribution in a free
  app (and attribution terms)?
- Real-time factor and memory on **target mid/low-end Android devices**?
- Which **ABIs** to ship (arm64-v8a only vs. + armeabi-v7a), and does that keep
  the Play Store APK/AAB size acceptable?
- Does the **NNAPI** execution provider help or hurt on real devices?
- Acceptable **first-run download size** (~80–165 MB) for target users?

---

## 8. Bottom line

- **Catalog/download:** clearly viable, low effort.
- **Playback/app:** standard Flutter, medium effort.
- **On-device neural TTS + cloning:** the differentiator and the hard part —
  **viable via FFI to `pocket-tts-raven`'s C API**, contingent on a successful
  Phase 0 native-build spike and confirmation of the model weight license.

**Recommendation: proceed, but start with the Phase 0 TTS spike** before
investing in UI. If the native build or on-device performance disappoints, fall
back to `flutter_tts` for v1 and keep neural cloning as a fast-follow.
