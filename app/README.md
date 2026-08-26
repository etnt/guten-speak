# Guten-Speak — read & listen to Project Gutenberg books

With the **Guten-Speak** mobile Flutter app you can search for books stored at Project Gutenberg.
You can search by Author or parts of Titles, browse categories and popular titles, get a list of matching books, download books for offline access, and read them directly within the app.

Guten-Speak also lets you **optionally listen** to a book, narrated entirely
on-device in a narrator voice you clone from a short `.wav` sample. Narration is
opt-in — the app is a fully usable plain e-reader on its own, and the ~470 MB TTS
model is only downloaded the first time you choose to listen. See
[`../plan/implementation-plan.md`](../plan/implementation-plan.md) for the full
build plan.

This app evolved from the sibling **guten-read** e-reader (its catalog + search)
plus the **Guten-Speak PoC** on-device TTS engine (`sherpa_onnx` PocketTTS,
zero-shot voice cloning).

## Access to Project Gutenberg 

Project Gutenberg itself does not provide a modern REST API, but it publishes raw
RDF/XML catalog dumps and predictable URL structures for direct downloads.
To bridge the gap, the community relies heavily on Gutendex, a free,
public REST API built specifically for querying Project Gutenberg's catalog.

Gutendex processes Gutenberg's raw feeds and serves them as a clean JSON API. It requires no authentication or API keys.

### 1. Gutendex API

- **Base Endpoint:** [https://gutendex.com/books](https://gutendex.com/books)
- **Search by Author/Title:** `GET https://gutendex.com/books?search=dickens%20great`
- **Filter by Topic or Language:** `GET https://gutendex.com/books?topic=fiction&languages=en`
- **Lookup by Gutenberg ID:** `GET https://gutendex.com/books/1342`

#### JSON Response Structure
Every book entry returns metadata alongside a formats object containing direct download URLs for EPUB, HTML, Mobipocket, and plain text formats:

```json
{
  "id": 1342,
  "title": "Pride and Prejudice",
  "authors": [{"name": "Austen, Jane", "birth_year": 1775, "death_year": 1817}],
  "languages": ["en"],
  "download_count": 52310,
  "formats": {
    "text/html": "https://www.gutenberg.org/files/1342/1342-h/1342-h.htm",
    "application/epub+zip": "https://www.gutenberg.org/ebooks/1342.epub3.images",
    "text/plain; charset=us-ascii": "https://www.gutenberg.org/ebooks/1342.txt.utf-8"
  }
}
```

### 2. Direct File Downloads (Native Gutenberg Paths)

If you already know the Gutenberg Book ID, you do not need an API to construct the download link. Project Gutenberg uses standard URL paths:

- **Plain Text (.txt):** `https://www.gutenberg.org/ebooks/{id}.txt.utf-8`
- **EPUB3:** `https://www.gutenberg.org/ebooks/{id}.epub3.images`
- **HTML:** `https://www.gutenberg.org/files/{id}/{id}-h/{id}-h.htm`

*(Example: Book #84 is Frankenstein, so `https://www.gutenberg.org/ebooks/84.txt.utf-8` fetches the UTF-8 text directly.)*

## Key App Features

- **Search & Browse:** Query by title, author, topic, or language using the Gutendex REST API.
- **Direct Book Downloads:** Download plain text or EPUB formats directly to local storage.
- **Text Cleaning & Formatting:** Automatically strip Project Gutenberg license headers and footers to present clean reading material.
- **Customizable Reader:** Clean typography, font size adjustments, theme switching (light, dark, sepia), and reading progress persistence.
- **Offline Library:** Manage downloaded books, bookmarks, and reading history locally on device.
