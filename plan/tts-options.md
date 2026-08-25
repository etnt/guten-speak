# Guten-Speak — TTS Options for Flutter

Comparison of ways to do text-to-speech (and voice cloning) in a Flutter Android
app, before committing to the `pocket-tts-raven` PoC.

**The decisive requirement:** on-device **zero-shot voice cloning** (clone a
narrator from a short clip), **free**, and **private** (nothing uploaded). That
combination is rare and rules out most options.

---

## Quick comparison

| Option | On-device | Zero-shot cloning | Mobile-feasible | Flutter integration | Cost / license | Fit |
|---|---|---|---|---|---|---|
| **pocket-tts-raven** (Kyutai Pocket TTS, ONNX/FFI) | ✅ | ✅ | ✅ (proven in mobile WASM demo) | Custom FFI + NDK build | Free; MIT runtime, check weight license | **Best fit** |
| **sherpa-onnx** (`sherpa_onnx` pub pkg) | ✅ | ⚠️ model-dependent | ✅ | **Prebuilt libs on pub.dev** (low effort) | Free, Apache-2.0 | **Strong — evaluate first** |
| **flutter_tts** (OS TTS) | ✅ | ❌ | ✅ | Trivial | Free | Fallback only |
| **Piper** (VITS/ONNX) | ✅ | ❌ (train per voice offline) | ✅ | Via sherpa-onnx or FFI | Free, MIT | Good quality, no cloning |
| **Kokoro** (82M ONNX) | ✅ | ❌ (fixed voice packs) | ✅ | Via sherpa-onnx/FFI | Free, Apache-2.0 | No cloning |
| **XTTS-v2 / F5-TTS / Fish / Zonos / Chatterbox** | ⚠️ | ✅ | ❌ (too large/slow for phones) | Heavy custom | Mixed licenses | Not mobile-viable |
| **Cloud cloning** (ElevenLabs, PlayHT, Cartesia, Azure Custom Voice, OpenAI) | ❌ | ✅ (excellent) | ✅ (thin client) | Trivial REST | Paid + uploads voice | Conflicts with free/private goal |

---

## Notes per option

### 1. pocket-tts-raven (current plan)
- Only widely-available engine that is **cloning-capable AND small/fast enough**
  for a phone — you already saw it clone your voice in the mobile WASM demo.
- Cost: custom **NDK build + FFI** wiring (the PoC's main risk).

### 2. sherpa-onnx — worth evaluating *before* the pocket-tts PoC
- Mature **k2-fsa** project with an official **`sherpa_onnx` package on pub.dev**
  that ships **prebuilt native libraries** for Android/iOS/desktop. This could
  **eliminate most of the NDK/CMake pain** that makes the pocket-tts PoC risky.
- Runs many on-device TTS models (VITS, Piper, Matcha, Kokoro) and includes
  speaker-embedding / voice-conversion building blocks.
- **Caveat:** true *zero-shot from a 10 s clip* depends on the specific model it
  supports at the time — not guaranteed to match pocket-tts quality. Verify what
  cloning-capable models are runnable under it before relying on it.
- **Spike outcome (2026-08-25): PASSED on macOS.** `sherpa_onnx` runs **Pocket
  TTS** with zero-shot cloning; the **fp32** model clones faithfully
  (Steps=28, Temp=0.20). This is the same model raven uses — see the
  runtime-comparison section below and [poc.md](poc.md) §9.
- **Recommendation:** do a 1-day spike here first. If a cloning model runs well
  via `sherpa_onnx`, it's a far lower-effort integration path.

### 3. flutter_tts (platform TTS)
- Wraps Android `TextToSpeech` / iOS `AVSpeechSynthesizer`. Zero setup, tiny,
  offline, reliable. **No cloning**, generic voices.
- **Role:** guaranteed v1 fallback / accessibility path while neural cloning is
  integrated. Not the product's differentiator.

### 4. Piper / Kokoro (high-quality non-cloning)
- Excellent, fast, small on-device voices — but **fixed voices**, no zero-shot
  cloning. Piper voices require offline training/fine-tuning per speaker.
- Good if the "favorite voice" feature were dropped; not what guten-speak wants.

### 5. Large zero-shot models (XTTS-v2, F5-TTS, Fish Speech, Zonos, Chatterbox)
- Great cloning quality, but **hundreds of MB to multiple GB** and heavy compute
  — not realistic for real-time narration on a mid-range Android phone. Skip.

### 6. Cloud cloning APIs
- Best quality and trivial from Dart (`http` POST), but:
  - **Ongoing cost** per character/second — kills "free" pitch.
  - **Uploads the user's voice** — kills "private, only you use it" pitch.
  - Most gate voice cloning behind **consent/identity verification**.
- Reasonable only if we ever abandon the on-device/private premise. Not now.

---

## sherpa-onnx vs pocket-tts-raven — same model, different runtime

Both run **the same underlying model** — Kyutai **Pocket TTS**, exported to ONNX,
zero-shot cloning from 6–15 s of audio, mono float32 @ 24 kHz, with the speaker
embedding cached after first use. They differ in **everything around** the model:

| | **sherpa-onnx** (our Step-0 spike) | **pocket-tts-raven** (the README demo) |
|---|---|---|
| Runtime | k2-fsa's `OfflineTtsPocket` C++ impl | Custom single-file C++ driver (`src/pocket_tts.cpp`) |
| Engine | ONNX Runtime (via sherpa) | ONNX Runtime (stock) **+ offline graph rewrites** — delta-KV cache, cross-layer dedup, merged flow, custom-op injection |
| ONNX export | sherpa's `sherpa-onnx-pocket-tts-2026-01-26` bundle | Kyutai's original bundle, **re-optimized locally** by `tools/prepare_models.sh` |
| Bindings | sherpa's **Dart FFI**, **prebuilt Android/macOS `.so`** | Own **C FFI** (`ptt_create`, `ptt_stream_*`) + WASM; **no prebuilt Android lib** (NDK cross-compile needed) |
| Precision | int8 / fp32 (we use **fp32**) | int8 / fp32 (`--precision`) |
| Step / temp knobs | `numSteps` (we use **28**), `temperature` (**0.20**) | `--lsd-steps` (default **1**), `--temperature` (default **0.7**) |
| Speed | fp32 slower; RTF TBD on-device | **~33× realtime native** (M4 Max), ~14× browser, ~3–4× iPhone WASM |
| License | runtime Apache-2.0; **model non-commercial** | runtime **MIT**; same non-commercial model terms |

**Key takeaways:**
- We chose **sherpa-onnx for the spike specifically because it ships prebuilt
  Android native libraries** — it lets us skip the NDK/CMake cross-compile that
  is the make-or-break step for raven.
- Raven's big advantage is **speed**: its graph rewrites ("merged flow") appear
  to reach good quality at **~1 flow step** vs the **~28** we needed under
  sherpa. If on-device **RTF becomes a problem on Android**, raven's optimized
  export is the strongest lever — but it costs the NDK build we're avoiding.
- The **model license is identical** (non-commercial) either way, so the runtime
  choice does not change the commercial-viability flag (see
  [viability.md](viability.md)).

---

## Recommendation

1. **Add a cheaper spike before the pocket-tts PoC:** evaluate **`sherpa-onnx`**
   (prebuilt Flutter libs) to see if a cloning-capable model runs well on-device.
   If yes → lowest-effort path to the same feature.
2. **If sherpa-onnx can't clone well enough → proceed with the pocket-tts-raven
   PoC** as planned (it's the proven cloning engine; cost is the NDK build).
3. **Ship `flutter_tts` as the built-in fallback voice** regardless, so v1 works
   on every device even if neural synthesis is disabled or too slow.
4. **Keep cloud cloning off the table** while "free + private + on-device" is a
   core promise.

**Net:** pocket-tts-raven is still the strongest fit for the actual goal, but
**sherpa-onnx deserves a quick look first** because its prebuilt Flutter
integration could save the most expensive part of the PoC.

**Update (2026-08-25):** the sherpa-onnx spike **passed** — same Pocket TTS
model, no NDK build needed. It is now the default runtime for Step 0. Keep
**pocket-tts-raven in reserve** as the speed lever if on-device RTF is
insufficient on mid-range Android.
