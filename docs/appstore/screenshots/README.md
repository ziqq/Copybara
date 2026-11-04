# App Store screenshots

Three English and three Russian screenshots of the production `PopupView` and
`SettingsView`, rendered in a separate native screenshot fixture with fixed demo
data. The presentation canvas and captions are screenshot-only; no app UI is
invented and no user clipboard content is used.

- `en/` and `ru/`: upload PNGs, 2880 × 1800 pixels, RGB, no alpha channel.
- `web/en/` and `web/ru/`: the same compositions at 1440 × 900, JPEG quality 85,
  for the landing page. Use these instead of the large upload PNGs.
- `web/en/*-window.png` and `web/ru/*-window.png`: native-window crops from the
  original PNG captures for the landing page, without presentation titles or
  backgrounds. No app UI is changed.
- `contact-sheet.png`: review only, English above Russian.
- `manifest.json`: upload file order, language and dimensions.

The three scenes show clipboard history, a pinned clip with its comment, and
native preferences. The preferences capture shows the visible viewport of the
real scrollable form; it does not rearrange or fabricate settings. The existing
production example image is a fixed color sample. Demo text can remain in
English inside the Russian UI, as actual copied content is not translated.

Apple's current [screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
allow this Mac screenshot size and PNG format. The files were checked for exact
dimensions and opaque RGB export, and all six compositions were visually reviewed.

## Re-export

From the repository root on a Mac with Xcode, XcodeGen and screen capture access:

```sh
python3 scripts/export_appstore_screenshots.py --build
```

This copies source files into `build/appstore-screenshots/source`, substitutes
only the screenshot renderer in that copy, builds under a dedicated bundle ID,
and captures each native window. It does not change production app sources,
launch the installed Copybara, start clipboard monitoring, or change the user's
clipboard. Each capture process is stopped in a `finally` block. The screenshot
fixture's data home and build products remain under `build/appstore-screenshots`.

To regenerate only opaque PNGs, web JPEGs and the contact sheet from existing
captures, without native UI interaction:

```sh
xcrun swift -module-cache-path build/appstore-screenshots/ModuleCache \
  docs/appstore/screenshots/fixtures/Derivatives.swift \
  "$PWD/docs/appstore/screenshots"
```
