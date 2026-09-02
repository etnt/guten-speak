#!/usr/bin/env bash
#
# Device-local TTS benchmark harness for the sherpa baseline (and, from the
# Raven worktree, the Raven candidate). Runs the on-device smoke/benchmark
# integration test, records device + build state, and pulls the JSON report.
#
# No voice audio or book text is uploaded anywhere; everything stays on the
# device and in the local results directory.
#
# Usage:
#   tools/run_android_tts_benchmark.sh [-s DEVICE_SERIAL] [-a APP_ID] [-o OUT_DIR]
#
# Requirements: adb + flutter on PATH, a connected arm64 device, and the app
# built in profile mode (debug measurements are diagnostic only, per plan 11.1).

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../app" && pwd)"
REPO_DIR="$(cd "${APP_DIR}/.." && pwd)"

DEVICE=""
APP_ID="se.kruskakli.guten_speak.benchsherpa"
OUT_DIR="${REPO_DIR}/plan/benchmark-results"

while getopts "s:a:o:h" opt; do
  case "${opt}" in
    s) DEVICE="${OPTARG}" ;;
    a) APP_ID="${OPTARG}" ;;
    o) OUT_DIR="${OPTARG}" ;;
    h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option" >&2; exit 2 ;;
  esac
done

if [[ -z "${DEVICE}" ]]; then
  DEVICE="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi
if [[ -z "${DEVICE}" ]]; then
  echo "No connected adb device found. Pass -s DEVICE_SERIAL." >&2
  exit 1
fi

ADB=(adb -s "${DEVICE}")
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="${OUT_DIR}/${STAMP}"
mkdir -p "${RUN_DIR}"

echo "Device:  ${DEVICE}"
echo "App ID:  ${APP_ID}"
echo "Output:  ${RUN_DIR}"

# --- 1. Record device + build state -----------------------------------------
STATE="${RUN_DIR}/device-state.txt"
{
  echo "timestamp_utc=${STAMP}"
  echo "device_serial=${DEVICE}"
  echo "app_id=${APP_ID}"
  echo "app_git_commit=$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)"
  if [[ -n "$(git -C "${REPO_DIR}" status --porcelain 2>/dev/null)" ]]; then
    echo "app_git_dirty=true"
  else
    echo "app_git_dirty=false"
  fi
  echo "--- getprop ---"
  "${ADB[@]}" shell getprop ro.product.model
  "${ADB[@]}" shell getprop ro.build.fingerprint
  "${ADB[@]}" shell getprop ro.product.cpu.abi
  echo "--- cpu cores ---"
  "${ADB[@]}" shell "cat /proc/cpuinfo | grep -c ^processor" || true
  echo "--- memory ---"
  "${ADB[@]}" shell cat /proc/meminfo | head -n 3 || true
  echo "--- battery ---"
  "${ADB[@]}" shell dumpsys battery | grep -E "level|status|powersave|temperature" || true
  echo "--- thermal ---"
  "${ADB[@]}" shell dumpsys thermalservice | grep -E "Temperature|mStatus" | head -n 20 || true
} >"${STATE}" 2>&1
echo "Wrote ${STATE}"

# --- 2. Run the on-device benchmark integration test -------------------------
LOG="${RUN_DIR}/logcat.txt"
"${ADB[@]}" logcat -c || true

echo "Running integration test (this downloads the model on first run)…"
(
  cd "${APP_DIR}"
  flutter test integration_test/tts_engine_smoke_test.dart \
    -d "${DEVICE}" --profile 2>&1
) | tee "${RUN_DIR}/flutter-test.log"

# Capture the benchmark markers the test prints to stdout/logcat.
"${ADB[@]}" logcat -d | grep "GS_BENCH" >"${LOG}" 2>/dev/null || true

# --- 3. Pull the JSON report from app-private storage ------------------------
# The test logs `GS_BENCH REPORT <path>` for the file it wrote.
REPORT_PATH="$(grep -oE 'GS_BENCH REPORT .*' "${RUN_DIR}/flutter-test.log" "${LOG}" 2>/dev/null \
  | tail -n 1 | sed 's/.*GS_BENCH REPORT //')"

if [[ -n "${REPORT_PATH}" ]]; then
  echo "Report on device: ${REPORT_PATH}"
  # run-as works for debuggable builds; profile builds are debuggable by default.
  if "${ADB[@]}" exec-out run-as "${APP_ID}" cat "${REPORT_PATH}" \
      >"${RUN_DIR}/report.json" 2>/dev/null; then
    echo "Pulled report to ${RUN_DIR}/report.json"
  else
    echo "Could not run-as ${APP_ID}; pull ${REPORT_PATH} manually." >&2
  fi
else
  echo "No GS_BENCH REPORT marker found; check ${RUN_DIR}/flutter-test.log." >&2
fi

echo "Done. Results in ${RUN_DIR}"
