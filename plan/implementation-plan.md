# Guten-Speak — Implementation Plan

This is the end-to-end build plan for **Guten-Speak**: a Flutter (Android-first)
app that searches Project Gutenberg, downloads books, and **reads them aloud in a
user-cloned narrator voice** — entirely on-device.

It is grounded in two things we already have:

1. **`guten-read`** (sibling project, symlinked at `./guten-read`) — a mature,
   clean-architecture Flutter e-reader for Project Gutenberg. Its catalog +
   search are already built; reader / library / download are planned. We **reuse
   its architecture and code** for the entire "read a Gutenberg book" half.
2. **The Guten-Speak PoC** (`./poc`, documented in [poc.md](poc.md)) — proved the
   hard part: **on-device zero-shot voice cloning + TTS** via the `sherpa_onnx`
   PocketTTS model, running in a background isolate at **RTF ≈ 1.12×** on a
   Pixel 10 Pro.

> **Guten-Speak = guten-read (reader) + PoC (narration).** The plan below is
> mostly "assemble two proven halves," plus the new glue: chapter-ahead
> synthesis, an audio cache, and a background player.

---

## 1. Product goals

- **Listen to public-domain books** from Project Gutenberg, narrated on-device.
- **Clone a favorite narrator voice** from a short `.wav` sample and reuse it
  across books (a named, persisted voice library).
- **Offline-first**: once a book is downloaded and a chapter is synthesized,
  reading *and* listening work with no network.
- **Free / non-commercial** by design — the PocketTTS weights are
  non-commercial-only (see §8), which fits a free personal app.
- **Read *and* listen — narration is optional.** Guten-Speak is a fully usable
   plain e-reader on its own: a user can search, download, and **just read** a
   book like in any other reader app, never touching voice narration. Narration
   (and therefore the ~470 MB model download) is an **opt-in** mode layered on
   top, ideally with the current paragraph highlighted as it plays.
- **App-wide theming.** The whole app supports switching between a **dark theme
  (default)** and a **light theme**, persisted across launches (this is the
  global app chrome — separate from the reader's per-page reading themes in §5.3).
| Area | Source | Status |
|---|---|---|
| Feature-first architecture, theming, nav shell | guten-read | ✅ reuse as-is |
| Gutendex catalog + search + book detail | guten-read | ✅ built, reuse |
| Dio client + User-Agent interceptor + `Failure`/`Result` | guten-read | ✅ reuse |
| Download pipeline + Gutenberg boilerplate stripper | guten-read plan (Phase 3) | ⬜ build (shared need) |
| Text reader (lazy render, paragraph-index positions, TOC) | guten-read plan (Phase 4) | ⬜ build (shared need) |
| Local library + progress (`sqflite`) | guten-read plan (Phase 5) | ⬜ build (shared need) |
| **On-device TTS service (clone + synth, worker isolate)** | **PoC** | ✅ proven, port in |
| **Model manager (download + fallback + low-disk extract)** | **PoC** | ✅ proven, port in |
| **Voice library (WAV upload, named, persisted, built-ins)** | **PoC** | ✅ proven, port in |
| **Text → narration segmentation** | new | ⬜ build |
| **Chapter-ahead synthesis + audio cache** | new | ⬜ build |
| **Background player (controls, lock screen, resume)** | new | ⬜ build |
| **Narration ↔ reader sync (highlight current line)** | new (stretch) | ⬜ build |

**Decision — codebase strategy:** evolve a **copy of `guten-read`** into
`guten-speak` (rename bundle id + app name), rather than depending on it as a
package. It is an application, not a library, and we need to modify the reader to
integrate narration. Keep the two git histories independent.

---

## 3. Technology stack

Merges guten-read's stack with the PoC's proven TTS/audio pieces.

| Category | Package / Tool | Purpose | From |
|---|---|---|---|
| Framework | Flutter (stable) / Dart 3.x | Cross-platform (Android first) | both |
| State mgmt | `flutter_riverpod` + `riverpod_annotation` (code-gen `@riverpod`) | Reactive, testable state | guten-read |
| Routing | `go_router` (StatefulShell bottom nav) | Declarative nav + deep links | guten-read |
| Networking | `dio` | HTTP, interceptors, download progress | guten-read |
| Metadata storage | `sqflite` | Books, progress, bookmarks, **synth cache index** | guten-read |
| Key-value | `shared_preferences` | Reader + narration settings | guten-read |
| Files | `path_provider` | Books, model, voices, cached audio | both |
| Covers | `cached_network_image` | Cover thumbnails | guten-read |
| Connectivity | `connectivity_plus` | Offline-first UX | guten-read |
| Codegen | `build_runner`, `freezed`, `json_serializable`, `riverpod_generator` | Models + providers | guten-read |
| **On-device TTS** | **`sherpa_onnx` ^1.13.6** | PocketTTS zero-shot cloning + synth (fp32, 24 kHz) | PoC |
| **Voice import** | **`file_picker`** | Import `.wav` voice samples | PoC |
| Archive | `archive` | Decode `.tar.bz2` model archive (custom low-disk path) | PoC |
| HTTP (model) | `http` | Stream model download with progress + fallback | PoC |
| **Audio playback** | **`just_audio` + `audio_service`** | Background play, lock-screen, seek, resume | new (viability) |
| Testing | `flutter_test`, `integration_test`, `mocktail` | Unit/widget/integration | guten-read |
| Lint / CI | `flutter_lints`, GitHub Actions | Static analysis, CI | guten-read |

> **Playback note:** the PoC used `audioplayers` for a quick one-shot preview.
> The full app needs **background** playback of long content with lock-screen
> controls, so migrate narration playback to **`just_audio` + `audio_service`**.
> Drop `permission_handler` (only needed for the abandoned mic path).

---

## 4. Architecture & directory structure

Feature-first, extending guten-read's layout with two new features (`voices`,
`narration`) and shared TTS infrastructure under `core/`.

```
lib/
├── app/                          # MaterialApp.router, GoRouter, theme, nav shell   (reuse)
├── core/
│   ├── constants/                # API endpoints, model/voice paths                 (reuse+extend)
│   ├── network/                  # Dio client, interceptors, Failure/Result         (reuse)
│   ├── storage/                  # sqflite + shared_preferences helpers             (reuse)
│   ├── tts/                      # ── ported from PoC ──
│   │   ├── tts_service.dart      #   OfflineTts hosted in a persistent isolate
│   │   ├── model_manager.dart    #   download (mirror→upstream) + low-disk extract
│   │   ├── wav_io.dart           #   tolerant WAV reader/writer (_readWavAsFloat32)
│   │   └── tts_isolate.dart      #   isolate protocol (init / synth / dispose)
│   ├── utils/                    # Gutenberg text stripper, segmenter               (build)
│   └── widgets/                  # shared loading/error/empty views                 (reuse)
└── features/
    ├── catalog/                  # Discover, Search, Book Detail                     (reuse)
    ├── library/                  # Downloads, shelves, progress, storage mgr        (build)
    ├── reader/                   # Text reader (lazy render, TOC, themes)            (build)
    ├── voices/                   # ── new: voice library ──
    │   ├── data/                 #   VoiceLibrary (JSON index + copied .wav files)
    │   └── presentation/         #   VoicesScreen, add/name/delete, built-ins
    ├── narration/                # ── new: TTS narration ──
    │   ├── data/                 #   NarrationRepository, SynthCache, audio encoder
    │   ├── domain/               #   NarrationUnit (segment), SynthJob, PlaybackState
    │   └── presentation/         #   PlayerScreen, mini-player, voice picker, providers
    └── settings/                 # App + reader + narration settings                (reuse+extend)
```

---

## 5. Core modules & specifications

### 5.1 Catalog & Search (`features/catalog`) — reuse
Already implemented in guten-read: Gutendex `search`/`topic`/`languages`/`page`,
Discover (popular + curated subjects), debounced Search, Book Detail. Add a
**"Listen"** action alongside "Read" on the Book Detail screen.

### 5.2 Download & text pipeline (`features/library`, `core/utils`) — build
Per guten-read Phase 3, plus a narration-specific step:
- Download `.txt.utf-8` via Dio with progress; fallback URL
  `https://www.gutenberg.org/ebooks/{id}.txt.utf-8`. Store under
  `books/{gutenberg_id}/`.
- **`TextCleanerService`**: strip `*** START/END OF ... PROJECT GUTENBERG
  EBOOK ***` (+ legacy `*END*THE SMALL PRINT!`, BOM, no-`***` variants); normalize
  hard-wrapped lines into paragraphs. Build a fixture corpus of real headers.
- **`NarrationSegmenter`** (new, shared with reader): split the cleaned text into
  ordered **narration units** — sentence/short-paragraph chunks sized for
  synthesis (roughly one to a few sentences). Each unit maps to a paragraph index
  so the reader and the player share the same position model. Persist the unit
  list once per book.

### 5.3 Reader (`features/reader`) — build
Per guten-read Phase 4: lazy `ListView.builder` render (never one giant `Text`),
paragraph-index scroll positions, themes (Light/Sepia/Dark/AMOLED), typography
controls, TOC extraction, auto-hiding controls. **Narration integration
(stretch):** when playback is active, highlight the currently spoken unit and
auto-scroll; tapping a paragraph seeks narration to that unit.

### 5.4 Voice Library (`features/voices`) — port from PoC
Proven in the PoC ([voice_library.dart](../poc/lib/voice_library.dart)):
- **Import `.wav`** via `file_picker`; copy into `<appSupport>/voices/` with a
  user-given name; persist a small **JSON index** (`id`, `name`, `file`).
- **Built-in voices** materialized from bundled assets on first load: **Reginald
  Ashworth (male)** and **Deja Thoris (female)**.
- Screen: list (built-ins first), **Add voice** (pick → name → store),
  select, delete (non-built-ins). No in-app recording (dropped in PoC §11 — quiet
  mic captures produced runaway white-noise clones).
- MP3 import deferred (needs a native decoder; `.wav` only for v1).

### 5.5 Narration / TTS service (`core/tts`) — port from PoC
Proven in the PoC ([tts_service.dart](../poc/lib/tts_service.dart),
[model_manager.dart](../poc/lib/model_manager.dart)):
- **Engine:** `sherpa_onnx` `OfflineTts`, **PocketTTS fp32**
  (`sherpa-onnx-pocket-tts-2026-01-26`), zero-shot cloning (no reference
  transcript), output **mono float32 @ 24 kHz**.
- **Persistent worker isolate** hosts `OfflineTts` (init once, then synth
  requests). **All heavy native work off the UI isolate** — on-UI extraction/
  synthesis triggered Android ANRs in the PoC.
- **Model manager:** download-on-first-run of the `.tar.bz2`, tried in order
  **our mirror → upstream k2-fsa** (survives either source vanishing); extract
  with the **low-disk** extractor (decode bz2 in RAM, delete archive before
  writing, then untar) — `archive`'s `extractFileToDisk` fails on Android.
- **Tolerant WAV I/O** (`_readWavAsFloat32`): handles `WAVE_FORMAT_EXTENSIBLE`,
  JUNK chunks, downmix + normalize, since `sherpa_onnx.readWave` is fragile.
- **Synthesis params (proven good):** `Steps = 28`, `Temp = 0.20`, `seed = 1234`,
  `numThreads = 4`. Expose Steps/Temp as advanced settings (Steps trades quality
  for speed; very high Steps runs into noise).

### 5.6 Chapter-ahead synthesis & audio cache (`features/narration/data`) — build
This is the key new subsystem that makes narration usable despite RTF ≈ 1.12×
(i.e. synthesis is *slower* than playback on a flagship, slower still mid-range).
**We do not stream in real time — we pre-render ahead of playback.**
- **`SynthCache`:** for `(bookId, voiceId, unitIndex)`, synthesize the unit's
  audio once and store it; index cache entries in `sqflite`. Reuse across
  sessions; a voice/book pair narrated once replays instantly and offline.
- **Look-ahead scheduler:** keep a buffer of N upcoming units synthesized ahead
  of the play head (start playing unit 0 as soon as it's ready; render 1..N in
  the worker isolate while unit 0 plays). Tune N so playback rarely stalls.
- **Audio storage format:** raw 24 kHz mono WAV is ~48 KB/s (~170 MB/hour) — too
  big to keep a whole book. Options (decide in Phase D): keep only a rolling
  window of upcoming/recent units as WAV and delete after play, **or** encode
  cached units to a compressed format (AAC/Opus). Start with the rolling-window
  approach; add optional "cache whole book for offline" later.
- **Invalidation:** cache keyed by voice + text-unit hash; changing voice or
  re-downloading the book invalidates affected entries.
- **Lazily initialized:** none of this (nor the model download) runs unless the
  user opts into narration — reading a book never triggers TTS work.

### 5.7 Player (`features/narration/presentation`) — build
- **`just_audio` + `audio_service`** for background playback, lock-screen /
  notification controls, seek, and resume. Feed it the cached per-unit audio
  (gapless concatenation or a playlist of unit clips).
- **Player UI:** play/pause, skip ±unit, speed, current book + voice, progress by
  unit index; a **mini-player** persistent above the nav bar; a **voice picker**
  bound to the voice library (re-narration re-renders the cache for that voice).
- **Resume:** persist `(bookId, unitIndex, offset, voiceId)`; restore on relaunch.

### 5.8 Settings (`features/settings`) — reuse + extend
**App theme:** global **dark (default) / light** toggle, exposed as a
`ThemeMode` provider that drives `MaterialApp.router`'s `theme`/`darkTheme`/
`themeMode`; persist the choice via `shared_preferences` and default to dark on
first launch. (Distinct from the reader's per-page reading themes in §5.3.)
Reader settings (reading theme, font, spacing) from guten-read, plus **narration
settings**: default voice, synthesis quality (Steps preset: Fast/Balanced/High),
playback speed, "pre-cache whole book on Wi-Fi," and cache/storage management
(model ~470 MB, per-book audio, voices).

---

## 6. Key design decisions (grounded in PoC data)

- **Pre-render, don't stream.** RTF **1.12×** on a Pixel 10 Pro (flagship) means
  compute is slower than playback; mid-range will be worse. Narration is built on
  **chapter-ahead synthesis + cache**, never live streaming.
- **fp32 over int8.** fp32 (`sherpa-onnx-pocket-tts-2026-01-26`, ~470 MB,
  `lm_main.onnx` = 302 MB) clones cleanly; int8 (~200 MB) introduced audible
  distortion at low temperature. Ship fp32; keep int8 as an optional
  "small/faster, lower quality" download later.
- **Model is downloaded, not bundled.** ~470 MB extracted is too large to bundle;
  download-on-first-run with **mirror→upstream fallback**. (For sideloaded APK
  distribution this keeps the APK small.)
- **Voice input is `.wav` upload only.** In-app recording is dropped — quiet mic
  captures (no AGC) produced runaway 80 s white-noise clones. Clean loud clips
  clone reliably.
- **Everything heavy runs in isolates.** Persistent TTS isolate + one-shot
  extraction isolate; low-disk tar extractor; tolerant WAV parser. These are
  hard-won PoC fixes — port them intact.
- **Shared position model.** Reader and narration both index by **narration
  unit / paragraph index**, so highlight-sync and resume are consistent.

---

## 7. Phased roadmap

```
Phase A  Scaffold: fork guten-read → guten-speak (rename, CI, deps)
Phase B  Reader half: download + text clean + segmenter + reader + library   (guten-read Ph.3–5)
Phase C  Narration core: port PoC (tts_service, model_manager, voice library)
Phase D  Synthesis cache + look-ahead scheduler
Phase E  Background player (just_audio + audio_service) + mini-player + voice picker
Phase F  Reader ↔ narration sync (highlight + tap-to-seek)   [stretch]
Phase G  Polish: settings, storage mgr, tests, accessibility, release APK
```

### Phase A — Scaffold
- [x] Copy `guten-read` into the `guten-speak` app module and re-init git history
      (independent from guten-read); update `pubspec.yaml` `name:` to
      `guten_speak` and fix all `package:guten_read/...` imports.
- [x] **Android rename** to `se.kruskakli.guten_speak`: `applicationId` **and**
      `namespace` in `app/build.gradle(.kts)`, `AndroidManifest` `android:label`,
      move `MainActivity.kt` to the `se/kruskakli/guten_speak/` folder + update its
      `package` line.
- [x] **iOS rename** to `se.kruskakli.gutenSpeak`: `PRODUCT_BUNDLE_IDENTIFIER`
      (Runner target) + `CFBundleDisplayName` = "Guten-Speak".
- [x] App label + launcher icon + display name (Android/iOS); update `README`.
      _(custom book + sound-wave launcher icon generated via
      `flutter_launcher_icons` — adaptive (Android) + all iOS sizes; source art
      under `app/assets/icon/`.)_
- [x] Merge dependencies: add `sherpa_onnx`, `file_picker`, `archive`, `http`,
      `just_audio`, `audio_service`; remove `permission_handler`. `flutter pub get`
      + `build_runner build` to confirm the scaffold still compiles.
- [x] Carry the PoC's **`compileSdk = 37` + `android-37` symlink** workaround
      (PoC §10) and set `minSdk`/`targetSdk` so `sherpa_onnx` + `audio_service`
      both load; verify an empty app boots on the Pixel 10 Pro.
      _(compileSdk 37 set; app boots on-device (Pixel 10 Pro, wireless debug) —
      `sherpa_onnx` + `audio_service` native libs load and the catalog renders.)_
- [x] **App theme:** `ThemeMode` provider (Riverpod) persisted via
      `shared_preferences`, wired into `MaterialApp.router`
      (`theme`/`darkTheme`/`themeMode`), **default dark** on first launch.
- [x] Keep guten-read's analysis options + GitHub Actions (`analyze` + `test`).
      _(CI moved to repo-root `.github/workflows/ci.yml` with `working-directory:
      app`.)_

### Phase B — Reader half (from guten-read Phases 3–5)
- [x] **Download manager** (Dio): progress, cancel, and resume/retry; primary
      `.txt.utf-8` + fallback `https://www.gutenberg.org/ebooks/{id}.txt.utf-8`;
      atomic write to `books/{id}/` (temp file → rename); free-space precheck.
      _(`BookDownloadDataSource` streams via a dedicated Dio with `Range: bytes=`
      resume; `LibraryRepositoryImpl` writes to `download.part`, cleans, then
      writes `text.txt.tmp` → rename. Fallback URL retried on non-cancel errors.
      Free-space check is a best-effort probe-write (`_ensureWritable`) — a real
      capacity check is deferred to Phase C's large model download.
      `BookDownloadController` (Riverpod family by bookId) drives progress/cancel.)_
- [x] **`TextCleanerService`** + fixture corpus of real Gutenberg headers: strip
      `*** START/END OF ...***`, legacy `*END*THE SMALL PRINT!`, BOM, and no-`***`
      variants; join hard-wrapped lines into paragraphs; unit-tested per fixture.
      _(`core/utils/text_cleaner_service.dart` + `text_cleaner_service_test.dart`
      covering modern/legacy markers, BOM, no-marker, blank-line collapse.)_
- [x] **`NarrationSegmenter`** — spell out the algorithm: split cleaned text into
      paragraphs (blank-line runs) → sentences (punctuation `. ! ?` with an
      abbreviation guard list: `Mr. Mrs. Dr. St. etc.` + initials); merge tiny
      fragments and hard-cap unit length (target ≈ 1–3 sentences / ~300 chars) so
      each unit synthesizes in one pass. Emit ordered units, each carrying its
      `paragraphIndex` (the shared reader/player position key); persist once.
      _(`core/utils/narration_segmenter.dart` — abbreviation + initial guard,
      closer absorption, ≤3 sentences/300 chars, per-paragraph indexing; tested.
      Persistence deferred to Phase D where the synth cache needs it.)_
- [x] **Reader screen**: lazy `ListView.builder` over paragraphs, paragraph-index
      scroll persistence, themes (Light/Sepia/Dark/AMOLED), typography controls,
      auto-hiding controls.
      _(`features/reader/…/reader_screen.dart` — `ScrollablePositionedList`
      (`scrollable_positioned_list`) for true index-precise resume/jump, with
      a top-bar-aware `alignment` so a jumped-to heading lands below the overlaid
      bar; debounced progress save to `reading_progress`, per-reader theme +
      font-scale via `readerSettingsProvider` (SharedPreferences), auto-hiding
      top/bottom bars.)_
- [x] **TOC extraction** from plain text (heuristic, best-effort): detect chapter
      headings via blank-line-delimited short lines matching
      `CHAPTER|BOOK|PART` + roman/arabic numerals; degrade gracefully to
      "no chapters" when nothing matches.
      _(`core/utils/toc_extractor.dart` — keyword + bare-numeral heuristics,
      surfaced as a TOC bottom sheet in the reader; tested.)_
- [x] **Library (`sqflite`)** — define the schema now: `books(id, title, author,
      path, downloaded_at)`, `reading_progress(book_id, paragraph_index,
      updated_at)`, plus the storage manager (list/delete downloaded books).
      _(`core/storage/app_database.dart` (v1, FK cascade) + `LibraryLocalDataSource`;
      Library screen lists/opens/deletes downloaded books. Schema adds
      `language`/`cover_url` to `books` for offline display.)_

### Phase C — Narration core (port PoC)
- [ ] Port `tts_service.dart`, `model_manager.dart`, WAV I/O into `core/tts/`
      behind the isolate protocol (`init`/`synth`/`dispose`).
- [ ] Port voice library into `features/voices/` (+ built-in Reginald & Deja).
- [ ] **First-run model download UX**: opt-in gate (only when the user first hits
      "Listen"), consent + storage-space check, progress, mirror→upstream
      fallback, cancel/retry, resumable.
- [ ] "Synthesize one unit in the selected voice" end-to-end smoke test.

### Phase D — Synthesis cache + scheduler
- [ ] `SynthCache` keyed by `(bookId, voiceId, unitHash)`, indexed in `sqflite`
      (`synth_cache(book_id, voice_id, unit_index, unit_hash, file, bytes,
      created_at)`); files under `audio/{bookId}/{voiceId}/`.
- [ ] **Look-ahead scheduler**: single serial synth queue on the worker isolate
      (one job at a time — RAM-bound); keep N units ahead of the play head;
      **cancel/replan the queue on seek or voice change** (drop now-stale jobs,
      re-prioritize around the new play head); backpressure when playback catches
      up (pause the player with a "buffering" state until the next unit lands).
- [ ] **Rolling-window storage**: keep only the window of recent/upcoming units on
      disk, evict played-and-past units (LRU by `unit_index` distance); decide
      WAV-vs-compressed here (start WAV, measure).
- [ ] Cache invalidation on voice change / book re-download (delete affected keys).

### Phase E — Player
- [ ] `audio_service` background handler + `just_audio`; feed cached per-unit
      clips as a `ConcatenatingAudioSource` (playlist) indexed by unit.
- [ ] **Not-ready handling**: when the next unit isn't synthesized yet, enter a
      `buffering` state (pause + spinner) and auto-resume when the scheduler
      delivers it — the player never plays past the synthesized frontier.
- [ ] **Gapless / clicks**: validate concatenation seams (trim leading/trailing
      silence, small crossfade or pre-concatenate the window) — see §9 risk.
- [ ] Audio focus + ducking (pause on call/other audio), lock-screen /
      notification actions (play/pause, skip ±unit), iOS background-audio
      capability (`UIBackgroundModes: audio`).
- [ ] Player screen + persistent mini-player above the nav bar; skip/seek/speed.
- [ ] Voice picker bound to the library; re-narrate re-renders the cache.
- [ ] Resume `(bookId, unitIndex, offset, voiceId)` persisted + restored.

### Phase F — Reader ↔ narration sync (stretch)
- [ ] Highlight current unit + auto-scroll during playback (drive off the shared
      `paragraphIndex`).
- [ ] Tap paragraph → seek narration to that unit (triggers scheduler replan).

### Phase G — Polish & release
- [ ] Narration settings (default voice, quality preset, speed, pre-cache) +
      surface the app dark/light theme toggle in Settings UI.
- [ ] Storage manager (model, per-book audio, voices) with delete/clear + sizes.
- [ ] Tests: text cleaner (fixtures), segmenter (abbrev/chunking), cache keying,
      scheduler replan-on-seek, notifiers; widget/golden for reader + player.
- [ ] Accessibility, predictive back, thermals/battery check on a mid-range phone.
- [ ] **Release build**: create/secure a signing keystore, wire release signing
      config, set `versionCode`/`versionName`, `flutter build apk --release`
      (consider `--split-per-abi`, arm64 primary); write release notes + About
      screen credits (PocketTTS/sherpa-onnx, non-commercial license).
- [ ] Publish the **sideloaded APK** on the GitHub releases page (current target).

---

## 8. Cross-cutting concerns

- **Model weight license (go/no-go on commercialization).** PocketTTS
  (`kyutai/pocket-tts`) weights are **NON-COMMERCIAL**. Guten-Speak stays **free
  and non-commercial**; surface attribution in an About/Licenses screen. A paid
  path would require a different, commercially-licensed cloning model.
- **Voice-cloning consent.** Ship clear copy: "only clone voices you own or have
  permission to use." Clones are local-only; avoid features that ease
  impersonation.
- **Storage headroom.** Model ~470 MB + per-book audio + voices. The PoC hit
  `INSTALL_FAILED_INSUFFICIENT_STORAGE` on a near-full device — check free space
  before download/synthesis and show clear guidance.
- **Battery / thermals.** Sustained synthesis is heavy; the pre-render-ahead +
  cache design bounds it, and cached playback is near-free. Prefer synthesizing
  on charge / Wi-Fi for whole-book pre-cache; throttle look-ahead on low battery.
- **Android toolchain.** API 37 needed `compileSdk = 37` with an `android-37`
  symlink workaround (PoC §10); carry that setup forward.
- **Offline-first.** Downloaded text + cached audio + local voices all work with
  no network; only catalog/search/model-download need connectivity.
- **Networking etiquette.** Descriptive User-Agent (already in guten-read),
  short-lived Gutendex cache, per-user on-demand downloads only.

---

## 9. Risks & open questions

- **Mid-range performance.** RTF measured only on a flagship Tensor G5 (1.12×).
  Confirm synthesis throughput + peak RAM (fp32 `lm_main.onnx` = 302 MB; expect
  ≥ ~0.5 GB in the worker isolate) on a real mid-range arm64 device. If too slow,
  offer the int8 model and/or fewer Steps as a "Fast" preset.
- **Cached-audio storage strategy.** WAV is ~170 MB/hour at 24 kHz — decide
  rolling-window vs. compressed (AAC/Opus) encoding, and where encoding runs.
- **Gapless playback.** Concatenating per-unit clips without clicks/gaps in
  `just_audio` (crossfade or pre-concatenation) needs validation.
- **Look-ahead tuning.** Choosing N (units rendered ahead) to avoid stalls
  without over-synthesizing on device.
- **Peak RAM ceiling** on low-end devices may force int8 or a smaller model.

---

## 10. Definition of done (v1)

- Search → download → **read** a Gutenberg book offline (guten-read parity) —
  fully usable as a plain reader with narration never enabled.
- **Optionally**, import/name a `.wav` voice (or pick a built-in) and **listen**
  to a book narrated in it, with **background playback** and resume; the model
  downloads only on first opt-in to narration.
- Chapter-ahead synthesis keeps playback smooth on the target device; cached
  narration replays instantly and offline.
- Zero `flutter analyze` errors; tests cover text cleaner, segmenter, and cache.
- Ships as a sideloadable APK from the GitHub releases page; About screen credits
  PocketTTS/sherpa-onnx and states the non-commercial license.
```
