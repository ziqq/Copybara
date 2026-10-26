<!--
Copyright (c) 2026 Anton Ustinoff. All rights reserved.
Use and redistribution are subject to LICENSE.
-->

# Releasing Copybara

Copybara is distributed as a DMG via **GitHub Releases**. Starting with 0.1.3,
the app uses Sparkle for on-demand updates (menu → *Check for Updates…*): it
downloads, verifies, installs, and relaunches. Automatic background checks are
disabled by default. Versions before 0.1.3 need one manual DMG installation.

Updates and the appcast are signed with an Ed25519 key. The public key is in
`Info.plist`; the private key is stored in the developer's Keychain account
`dev.ustinoff.copybara` and the repository's `SPARKLE_PRIVATE_KEY` Actions secret.
Never commit the private key or pass it as a command-line argument. Keep a
secure backup: ad-hoc builds cannot rotate a lost key using Developer ID.

## Cut a release

1. Update the changelogs: move the `## Unreleased` entries under a new version
   heading in [`CHANGELOG.md`](../CHANGELOG.md) and [`CHANGELOG.ru.md`](../CHANGELOG.ru.md).
2. Tag and push:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
   To publish an existing tag manually, run:
   ```bash
   gh workflow run release.yml --ref v0.2.0
   ```
   The workflow reads the version from the selected tag and rejects branch
   refs. It does not create tags.

The **Release** workflow (`.github/workflows/release.yml`) uses the `release`
environment and then:
- imports the Copybara signing identity into a temporary keychain from
  `APPLE_SIGNING_CERTIFICATE_BASE64` (encrypted PKCS12) and
  `APPLE_SIGNING_CERTIFICATE_PASSWORD` Actions secrets, then deletes that
  keychain at the end; missing secrets stop the release,
- builds a Release DMG (`scripts/build_dmg.sh`, version injected from the tag)
  as `build/Copybara-<version>.dmg`, then mounts it read-only to check the app,
  the `Applications` link and the code signature,
- computes `SHA256SUMS.txt` (by bare file name: `shasum -a 256 -c` works next
  to the download),
- assigns the workflow run number to `CFBundleVersion` so Sparkle can order
  successive release builds,
- signs the DMG and appcast using Sparkle 2.10.0 tools and the Actions secret,
- verifies the pinned certificate identity and checks that changing the app's
  version does not change its identity requirement,
- generates notes: DMG install steps first, a file / size / SHA-256 table, the
  build-from-source fallback, the commit log since the previous tag,
- publishes a GitHub Release with the DMG, checksum, and `appcast.xml`.

The feed URL is the latest release's `appcast.xml` asset. Its enclosure points
to the version-specific DMG asset. Sparkle requires valid archive and feed
signatures before installing; downloading a DMG in a browser remains available
for first-time installation.

## Release signing and Accessibility

Starting with 0.1.6, releases use the same Apple Development certificate.
Its public SHA1 identity is `2A1CD7C372968E01732ED7B26AC5CBB9F4014D33`; the
private key is held only in the developer's Keychain and the encrypted Actions
secret. `scripts/verify_signing.py` rejects ad-hoc signatures, mismatched
certificates and versions that fail each other's designated requirement.

The first migration from an ad-hoc release still needs a new Accessibility
grant: remove the old entry with − and add `/Applications/Copybara.app` again.
Later certificate-signed releases use the same identity. This certificate does
not provide Developer ID notarization; the downloaded app may still need its
quarantine flag cleared on first installation.

## Release configuration

The workflow uses these existing Actions secrets, available to the protected
`release` environment:

| Name | Purpose |
|---|---|
| `APPLE_SIGNING_CERTIFICATE_BASE64` | Base64 of the owner's encrypted Apple Development PKCS12, including its private key |
| `APPLE_SIGNING_CERTIFICATE_PASSWORD` | Password for that PKCS12 |
| `SPARKLE_PRIVATE_KEY` | Existing Ed25519 key for the update archive and appcast |

The public certificate SHA1 is pinned in the workflow. No Developer ID
certificate, notarization credentials, or new repository variables are required
for this release path. PR build/test CI does not use the release credentials;
a green PR does not verify certificate import or a signed release DMG.

## Local builds and notarization

Without a team the DMG is **ad-hoc signed** (sealed as `dev.ustinoff.copybara`,
no certificate), so users clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/Copybara.app
```

An ad-hoc local build is tied to its exact binary and loses its previous
Accessibility grant after changes. To use a stable installed certificate:

```bash
COPYBARA_CODE_SIGN_IDENTITY=<certificate-SHA1> ./scripts/build_dmg.sh
```

Notarization is optional and separate from the GitHub Release workflow. To
notarize a local build, use a Developer ID Application certificate and Team ID,
and load `APPLE_ID` and `APPLE_APP_PASSWORD` into the environment through a
secure prompt or secret manager. Then run:

```bash
COPYBARA_NOTARIZE=1 \
COPYBARA_CODE_SIGN_IDENTITY=<Developer-ID-certificate-SHA1> \
COPYBARA_TEAM_ID=<your-team-ID> \
./scripts/build_dmg.sh
```

This opts into signing, notarization, stapling and verification for the app
and DMG. Receipts and logs are written to `build/notarization/`. No release is
created. Never commit or print the app-specific password, or place it in
shell history.

See [Apple's notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [custom workflow guidance](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
