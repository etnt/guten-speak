#!/usr/bin/env python3
"""Generate side-by-side listening samples for the sherpa vs pocket-tts-raven
quality comparison, both cloning the *same* reference voice (Reginald).

Audio quality is platform-independent (identical ONNX weights), so both engines
are run on macOS here to get a clean same-voice A/B without another slow
on-device sherpa pass.

Outputs one concatenated WAV per engine/profile (with short silence gaps between
corpus units) plus the per-unit clips under plan/benchmark-results/listen/.

Run with the sherpa venv python:
  /tmp/sherpa_venv/bin/python tools/make_listen_samples.py
"""

from __future__ import annotations

import json
import struct
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
CORPUS = REPO / "app/assets/benchmark/tts_benchmark_corpus_small.json"
REGINALD = REPO / "app/assets/voices/reginald-ashworth.wav"
OUT = REPO / "plan/benchmark-results/listen"

# Raven native pieces.
RAVEN_BIN = REPO / "pocket-tts-raven/pocket-tts"
RAVEN_MODELS = REPO / "pocket-tts-raven/models"
RAVEN_TOKENIZER = RAVEN_MODELS / "tokenizer.model"
RAVEN_VOICES = OUT / "voices"  # scratch dir so the .cache/ lands here, not in assets

# Sherpa PoC (fp32) Pocket TTS model bundled with the macOS PoC app.
SHERPA_DIR = (
    Path.home()
    / "Library/Containers/com.gutenspeak.gutenSpeakPoc/Data/Library/Application Support"
    / "com.gutenspeak.gutenSpeakPoc/models/sherpa-onnx-pocket-tts-2026-01-26"
)

SAMPLE_RATE = 24000
GAP_SECONDS = 0.5


def normalize_tts_text(text: str) -> str:
    """Mirror app/lib/core/tts/tts_text_processing.dart normalizeTtsText."""
    return (
        text.replace('"', "")
        .replace("\u201c", "")
        .replace("\u201d", "")
        .replace("\u201e", "")
        .replace("\u201f", "")
        .replace("\u2018", "'")
        .replace("\u2019", "'")
    )


def read_wav_float(path: Path) -> tuple[list[float], int]:
    """Read a mono WAV as float samples in [-1, 1].

    Handles both 16-bit PCM (fmt tag 1, e.g. the reference voice) and 32-bit
    IEEE float (fmt tag 3, what pocket-tts-raven emits). Python's stdlib wave
    module rejects float WAVs, so parse the RIFF chunks directly.
    """
    raw = path.read_bytes()
    assert raw[:4] == b"RIFF" and raw[8:12] == b"WAVE", f"{path}: not a WAV"
    fmt_tag = bits = channels = rate = None
    data = None
    pos = 12
    while pos + 8 <= len(raw):
        cid = raw[pos : pos + 4]
        size = struct.unpack("<I", raw[pos + 4 : pos + 8])[0]
        body = raw[pos + 8 : pos + 8 + size]
        if cid == b"fmt ":
            fmt_tag, channels, rate, _, _, bits = struct.unpack("<HHIIHH", body[:16])
        elif cid == b"data":
            data = body
        pos += 8 + size + (size & 1)  # chunks are word-aligned
    assert fmt_tag is not None and data is not None, f"{path}: missing fmt/data"

    if fmt_tag == 1 and bits == 16:
        ints = struct.unpack("<%dh" % (len(data) // 2), data)
        samples = [s / 32768.0 for s in ints]
    elif fmt_tag == 3 and bits == 32:
        samples = list(struct.unpack("<%df" % (len(data) // 4), data))
    else:
        raise ValueError(f"{path}: unsupported fmt tag {fmt_tag}/{bits}-bit")

    if channels and channels > 1:  # downmix to mono
        samples = [
            sum(samples[i : i + channels]) / channels
            for i in range(0, len(samples), channels)
        ]
    return samples, rate


def write_wav_float(path: Path, samples: list[float], rate: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = [max(-1.0, min(1.0, s)) for s in samples]
    data = struct.pack("<%dh" % len(clipped), *[int(s * 32767) for s in clipped])
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data)


def concat(clips: list[list[float]]) -> list[float]:
    gap = [0.0] * int(SAMPLE_RATE * GAP_SECONDS)
    out: list[float] = []
    for i, c in enumerate(clips):
        if i:
            out += gap
        out += c
    return out


def load_corpus() -> list[dict]:
    return json.loads(CORPUS.read_text())["units"]


# ---------------------------------------------------------------------------
# Sherpa (Pocket TTS, fp32) — mirrors the app worker's generateWithConfig call.
# ---------------------------------------------------------------------------
def gen_sherpa(units: list[dict]) -> None:
    import sherpa_onnx

    print(f"[sherpa] loading Pocket TTS from {SHERPA_DIR}")
    pocket = sherpa_onnx.OfflineTtsPocketModelConfig(
        lm_flow=str(SHERPA_DIR / "lm_flow.onnx"),
        lm_main=str(SHERPA_DIR / "lm_main.onnx"),
        encoder=str(SHERPA_DIR / "encoder.onnx"),
        decoder=str(SHERPA_DIR / "decoder.onnx"),
        text_conditioner=str(SHERPA_DIR / "text_conditioner.onnx"),
        vocab_json=str(SHERPA_DIR / "vocab.json"),
        token_scores_json=str(SHERPA_DIR / "token_scores.json"),
    )
    config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            pocket=pocket,
            num_threads=6,
            debug=False,
        )
    )
    tts = sherpa_onnx.OfflineTts(config)

    ref_samples, ref_rate = read_wav_float(REGINALD)
    print(f"[sherpa] reference {REGINALD.name}: {len(ref_samples)} samples @ {ref_rate} Hz")

    clips: list[list[float]] = []
    for u in units:
        text = normalize_tts_text(u["text"])
        gc = sherpa_onnx.GenerationConfig()
        gc.num_steps = 28
        gc.reference_audio = ref_samples
        gc.reference_sample_rate = ref_rate
        gc.extra = {
            "max_reference_audio_len": "12",
            "temperature": "0.20",
            "seed": "1234",
            "max_char_in_sentence": "100",
            "max_frames": "160",
        }
        audio = tts.generate(text, gc)
        samples = list(audio.samples)
        rate = audio.sample_rate
        assert rate == SAMPLE_RATE, f"sherpa returned {rate} Hz, expected {SAMPLE_RATE}"
        write_wav_float(OUT / "sherpa" / f"{u['id']}.wav", samples, rate)
        clips.append(samples)
        print(f"[sherpa] {u['id']}: {len(samples)/rate:.2f}s")

    combined = concat(clips)
    write_wav_float(OUT / "sherpa" / "sherpa_reginald_28step_t020.wav", combined, SAMPLE_RATE)
    print(f"[sherpa] wrote combined {len(combined)/SAMPLE_RATE:.2f}s")


# ---------------------------------------------------------------------------
# Raven (int8) — native CLI, two profiles.
# ---------------------------------------------------------------------------
def gen_raven(units: list[dict], lsd_steps: int, temperature: float, label: str) -> None:
    RAVEN_VOICES.mkdir(parents=True, exist_ok=True)
    voice_dst = RAVEN_VOICES / REGINALD.name
    if not voice_dst.exists():
        voice_dst.write_bytes(REGINALD.read_bytes())

    print(f"[raven:{label}] steps={lsd_steps} temp={temperature}")
    clips: list[list[float]] = []
    with tempfile.TemporaryDirectory() as td:
        for u in units:
            text = normalize_tts_text(u["text"])
            tmp = Path(td) / f"{u['id']}.wav"
            cmd = [
                str(RAVEN_BIN),
                text,
                REGINALD.name,
                str(tmp),
                "--voices-dir", str(RAVEN_VOICES),
                "--models-dir", str(RAVEN_MODELS),
                "--tokenizer", str(RAVEN_TOKENIZER),
                "--precision", "int8",
                "--lsd-steps", str(lsd_steps),
                "--temperature", str(temperature),
            ]
            r = subprocess.run(cmd, capture_output=True, text=True)
            if r.returncode != 0 or not tmp.exists():
                sys.stderr.write(r.stderr)
                raise RuntimeError(f"raven failed on {u['id']}")
            samples, rate = read_wav_float(tmp)
            assert rate == SAMPLE_RATE, f"raven returned {rate} Hz"
            write_wav_float(OUT / "raven" / f"{label}_{u['id']}.wav", samples, rate)
            clips.append(samples)
            print(f"[raven:{label}] {u['id']}: {len(samples)/rate:.2f}s")

    combined = concat(clips)
    write_wav_float(OUT / "raven" / f"raven_reginald_{label}.wav", combined, SAMPLE_RATE)
    print(f"[raven:{label}] wrote combined {len(combined)/SAMPLE_RATE:.2f}s")


def main() -> None:
    units = load_corpus()
    OUT.mkdir(parents=True, exist_ok=True)

    which = sys.argv[1] if len(sys.argv) > 1 else "all"

    if which in ("all", "raven"):
        gen_raven(units, lsd_steps=1, temperature=0.20, label="1step_t020")
        gen_raven(units, lsd_steps=4, temperature=0.20, label="4step_t020")
    if which in ("all", "sherpa"):
        gen_sherpa(units)

    print("\nDone. Listen under:", OUT)


if __name__ == "__main__":
    main()
