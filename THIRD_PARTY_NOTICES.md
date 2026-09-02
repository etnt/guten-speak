# Third-party notices

Guten-Speak's own source code is licensed under the Mozilla Public License 2.0
(see [LICENSE](LICENSE)). This file lists the third-party software, model
weights, and assets that Guten-Speak ships in its APK or downloads at runtime.
Each component remains under its own license, linked below.

The Flutter/Dart package dependencies are not repeated here; their full license
texts are aggregated at runtime and viewable in the app under
**Settings → About → Licenses & notices**.

## Native runtime libraries (bundled in the APK)

These ship inside the `pocket_tts_raven` Flutter FFI plugin. See also the
plugin's own notices:
[app/packages/pocket_tts_raven/third_party/raven/THIRD_PARTY_NOTICES.md](app/packages/pocket_tts_raven/third_party/raven/THIRD_PARTY_NOTICES.md).

- **Pocket TTS Raven** — the on-device inference engine (C++). MIT License.
  Source: <https://github.com/etnt/pocket-tts-raven> (fork of
  <https://github.com/pkalogiros/pocket-tts-raven>, mirrored for durability)
- **ONNX Runtime** (native, arm64) — MIT License. © Microsoft Corporation.
  Source: <https://github.com/microsoft/onnxruntime>
- **SentencePiece** — Apache License 2.0. © Google LLC.
  Source: <https://github.com/google/sentencepiece>
- **dr_libs** (dr_wav) — public domain (Unlicense) or MIT-0, at your option.
  Source: <https://github.com/mackron/dr_libs>

## Speech model weights (downloaded at runtime)

Guten-Speak does not bundle the speech model in the app or in this repository.
On first opt-in it downloads a prepared model bundle from Guten-Speak's own
GitHub release area (<https://github.com/etnt/guten-speak/releases>) so
availability does not depend on any third-party host.

- **Pocket TTS model** — © Kyutai. Licensed
  **[CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/)**.
  Source: <https://huggingface.co/kyutai/pocket-tts>

  The bundle Guten-Speak distributes is derived from these weights via the
  Pocket TTS Raven preparation pipeline. Attribution to Kyutai is required and
  is given here and in the app.

  **Acceptable use.** The model carries additional prohibited-use terms. Do not
  use it — or speech synthesized with it — for non-consensual voice cloning,
  impersonation, deception, fraud, harassment, or privacy-invasive purposes.
  You are responsible for complying with the model card and applicable law.

## Bundled narrator voices

- `app/assets/voices/reginald-ashworth.wav`
- `app/assets/voices/deja-thoris.wav`

These are **synthetic** voice samples created by the project maintainer through
experimentation with several voice-generation tools. They are not recordings of
any real, identifiable person, and their exact provenance is not individually
tracked. They are provided solely as ready-made demo narrator voices for use
within Guten-Speak.

## Application source

- **Guten-Speak** — Mozilla Public License 2.0. See [LICENSE](LICENSE).
