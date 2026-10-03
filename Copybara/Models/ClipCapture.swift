// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import Foundation

/// A single captured clipboard entry, ready to be stored. Produced by
/// `PasteboardReader` from the richest representation available on the pasteboard.
struct ClipCapture {
    let kind: ClipKind
    /// Plain-text preview / searchable text.
    let text: String
    /// Payload for non-text kinds: RTF data, PNG image data, or archived file
    /// paths. `nil` for plain text.
    let data: Data?
    /// Stable hash used for de-duplication across launches. `nil` falls back to
    /// de-duplicating plain text by its exact value.
    let contentHash: String?
    /// Bundle identifier of the source app, when known.
    let appBundleID: String?
}
