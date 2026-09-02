#!/usr/bin/env python3
"""Build a small, engine-independent TTS benchmark corpus from real public-domain
book text (Project Gutenberg's Hans Christian Andersen fairy tales).

The corpus is intentionally tiny (~100 words total) so a single on-device pass of
the slow sherpa baseline finishes in a sensible time. It exercises the same
category buckets used by the full measurement corpus (short, median, dialogue,
numbers, names, punctuation, smart_quotes) so sherpa and Raven can be compared on
identical inputs.

Usage:
    python3 tools/build_benchmark_corpus.py \
        --epub HC-Andersens-fairy-tales.epub \
        --out app/assets/benchmark/tts_benchmark_corpus_small.json \
        --target-words 100
"""

from __future__ import annotations

import argparse
import glob
import html
import json
import os
import re
import tempfile
import zipfile


def extract_text(epub_path: str) -> str:
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(epub_path) as zf:
            zf.extractall(tmp)
        raw = ""
        for name in sorted(glob.glob(os.path.join(tmp, "**", "*.xhtml"), recursive=True)):
            if "htm" not in os.path.basename(name):
                continue
            with open(name, encoding="utf-8") as fh:
                raw += fh.read()
    raw = re.sub(r"(?is)<head.*?</head>", " ", raw)
    raw = re.sub(r"<[^>]+>", " ", raw)
    raw = html.unescape(raw).replace("\r", " ")
    raw = re.sub(r"\s+", " ", raw).strip()
    # Drop Project Gutenberg frontmatter/license boilerplate: keep only the text
    # between the START and END markers.
    m = re.search(r"\*\*\*\s*START OF.*?\*\*\*", raw, re.IGNORECASE)
    if m:
        raw = raw[m.end():]
    m = re.search(r"\*\*\*\s*END OF.*?\*\*\*", raw, re.IGNORECASE)
    if m:
        raw = raw[: m.start()]
    return raw.strip()


BANNED = (
    "gutenberg",
    "license",
    "copyright",
    "foundation",
    "ebook",
    "www.",
    "http",
    "trademark",
    "donation",
)


def is_clean(s: str) -> bool:
    low = s.lower()
    if any(b in low for b in BANNED):
        return False
    # Must begin like a real sentence (capital letter or an opening quote).
    if not (s[0].isupper() or s[0] in ("\u201c", '"', "\u2018")):
        return False
    # Must end with terminal punctuation, optionally followed by a closing quote.
    return bool(re.search(r'[.!?][\u201d\u2019"\']?$', s))


def words(s: str) -> int:
    return len(s.split())


def has_quote(s: str) -> bool:
    return any(c in s for c in ("\u201c", "\u201d", '"'))


def has_digit(s: str) -> bool:
    return any(c.isdigit() for c in s)


def has_smart(s: str) -> bool:
    return any(c in s for c in ("\u2018", "\u2019", "\u201c", "\u201d", "\u2014"))


def has_punct(s: str) -> bool:
    return any(c in s for c in (";", ":", "\u2014"))


def has_name(s: str) -> bool:
    for w in s.split()[1:]:
        cw = re.sub(r"[^A-Za-z]", "", w)
        if cw and cw[0].isupper() and cw.lower() != "i":
            return True
    return False


def sentences(raw: str) -> list[str]:
    parts = re.split(r'(?<=[.!?\u201d"])\s+', raw)
    out = []
    for s in parts:
        s = s.strip()
        if 3 <= words(s) <= 40 and is_clean(s):
            out.append(s)
    return out


def balanced_quote(s: str) -> bool:
    if s.count("\u201c") == 1 and s.count("\u201d") == 1 and s.index("\u201c") < s.index("\u201d"):
        return True
    return s.count('"') == 2


def no_quote(s: str) -> bool:
    return not any(c in s for c in ("\u201c", "\u201d", '"'))


def build(raw: str, target_words: int) -> list[dict]:
    sents = sentences(raw)
    # Ordered category selectors: (category, predicate, max desired units).
    selectors = [
        ("short", lambda s: 3 <= words(s) <= 5 and no_quote(s), 3),
        ("median", lambda s: 12 <= words(s) <= 18 and no_quote(s), 2),
        ("dialogue", lambda s: balanced_quote(s) and words(s) <= 20, 2),
        ("numbers", lambda s: has_digit(s) and no_quote(s) and words(s) <= 20, 1),
        ("names", lambda s: has_name(s) and no_quote(s) and words(s) <= 14, 1),
        ("punctuation", lambda s: has_punct(s) and no_quote(s) and words(s) <= 18, 1),
        ("smart_quotes", lambda s: "\u2019" in s and no_quote(s) and words(s) <= 18, 1),
    ]
    chosen: list[tuple[str, str]] = []
    used: set[str] = set()
    budget = target_words
    for category, pred, cap in selectors:
        count = 0
        for s in sents:
            if count >= cap:
                break
            if s in used or not pred(s):
                continue
            if words(s) > budget and chosen:
                continue
            chosen.append((category, s))
            used.add(s)
            budget -= words(s)
            count += 1
    units = []
    per_cat: dict[str, int] = {}
    for category, text in chosen:
        n = per_cat.get(category, 0) + 1
        per_cat[category] = n
        units.append({"id": f"{category}-{n:03d}", "category": category, "text": text})
    return units


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epub", default="HC-Andersens-fairy-tales.epub")
    ap.add_argument("--out", default="app/assets/benchmark/tts_benchmark_corpus_small.json")
    ap.add_argument("--target-words", type=int, default=100)
    args = ap.parse_args()

    raw = extract_text(args.epub)
    units = build(raw, args.target_words)
    total_words = sum(words(u["text"]) for u in units)
    total_chars = sum(len(u["text"]) for u in units)
    corpus = {
        "version": 1,
        "note": (
            "Small (~100-word) engine-independent TTS benchmark corpus assembled from "
            "real public-domain book text (Project Gutenberg: Hans Christian Andersen's "
            "Fairy Tales). Used as a fast on-device pass to compare the sherpa baseline "
            "against Raven candidates on identical inputs. Regenerate with "
            "tools/build_benchmark_corpus.py."
        ),
        "source": "Project Gutenberg: Hans Christian Andersen's Fairy Tales (public domain)",
        "totalWords": total_words,
        "totalChars": total_chars,
        "units": units,
    }
    os.makedirs(os.path.dirname(args.out), exist_ok=True)
    with open(args.out, "w", encoding="utf-8") as fh:
        json.dump(corpus, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print(f"wrote {args.out}: {len(units)} units, {total_words} words, {total_chars} chars")
    for u in units:
        print(f"  {u['id']:>16}  {words(u['text']):>2}w  {u['text'][:80]}")


if __name__ == "__main__":
    main()
