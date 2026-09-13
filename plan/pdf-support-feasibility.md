# Feasibility study: PDF support in Guten-Speak

Investigated 2026-09-05 against the current `app/` codebase (EPUB + plain-text
pipeline), pub.dev package metadata, Project Gutenberg's published format
policy, and the Gutendex API.

## Recommendation

**PDF support is feasible, but only as text extraction into the existing
paragraph pipeline — not as a page-rendering PDF viewer.** The recommended
approach is a `PdfParser` that mirrors the existing `EpubParser` contract
(`paragraphs` + `toc`), slotted into `BookContentLoader` as a third resolution
step. Everything downstream — reader, narration, resume, bookmarks, the
`content.json` cache — then works unchanged.

Before building, be aware of the decisive scope fact: **Project Gutenberg does
not auto-generate PDFs.** PDF is only available for a small minority of books
(chiefly older items and LaTeX-typeset math/science titles), so PDF can only
ever be a *fallback* input format, never a replacement for the EPUB/text
pipeline. A Go decision should therefore be framed as "cheap robustness for
books whose only good edition is a PDF, plus `.pdf` file import", not "PDF as a
first-class reading format".

**Recommended decision:** proceed with a small, time-boxed extraction spike
(Phase 1 below) using **PDFium via `pdfium_dart`** (free, MIT/Apache) with
**Syncfusion's `syncfusion_flutter_pdf`** as the fallback candidate if the FFI
extraction quality/effort is unacceptable (accepting its commercial-license
obligation). Do **not** build a page-based viewer.

## 1. How book content flows today

The app's entire reading and narration stack is built on one abstraction:

```
download (Gutendex formats / file picker)
  → <booksDir>/<id>/book.epub  (preferred)   or   text.txt  (fallback)
  → BookContentLoader.load(bookDir)
  → BookContent { paragraphs: List<String>, toc: List<TocEntry> }
  → cached to content.json (atomic, versioned)
  → Reader (ScrollablePositionedList over paragraphs, index-precise resume/jump)
  → Narration (NarrationSegmenter → Raven TTS, look-ahead scheduling, synth cache)
```

Key properties that constrain any new input format:

- **Everything is paragraphs.** `BookContent` (`app/lib/features/library/domain/entities/book_content.dart`)
  is a flat list of plain strings plus TOC entries pointing at paragraph
  indexes. There is no page concept, no markup, no images in the reading flow.
- **The EPUB parser already drops layout.** `EpubParser`
  (`app/lib/core/utils/epub_parser.dart`) extracts only reading-flow text and
  the navigation TOC; images and styling are discarded. Gutenberg boilerplate
  (`*** START/END OF THE PROJECT GUTENBERG EBOOK ***`) is stripped and the TOC
  is re-indexed against the trimmed paragraph list.
- **Narration is index-based.** Progress, bookmarks (`TocEntry.paragraphIndex`),
  and the TTS synth cache all key off paragraph indexes/text hashes. A new
  format that yields the same `BookContent` shape inherits all of this for free.
- **File import currently accepts `.epub` only**
  (`library_screen.dart`: `FilePicker.pickFiles(..., allowedExtensions: ['epub'])`).
- **Download URLs for txt/epub are synthesized from the book id**

## 2. The PDF situation at Project Gutenberg (verified)

- Gutenberg's own file-format help page states: *"Almost every Project Gutenberg
  eBook since 2004 is released as plain text and HTML, as master formats. Other
  formats, such as epub and mobi, are generated automatically. **A small number
  of items use LaTeX as the master format**, especially when mathematical
  notation is needed. **LaTeX is used to generate PDF.**"* — i.e. PDF is
  hand-picked/LaTeX-derived, not auto-generated.
- Gutendex exposes PDFs under the `application/pdf` mime-type key in a book's
  `formats` map, with URLs of varying shapes
  (`https://www.gutenberg.org/files/<id>/<id>-pdf.pdf` and variants). Verified
  that **Pride and Prejudice (1342) has no PDF at all** — its formats contain
  only html/epub/mobi/rdf/plain-text.
- Consequences for us:
  - PDF URLs are **not derivable from the id**; the download path must read the
    URL from Gutendex's `formats` map (the repository already receives
    `BookSummary` data sourced from Gutendex).
  - Coverage is small. (A Gutendex `?mime_type=application/pdf` count query was
    attempted for this study but the API returned HTTP 503; the exact count
    should be captured in Phase 0. Gutenberg's own description — "a small
    number of items" — plus spot checks strongly suggest a low single-digit
    percentage of the ~79k catalog.)
  - Many surviving PDFs are older, TeX-typeset, or scanned. LaTeX PDFs have
    selectable text; **scanned PDFs have no text layer at all** and are
    unusable without OCR (out of scope — must be detected and rejected, §4).

## 3. Architecture options

### Option A — text extraction into the existing pipeline (recommended)

Extract paragraphs + TOC from the PDF and produce a normal `BookContent`. The
reader and narration treat it exactly like an EPUB import today.

| Aspect | Assessment |
| --- | --- |
| Reader experience | Re-flowable, themeable, matches the rest of the app. |
| Narration | Works unchanged; paragraphs feed `NarrationSegmenter` → Raven. |
| Resume / bookmarks / TOC | Paragraph-index based; PDF outline (bookmarks) can map to `TocEntry`, with the heuristic `TocExtractor` as fallback. |
| Cache | `content.json` cache reused verbatim; PDF parsed once per download. |
| Risk | Extraction quality (reading order, headers/footers, hyphenation, ligatures) — see §4. |
| Effort | One parser class + loader/repository plumbing; no reader changes. |

### Option B — page-rendering PDF viewer (rejected)

Show the PDF's pages as rendered images (e.g. `pdfx`, `pdfrx`, or Android's
native `PdfRenderer` via a platform channel).

Why it is the wrong fit:

- **No narration.** Guten-Speak's core feature is reading aloud. `PdfRenderer`
  and `pdfx` expose no text at all, so TTS would need a *separate* text
  extraction pipeline anyway — we would build Option A twice.
- **No reflow/theming/accessibility**, no consistent progress model with the
  rest of the library (page number vs paragraph index), duplicated bookmark and
  resume logic.
- Doesn't reuse `content.json`, `TocEntry`, or any reader infrastructure.

A minimal page viewer is only worth considering later as a *diagnostic* fallback
("this PDF has no text layer") and even then, a clear error message is cheaper.

### Option C — hybrid (not needed initially)

Extraction first; keep the raw PDF on disk so a viewer can be added later
without a re-download. This costs nothing beyond keeping `book.pdf` in the book
directory (the loader's resolution order already tolerates multiple artifacts).

## 4. Extraction quality: the real work

The engineering risk is not the viewer or the plumbing — it is producing clean,
reading-order-correct paragraphs from a page-layout format. Known issues,
mapped to the mitigations this codebase already uses or would need:

| PDF artifact | Impact | Mitigation |
| --- | --- | --- |
| Running headers/footers, page numbers | Repeated junk on every page | Drop text in recurring top/bottom page zones (PDFium gives text-rect geometry); cross-check that removed strings repeat across ≥ N pages |
| Gutenberg licence header/footer | Boilerplate around the book body | Reuse the `EpubParser` START/END marker regexes — the PDF's generated text carries the same markers |
| Hyphenation at line breaks (`exam- ple`) | Broken words inside paragraphs | Dehyphenate when re-assembling lines into paragraphs (LaTeX PDFs hyphenate aggressively) |
| Ligatures (fi, fl, … — code points U+FB00–FB04) | Garbled TTS pronunciation | Unicode NFKC/fold ligature normalization before paragraph assembly |
| Reading order (multi-column, footnotes, captions) | Scrambled paragraphs | Single-column TeX output is mostly safe; use text-box geometry (y-sort, x for columns) rather than raw insertion order; treat complex layouts as a known limitation |
| Footnotes | Interrupt narrative flow | Best-effort: drop or append footnote blocks per page; document the limitation |
| Scanned PDFs (no text layer) | Nothing to extract | Detect `FPDFText_CountChars == 0` per document and fail with a clear "no selectable text (scanned PDF)" failure |
| No publisher TOC in some PDFs | Missing chapters | Map the PDF outline (`FPDFBookmark_*`) to `TocEntry`; fall back to the existing heuristic `TocExtractor` |


## 5. Library landscape (pub.dev, verified 2026-09-05)

| Option | What it gives us | License | Fit |
| --- | --- | --- | --- |
| **`pdfium_dart` 0.3.0** | FFI bindings to PDFium's full C API (`FPDFText_*` text extraction, `FPDFBookmark_*` outline); bundles PDFium binaries via Dart native assets (Android arm64/armv7/x86/x86_64 supported); maintained by the `pdfrx` author | MIT (PDFium itself: Apache 2.0 / BSD-style) | **Best fit for Option A.** Free, extraction + outline, no UI we don't need. Cost: hand-written extraction layer over a low-level API, and a build-time native-asset download to vet |
| **`syncfusion_flutter_pdf` 34.2.6** | High-level pure-Dart text extraction (`PdfTextExtractor`), outline access, no native code | Commercial (free Community license under Syncfusion's revenue threshold; registration required) | Fastest path to good extraction quality; **licensing obligation** and vendor dependency must be accepted deliberately |
| `pdfrx` 2.6.1 | Full PDFium viewer with text selection, outline, search (via `pdfrx_engine`) | MIT | Viewer-only relevance (Option B). Also **requires Dart 3.13 / Flutter 3.47**; `app/pubspec.yaml` pins `sdk: ^3.12.0` (Flutter 3.44) — would force a toolchain bump |
| `pdfx` 2.11.0 | Rendering only; on Android uses native `PdfRenderer`, **no text extraction** | MIT | Not useful for Option A |
| Android `PdfRenderer` (platform channel) | Page-to-bitmap rendering | Android SDK | No text API at all; render-only |
| MuPDF | Extraction + rendering | AGPL / commercial | AGPL is incompatible with our distribution model; commercial is unjustified for this need |

Note on process isolation: PDF parsing must run off the UI isolate (the EPUB
parse already does heavy work in isolates). PDFium via FFI is callable from a
Dart isolate; Syncfusion is pure Dart and isolate-friendly.

## 6. Integration plan (minimal diff)

All changes are additive to the existing library feature; the reader and
narration features are untouched.

1. **`core/utils/pdf_parser.dart`** — new `PdfParser` mirroring `EpubParser`:
   `parse(bytes) → {paragraphs, toc, title?}` with ligature normalization,
   dehyphenation, page-zone boilerplate removal, Gutenberg marker stripping
   (reuse the existing regexes), outline → `TocEntry` mapping with
   `TocExtractor` fallback, and a distinct failure for text-less (scanned)
   PDFs. Pure function of bytes so it is unit-testable offline, like
   `EpubParser`.
2. **`BookContentLoader`** — add `book.pdf` to the resolution order between
   `book.epub` and `text.txt`, reusing the `content.json` cache unchanged.
3. **`LibraryRepositoryImpl`** — in `downloadBook`, read the PDF URL from the
   book's Gutendex `formats` map (requires carrying `application/pdf` through
   `BookSummary`) and prefer `epub → pdf → text`; reuse the existing
   `_downloadWithFallback` / `.part` machinery. Delete stale artifacts of the
   other formats on success, mirroring the existing text-fallback cleanup.
4. **Import** — extend the file picker's `allowedExtensions` with `pdf` and
   branch to the PDF path in the import flow.
5. **Tests** — fixture-based parser tests (a committed small public-domain PDF
   with a text layer + outline; a synthetic text-less PDF for the scanned-case
   failure), loader resolution-order tests, and a download-preference test.

## 7. Phased plan and effort

| Phase | Work | Estimate |
| --- | --- | --- |
| 0 — Scope check | Capture the real Gutendex `application/pdf` count and URL shapes; sample ~20 PDFs for text-layer presence and extraction quality; confirm the toolchain/dependency choice | 0.5–1 day |
| 1 — Extraction spike | `PdfParser` over the chosen engine against the sampled corpus; measure paragraph fidelity vs plain-text ground truth | 3–5 days |
| 2 — Pipeline integration | Loader/repository/import plumbing, cache, failure mapping, tests | 2–3 days |
| 3 — Narration validation | On-device listen-through of a PDF-sourced book; segmenter/synth-cache sanity; TTS pronunciation check after ligature handling | 1–2 days |
| 4 — Hardening | Large-document performance (isolate + memory), edge cases, third-party license registration (Syncfusion path only) | 1–2 days |

Total: roughly **1.5–3 weeks**, dominated by Phase 1 extraction quality. A
kill-switch criterion: if > ~20 % of sampled PDFs produce badly ordered or
mangled paragraphs after Phase 1, stop — the format's payoff is too small to
justify deep layout handling.

## 8. Risks and open questions

- **Low payoff ceiling.** PDF covers a small slice of the catalog; most books
  that have a PDF also have EPUB/text, which already extract more cleanly.
  The feature's value is mostly (a) LaTeX/math books whose PDF is the best
  edition, (b) arbitrary user PDF imports, (c) resilience if a book's other
  formats are missing.
- **Extraction fidelity is unpredictable per document** (§4). Mitigated by the
  Phase 1 spike and the kill-switch criterion.
- **Toolchain coupling.** `pdfrx`/newest `pdfium_dart`-ecosystem releases track
  recent Flutter/Dart versions; `app/pubspec.yaml` currently pins Dart
  `^3.12.0`. Verify native-asset builds on our exact toolchain before
  committing (the repo already builds a native FFI plugin, `pocket_tts_raven`,
  so the pattern is proven).
- **Open:** should imported PDFs keep the raw `book.pdf` on disk (Option C) for
  a future viewer? Default: yes — it costs one file.
- **Open:** expected UX when a PDF has no text layer. Proposed: a precise
  "scanned PDF — no selectable text" failure, consistent with the LCP study's
  principle of precise, honest error states.
- **Open:** Syncfusion Community-license acceptance if the FFI path underperforms.

## 9. Sources

- [Project Gutenberg — File Formats utilized by Project Gutenberg](https://www.gutenberg.org/help/file_formats.html) (PDF/LaTeX policy quote)
- [Gutendex API](https://gutendex.com/) — book 1342 `formats` (no `application/pdf`); total catalog count 79,326; the `?mime_type=application/pdf` count query returned HTTP 503 at investigation time
- [pub.dev: pdfx](https://pub.dev/packages/pdfx) — 2.11.0, MIT, render-only, Android engine: native `PdfRenderer`
- [pub.dev: pdfrx](https://pub.dev/packages/pdfrx) — 2.6.1, MIT, PDFium viewer, requires Flutter 3.47+/Dart 3.13+
- [pub.dev: pdfium_dart](https://pub.dev/packages/pdfium_dart) — 0.3.0, MIT, FFI bindings, PDFium via Dart native assets
- [pub.dev: syncfusion_flutter_pdf](https://pub.dev/packages/syncfusion_flutter_pdf) — 34.2.6, commercial/community license, pure-Dart text extraction
- Internal: `app/lib/features/library/data/book_content_loader.dart`, `app/lib/core/utils/epub_parser.dart`, `app/lib/core/utils/toc_extractor.dart`, `app/lib/features/library/data/repositories/library_repository_impl.dart`, `app/lib/core/constants/app_constants.dart`, `plan/support-commercial-epub-books.md` (error-state precedent)
