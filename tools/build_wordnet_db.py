#!/usr/bin/env python3
"""Build the offline WordNet dictionary database used by Guten-Speak.

The app downloads a single SQLite file (``wordnet.sqlite``) on first use and
queries a ``senses`` table. This script generates that file from the official
WordNet database files (the ``data.noun`` / ``data.verb`` / ``data.adj`` /
``data.adv`` files in a WordNet ``dict/`` directory).

Usage
-----
1. Download the WordNet 3.1 database files from Princeton and unpack them:
       https://wordnet.princeton.edu/download/current-version
   You want the directory containing ``data.noun``, ``data.verb``, etc.
   (usually ``dict/``).

2. Run this script:
       python3 tools/build_wordnet_db.py --dict /path/to/wordnet/dict \
           --out wordnet.sqlite

3. Upload the resulting ``wordnet.sqlite`` as an asset on the GitHub release
   tag the app downloads from (see ``DictionaryManager._urls`` in
   ``app/lib/features/dictionary/data/dictionary_manager.dart``).

Schema
------
    CREATE TABLE senses(
        word       TEXT NOT NULL,  -- lemma, lowercased (spaces preserved)
        pos        TEXT NOT NULL,  -- n | v | a | s | r
        definition TEXT NOT NULL,
        examples   TEXT,           -- newline-joined example sentences
        synonyms   TEXT            -- newline-joined synonyms (other lemmas)
    );
    CREATE INDEX idx_senses_word ON senses(word);

WordNet is distributed under a permissive license (see the WordNet license),
which is compatible with a free, non-commercial app.
"""

from __future__ import annotations

import argparse
import os
import sqlite3
import sys

DATA_FILES = {
    "data.noun": "n",
    "data.verb": "v",
    "data.adj": "a",
    "data.adv": "r",
}


def parse_gloss(gloss: str) -> tuple[str, list[str]]:
    """Split a WordNet gloss into (definition, examples).

    A gloss looks like ``a definition here; "an example"; "another"``. The
    quoted, semicolon-separated segments are examples; everything else is the
    definition.
    """
    definition_parts: list[str] = []
    examples: list[str] = []
    for part in gloss.split(";"):
        stripped = part.strip()
        if not stripped:
            continue
        if stripped.startswith('"'):
            examples.append(stripped.strip('"').strip())
        else:
            definition_parts.append(stripped)
    return "; ".join(definition_parts).strip(), examples


def parse_data_file(path: str, pos: str):
    """Yields (words, pos, definition, examples) tuples for each synset."""
    with open(path, encoding="latin-1") as handle:
        for line in handle:
            # License header lines begin with a space; data lines don't.
            if line.startswith(" "):
                continue
            line = line.rstrip("\n")
            if "|" not in line:
                continue
            head, gloss = line.split("|", 1)
            fields = head.split()
            # fields: offset lex_filenum ss_type w_cnt (word lex_id)* p_cnt ...
            try:
                w_cnt = int(fields[3], 16)
            except (IndexError, ValueError):
                continue
            words: list[str] = []
            idx = 4
            for _ in range(w_cnt):
                if idx >= len(fields):
                    break
                words.append(fields[idx].replace("_", " "))
                idx += 2  # skip the lex_id following each word
            if not words:
                continue
            definition, examples = parse_gloss(gloss.strip())
            if not definition:
                continue
            yield words, pos, definition, examples


def build(dict_dir: str, out_path: str) -> int:
    if os.path.exists(out_path):
        os.remove(out_path)

    conn = sqlite3.connect(out_path)
    try:
        conn.execute("PRAGMA journal_mode = DELETE")
        conn.execute(
            """
            CREATE TABLE senses(
                word       TEXT NOT NULL,
                pos        TEXT NOT NULL,
                definition TEXT NOT NULL,
                examples   TEXT,
                synonyms   TEXT
            )
            """
        )
        conn.execute(
            "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)"
        )

        total = 0
        for file_name, pos in DATA_FILES.items():
            path = os.path.join(dict_dir, file_name)
            if not os.path.exists(path):
                print(f"warning: {path} not found, skipping", file=sys.stderr)
                continue
            rows = []
            for words, ss_pos, definition, examples in parse_data_file(path, pos):
                examples_blob = "\n".join(examples)
                for i, word in enumerate(words):
                    synonyms = [w for j, w in enumerate(words) if j != i]
                    rows.append(
                        (
                            word.lower(),
                            ss_pos,
                            definition,
                            examples_blob,
                            "\n".join(synonyms),
                        )
                    )
                if len(rows) >= 5000:
                    conn.executemany(
                        "INSERT INTO senses(word, pos, definition, examples, "
                        "synonyms) VALUES(?, ?, ?, ?, ?)",
                        rows,
                    )
                    total += len(rows)
                    rows = []
            if rows:
                conn.executemany(
                    "INSERT INTO senses(word, pos, definition, examples, "
                    "synonyms) VALUES(?, ?, ?, ?, ?)",
                    rows,
                )
                total += len(rows)

        conn.execute("CREATE INDEX idx_senses_word ON senses(word)")
        conn.execute(
            "INSERT INTO meta(key, value) VALUES('source', 'WordNet')"
        )
        conn.execute(
            "INSERT INTO meta(key, value) VALUES('sense_count', ?)",
            (str(total),),
        )
        conn.commit()
        conn.execute("VACUUM")
        conn.commit()
        return total
    finally:
        conn.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dict",
        required=True,
        help="Path to the WordNet dict/ directory (contains data.noun, etc.)",
    )
    parser.add_argument(
        "--out",
        default="wordnet.sqlite",
        help="Output SQLite path (default: wordnet.sqlite)",
    )
    args = parser.parse_args()

    if not os.path.isdir(args.dict):
        parser.error(f"not a directory: {args.dict}")

    total = build(args.dict, args.out)
    size_mb = os.path.getsize(args.out) / (1024 * 1024)
    print(f"Wrote {total} senses to {args.out} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
