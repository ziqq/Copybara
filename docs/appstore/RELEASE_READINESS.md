<!-- Copyright (c) 2026 Anton Ustinoff. Use and redistribution are subject to LICENSE. -->

# Copybara 0.1.12 (14) release preparation

Prepared on 2026-11-03. This records local evidence, not App Review approval
or a published application release.

## Prepared

- Separate sandboxed Store configuration without Sparkle or GitHub updater.
- Local Store archive: `build/ReleaseCandidate/Copybara-AppStore-0.1.12.xcarchive`.
  The archive is ad-hoc signed for validation, not upload-ready.
- EN/RU metadata, review notes and three native screenshots per locale. Upload
  PNGs are 2880 × 1800 RGB without alpha; web JPEGs show the same compositions.
- Existing unit suite: 314 reported cases, one skipped, zero failures. The
  skipped inactive-application WindowServer case needs a separate active app.
- Fresh manual Accessibility grant and real Paster insertion into an isolated
  native NSTextView receiver passed on macOS 26.7.2 with App Sandbox enforced.
- One-time OS sandbox migration passed with a real Core Data record, pin,
  comment, 2 MiB external payload, snippet and history-size preference.

## Remaining release gates

- Export using the owner's App Store distribution certificate and provisioning
  profile. Local export without provisioning updates reports missing
  `Mac Installer Distribution` and a profile for `dev.ustinoff.copybara`.
- App Store Connect record, final privacy/age/category answers and submission.
- Current 0.1.12 Developer ID app notarization and signed/stapled DMG acceptance.
  The Apple submission `f30f28f0-2c49-47a1-8504-388a27d92dea` remains in progress;
  a previous 0.1.7 acceptance does not validate this candidate.
- Configure the new protected release environment signing/notarization values
  listed in `docs/RELEASE.md`; never commit private keys or passwords.
- Browser and Electron insertion acceptance, older supported macOS runtime
  validation, and switching back from Store to direct distribution.
- Full local UI-suite validation: the current run reports a failure in
  `testClosingSettingsWhileRecordingPreservesShortcutAndReleasesTextInput`
  (expected `r`, received empty text). The unit-only result above does not
  cover this failure; confirm it in an unattended WindowServer session.

The migration moves data into the Store container once. It does not provide
shared live history or automatic reverse migration between channels.
