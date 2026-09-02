# Vendored Pocket TTS Raven source snapshot

This directory is a reviewed, pinned snapshot of the upstream Pocket TTS Raven
native runtime, vendored into the `pocket_tts_raven` Flutter FFI plugin per the
implementation plan (`plan/pocket-tts-raven-implementation-plan.md` §5.1) and the
Phase 0 freeze (`plan/pocket-tts-raven-phase-0-freeze.md` §2).

## Upstream

- Repository: https://github.com/pkalogiros/pocket-tts-raven
- Revision (pinned): `abd26158ab50f954616eaf42296b09c4856489d7` (2026-07-08)
- License: MIT (see `LICENSE`, `THIRD_PARTY_NOTICES.md`)
- Audio contract: mono float32 PCM @ 24000 Hz.

## Files copied verbatim from the pinned revision

| Vendored path | Upstream path |
|---|---|
| `include/pocket_tts.h` | `include/pocket_tts.h` |
| `src/pocket_tts.cpp` | `src/pocket_tts.cpp` |
| `src/pocket_tts_custom_attention.hpp` | `src/pocket_tts_custom_attention.hpp` |
| `src/ptt_custom_ops.cpp` | `src/ptt_custom_ops.cpp` (Apple-only; vendored for provenance, NOT compiled on Android) |
| `LICENSE` | `LICENSE` |
| `THIRD_PARTY_NOTICES.md` | `THIRD_PARTY_NOTICES.md` |

The upstream `CMakeLists.txt` is intentionally **not** vendored. The plugin's
`src/CMakeLists.txt` builds only the FFI shared library (`libpocket_tts_raven.so`)
for Android arm64 from `pocket_tts.cpp` with `PTT_SHARED_LIB` defined, mirroring
the upstream `BUILD_SHARED_LIB` target. SentencePiece (v0.2.1) and dr_libs
(`cd99e2cca5ccb48f8d000f1cd844424dcdbbaf59`) are fetched at configure time at the
same revisions the upstream build pins; ONNX Runtime 1.23.2 (Android AAR) is
supplied as a prebuilt `libonnxruntime.so` under `android/src/main/jniLibs/`.

## Local patches

The vendored sources are upstream except for reviewable patches recorded under
`patches/` and marked inline with `[guten-speak patch: ...]` comments:

- `patches/0001-stream-terminal-error.patch` — adds `ptt_stream_error()` and
  terminal-error capture on the stream context (`include/pocket_tts.h`,
  `src/pocket_tts.cpp`) so the app can distinguish a failed stream from a clean
  end, and adds a `catch (...)` so no exception can unwind out of the stream
  thread (plan §5.4). Regenerate the diff with
  `diff -u <pristine> <vendored>`.

Other Android-specific changes live in the plugin build system, not the vendored
C++:

1. `src/CMakeLists.txt` (plugin-authored, not upstream): builds only the shared
   library, resolves the ONNX Runtime Android headers/`.so` from a supplied path,
   and links `log` (SentencePiece's bundled protobuf-lite calls
   `__android_log_write`) — the upstream shared-lib target only links `log` for
   the CLI, not the FFI library.
