# Project Gutenberg OPDS 2 feed — findings & future-implementation notes

> Status: **research / not scheduled.** Captured after a Project Gutenberg
> maintainer pointed us at their new OPDS 2 feed (officially launching soon):
> `https://opds-test.pglaf.org/opds/`. This documents what the feed offers and
> how it could map onto Guten-Speak's existing catalog architecture, so a future
> implementation can start from facts rather than re-probing.

## TL;DR

- The feed is a **first-party** (PGLAF = Project Gutenberg Literary Archive
  Foundation), structured **OPDS 2.0** JSON API — a modern replacement for the
  data we currently scrape two different ways:
  - the third-party, flaky **Gutendex** REST API (powers Discover + online search), and
  - the ~21 MB **`pg_catalog.csv`** bulk dump (powers offline search/detail).
- It could replace **Gutendex** outright. It does **not** by itself replace the
  offline CSV index — OPDS is an online API (one network request per query),
  whereas the CSV gives fully offline search of ~80k books. Keep that trade-off
  in mind (see "Offline story" below).
- It is a **test** endpoint (`opds-test`), not the launch URL. Treat as
  forward-looking; do not hard-code `opds-test.pglaf.org` as if permanent.

## What the feed actually returns

Root `GET https://opds-test.pglaf.org/opds/` → `application/opds+json`:

```jsonc
{
  "metadata": { "title": "Project Gutenberg" },
  "links": [
    { "rel": "self",   "href": ".../opds/", "type": "application/opds+json" },
    { "rel": "start",  "href": ".../opds/", "type": "application/opds+json" },
    { "rel": "search", "href": ".../opds/search{?query,title,author}",
      "type": "application/opds+json", "templated": true }
  ],
  "groups": [
    { "metadata": { "title": "Navigation", "numberOfItems": 2 },
      "navigation": [
        { "title": "Browse Bookshelves", "href": ".../opds/bookshelves", "rel": "subsection" },
        { "title": "Browse Subjects",    "href": ".../opds/loccs",       "rel": "subsection" }
      ] },
    { "metadata": { "title": "Recently Added", "numberOfItems": 78380 },
      "links": [ { "rel": "self", "href": ".../opds/search?sort=release_date&sort_order=desc" } ],
      "publications": [ /* preview list */ ] },
    { "metadata": { "title": "Most Popular", "numberOfItems": 78380 },
      "links": [ { "rel": "self", "href": ".../opds/search?sort=downloads&sort_order=desc" } ],
      "publications": [ /* preview list */ ] },
    // then one group per bookshelf category, each linking to
    //   .../opds/bookshelf_groups?category=LITERATURE  (etc.)
    // categories seen: LITERATURE, SCIENCE_TECHNOLOGY, HISTORY,
    //   SOCIAL_SCIENCES_SOCIETY, ARTS_CULTURE, RELIGION_PHILOSOPHY,
    //   LIFESTYLE_HOBBIES, HEALTH_MEDICINE, EDUCATION_REFERENCE
  ]
}
```

### Endpoints discovered

| Endpoint | Purpose |
| --- | --- |
| `/opds/` | Root navigation feed: search link + "Recently Added" / "Most Popular" / per-category preview groups |
| `/opds/search{?query,title,author}` | Search (templated). Also accepts `sort` (`release_date`, `downloads`) + `sort_order` (`asc`/`desc`). This is the same endpoint the Recently Added / Most Popular groups point at. |
| `/opds/publications?id=<id>` | Single publication detail (`application/opds-publication+json`) |
| `/opds/bookshelves` | Browse bookshelves |
| `/opds/loccs` | Browse subjects (Library of Congress Classification) |
| `/opds/bookshelf_groups?category=<CATEGORY>` | Books within a top-level category |

> Not yet verified: pagination link shape (`next`/`previous` + `itemsPerPage`)
> on `/opds/search`, and whether `/opds/publications?id=` exposes **multiple**
> acquisition formats (plain text, non-image epub, kindle). The root feed only
> shows the single EPUB3-images acquisition — see "Gaps to verify".

### Publication shape

Each entry in a group's `publications[]`:

```jsonc
{
  "metadata": {
    "@type": "http://schema.org/Book",
    "identifier": "https://www.gutenberg.org/ebooks/1342",  // numeric id at the end
    "title": "Pride and Prejudice",
    "language": "en",
    "author": { "name": "Austen, Jane", "sortAs": "Austen, Jane" }
    // author/translator/editor/illustrator/contributor may each be a single
    // object OR an array of objects; each has name + sortAs
  },
  "links": [
    { "rel": "self", "href": ".../opds/publications?id=1342",
      "type": "application/opds-publication+json" },
    { "rel": "http://opds-spec.org/acquisition/open-access",
      "href": "https://www.gutenberg.org/cache/epub/1342/pg1342-images-3.epub",
      "type": "application/epub+zip", "length": 24835578,
      "title": "EPUB3 (E-readers incl. Send-to-Kindle)" }
  ],
  "images": [
    { "rel": "http://opds-spec.org/image",
      "href": ".../cache/epub/1342/pg1342.cover.medium.jpg",
      "type": "image/jpeg", "width": 200, "height": 288 },
    { "rel": "http://opds-spec.org/image/thumbnail",
      "href": ".../cache/epub/1342/pg1342.cover.small.jpg",
      "type": "image/jpeg", "width": 66, "height": 95 }
  ]
}
```

Notes:
- `identifier` is a full `…/ebooks/<id>` URL — parse the trailing integer to get
  our existing `int` book id.
- Cover URLs match our current `AppConstants.coverImageUrl` pattern exactly
  (`.cover.medium.jpg` / `.cover.small.jpg`), so covers are a drop-in.
- Acquisition `length` (bytes) is included — useful to show download size up
  front, which we don't do today.
- The only acquisition in the root feed is **EPUB3-with-images**
  (`pg<id>-images-3.epub`). These can be **large** (Pride & Prejudice 24 MB,
  Count of Monte Cristo ~84 MB) because they embed images. Our current default
  favours the smaller `epub3.images` / plain-text; confirm whether the
  publication-detail endpoint lists lighter formats before switching download
  derivation to the feed's links.

## How it maps onto our current architecture

Our catalog stack is already cleanly layered (see
[implementation-plan.md](implementation-plan.md) and the code map below), which
makes an OPDS source a mostly-additive change.

Current sources (all under `app/lib/features/catalog/`):
- **Gutendex** online: [gutendex_remote_data_source.dart](../app/lib/features/catalog/data/datasources/gutendex_remote_data_source.dart)
  → `CatalogRepository` → providers `popularBooks`, `booksByTopic`, `bookDetail`.
- **Offline CSV index**: [catalog_import_service.dart](../app/lib/features/catalog/data/services/catalog_import_service.dart)
  downloads `pg_catalog.csv`, [catalog_csv_parser.dart](../app/lib/features/catalog/data/datasources/catalog_csv_parser.dart)
  parses it in an isolate, [local_catalog_data_source.dart](../app/lib/features/catalog/data/datasources/local_catalog_data_source.dart)
  stores it in the `catalog` SQLite table and serves `search()` / `bookById()`.
- Canonical domain entity is **`BookSummary`**
  ([book_summary.dart](../app/lib/features/catalog/data/models/book_summary.dart)):
  `id:int`, `title`, `authors:List<Author>`, `subjects`, `languages`,
  `formats:Map<String,String>` (MIME→URL), `downloadCount`, plus URL getters.
  Download + reader + library all consume `BookSummary` / `LibraryBook`.
- Networking: **Dio** with a shared `UserAgentInterceptor`
  ([dio_client.dart](../app/lib/core/network/dio_client.dart),
  [user_agent_interceptor.dart](../app/lib/core/network/user_agent_interceptor.dart)),
  UA `GutenSpeak/1.0 (https://github.com/etnt/guten-speak)`.

### Proposed shape of an OPDS integration

1. **New data source** `OpdsRemoteDataSource` (sibling of the Gutendex one),
   injected with a Dio instance from a provider. Methods roughly:
   - `Future<OpdsFeed> fetchRoot()` — parse root groups → home sections.
   - `Future<OpdsPage> search({String? query, String? author, String? title, String? sort, String? sortOrder, String? pageHref})` — hits `/opds/search`, follows `next` links for pagination.
   - `Future<BookSummary> fetchPublication(int id)` — `/opds/publications?id=`.
   - `Future<List<OpdsNavItem>> browse(String href)` — bookshelves / subjects / category groups.
2. **Mapper** OPDS publication → existing `BookSummary`:
   - id = trailing int of `metadata.identifier`.
   - authors = normalize the single-or-array `author`/`editor`/… objects into `List<Author>` (we already have `Author`).
   - `formats` = build from acquisition `links` (rel `…/acquisition/open-access`) keyed by `type` (e.g. `application/epub+zip`), so `epubUrl`/`plainTextUrl` getters keep working — **or** keep synthesizing URLs from id via `AppConstants` if the feed only exposes the heavy images-epub.
   - cover = `images[]` (already our format).
3. **Repository**: either add OPDS methods to `CatalogRepository` or introduce a
   `BookCatalogSource` interface with `GutendexSource` / `OpdsSource` impls and a
   settings/flag to choose. The UI talks to providers only, so swapping the impl
   behind `popularBooks` / `booksByTopic` / `bookDetail` needs **no UI change**.
4. **Config**: add `opdsBaseUrl` to `AppConstants` (default to the launch URL
   once announced; keep it overridable). Reuse the shared `UserAgentInterceptor`.

### Offline story (important)

The CSV index exists so search/detail work **fully offline** and don't depend on
a flaky third party. OPDS is online-only per request. Options if we adopt OPDS:
- **Discover / online search** → OPDS (first-party, structured, has sort +
  categories + covers + sizes). Straight win over Gutendex.
- **Offline search** → either keep the `pg_catalog.csv` importer as-is, or later
  build the local index by paging the OPDS `search` feed and caching results.
  Simplest near-term: OPDS replaces Gutendex, CSV importer stays.

## Advantages over the status quo

- **First-party & stable** — removes the Gutendex third-party dependency (the
  code even has bespoke retry logic for Gutendex flakiness).
- **Structured navigation** for free: Recently Added, Most Popular, per-category
  bookshelves, subject browse — much of the Discover screen becomes feed-driven.
- **Richer metadata** in one call: cover (matching our URLs), acquisition size,
  sort options (`downloads`, `release_date`).
- **Standards-based** — OPDS 2.0 is a documented spec; parsing is stable and
  reusable, versus screen-shaping Gutendex JSON.

## Gaps / things to verify before implementing

1. **Pagination**: confirm `/opds/search` returns `next`/`previous` links and
   `itemsPerPage`/`numberOfItems` so we can page (our UI already pages Gutendex).
2. **Multiple formats**: check whether `/opds/publications?id=<id>` lists
   plain-text / non-image epub / kindle acquisitions, or only the heavy
   images-epub. Impacts whether we read download URLs from the feed vs. keep
   synthesizing them from id.
3. **Language / topic filters**: does `search` accept `languages` / subject
   filters (we use `languages=en` + `topic=` on Gutendex today)? `/opds/loccs`
   suggests subject browse exists; confirm query-param filtering on `search`.
4. **Launch URL & stability**: get the production host (not `opds-test`) and any
   rate-limit / caching guidance before shipping.
5. **Payload size**: the root feed is large (previews for every category). Fetch
   once, cache briefly; don't re-pull on every Discover open.

## References

- Feed (test): https://opds-test.pglaf.org/opds/
- OPDS 2.0 spec: https://drafts.opds.io/opds-2.0
- Existing catalog design: [implementation-plan.md](implementation-plan.md)
- Constants / URL derivation: [app_constants.dart](../app/lib/core/constants/app_constants.dart)
