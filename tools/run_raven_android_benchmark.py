#!/usr/bin/env python3
"""Run the pocket-tts-raven Android CLI on a Pixel over the small benchmark corpus.

Pushes the cross-compiled arm64 binary + libonnxruntime.so + models + a voice
sample to /data/local/tmp/raven on the device, then runs each corpus unit under
one or more Raven profiles and records the reported RTFx per unit. Saves an
aggregate JSON alongside the sherpa baseline for direct comparison.

Usage:
  python3 tools/run_raven_android_benchmark.py [--serial SERIAL] [--repush-models]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import statistics
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RAVEN = REPO / "pocket-tts-raven"
OUT_DIR = RAVEN / ".build-android" / "out"
MODELS = RAVEN / "models"
VOICE = RAVEN / "voices" / "example.wav"
CORPUS = REPO / "app" / "assets" / "benchmark" / "tts_benchmark_corpus_small.json"
RESULT = REPO / "plan" / "benchmark-results" / "raven-small-pixel10pro.json"

DEVICE_DIR = "/data/local/tmp/raven"
ADB = os.path.expanduser("~/Library/Android/sdk/platform-tools/adb")
DEFAULT_SERIAL = "56041FDCH00CDN"

# Raven profiles to sweep. (No --seed flag exists; seed is time-based and does
# not affect compute time, only output content, so it's irrelevant for speed.)
PROFILES = [
    {"id": "int8-1step-t0.70", "args": ["--precision", "int8", "--lsd-steps", "1", "--temperature", "0.70"]},
    {"id": "int8-1step-t0.20", "args": ["--precision", "int8", "--lsd-steps", "1", "--temperature", "0.20"]},
    {"id": "int8-4step-t0.20", "args": ["--precision", "int8", "--lsd-steps", "4", "--temperature", "0.20"]},
]

RTFX_RE = re.compile(r"([\d.]+)s audio in ([\d.]+)s \(RTFx: ([\d.]+)x\)")
LOADED_RE = re.compile(r"Loaded in ([\d.]+)s")
THREADS_RE = re.compile(r"threads=(\d+)")


def adb(serial: str, *args: str, **kw) -> subprocess.CompletedProcess:
    return subprocess.run([ADB, "-s", serial, *args], text=True, capture_output=True, **kw)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--serial", default=DEFAULT_SERIAL)
    ap.add_argument("--repush-models", action="store_true", help="Force re-push of the models dir")
    args = ap.parse_args()
    serial = args.serial

    binary = OUT_DIR / "pocket-tts"
    ort = OUT_DIR / "libonnxruntime.so"
    for p in (binary, ort, VOICE, CORPUS):
        if not p.exists():
            print(f"ERROR: missing {p}", file=sys.stderr)
            return 1
    if not MODELS.is_dir():
        print(f"ERROR: missing models dir {MODELS}", file=sys.stderr)
        return 1

    corpus = json.loads(CORPUS.read_text())
    units = corpus["units"]
    print(f"Corpus: {len(units)} units, {corpus.get('totalWords')} words")

    # --- Push bundle ---------------------------------------------------------
    adb(serial, "shell", f"mkdir -p {DEVICE_DIR}/voices")
    print("Pushing binary + libonnxruntime.so + voice...")
    adb(serial, "push", str(binary), f"{DEVICE_DIR}/pocket-tts")
    adb(serial, "push", str(ort), f"{DEVICE_DIR}/libonnxruntime.so")
    adb(serial, "push", str(VOICE), f"{DEVICE_DIR}/voices/example.wav")
    adb(serial, "shell", f"chmod 755 {DEVICE_DIR}/pocket-tts")

    have_models = adb(serial, "shell", f"ls {DEVICE_DIR}/models/flow_lm_main_int8.onnx 2>/dev/null").stdout.strip()
    if args.repush_models or not have_models:
        print("Pushing models (~285MB, one-time)...")
        r = adb(serial, "push", str(MODELS), f"{DEVICE_DIR}/models")
        if r.returncode != 0:
            print(r.stderr, file=sys.stderr)
            return 1
    else:
        print("Models already on device (use --repush-models to force).")

    # --- Build the on-device run script (avoids adb-shell quoting of quotes/em-dashes) ---
    lines = ["set -e", f"cd {DEVICE_DIR}", "export LD_LIBRARY_PATH=."]
    # Warm the voice-embedding cache once so timed runs use the cached embedding.
    lines.append('./pocket-tts "Warmup sentence for embedding cache." example.wav /data/local/tmp/raven/_warm.wav >/dev/null 2>&1 || true')
    for prof in PROFILES:
        pargs = " ".join(shlex.quote(a) for a in prof["args"])
        for u in units:
            text = u["text"]
            # single-quote the text for the device shell; escape embedded single quotes
            q = "'" + text.replace("'", "'\\''") + "'"
            lines.append(f'echo "GS_RAVEN_BEGIN {prof["id"]} {u["id"]}"')
            lines.append(f'./pocket-tts {q} example.wav /data/local/tmp/raven/_out.wav {pargs} 2>&1 || echo "GS_RAVEN_ERR {prof["id"]} {u["id"]}"')
            lines.append(f'echo "GS_RAVEN_END {prof["id"]} {u["id"]}"')
    script = "\n".join(lines) + "\n"

    script_local = REPO / "tools" / ".raven_device_run.sh"
    script_local.write_text(script)
    adb(serial, "push", str(script_local), f"{DEVICE_DIR}/run.sh")

    print("Running on device...")
    run = adb(serial, "shell", f"sh {DEVICE_DIR}/run.sh")
    output = run.stdout + "\n" + run.stderr

    # --- Parse ---------------------------------------------------------------
    results: dict[str, list[dict]] = {p["id"]: [] for p in PROFILES}
    threads = None
    cur_prof = cur_unit = None
    block: list[str] = []
    for line in output.splitlines():
        m = re.match(r"GS_RAVEN_BEGIN (\S+) (\S+)", line)
        if m:
            cur_prof, cur_unit = m.group(1), m.group(2)
            block = []
            continue
        if line.startswith("GS_RAVEN_END"):
            btext = "\n".join(block)
            tm = THREADS_RE.search(btext)
            if tm:
                threads = int(tm.group(1))
            rm = RTFX_RE.search(btext)
            lm = LOADED_RE.search(btext)
            if rm and cur_prof in results:
                results[cur_prof].append({
                    "unitId": cur_unit,
                    "audioSeconds": float(rm.group(1)),
                    "computeSeconds": float(rm.group(2)),
                    "rtfx": float(rm.group(3)),
                    "loadedSeconds": float(lm.group(1)) if lm else None,
                })
            else:
                results.setdefault(cur_prof, []).append({"unitId": cur_unit, "error": btext.strip()[:400]})
            cur_prof = cur_unit = None
            continue
        if cur_prof is not None:
            block.append(line)

    # --- Aggregate + save ----------------------------------------------------
    summary = {}
    for pid, rows in results.items():
        ok = [r for r in rows if "rtfx" in r]
        if not ok:
            summary[pid] = {"units": len(rows), "ok": 0, "note": "no successful runs"}
            continue
        total_audio = sum(r["audioSeconds"] for r in ok)
        total_compute = sum(r["computeSeconds"] for r in ok)
        rtfxs = [r["rtfx"] for r in ok]
        summary[pid] = {
            "units": len(rows),
            "ok": len(ok),
            "rtfxMedian": round(statistics.median(rtfxs), 3),
            "rtfxMin": round(min(rtfxs), 3),
            "rtfxMax": round(max(rtfxs), 3),
            "durationWeightedRtfx": round(total_audio / total_compute, 3) if total_compute else None,
            "totalAudioSeconds": round(total_audio, 3),
            "totalComputeSeconds": round(total_compute, 3),
        }

    doc = {
        "engine": "pocket-tts-raven",
        "device": "Pixel 10 Pro",
        "serial": serial,
        "abi": "arm64-v8a",
        "ortVersion": "1.23.2",
        "threads": threads,
        "capturedAt": datetime.now(timezone.utc).isoformat(),
        "corpus": {
            "source": CORPUS.name,
            "units": len(units),
            "totalWords": corpus.get("totalWords"),
            "totalChars": corpus.get("totalChars"),
        },
        "profiles": summary,
        "perUnit": results,
    }

    # --- Normalized comparison vs the sherpa baseline ------------------------
    # sherpa harness reports nativeRtf = compute/audio (higher = SLOWER).
    # Raven CLI reports RTFx = audio/compute (higher = FASTER). Convert both to
    # secondsComputePerSecondAudio (lower = faster) for an apples-to-apples ratio.
    sherpa_path = RESULT.parent / "sherpa-small-pixel10pro-profile.json"
    if sherpa_path.exists():
        sh = json.loads(sherpa_path.read_text())
        sherpa_cpa = sh["aggregate"]["durationWeightedNativeRtf"]  # compute per audio
        comp = {
            "note": "secondsComputePerSecondAudio: lower = faster. speedupVsSherpa = sherpa / raven (x faster).",
            "sherpaBaseline": {
                "source": sherpa_path.name,
                "secondsComputePerSecondAudio": round(sherpa_cpa, 3),
                "timesRealtime": round(1.0 / sherpa_cpa, 4),
            },
            "raven": {},
        }
        for pid, s in summary.items():
            dw = s.get("durationWeightedRtfx")
            if not dw:
                continue
            raven_cpa = 1.0 / dw
            comp["raven"][pid] = {
                "timesRealtime": round(dw, 3),
                "secondsComputePerSecondAudio": round(raven_cpa, 3),
                "speedupVsSherpa": round(sherpa_cpa / raven_cpa, 1),
            }
        doc["comparisonToSherpa"] = comp

    RESULT.parent.mkdir(parents=True, exist_ok=True)
    RESULT.write_text(json.dumps(doc, indent=2) + "\n")

    print("\n=== Raven on-device summary ===")
    for pid, s in summary.items():
        print(f"  {pid}: {s}")
    if "comparisonToSherpa" in doc:
        print("\n=== vs sherpa baseline (higher speedup = Raven faster) ===")
        base = doc["comparisonToSherpa"]["sherpaBaseline"]
        print(f"  sherpa: {base['timesRealtime']:.3f}x realtime ({base['secondsComputePerSecondAudio']}s compute/s audio)")
        for pid, c in doc["comparisonToSherpa"]["raven"].items():
            print(f"  {pid}: {c['timesRealtime']}x realtime -> {c['speedupVsSherpa']}x faster than sherpa")
    print(f"\nSaved: {RESULT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
