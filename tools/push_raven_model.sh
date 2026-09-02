#!/usr/bin/env bash
# Provision the Pocket TTS Raven int8 model bundle + a reference voice into
# app-private storage on the device, mirroring push_tts_model.sh.
#
# The device DNS is unreliable and there is no in-app Raven downloader yet, so
# we push the int8/4-step model subset that already lives in this repo's
# pocket-tts-raven clone. Only the graphs the Android (non-custom-attention,
# non-accelerated-conv) int8 path actually loads are pushed (~163 MB).
#
# Re-run before EVERY on-device integration run: `flutter test` uninstalls the
# app at the end, wiping app-private storage.
set -euo pipefail

DEVICE="${1:-56041FDCH00CDN}"
ADB="$HOME/Library/Android/sdk/platform-tools/adb"
PKG="se.kruskakli.guten_speak"
REPO="/Users/ttornkvi/git/guten-speak"
SRC="$REPO/pocket-tts-raven/models"
VOICE_SRC="$REPO/app/assets/voices/reginald-ashworth.wav"
MODEL_DIR="files/models/raven-int8-2026-01"
VOICE_DIR="files/voices"

# The exact files the Android int8 path opens (delta_attn / delta_convtr /
# non-delta decoder variants are skipped when custom attention + accelerated
# conv are unavailable, which is the case on Android arm64).
MODEL_FILES=(
  flow_lm_main_int8.onnx
  flow_lm_flow_int8.onnx
  mimi_decoder_delta_int8.onnx
  mimi_encoder.onnx
  text_conditioner.onnx
  bos_before_voice.npy
  tokenizer.model
)

"$ADB" -s "$DEVICE" shell run-as "$PKG" mkdir -p "$MODEL_DIR"
"$ADB" -s "$DEVICE" shell run-as "$PKG" mkdir -p "$VOICE_DIR"

for f in "${MODEL_FILES[@]}"; do
  echo "pushing model $f ..."
  "$ADB" -s "$DEVICE" push "$SRC/$f" "/data/local/tmp/$f" >/dev/null
  "$ADB" -s "$DEVICE" shell "cat /data/local/tmp/$f | run-as $PKG sh -c 'cat > $MODEL_DIR/$f'"
  "$ADB" -s "$DEVICE" shell rm "/data/local/tmp/$f"
done

echo "pushing voice reginald-ashworth.wav ..."
"$ADB" -s "$DEVICE" push "$VOICE_SRC" "/data/local/tmp/reginald-ashworth.wav" >/dev/null
"$ADB" -s "$DEVICE" shell "cat /data/local/tmp/reginald-ashworth.wav | run-as $PKG sh -c 'cat > $VOICE_DIR/reginald-ashworth.wav'"
"$ADB" -s "$DEVICE" shell rm "/data/local/tmp/reginald-ashworth.wav"

echo "--- installed model files ---"
"$ADB" -s "$DEVICE" shell run-as "$PKG" ls -l "$MODEL_DIR"
echo "--- installed voices ---"
"$ADB" -s "$DEVICE" shell run-as "$PKG" ls -l "$VOICE_DIR"
