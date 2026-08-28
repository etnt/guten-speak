# Bookmarks — Implementation Plan

A focused build plan for user-created bookmarks in Guten-Speak. It refines the
Phase G sketch in [implementation-plan.md](implementation-plan.md) (§5.3) into a
concrete, testable slice that mirrors the existing `reading_progress` stack.

> **Status: implemented and verified on device (Pixel 10 Pro).** The v1 scope
> below shipped; §9 records what landed. Remaining items are the noted
> follow-ups (scroll-track markers, narration-side affordance).

Grounded in the current code as of this plan:
- Position model, DB, and migrations: [app/lib/core/storage/app_database.dart](../app/lib/core/storage/app_database.dart)
- Progress data source: [library_local_data_source.dart](../app/lib/features/library/data/datasources/library_local_data_source.dart)
- Repository contract + impl: [library_repository.dart](../app/lib/features/library/domain/repositories/library_repository.dart), [library_repository_impl.dart](../app/lib/features/library/data/repositories/library_repository_impl.dart)
- Providers: [library_providers.dart](../app/lib/features/library/presentation/providers/library_providers.dart), [reader_providers.dart](../app/lib/features/reader/presentation/providers/reader_providers.dart)
- Reader UI: [reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart)

## 1. Goal & scope

Let a reader **mark the current position in a book, see all their marks, jump
back to one, and remove it** — reusing the existing paragraph-index position
model and jump mechanism.

In scope (v1):
- Add / remove a bookmark at the current top paragraph.
- A "Bookmarks" list (bottom sheet, sibling to the TOC sheet) that jumps on tap.
- A visual indicator on the reader's bottom-bar control for the current position
  when it is already bookmarked (toggle affordance).
- An in-text indicator (right-margin bookmark ribbon) on bookmarked paragraphs.
- Persistence in SQLite, cascade-deleted with the book, many bookmarks per book.
- Optional short free-text note per bookmark.

Out of scope (v1, note as follow-ups):
- Off-screen bookmark awareness via scroll-track tick marks.
- Narration/player bookmark affordance (the player has no TOC-style UI yet).
- Cross-device sync, export/import, deep-link to a specific bookmark.

## 2. Position model (reuse, do not reinvent)

The canonical position is the **0-based `paragraphIndex`** into the book's
paragraph list — the same key used by `reading_progress`, the TOC
(`TocEntry.paragraphIndex`), and narration units (`NarrationUnit.paragraphIndex`).

The reader already exposes exactly what bookmarks need:
- Current top paragraph: `_firstVisible` / `_computeFirstVisibleIndex()`
  ([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L104-L129)).
- Jump-to-position: `_jumpToParagraph(index)`
  ([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L131-L141)),
  the same call the TOC sheet uses.

A bookmark is therefore just a persisted, user-labeled `paragraphIndex`.

## 3. Data model

New freezed entity, matching the `ReadingProgress` style
([reading_progress.dart](../app/lib/features/library/domain/entities/reading_progress.dart)).

`app/lib/features/library/domain/entities/bookmark.dart`

```dart
@freezed
abstract class Bookmark with _$Bookmark {
  const factory Bookmark({
    required int bookId,
    required int paragraphIndex,
    required DateTime createdAt,
    int? id,      // null until persisted (autoincrement row id)
    String? note, // optional user label
  }) = _Bookmark;
}
```

Notes:
- `id` is nullable so the UI can build an unsaved bookmark before insert; the
  data source returns a copy with the assigned row id.
- Keep it a plain data holder (no controller logic), like `ReadingProgress`.
- Requires the freezed codegen run (see §8).

## 4. Database

Follow the exact table-addition pattern already used for `synth_cache` and
`narration_progress` in [app_database.dart](../app/lib/core/storage/app_database.dart).

### 4.1 Constants (in the `Db` class)

```dart
// bookmarks (user-saved positions; many per book) ---------------------
static const String bookmarks = 'bookmarks';
static const String bookmarkId = 'id';
static const String bookmarkBookId = 'book_id';
static const String bookmarkParagraphIndex = 'paragraph_index';
static const String bookmarkNote = 'note';
static const String bookmarkCreatedAt = 'created_at';
```

### 4.2 Schema

```sql
CREATE TABLE IF NOT EXISTS bookmarks (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id INTEGER NOT NULL
    REFERENCES books (id) ON DELETE CASCADE,
  paragraph_index INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
)
```

Add an index for the common per-book, ordered read:

```sql
CREATE INDEX IF NOT EXISTS idx_bookmarks_book
  ON bookmarks (book_id, paragraph_index)
```

### 4.3 Migration

- Bump `Db.version` from `4` → `5`
  ([app_database.dart](../app/lib/core/storage/app_database.dart#L16)).
- Add `_createBookmarksTable(db)` and call it from `_onCreate`
  ([app_database.dart](../app/lib/core/storage/app_database.dart#L86-L111)).
- Add the upgrade branch in `_onUpgrade`
  ([app_database.dart](../app/lib/core/storage/app_database.dart#L113-L124)):

```dart
if (oldVersion < 5) {
  await _createBookmarksTable(db);
}
```

Cascade delete is automatic via the FK (foreign keys are already enabled with
`PRAGMA foreign_keys = ON` in `onConfigure`), so deleting a book removes its
bookmarks — consistent with `reading_progress` and `synth_cache`. No change is
needed in `LibraryRepositoryImpl.deleteBook`.

## 5. Data & domain layers

### 5.1 Data source

Extend [LibraryLocalDataSource](../app/lib/features/library/data/datasources/library_local_data_source.dart)
(mirroring its `getProgress` / `saveProgress` methods and the
`NarrationProgressDataSource` CRUD shape):

```dart
Future<List<Bookmark>> getBookmarks(int bookId);      // ORDER BY paragraph_index ASC
Future<Bookmark> addBookmark(Bookmark bookmark);       // insert; return copy with row id
Future<void> deleteBookmark(int id);                   // by row id
Future<Bookmark?> bookmarkAt(int bookId, int paragraphIndex); // toggle/exists check
```

- `addBookmark` uses `_db.insert(Db.bookmarks, {...})` (no replace conflict; row
  id is autoincrement) and returns `bookmark.copyWith(id: insertedId)`.
- Reconstruct rows via a private `_bookmarkFromRow` helper, like `_bookFromRow`.

### 5.2 Repository

Add to the [LibraryRepository](../app/lib/features/library/domain/repositories/library_repository.dart)
interface and implement in [LibraryRepositoryImpl](../app/lib/features/library/data/repositories/library_repository_impl.dart)
using the existing `_guard(...)` wrapper (returns `Result<T>`, maps thrown
`DatabaseException`s to typed `Failure`s):

```dart
Future<Result<List<Bookmark>>> getBookmarks(int bookId);
Future<Result<Bookmark>> addBookmark(int bookId, int paragraphIndex, {String? note});
Future<Result<void>> deleteBookmark(int id);
```

`addBookmark` builds the `Bookmark` (with `createdAt: DateTime.now()`) and
delegates to the data source, exactly like `saveProgress` builds a
`ReadingProgress`.

### 5.3 Providers

In [library_providers.dart](../app/lib/features/library/presentation/providers/library_providers.dart),
add a family read provider and a controller, matching `readingProgressProvider`
and the `BookImportController` / `ReaderController` styles:

```dart
/// All bookmarks for [bookId], earliest position first.
@riverpod
Future<List<Bookmark>> bookmarks(Ref ref, int bookId) async {
  final repo = await ref.watch(libraryRepositoryProvider.future);
  final result = await repo.getBookmarks(bookId);
  return result.when(
    onSuccess: (list) => list,
    onFailure: (failure) => throw failure,
  );
}

/// Add/remove bookmarks; invalidates the [bookmarksProvider] for the book.
@riverpod
class BookmarkController extends _$BookmarkController {
  @override
  void build() {}

  Future<void> add(int bookId, int paragraphIndex, {String? note}) async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final result = await repo.addBookmark(bookId, paragraphIndex, note: note);
    result.when(
      onSuccess: (_) => ref.invalidate(bookmarksProvider(bookId)),
      onFailure: (failure) => throw failure,
    );
  }

  Future<void> remove(int bookId, int id) async {
    final repo = await ref.read(libraryRepositoryProvider.future);
    final result = await repo.deleteBookmark(id);
    result.when(
      onSuccess: (_) => ref.invalidate(bookmarksProvider(bookId)),
      onFailure: (failure) => throw failure,
    );
  }
}
```

(Whether the bookmark providers live in `library_providers.dart` or a new
`reader`-side file is a judgment call; keeping them beside `readingProgress`
in the library feature matches where the data lives.)

## 6. Reader UI

Three small additions in [reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart),
all reusing existing patterns.

### 6.1 Bookmark control (bottom bar)

Use the reserved 48px slot already in the bottom bar labeled
"Reserved for the Phase G bookmark toggle"
([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L749-L751)) —
replace the placeholder `SizedBox.square` with the bookmark control, sitting
alongside the voice picker and narrator toggle in `_buildBottomBar`
([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L626-L753)).

The bottom bar has room for both actions, so put them here (no top-bar change):
- An **add/remove toggle** `IconButton` (`Icons.bookmark` /
  `Icons.bookmark_border`) that reflects and flips the current position's
  bookmarked state.
- A **"Bookmarks" list** `IconButton` (`Icons.bookmarks_outlined`) that opens
  the bookmarks sheet.

Update §5.3 of [implementation-plan.md](implementation-plan.md) to say the
bookmark controls live in the bottom bar (it currently says "toggle in the top
bar"), and drop the stale placeholder comment.

### 6.2 Add / remove toggle

A toggle that reflects whether the current top paragraph is already bookmarked:
- Compute "current is bookmarked" by checking `_firstVisible` against the
  watched `bookmarksProvider(bookId)` list.
- Tapping when absent → `BookmarkController.add(bookId, _firstVisible)`
  (optionally prompt for a note first; v1 can add immediately and allow renaming
  from the list).
- Tapping when present → `BookmarkController.remove(bookId, existing.id!)`.
- Show a brief `SnackBar` confirmation, matching the import/delete flows in the
  library screen.

### 6.3 Bookmarks sheet

Mirror `_showTocSheet`
([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L744-L790)):
`showModalBottomSheet` with a `ListView` of the book's bookmarks. Each row:
- Title: `note` if set, else a derived label — prefer the nearest preceding TOC
  entry title (search `content.toc` for the greatest `paragraphIndex <=
  bookmark.paragraphIndex`), falling back to `"Paragraph N"`.
- On tap: pop the sheet and call `_jumpToParagraph(bookmark.paragraphIndex)`.
- Trailing delete affordance (icon or swipe-to-dismiss) → controller `remove`.
- Empty state: a short "No bookmarks yet" message.

Order the list by `paragraphIndex` (reading order); the DB query already does.

### 6.4 In-text indicator — right-margin ribbon

Show bookmarked paragraphs directly in the reading view with a small
**bookmark ribbon on the right edge** of the paragraph. This is the universal
bookmark metaphor and deliberately avoids the slots narration already owns:
the **left** 4px band (`bandColor`), the leading speaker icon, and the narrated
background tint
([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L886-L915)).

Wiring:
- In `_buildReader`, derive a `Set<int>` of bookmarked indices from the watched
  `bookmarksProvider(widget.bookId)` (like `headingIndices` is built from the
  TOC — [reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L479)),
  and pass `isBookmarked: bookmarkedIndices.contains(index)` into
  `_ReaderParagraph`.
- Add a `final bool isBookmarked;` field to `_ReaderParagraph`
  ([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L844-L870)).
- Render the ribbon on the right of the paragraph. Simplest: a trailing
  `Icons.bookmark` (size ~16, tinted from `widget.style.color`) after the
  `Expanded` text in the existing `Row`
  ([reader_screen.dart](../app/lib/features/reader/presentation/screens/reader_screen.dart#L902-L921)),
  shown only when `isBookmarked`. For a true edge-pinned ribbon that doesn't
  reflow with short paragraphs, wrap the paragraph body in a `Stack` and
  `Positioned(top: 0, right: 0, ...)` the ribbon instead.
- Keep it purely decorative in v1 (no tap target on the ribbon); add/remove
  stays on the bottom-bar toggle (§6.1–6.2) and delete stays in the sheet.

Rebuild cost is negligible: the set is rebuilt only when `bookmarksProvider`
changes, and `ScrollablePositionedList` already rebuilds only visible rows.

Follow-up (not v1): off-screen awareness via scroll-track tick marks, and an
optional right-aligned note chip when a bookmark has a note.

## 7. Testing

Mirror the existing data-source/repository tests under
[app/test/features/library](../app/test/features/library) (mocktail + a mocked
`Database`, e.g. `library_local_data_source_test.dart`) and narration value
tests.

- `bookmarks_data_source_test.dart`: insert returns row id; list is ordered by
  paragraph index; `bookmarkAt` finds/does not find; delete issues the right
  `where`.
- Repository test: `Result` success/failure wrapping via `_guard`; `add` stamps
  `createdAt` and forwards fields.
- Provider test: `bookmarks` unwraps `Result`; `BookmarkController.add/remove`
  invalidate `bookmarksProvider(bookId)`.
- Migration smoke test: open a v4 DB, upgrade to v5, assert the `bookmarks`
  table exists and a book delete cascades its bookmarks (an on-disk temp DB test
  like `book_content_loader_test.dart` uses `Directory.systemTemp`).
- Widget test (optional): tapping the toggle adds a bookmark; the sheet lists it
  and jumps.

## 8. Codegen & migration checklist

- Add `bookmark.dart` (freezed) and the two new `@riverpod` providers, then run:
  `dart run build_runner build --delete-conflicting-outputs`
  (generates `bookmark.freezed.dart` and updates `*.g.dart`).
- Bump `Db.version` to 5 and wire `_createBookmarksTable` into both `_onCreate`
  and `_onUpgrade`.
- Existing installs upgrade in place (no data loss); fresh installs create the
  table in `_onCreate`.

## 9. Build order (small, shippable steps)

1. [x] Entity + DB constants/table + migration (v5) + codegen.
2. [x] Data source CRUD + unit tests.
3. [x] Repository methods (`_guard`) + provider.
4. [x] Reader: bookmarks sheet (list + jump) plus the bottom-bar list button.
5. [x] Reader: add/remove toggle in the reserved bottom-bar slot with
   bookmarked-state reflection; placeholder removed and implementation-plan §5.3
   updated.
6. [x] Reader: in-text right-margin ribbon on bookmarked paragraphs.
7. [x] Label derivation from TOC + empty state.
8. [ ] (Follow-up) scroll-track markers; (follow-up) narration-side affordance.

> **Delivered notes / deviations:**
> - The bookmarked-state toggle stays live while scrolling via a
>   `ValueNotifier<int>` (`_firstVisibleParagraph`) wrapped in a
>   `ValueListenableBuilder`, avoiding a full reader rebuild per scroll step.
> - Add is immediate (no note prompt in v1); notes are supported by the model and
>   surfaced as the list label when present, but there is no edit UI yet.
> - Tests cover the data-source CRUD SQL. The on-disk migration smoke test was
>   skipped: the app has no `sqflite_common_ffi` dev dependency and no existing
>   FFI-based DB tests, so adding one was out of scope.

## 10. Definition of done

- [x] A reader can add a bookmark at the current position, see it in a list,
  jump to it, and delete it; the current-position control reflects bookmarked
  state.
- [x] Bookmarks persist across restarts and are removed when the book is deleted
  (FK cascade).
- [x] Data source, repository, and providers land; data-source SQL is covered by
  tests and `flutter analyze` is clean. (Migration smoke test deferred — see §9.)
- [x] The Phase G bookmark placeholder in the reader and the §5.3 sketch in
  [implementation-plan.md](implementation-plan.md) are reconciled with the
  shipped UI.
