#!/usr/bin/env bash
# Provision the sherpa Pocket TTS model into app-private storage on the device.
# The device's own DNS is unreliable, so we push the model that is already on
# this Mac (from the PoC app) instead of letting the app download it.
set -euo pipefail

DEVICE="${1:-56041FDCH00CDN}"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
PKG="se.kruskakli.guten_speak"
NAME="sherpa-onnx-pocket-tts-2026-01-26"
SRC="/Users/ttornkvi/Library/Containers/com.gutenspeak.gutenSpeakPoc/Data/Library/Application Support/com.gutenspeak.gutenSpeakPoc/models/$NAME"
DST="files/models/$NAME"

"$ADB" -s "$DEVICE" shell run-as "$PKG" mkdir -p "$DST"
for f in encoder.onnx decoder.onnx lm_flow.onnx lm_main.onnx text_conditioner.onnx vocab.json token_scores.json; do
  echo "pushing $f ..."
  "$ADB" -s "$DEVICE" push "$SRC/$f" "/data/local/tmp/$f" >/dev/null
  "$ADB" -s "$DEVICE" shell "cat /data/local/tmp/$f | run-as $PKG sh -c 'cat > $DST/$f'"
  "$ADB" -s "$DEVICE" shell rm "/data/local/tmp/$f"
done
echo "--- installed model files ---"
"$ADB" -s "$DEVICE" shell run-as "$PKG" ls -l "$DST"
