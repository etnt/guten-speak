# Pocket TTS Raven — Phase 0 freeze record

**Status:** Complete (PoC-scope decisions locked; distribution beyond the PoC still
requires legal sign-off per the Phase 0 stop gate)
**Date:** 2026-08-31
**Plan:** [pocket-tts-raven-implementation-plan.md](pocket-tts-raven-implementation-plan.md)
**Baseline investigation:** [pocket-tts-raven-investigation.md](pocket-tts-raven-investigation.md)

This document is the Phase 0 deliverable: locked revisions and dependency hashes, the
model-distribution decision, the benchmark application IDs and branch/worktree
instructions, and the model/bundled-voice attribution requirements.

## 1. Locked revisions

### 1.1 Source revisions

| Artifact | Value | Verified |
|---|---|---|
| Guten-Speak baseline commit | `c40c6cdbab1b915970d0448c01c10f4d4d6a9525` (2026-08-29, `docs(tts): assess Pocket TTS Raven for Android narration`) | `git log -1` in `/Users/ttornkvi/git/guten-speak` |
| Pocket TTS Raven upstream revision | `abd26158ab50f954616eaf42296b09c4856489d7` (2026-07-08, "(tweaks) better ux") | `git log -1` in `/Users/ttornkvi/git/pocket-tts-raven`; checkout is clean and exactly at the pinned revision |
| Flutter toolchain | 3.44.0 stable (Dart 3.12.0, DevTools 2.57.0) | `flutter --version`; `pubspec.lock` requires Flutter ≥ 3.44.0 |
| FFI plugin template | To be generated with the current Flutter 3.44.0 `plugin_ffi` template at Phase 2 start | per plan §4.2 |

### 1.2 Dependency hashes and pins

| Dependency | Pin | Hash |
|---|---|---|
| sherpa_onnx (baseline engine, pub.lock-locked) | `1.13.6` | `5d6cd57eca94caf4b3ce3b07d9affb11ad68d14c37e1e7aa3f60e63b59aee361` |
| ONNX Runtime Android AAR (Raven PoC) | `com.microsoft.onnxruntime:onnxruntime-android:1.23.2`, Maven Central, published 2025-10-25 | SHA-256 `82048d1f462218adae4ba76477089ab0ba76093d84f733540066db1a8ba6b827` (computed from the downloaded AAR, 30,241,654 bytes; matches Maven-published SHA-1 `6c74a76bb284681c2d73288095c7320f1f7079b2`) |
| ONNX Runtime native releases (Raven CMake reference pins) | v1.23.2 desktop artifacts | hash-pinned in Raven's `CMakeLists.txt` (linux-x64 `1fa4dcae…`, linux-aarch64 `7c63c735…`, osx-universal2 `49ae8e3a…`, win-x64 `0b38df9a…`) |
| SentencePiece | `v0.2.1` (GIT_TAG, shallow) | built from source with Raven's GCC-14/cmake-minimum patch |
| dr_libs | GIT_TAG `cd99e2cca5ccb48f8d000f1cd844424dcdbbaf59` | header-only (dr_wav/dr_mp3/dr_flac) |

### 1.3 Model source bundle pins (`english_2026-04` int8 ONNX)

Default mirror URL in Raven's `tools/prepare_models.sh`:
`https://huggingface.co/KevinAHM/pocket-tts-onnx/resolve/main/onnx/english_2026-04`
(a mirror of the official Kyutai pocket-tts ONNX bundle; every file hash-pinned below, so
the mirror does not need to be trusted).

| File | SHA-256 |
|---|---|
| `tokenizer.model` | `d461765ae179566678c93091c5fa6f2984c31bbe990bf1aa62d92c64d91bc3f6` |
| `text_conditioner.onnx` | `4ecee995fb69f85c7a7493d11f7b5ee15d9950facc7ab3f5c9c49ef1e03847bb` |
| `mimi_encoder.onnx` | `853e2ca623b8782d94c3745ec6133bfdff7ce33d9b11128bd29ea03f28d76e3d` |
| `flow_lm_main_int8.onnx` | `f9bd8106b79a0192c1c43399ab938fb24900a95c1c599870d75a884e99000116` |
| `flow_lm_flow_int8.onnx` | `3dd781ee5abee9e195320bf0106bebd6372a852b3b36352524ee78b40554635d` |
| `mimi_decoder_int8.onnx` | `3630450a3297a101792a6ac66619ebc70ab916b265e6220c2afaef8b1673f925` |
| `bos_before_voice.npy` | `f46edf4f7007b7ba4ea58831f49d003e59e167b4641c44bb3addfe9231a780b1` |

Transformed artifacts produced by Raven's deterministic rewrites (delta-KV, AttentionTail,
dedup, merged flow, portable decoder) are not hash-locked here because they are generated;
the Phase 0 model-bundle tool (`tools/build_raven_android_model_bundle.sh`, plan §6.1) will
hash the exact outputs it archives and record them in the signed manifest.

### 1.4 Android toolchain

| Component | Status |
|---|---|
| NDK | r28.2.13676358 installed at `~/Library/Android/sdk/ndk/` — satisfies the plan's "r28 or newer" requirement and will be pinned explicitly in Gradle |
| compileSdk | 37 (already pinned in `app/android/app/build.gradle.kts` for the Pixel 10 Pro / Android 17) |
| ABI | arm64-v8a only (already pinned via `ndk { abiFilters }`) |
| CMake | Raven's `CMakeLists.txt` requires CMake ≥ 3.28. The Android SDK side-installed CMake is 3.22.1; Homebrew CMake 4.1.2 is available. **Phase 2 risk:** Gradle must be pointed at a CMake ≥ 3.28 (SDK `cmake;3.31.x`+ or the Homebrew install) or the Raven CMake minimum must be lowered in the vendored patch set. |
| 16 KB page size | NDK r28 defaults to 16 KB-aligned `.so` linking; the smoke test on a 16 KB environment remains a Phase 2 gate. |

## 2. Vendoring decision

**Decision: vendor a reviewed Raven source snapshot inside the local Flutter FFI plugin**
(`app/packages/pocket_tts_raven/`), as recommended by plan §5.1.

Rationale:

- The reviewed revision `abd26158` has no Android build target and no upstream
  release process; building directly from a sibling checkout would make the PoC
  dependent on undeclared local state.
- The snapshot is small (`include/`, `src/`, `tools/`, `CMakeLists.txt`, `LICENSE`,
  `THIRD_PARTY_NOTICES.md`) and reviewable; the plan requires recording the upstream
  revision, full commit SHA, the copied file list, and the Android patch set in a
  patch-series directory.
- SentencePiece and dr_libs stay pinned via the recorded GIT_TAGs above rather than
  being snapshot-copied, matching Raven's own FetchContent behavior. If vendor-at-build
  fetches are unacceptable for CI, the patch-series work in Phase 2 can copy them under
  the same recorded revisions.

The Phase 0 snapshot copy itself happens at Phase 2 start (creating the plugin); what is
locked now is the mechanism and the revision.


## 3. ONNX Runtime / NDK confirmation

**Confirmed available:**

- ORT Android `1.23.2` AAR is published on Maven Central (2025-10-25) and its SHA-256 is
  recorded above after download verification. Gradle will resolve it as a normal
  dependency; the plan's requirement that the final APK contain exactly one
  `libonnxruntime.so` and the `tools/inspect_tts_apk.sh` checks remain Phase 2/3 gates.
- NDK r28.2.13676358 is installed; r28+ availability confirmed.
- The sherpa baseline continues to ship its own bundled ORT 1.27.1 in the sherpa
  worktree only; no attempt is made to share runtimes in the PoC (plan §10).

## 4. Model download / distribution decision (written)

**Decision (PoC scope): the model bundle is downloaded at build/preparation time on the
developer machine from the hash-pinned mirror route above, never redistributed by this
project during the PoC, and never downloaded or generated on the phone.**

Concretely:

1. `tools/build_raven_android_model_bundle.sh` (Phase 2) downloads the pinned
   `english_2026-04` files, applies Raven's deterministic rewrites locally, verifies
   Raven's equivalence checks, and produces the deterministic archive + signed manifest
   locally.
2. The resulting bundle is sideloaded to benchmark devices via `adb push` / the app's
   local model installer. No transformed weights leave the controlled machine.
3. **No-publication stop gate (unchanged from the plan):** no transformed weights, no
   public Raven build, and no distribution of the model bundle through app stores or any
   public channel occurs until (a) the exact weight source and terms for the April 2026
   ONNX export are confirmed against the gated Kyutai model card, and (b) project/legal
   review approves the route. The mirror (`KevinAHM/pocket-tts-onnx` /
   `Verylicious/pocket-tts-ungated`) is used only because every file is hash-pinned to
   the official bundle; this is acceptable for lawful local PoC use, not as a
   distribution route.
4. If a production go-decision is reached in Phase 5, the distribution route must be
   re-decided (approved/gated download vs. permitted redistribution) before Phase 6
   user-facing work.

This decision satisfies the Phase 0 stop gate: local technical work continues with
lawfully obtained artifacts; nothing is published.

## 5. Benchmark application IDs and worktree branches

The benchmark builds follow plan §10.2: two pinned Git worktrees from the same
benchmark-harness commit, each producing an APK with a distinct application ID so their
model, voice, cache, and result sandboxes cannot contaminate one another or the
developer's normal app data. Gradle flavors alone are insufficient because both TTS
plugins contribute native libraries before a product flavor is selected (plan §10.1).

### 5.1 Application IDs

Base application ID (unchanged normal app): `se.kruskakli.guten_speak`
(from `app/android/app/build.gradle.kts`).

| Benchmark build | Application ID | Engine |
|---|---|---|
| Sherpa baseline | `se.kruskakli.guten_speak.benchsherpa` | sherpa_onnx 1.13.6, ORT 1.27.1 |
| Raven candidate | `se.kruskakli.guten_speak.benchraven` | pocket_tts_raven plugin, ORT 1.23.2 |

The suffix is applied to the release/benchmark build via `applicationIdSuffix`
(`.benchsherpa` / `.benchraven`) so the normal `se.kruskakli.guten_speak` install is
never touched. `namespace` stays `se.kruskakli.guten_speak`.

### 5.2 Worktree branches

Both worktrees branch from the same benchmark-harness commit; the engine adapter/provider
wiring is the only intended branch delta. The engine-independent benchmark corpus, metrics
schema, profile logic, and report generator must be byte-identical between the two.

| Worktree | Branch | Location | Dependency graph |
|---|---|---|---|
| Sherpa baseline | `bench/sherpa-baseline` | `../guten-speak-benchsherpa` | keeps `sherpa_onnx`; does not depend on the Raven plugin |
| Raven candidate | `bench/raven-candidate` | `../guten-speak-benchraven` | removes `sherpa_onnx` and its ABI helper packages; depends on `app/packages/pocket_tts_raven` + ORT 1.23.2 |

Create the worktrees from the shared harness commit (created in Phase 1) with:

```bash
# from /Users/ttornkvi/git/guten-speak, after the Phase 1 harness commit exists
git worktree add -b bench/sherpa-baseline ../guten-speak-benchsherpa <harness-commit>
git worktree add -b bench/raven-candidate ../guten-speak-benchraven  <harness-commit>
```

`tools/inspect_tts_apk.sh` (plan §10.2) asserts the expected application ID and engine
marker, exactly one arm64 `libonnxruntime.so`, and mutual absence of the other engine's
native libraries in each APK. A benchmark report is invalid if inspection fails. If
side-by-side install proves awkward, install sequentially and clear only the benchmark
app sandbox — never the normal `se.kruskakli.guten_speak` data.

## 6. Model and bundled-voice attribution requirements

This section records the attribution *requirements* verified in Phase 0. It does not
grant a distribution right; the Phase 0 stop gate (§4) still governs any public build.

### 6.1 Component attribution

| Component | License | Attribution requirement |
|---|---|---|
| Pocket TTS model weights (Kyutai `pocket-tts`) | CC-BY-4.0 + gated prohibited-use terms | Credit Kyutai under CC-BY-4.0 metadata; carry the gated prohibited-use terms (no non-consensual cloning, impersonation, deception, harassment, privacy-invasive use). |
| Pocket TTS Raven (`abd26158`) | MIT | Include the MIT license and copyright notice. |
| ONNX Runtime 1.23.2 | MIT | Include the MIT license. |
| SentencePiece v0.2.1 | Apache-2.0 | Include the Apache-2.0 license and NOTICE. |
| dr_libs (`cd99e2c…`) | public-domain / MIT-0 dual | Include the chosen notice. |

These belong in a root `THIRD_PARTY_NOTICES.md` and be surfaced in-app before any
distributed Raven build (plan §16). Adding that file and the in-app notices is Phase 6
production work; Phase 0 only fixes the required set above.

### 6.2 Bundled benchmark voices

The built-in reference clips shipped in the repo and used as consented/bundled benchmark
voices are:

| Voice ID | Asset | Role |
|---|---|---|
| Reginald Ashworth | `app/assets/voices/reginald-ashworth.wav` | male built-in default reference |
| Deja Thoris | `app/assets/voices/deja-thoris.wav` | female built-in reference |

Requirement verified: both are self-created by the project author, who is the owner and
speaker of the clips; there is no third-party voice to obtain consent from. They replaced
the sherpa tarball's `bria.wav` sample (per `plan/poc.md`) and are the only voices bundled
for the benchmark corpus; no third-party voice is redistributed by the PoC. The blinded
listening panel adds no new bundled voices without a recorded consent/ownership basis.

Provenance of record: `reginald-ashworth.wav` and `deja-thoris.wav` are author-created and
author-owned. No further consent is required for their bundled use.

### 6.3 Known documentation defect (correction deferred)

`README.md` currently states "PocketTTS model weights are NON-COMMERCIAL." Per the
investigation this is inaccurate — the weights are CC-BY-4.0 with prohibited-use terms.
The correction is intentionally deferred to the licensing-correction pass / Phase 6 and is
recorded here so Phase 0 does not silently rely on the outdated claim.

