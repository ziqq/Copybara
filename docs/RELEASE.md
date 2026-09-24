# Releasing Copybara

Copybara is distributed as a DMG via **GitHub Releases**. The app checks for
updates on demand through the GitHub Releases API (menu → *Check for Updates…*) —
no Sparkle, appcast, or signing keys required. A paid Apple Developer account is
optional (only needed to ship a signed, notarized DMG that installs without the
Gatekeeper quarantine step).

## Cut a release

1. Update the changelogs: move the `## Unreleased` entries under a new version
   heading in [`CHANGELOG.md`](../CHANGELOG.md) and [`CHANGELOG.ru.md`](../CHANGELOG.ru.md).
2. Tag and push:
   ```bash
   git tag v0.2.0
   git push origin v0.2.0
   ```
   (Or run the **Release** workflow manually via *workflow_dispatch* with the
   version — it creates the tag for you.)

The **Release** workflow (`.github/workflows/release.yml`) then:
- builds a Release DMG (`scripts/build_dmg.sh`, version injected from the tag)
  as `build/Copybara-<version>.dmg`, then mounts it read-only to check the app,
  the `Applications` link and (for signed builds) the code signature,
- computes `SHA256SUMS.txt` (by bare file name: `shasum -a 256 -c` works next
  to the download),
- generates notes: DMG install steps first, a file / size / SHA-256 table, the
  build-from-source fallback, the commit log since the previous tag,
- publishes a GitHub Release with the DMG + checksum.

*Check for Updates…* links to the release's `.dmg` asset, so keep that
extension if the packaging changes.

Users get *Check for Updates…* → it compares the latest release tag to the
running version and points them at the download.

## Signing (optional, needs a paid account)

The DMG is **unsigned/ad-hoc** by default, so users clear the quarantine flag:

```bash
xattr -dr com.apple.quarantine /Applications/Copybara.app
```

To ship a clean, notarized DMG, build signed and notarize:

```bash
DEVELOPMENT_TEAM=YOURTEAMID ./scripts/build_dmg.sh
xcrun notarytool submit build/Copybara-<version>.dmg \
  --apple-id "you@example.com" --team-id "YOURTEAMID" \
  --password "app-specific-password" --wait
xcrun stapler staple build/Copybara-<version>.dmg
```

Then attach the notarized DMG to the release.
