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
- imports the owner's Developer ID Application identity into a temporary keychain
  from the `DEVELOPER_ID_CERTIFICATE_BASE64` (encrypted PKCS12) and
  `DEVELOPER_ID_CERTIFICATE_PASSWORD` environment secrets; missing signing or
  notarization configuration stops the release,
- signs the app and Sparkle's nested helpers inside-out with hardened runtime
  and a secure timestamp, retaining the helpers' existing entitlements,
- submits the app to Apple's notary service, requires `Accepted`, retrieves the
  notary log, staples and validates the ticket, and checks Gatekeeper,
- packages the stapled app in `build/Copybara-<version>.dmg`
  (`scripts/build_dmg.sh`, version injected from the tag), signs, notarizes and
  staples that image, then mounts it read-only to check both tickets, the app,
  the `Applications` link, signatures and Gatekeeper,
- computes `SHA256SUMS.txt` (by bare file name: `shasum -a 256 -c` works next
  to the download),
- assigns the workflow run number to `CFBundleVersion` so Sparkle can order
  successive release builds,
- signs the DMG and appcast using Sparkle 2.10.0 tools and the Actions secret,
- verifies the pinned certificate identity and checks that changing the app's
  version does not change its identity requirement,
- generates notes: DMG install steps first, a file / size / SHA-256 table, the
  build-from-source fallback, the commit log since the previous tag,
- publishes a GitHub Release with the DMG, checksum, and `appcast.xml`,
- saves the app and DMG notary submission receipts and logs as a workflow
  artifact for 30 days and removes the temporary signing keychain.

Checksums and Sparkle signatures are generated only after both tickets are
stapled. Notarization failure, a missing timestamp, a different certificate,
`get-task-allow`, or a failed Gatekeeper assessment prevents publication.

The feed URL is the latest release's `appcast.xml` asset. Its enclosure points
to the version-specific DMG asset. Sparkle requires valid archive and feed
signatures before installing; downloading a DMG in a browser remains available
for first-time installation.

## Release signing and Accessibility

Releases from 0.1.6 initially used an Apple Development certificate. The
production workflow now requires the owner's **Developer ID Application**
certificate from the G2 authority. `scripts/verify_signing.py` verifies the
configured public certificate SHA1 and Team ID, Developer ID certificate type,
hardened runtime, secure timestamp, sealed bundle, nested Sparkle code and
mutual designated requirements across version changes.

The first migration from Apple Development or ad-hoc signing changes the
signing requirement. If pasting stops, remove the old Accessibility grant with
− and add `/Applications/Copybara.app` again. The version-change check applies
to successive Developer ID builds; it does not prove continuity with the old
Apple Development identity. The existing Sparkle Ed25519 key and feed remain
unchanged.

## Production configuration

Configure these **new** values in the protected `release` environment:

| Kind | Name | Purpose |
|---|---|---|
| Secret | `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64 of the owner's encrypted Developer ID Application PKCS12, including its private key |
| Secret | `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password for that PKCS12 |
| Variable | `DEVELOPER_ID_CERTIFICATE_SHA1` | Public SHA1 of that certificate, 40 hexadecimal characters |
| Variable | `APPLE_TEAM_ID` | The owner's 10-character Developer ID Team ID |
| Secret | `APPLE_ID` | The owner's Apple ID authorized for notarization in this team |
| Secret | `APPLE_APP_PASSWORD` | An app-specific password for that Apple ID |

Create a Developer ID Application certificate using **G2 Sub-CA**. The old G1
intermediate expires on February 1, 2027; newly issued G2 leaf certificates must
be renewed annually. See [Apple's certificate guidance](https://developer.apple.com/help/account/certificates/replace-developer-id-certificates).
Use only the repository owner's identity. Do not substitute another team or
fall back to Apple Development signing for a production release. Preserve the
existing `APPLE_SIGNING_CERTIFICATE_BASE64`,
`APPLE_SIGNING_CERTIFICATE_PASSWORD`, and `SPARKLE_PRIVATE_KEY` secrets.

Before merging the workflow migration, provision the owner's credentials and
verify an end-to-end Developer ID build: both app and DMG submissions must be
`Accepted`, both stapled tickets must validate, and Gatekeeper must accept the
mounted app and DMG. PR build/test CI runs without production credentials; a
green PR does **not** prove notarization. Do not create a release merely to test
credentials or publish before this validation.

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

To validate a production build locally without publishing, set the public
certificate identity and Team ID, and load `APPLE_ID` and
`APPLE_APP_PASSWORD` into the environment through a secure prompt or secret
manager. Then run:

```bash
COPYBARA_NOTARIZE=1 \
COPYBARA_CODE_SIGN_IDENTITY=<Developer-ID-certificate-SHA1> \
COPYBARA_TEAM_ID=<your-team-ID> \
./scripts/build_dmg.sh
```

This runs the same signing, notarization, stapling and verification path as
production. Receipts and logs are written to `build/notarization/`. No release
is created. Never commit or print the app-specific password, or place it in
shell history.

See [Apple's notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [custom workflow guidance](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
