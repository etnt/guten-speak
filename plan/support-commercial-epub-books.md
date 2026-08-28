# Supporting commercial EPUB books protected with Readium LCP

Reviewed 2026-08-28 against Readium Kotlin 3.3.0, Readium Swift 3.11.0,
the current Guten-Speak import pipeline, and the supplied Bokus publication.

## Decision

**Readium LCP support is technically feasible on Android and iOS, but the
original design is not feasible as written.** It assumes APIs which do not
exist and, more importantly, assumes that Readium outputs a permanently
decrypted EPUB. It does not. The downloaded publication remains encrypted;
Readium decrypts protected resources while an authorized `Publication` is open.

Production support also has a non-technical gate. The open-source
`readium-lcp`/`ReadiumLCP` modules are not sufficient for production licenses.
EDRLab supplies a confidential, app-specific native component:

- Android: `liblcp`
- iOS: `R2LCPClient.framework`

An organization must contact EDRLab, obtain the test component, sign the LCP
Terms of Use, pay the applicable annual membership/certification fees, obtain
the production component, and pass certification. The current public pricing
starts at EUR 300/year before VAT for one mobile app in the lowest revenue
class, in addition to EDRLab membership. Pricing and eligibility must be
confirmed directly with EDRLab.

**Recommended decision:** proceed only after EDRLab confirms that Guten-Speak's
custom Flutter reader, plaintext delivery to Dart, neural narration, and audio
cache design can satisfy its Robustness Rules. Start with an Android proof of
concept and EDRLab test publications. Do not build a decryption/export feature.

## Corrections to the original sketch

| Original assumption | Verified behavior |
| --- | --- |
| Import requires the passphrase before download. | `acquirePublication` downloads and injects the LCPL without a passphrase. The passphrase is needed when protected content is opened. |
| `loadLicense`, `license.unlock`, and `fetchPublication` form the current API. | These calls are not the current Readium APIs. Use `LcpService.acquirePublication(...)` / `LCPService.acquirePublication(...)`, then a `PublicationOpener` configured with LCP `ContentProtection`. |
| Native code returns a fully decrypted EPUB path. | Acquisition returns a **protected** package. Decryption is transparent and resource-by-resource while the publication is open. |
| The returned EPUB can go through the existing Dart parser. | The current parser reads encrypted XHTML as malformed UTF-8. It cannot consume an LCP package. |
| Adding the public Readium dependency is enough. | Production-profile licenses require EDRLab's private binary and certification. Without it, Android's `LcpService` is unavailable and iOS has no production `LCPClient`. |
| A passphrase may be stored with the book record. | Never store clear passphrases in SQLite, preferences, logs, or `content.json`. Let Readium store passphrase hashes in its Android database or iOS Keychain repository. |
| Implement the bridge directly in both app delegates. | Prefer a dedicated Flutter plugin/Pigeon host API. Guten-Speak's Android activity derives from `AudioServiceActivity`, and iOS uses Flutter's implicit-engine/scene lifecycle; a plugin has cleaner ownership and teardown. |

## Supplied test data

The local files are useful evidence but must remain private and must not be
committed or uploaded to CI. Exact entries were added to the repository
`.gitignore`.

Inspection without decrypting content found:

- `Science-Fiction-Anthology.lcpl` is an LCPL for LCP production profile 1.0.
- `science-fiction-anthology.epub` is a fulfilled LCP EPUB containing both
  `META-INF/license.lcpl` and `META-INF/encryption.xml`.
- Its embedded license exactly matches the standalone LCPL.
- 110 resources are encrypted: 104 XHTML text resources and 4 images (the
  remainder are non-content resources).
- The license has a start right but no end date, so it represents a purchase,
  not an expiring loan.
- A test-grade `liblcp` normally supports EDRLab's test/basic profile, not this
  production-profile Bokus license. Use EDRLab's test server for the initial
  proof of concept; the purchased sample requires the production component.

The current `EpubParser` probe returned the correct unencrypted package
metadata but accepted 104 paragraphs of ciphertext as garbled text. Therefore
the existing message saying DRM-protected books cannot be imported is not a
reliable guard. Independently of LCP implementation, add explicit detection of
the LCP encryption scheme in `META-INF/encryption.xml` and fail with a typed
"LCP support unavailable" error when the native feature is absent.

## Current Guten-Speak mismatch

The existing EPUB path is deliberately simple:

1. Flutter picks an `.epub`.
2. `LibraryRepositoryImpl.importEpub` copies it to `book.epub`.
3. The pure-Dart `EpubParser` extracts the whole book.
4. Every plaintext paragraph and the TOC are persisted in `content.json`.
5. Narration converts the whole paragraph list to units and persists generated
   WAV files in the synthesis cache.

That model is appropriate for public-domain/unprotected books, but not for DRM:

- A protected EPUB cannot be parsed directly by Dart.
- Writing a complete plaintext `content.json` defeats protection at rest.
- Returning a decrypted EPUB would create a reusable circumvention artifact.
- Persisting enough WAV files to reconstruct a commercial audiobook may be
  incompatible with content rights or LCP robustness requirements.
- Expiration, revocation, early return, renewal, and copy/print rights must be
  enforced while content is accessed, not only at import time.

## Correct architecture

```text
Import
  Flutter file picker (.lcpl or fulfilled .epub)
      -> typed native LCP bridge
      -> acquirePublication(.lcpl), with progress and cancellation
      -> move the still-encrypted EPUB into the app library
      -> read unprotected metadata/cover
      -> store protection type and protected EPUB path

Open/read
  Flutter reader requests a book/range
      -> native PublicationOpener + LCP ContentProtection
      -> Readium asks for a passphrase only when no valid hash is stored
      -> Readium checks license/LSD status and decrypts requested resources
      -> bridge returns only the bounded text/TOC needed by the UI
      -> no decrypted EPUB and no full plaintext cache

Narrate
  Flutter requests a small look-ahead window of authorized text
      -> existing on-device TTS
      -> bounded/ephemeral audio cache, subject to EDRLab approval
```

The encrypted publication is the durable source of truth. A standalone LCPL
may be removed after successful fulfillment because Readium injects it into the
downloaded package. Metadata such as title and cover can be read without the
passphrase; content cannot.

### Native integration

Use the same high-level model on both platforms:

1. Create the Readium HTTP client and asset retriever.
2. Create the LCP service with the private LCP client.
3. Configure `PublicationOpener` with
   `lcpService.contentProtection(authentication)`.
4. For `.lcpl`, call `acquirePublication`, move `localFile`/`localURL` from its
   temporary location into the book directory, and retain the encrypted file.
5. Open that file with `allowUserInteraction: true` when content is needed.
6. Reject a restricted publication and map `LcpError`/`LCPError` to stable Dart
   error codes.
7. Close publications and resources deterministically.

Baseline dependencies as of this review:

- Android: Readium Kotlin 3.3.0 modules `readium-shared`,
  `readium-streamer`, and `readium-lcp`, plus EDRLab `liblcp`. The app's compile
  SDK 37 is sufficient; verify the effective minimum SDK is at least 23.
- iOS: Readium Swift 3.11.0 products `ReadiumShared`, `ReadiumStreamer`, and
  `ReadiumLCP`, plus EDRLab `R2LCPClient.framework`. This release requires
  iOS 15, so Guten-Speak's deployment target must rise from iOS 13 to iOS 15.
- `ReadiumNavigator` is optional only if the Flutter reader remains. It is the
  safer, more conventional choice if EDRLab does not approve exposing
  decrypted text through the Flutter boundary.

Do not copy code against the `develop` branches or guess dependency versions;
pin matching stable Readium and private-binary versions supplied by EDRLab.

### Flutter/native contract

Use Pigeon or an equivalently typed bridge rather than an unstructured
`MethodChannel`. Suggested operations:

- `capabilities()` — reports whether the private LCP component is present.
- `acquire(lcplPath, destinationDirectory)` — emits progress and returns the
  protected path, suggested filename, format, and public metadata.
- `inspect(protectedPath)` — reports LCP protection and public license metadata.
- `open(protectedPath, passphrase?)` — returns an opaque session ID, never a
  key or decrypted path.
- `tableOfContents(sessionId)` — returns navigation metadata.
- `readText(sessionId, locator/range)` — returns a bounded authorized text
  window; the exact granularity must be reviewed for robustness.
- `close(sessionId)` — releases native publication/resource handles.
- `returnLoan` and `renewLoan` — later, for loan licenses.

Acquisition progress should use a stream/event API, and cancellation should
cancel the underlying coroutine/task. Native errors should map to cases such
as missing component, invalid LCPL, download/hash failure, wrong passphrase,
expired/revoked/returned license, network required, and unsupported profile.

## Storage changes

The `books.path` column can continue to point at `book.epub`, but the model
needs an explicit format/protection discriminator. A future database migration
could add:

- `format`: `txt` or `epub`
- `protection`: `none` or `readium_lcp`
- optional non-secret license ID/provider/status metadata for display

Do **not** add a clear passphrase column or retain the original passphrase file.
Do **not** generate `content.json` for LCP books. If native parsing needs an
index, it must not contain recoverable full plaintext unless EDRLab explicitly
approves and specifies suitable protection.

For narration, begin with only a short look-ahead cache and delete audio after
playback/session close. Exclude generated audio from device backups. Persistent
offline narration should remain out of scope until the publisher/content
rights and EDRLab robustness review explicitly allow it.

## Delivery plan and gates

### Gate 0 — business, legal, and robustness (blocking)

1. Contact EDRLab as a prospective LCP reading-system provider.
2. Describe the Flutter/native architecture, open-source status, custom TTS,
   cloned voices, plaintext boundary, and audio caching.
3. Confirm eligibility, membership/certification cost, permitted platforms,
   private binary delivery, and the required robustness controls.
4. Obtain test-grade Android and iOS components and test credentials/files.

Do not start production integration until this gate has an acceptable answer.

### Phase 1 — safe detection

1. Detect LCP in `EpubParser` before any encrypted resource is decoded.
2. Let the picker accept `.lcpl` and `.epub`.
3. Show a precise "LCP support is not installed" result instead of importing
   ciphertext or claiming every parse error is DRM.
4. Add generated, non-commercial test fixtures for detection tests.

### Phase 2 — Android acquisition proof of concept

1. Add pinned Readium modules and test `liblcp` in a dedicated native plugin.
2. Fulfill an EDRLab test LCPL and persist the protected package.
3. Open it online and offline, authenticate once, read metadata/TOC, and fetch
   one bounded text resource without writing plaintext to disk.
4. Validate plugin lifecycle alongside `AudioServiceActivity`.

### Phase 3 — reader and narration adaptation

1. Introduce a `BookContentSource` abstraction so unprotected books can keep
   using cached full content while LCP books use native, lazy windows.
2. Refactor reader positioning from a process-wide paragraph array to stable
   Readium locators or a mapped native index.
3. Feed narration only the current unit plus a small look-ahead window.
4. Apply the approved audio-cache policy and enforce current license status.

### Phase 4 — iOS parity

1. Raise the deployment target to iOS 15.
2. Integrate the same host API with Readium Swift, Keychain repositories, and
   `R2LCPClient.framework`.
3. Register the LCPL imported type/document type in `Info.plist` if the app
   should appear in system "Open with" flows.

### Phase 5 — production and certification

1. Replace test components with the EDRLab production components.
2. Implement all required rights/status/loan interactions and user-facing
   error messages.
3. Run robustness, interoperability, accessibility, and security reviews.
4. Submit Android and iOS builds to EDRLab for certification.

## Required test matrix

- Valid LCPL acquisition, progress, cancellation, retry, and hash mismatch.
- Already fulfilled LCP EPUB import.
- Correct, incorrect, cancelled, reused, and changed passphrases.
- First open online; subsequent open offline.
- Active, expired, revoked, returned, renewed, and malformed licenses.
- Missing/wrong-version private component and unsupported profile.
- Process death and app restart without leaking plaintext or passphrases.
- Concurrent opens, deterministic close, book deletion, and cache cleanup.
- Copy/print limits and all UI paths that expose text.
- Narration start/seek/stop while a license becomes restricted.
- Android/iOS platform integration tests using EDRLab test licenses only.

The purchased Bokus files are suitable for a final manual production-profile
smoke test, but not as repository or CI fixtures.

## Sources

- [Readium Kotlin: Supporting Readium LCP](https://readium.org/kotlin-toolkit/latest/guides/lcp/)
- [Readium Kotlin Toolkit](https://github.com/readium/kotlin-toolkit)
- [Readium Swift Toolkit](https://github.com/readium/swift-toolkit)
- [EDRLab: Become an LCP reading system provider](https://www.edrlab.org/readium-lcp/how-to-lcp-reading-system-provider/)
- [EDRLab: LCP pricing](https://www.edrlab.org/readium-lcp/pricing/)
- [EDRLab: LCP FAQ](https://www.edrlab.org/readium-lcp/faq/)
- [Readium LCP specification](https://readium.org/lcp-specs/releases/lcp/latest)
- [Readium License Status Document specification](https://readium.org/lcp-specs/releases/lsd/latest)