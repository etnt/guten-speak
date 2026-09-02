#!/usr/bin/env bash
# Package the Pocket TTS Raven int8 model bundle into the tar.bz2 archive that
# the in-app RavenModelManager downloads and extracts.
#
# The archive must contain a single top-level directory named after the model
# (`raven-int8-2026-01/`) holding exactly the files the Android int8 path opens.
# The manager extracts it into `<appSupport>/models/`, producing
# `<appSupport>/models/raven-int8-2026-01/<file>` — the layout its sentinel
# checks (flow_lm_main_int8.onnx + tokenizer.model) expect.
#
# The reference voice is NOT bundled: it ships as a Flutter asset and is
# materialized to `<appSupport>/voices/` by VoiceLibrary at runtime.
#
# Usage:
#   tools/pack_raven_model.sh [OUTPUT_PATH]
#
# Default OUTPUT_PATH: <repo>/dist/raven-int8-2026-01.tar.bz2
#
# After building, upload the archive to the guten-speak release (the only
# download source the app trusts):
#   gh release upload tts-models <OUTPUT_PATH> --repo etnt/guten-speak
set -euo pipefail

MODEL_NAME="raven-int8-2026-01"
RELEASE_TAG="tts-models"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/pocket-tts-raven/models"
OUT="${1:-$REPO/dist/$MODEL_NAME.tar.bz2}"

# The exact files the Android int8 path opens (delta_attn / delta_convtr /
# non-delta decoder variants are skipped when custom attention + accelerated
# conv are unavailable, which is the case on Android arm64). Keep this list in
# sync with tools/push_raven_model.sh and RavenModelManager.
MODEL_FILES=(
  flow_lm_main_int8.onnx
  flow_lm_flow_int8.onnx
  mimi_decoder_delta_int8.onnx
  mimi_encoder.onnx
  text_conditioner.onnx
  bos_before_voice.npy
  tokenizer.model
)

echo "Source model dir: $SRC"
missing=0
for f in "${MODEL_FILES[@]}"; do
  if [[ ! -f "$SRC/$f" ]]; then
    echo "  MISSING: $f" >&2
    missing=1
  fi
done
if [[ "$missing" -ne 0 ]]; then
  echo "error: one or more model files are missing under $SRC" >&2
  exit 1
fi

# Stage the files under a top-level <MODEL_NAME>/ directory so the archive has
# the exact layout the extractor writes.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/$MODEL_NAME"
for f in "${MODEL_FILES[@]}"; do
  cp "$SRC/$f" "$STAGE/$MODEL_NAME/$f"
done

mkdir -p "$(dirname "$OUT")"
echo "Packing ${#MODEL_FILES[@]} files -> $OUT"
# -C stages the working dir so archive entries are "<MODEL_NAME>/<file>".
tar -C "$STAGE" -cjf "$OUT" "$MODEL_NAME"

echo "--- archive contents ---"
tar -tjf "$OUT"

size_bytes="$(wc -c < "$OUT" | tr -d ' ')"
size_h="$(du -h "$OUT" | cut -f1)"
if command -v shasum >/dev/null 2>&1; then
  sha="$(shasum -a 256 "$OUT" | cut -d' ' -f1)"
else
  sha="$(sha256sum "$OUT" | cut -d' ' -f1)"
fi

echo
echo "Built: $OUT"
echo "  size:   $size_h ($size_bytes bytes)"
echo "  sha256: $sha"
echo
echo "Upload to the guten-speak release (only trusted source):"
echo "  gh release upload $RELEASE_TAG \"$OUT\" --repo etnt/guten-speak"
