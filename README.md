# Guten-Speak - audio app for Project Gutenberg

With the guten-speak mobile Flutter app you can search for books stored at Project Gutenberg.
You can search for Author or parts of Titles, get a list of matching books.
You can the ndownload the book and have it being read up for you.
With guten-speak you can easily clone your favorite voices and use them
as narrators of the book being read for you.

## Access to Project Gutenberg 

Project Gutenberg itself does not provide a modern REST API, but it publishes raw
RDF/XML catalog dumps and predictable URL structures for direct downloads.
To bridge the gap, the community relies heavily on Gutendex, a free,
public REST API built specifically for querying Project Gutenberg's catalog.

Gutendex processes Gutenberg's raw feeds and serves them as a clean JSON API. It requires no authentication or API keys.

Base Endpoint: [https://gutendex.com/books](https://gutendex.com/books)

Search by Author/Title:
GET [https://gutendex.com/books?search=dickens%20great](https://gutendex.com/books?search=dickens%20great)

Filter by Topic or Language:
GET [https://gutendex.com/books?topic=fiction&languages=en](https://gutendex.com/books?topic=fiction&languages=en)

Lookup by Gutenberg ID:
GET [https://gutendex.com/books/1342](https://gutendex.com/books/1342)

JSON Response Structure:
Every book entry returns metadata alongside a formats object containing direct download URLs for EPUB, HTML, Mobipocket, and plain text formats.

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

2. Direct File Downloads (Native Gutenberg Paths)
If you already know the Gutenberg Book ID, you do not need an API to construct the download link. Project Gutenberg uses standard URL paths:

Plain Text (.txt): [https://www.gutenberg.org/ebooks/](https://www.gutenberg.org/ebooks/){id}.txt.utf-8

EPUB3: [https://www.gutenberg.org/ebooks/](https://www.gutenberg.org/ebooks/){id}.epub3.images

HTML: [https://www.gutenberg.org/files/](https://www.gutenberg.org/files/){id}/{id}-h/{id}-h.htm

(Example: Book #84 is Frankenstein, so [https://www.gutenberg.org/ebooks/84.txt.utf-8](https://www.gutenberg.org/ebooks/84.txt.utf-8) fetches the UTF-8 text directly.)

## Text to Speech

The pocket-tts-raven makes it possible to clone voices and 
to produce speech from text:

https://github.com/pkalogiros/pocket-tts-raven

By combining this functionality with the access to Porject Gutenberg
we could potentially create a very nice mobile app that makes it possible
to listen to books from Project Gutenberg, narrated with your favorite voice.

Since the app is free, and the cloned voices only is used by yourself, there
ought to be no problems with copyright infringement.
