<!-- Copyright (c) 2026 Anton Ustinoff. Use and redistribution are subject to LICENSE. -->

# Copybara 0.1.12 (14) release preparation

Prepared on 2026-11-03. This records local evidence, not App Review approval
or a published application release.

## Prepared

- Separate sandboxed Store configuration without Sparkle or GitHub updater.
- Local Store archive: `build/ReleaseCandidate/Copybara-AppStore-0.1.12.xcarchive`.
  The archive is ad-hoc signed for validation, not upload-ready.
- Xcode export with authorized provisioning updates succeeded:
  `build/ReleaseCandidate/AppStoreExport/Copybara.pkg`. The exported app uses
  Cloud Managed Apple Distribution and the Copybara Store profile for
  `YR2NM5B2YZ`; the package is signed by the owner's
  `3rd Party Mac Developer Installer` certificate. Both architectures are
  included. Signature verification passed; Sandbox is enabled, debug
  `get-task-allow` and Sparkle are absent, and migration resources are present.
  SHA-256: `07e8a3c8f370c5a082ee7f7f5e9c369d0429a5e62e6e3fad1ff0cc7429108f9c`.
- Xcode upload to App Store Connect succeeded for 0.1.12 (14). Server
  validation required the Utilities category and exclusion of the source
  `Resources/Info.plist` from copied resources; both packaging fixes are applied.
- Direct-download app and DMG notarization: `Accepted`, no issues. App
  submission: `b8bc53d9-b1d2-4282-8d2b-b856affc0b36`; DMG submission:
  `601ff1d2-bf98-4afd-9fda-bf1aa4ca8a1f`. Both tickets are stapled; Gatekeeper
  accepts the DMG and the app mounted from it. The image includes the
  `/Applications` link and the owner's verified Developer ID signature.
  DMG: `build/ReleaseCandidate/Copybara-0.1.12.dmg`.
  SHA-256: `67d27bea27355e4d7de4edb230a3d0a5093c0b96361c24f966f7eac2f88520be`.
  The first attempt timed out during S3 Transfer Acceleration upload; a new
  upload with `--no-s3-acceleration` completed and was accepted. The release
  script now uses that official endpoint too.
- EN/RU metadata, review notes and three native screenshots per locale. Upload
  PNGs are 2880 × 1800 RGB without alpha; web JPEGs show the same compositions.
- Existing unit suite: 314 reported cases, one skipped, zero failures. The
  skipped inactive-application WindowServer case needs a separate active app.
- Fresh manual Accessibility grant and real Paster insertion into an isolated
  native NSTextView receiver passed on macOS 26.7.2 with App Sandbox enforced.
- The same sandboxed Paster also passed insertion into a separate Chrome
  profile and local textarea (exact 36-character match; clipboard restored).
- Sandboxed Paster insertion into an isolated Electron 43.7.7 BrowserWindow
  passed with an exact 36-character match and clipboard restoration. The
  official Electron binary checksum was verified before execution.
- One-time OS sandbox migration passed with a real Core Data record, pin,
  comment, 2 MiB external payload, snippet and history-size preference.
- Protected GitHub `release` environment contains the owner's Developer ID
  PKCS12/password, Apple ID/app-specific password, certificate SHA1 and Team ID.
  Existing Sparkle and legacy signing secrets were preserved. Only names and
  public variables were read back; a real CI notarization is still required.
- All three existing UI tests passed on macOS 26.7.2 with the ABC input source,
  zero failures. The earlier failures reproduce with Russian input: ordinary
  letters from XCTest do not arrive, while Esc and Tab do. Diagnostic logging
  confirmed that the shortcut recorder removes its event monitor correctly.
  Neither production UI code nor test files needed changes. The input-source
  requirement is documented in `CONTRIBUTING.md`.
- Store listing name selected by the owner: `Copybara: Clipboard History`
  (`Copybara` alone is already taken). The Store version will be free.
- App Store Connect draft 6830139807 contains saved EN/RU descriptions,
  keywords, support/marketing links, three screenshots per locale and review
  information. Localized subtitles and Utilities category are saved; the age
  questionnaire calculated 4+. No App Review submission has been made.

## Remaining release gates

- App Store Connect record, final privacy/age/category answers and submission.
- Older supported macOS runtime validation and switching back from Store to
  direct distribution.

The migration moves data into the Store container once. It does not provide
shared live history or automatic reverse migration between channels.
