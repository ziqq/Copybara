# Copybara — App Review notes

Copybara is a native, local clipboard-history utility for macOS 12 or later.
No sign-in, backend, subscription or in-app purchase is required.

## Review steps

1. Launch Copybara. It appears in the menu bar; follow the welcome screen.
2. Copy harmless sample text in TextEdit or a browser. Press Command-Shift-V to
   open history, type to search, and select the sample entry.
3. To test automatic pasting, use the welcome screen's Grant Accessibility
   action, then enable Copybara in System Settings → Privacy & Security →
   Accessibility. If Copybara is missing from the list, use + to add
   `/Applications/Copybara.app`, then enable it. Return to the destination app
   with an editable field focused.
4. Open history with Command-Shift-V and press Return. Copybara places the clip
   on the pasteboard and posts the Command-V keyboard shortcut to the focused
   application. It does not read screen contents or manipulate other apps' UI
   through Accessibility. Permission may require relaunching the app after it
   is granted or the installed signing identity changes.
5. Pin an entry, add a comment using Option-N, and search for the comment. The
   context menu also offers paste without formatting and deletion.
6. Open Settings to manage history, privacy exclusions and text snippets.

The Mac App Store build enables App Sandbox and contains no Sparkle framework,
GitHub update checker, appcast configuration or in-app update action. Updates
are delivered through the Mac App Store.

History, comments, snippets and settings are stored locally. The app does not
send clipboard contents off the device and includes no analytics, advertising
or crash-reporting SDK. Concealed/transient clipboard markers are respected;
this relies on the copying application marking its data appropriately.

Launch at login requires macOS 13 or later; Liquid Glass requires macOS 26 and
falls back to native material on earlier releases.

No non-sandboxed helper, private API, downloaded executable or external tool is
required by the shipping app. The screenshot export tools in the repository
are developer-only tools and are not part of the app bundle.

The website/support/privacy links are in the locale metadata files. Screenshots
use controlled demonstration entries, never a user's private clipboard.
