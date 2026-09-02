#!/usr/bin/env bash
# Cross-compile the pocket-tts-raven native CLI for Android arm64.
#
# Downloads the onnxruntime-android AAR (ORT is distributed for Android via
# Maven Central, not the GitHub releases page), extracts the arm64-v8a .so +
# headers, then configures/builds pocket-tts with the NDK toolchain.
#
# Usage: bash tools/build_raven_android.sh
set -euo pipefail

RAVEN_DIR="$(cd "$(dirname "$0")/../pocket-tts-raven" && pwd)"
ORT_VERSION="1.23.2"
ANDROID_ABI="arm64-v8a"
ANDROID_PLATFORM="android-24"

# --- Locate the NDK ---------------------------------------------------------
SDK="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
NDK_DIR="$(ls -d "$SDK"/ndk/* 2>/dev/null | sort -V | tail -n1)"
if [[ -z "${NDK_DIR:-}" || ! -d "$NDK_DIR" ]]; then
  echo "ERROR: Android NDK not found under $SDK/ndk" >&2
  exit 1
fi
TOOLCHAIN="$NDK_DIR/build/cmake/android.toolchain.cmake"
echo "Using NDK: $NDK_DIR"

# --- Fetch + extract ONNX Runtime Android AAR -------------------------------
ORT_HOME="$RAVEN_DIR/.ort-android/$ORT_VERSION"
if [[ ! -f "$ORT_HOME/jni/$ANDROID_ABI/libonnxruntime.so" ]]; then
  echo "Downloading onnxruntime-android $ORT_VERSION AAR..."
  mkdir -p "$ORT_HOME"
  AAR_URL="https://repo1.maven.org/maven2/com/microsoft/onnxruntime/onnxruntime-android/$ORT_VERSION/onnxruntime-android-$ORT_VERSION.aar"
  curl -fSL "$AAR_URL" -o "$ORT_HOME/ort.aar"
  ( cd "$ORT_HOME" && unzip -oq ort.aar )
fi
if [[ ! -d "$ORT_HOME/headers" ]]; then
  echo "ERROR: extracted AAR has no headers/ dir at $ORT_HOME" >&2
  ls -la "$ORT_HOME" >&2
  exit 1
fi
echo "ORT Android home: $ORT_HOME"

# --- Configure + build ------------------------------------------------------
BUILD_DIR="$RAVEN_DIR/.build-android"
cmake -B "$BUILD_DIR" -S "$RAVEN_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
  -DANDROID_ABI="$ANDROID_ABI" \
  -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
  -DORT_ANDROID_HOME="$ORT_HOME" \
  -DPTT_OUTPUT_DIR="$BUILD_DIR/out"

cmake --build "$BUILD_DIR" -j

echo "=== Built artifacts ==="
ls -la "$BUILD_DIR/out"
