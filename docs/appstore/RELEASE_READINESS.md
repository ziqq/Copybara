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
  SHA-256: `b056836c89b65c606fa9b5a0b6e95101c03c60c83975e622ab7b78f88b8c821c`.
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
- One-time OS sandbox migration passed with a real Core Data record, pin,
  comment, 2 MiB external payload, snippet and history-size preference.
- Protected GitHub `release` environment contains the owner's Developer ID
  PKCS12/password, Apple ID/app-specific password, certificate SHA1 and Team ID.
  Existing Sparkle and legacy signing secrets were preserved. Only names and
  public variables were read back; a real CI notarization is still required.

## Remaining release gates

- App Store Connect record, final privacy/age/category answers and submission.
- Electron insertion acceptance, older supported macOS runtime
  validation, and switching back from Store to direct distribution.
- Full local UI-suite validation: the current run reports a failure in
  `testClosingSettingsWhileRecordingPreservesShortcutAndReleasesTextInput`
  (expected `r`, received empty text). The unit-only result above does not
  cover this failure. A separate rerun reproduced it on macOS 26.7.2. The other
  full-suite UI failure is an event-synthesis timeout in
  `testSettingsButtonsAndUpdaterRunThroughApplicationDelegate`. The remote
  macOS 15 CI passes; this does not close the local macOS 26 failures.

The migration moves data into the Store container once. It does not provide
shared live history or automatic reverse migration between channels.
