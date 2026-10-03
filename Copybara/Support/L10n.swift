// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import Foundation

/// Shared localization for AppKit controls and dynamically chosen SwiftUI text.
enum L10n {
    static func string(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: Locale.current, arguments: arguments)
    }
}
