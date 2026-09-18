# Releasing Copybara

Copybara ships as a signed, notarized DMG and updates itself with
[Sparkle](https://sparkle-project.org). These steps need an Apple Developer
account and are done by the maintainer.

## One-time setup

### 1. Sparkle signing keys
Sparkle verifies updates with an EdDSA key pair. Generate it once:

```bash
# generate_keys ships inside the resolved Sparkle package artifact.
find ~/Library/Developer/Xcode/DerivedData -name generate_keys -path '*Sparkle*' | head -1
```

Run `generate_keys`; it stores the **private** key in your login Keychain and
prints the **public** key. Put the public key in `Copybara/Resources/Info.plist`
under `SUPublicEDKey` (replacing the placeholder). Never commit the private key.

### 2. Appcast hosting
Host `appcast.xml` and the DMGs somewhere stable. The default `SUFeedURL` is
`https://ziqq.github.io/Copybara/appcast.xml` (GitHub Pages). Change it in
`Info.plist` if you host elsewhere.

## Each release

1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Build the DMG (signed):
   ```bash
   DEVELOPMENT_TEAM=YOURTEAMID ./scripts/build_dmg.sh
   ```
3. Notarize and staple:
   ```bash
   xcrun notarytool submit build/Copybara.dmg \
     --apple-id "you@example.com" --team-id "YOURTEAMID" \
     --password "app-specific-password" --wait
   xcrun stapler staple build/Copybara.dmg
   ```
4. Sign the update and regenerate the appcast (Sparkle tools):
   ```bash
   sign_update build/Copybara.dmg        # prints the edSignature
   generate_appcast /path/to/dmgs        # writes appcast.xml
   ```
5. Publish the DMG (e.g. a GitHub Release) and the updated `appcast.xml`.

Existing users get the update automatically; **Check for Updates…** in the
menu triggers a manual check.
