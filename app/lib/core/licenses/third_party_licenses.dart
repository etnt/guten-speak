import 'package:flutter/foundation.dart';

/// Registers license notices for components that are not part of the
/// Flutter/Dart package graph (native libraries, the downloaded speech model,
/// and the bundled narrator voices) so they appear on the in-app licenses page
/// (Settings → About → Licenses & notices) alongside the auto-collected package
/// licenses. Mirrors the repository's THIRD_PARTY_NOTICES.md.
void registerThirdPartyLicenses() {
  LicenseRegistry.addLicense(_thirdPartyLicenses);
}

Stream<LicenseEntry> _thirdPartyLicenses() async* {
  yield const LicenseEntryWithLineBreaks(
    <String>['Pocket TTS Raven (inference engine)'],
    'Pocket TTS Raven — on-device TTS inference engine (C++).\n'
    'MIT License.\n'
    'Source: https://github.com/etnt/pocket-tts-raven '
    '(fork of https://github.com/pkalogiros/pocket-tts-raven)',
  );
  yield const LicenseEntryWithLineBreaks(
    <String>['ONNX Runtime'],
    'ONNX Runtime (native, arm64).\n'
    'MIT License. Copyright (c) Microsoft Corporation.\n'
    'Source: https://github.com/microsoft/onnxruntime',
  );
  yield const LicenseEntryWithLineBreaks(
    <String>['SentencePiece'],
    'SentencePiece.\n'
    'Apache License 2.0. Copyright Google LLC.\n'
    'Source: https://github.com/google/sentencepiece',
  );
  yield const LicenseEntryWithLineBreaks(
    <String>['dr_libs'],
    'dr_libs (dr_wav).\n'
    'Public domain (Unlicense) or MIT-0, at your option.\n'
    'Source: https://github.com/mackron/dr_libs',
  );
  yield const LicenseEntryWithLineBreaks(
    <String>['Pocket TTS model weights (Kyutai)'],
    'Pocket TTS model — Copyright Kyutai.\n'
    'Licensed under CC-BY-4.0 '
    '(https://creativecommons.org/licenses/by/4.0/).\n'
    'Source: https://huggingface.co/kyutai/pocket-tts\n'
    '\n'
    'Guten-Speak downloads a bundle derived from these weights via the Pocket '
    'TTS Raven preparation pipeline. Attribution to Kyutai is required.\n'
    '\n'
    'Acceptable use: the model carries additional prohibited-use terms. Do not '
    'use it, or speech synthesized with it, for non-consensual voice cloning, '
    'impersonation, deception, fraud, harassment, or privacy-invasive '
    'purposes. You are responsible for complying with the model card and '
    'applicable law.',
  );
  yield const LicenseEntryWithLineBreaks(
    <String>['Bundled narrator voices'],
    'reginald-ashworth.wav and deja-thoris.wav are synthetic voice samples '
    'created through experimentation with several voice-generation tools. They '
    'are not recordings of any real, identifiable person. Provided as demo '
    'narrator voices for use within Guten-Speak.',
  );
}
