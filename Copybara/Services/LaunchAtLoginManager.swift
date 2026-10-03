// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import ServiceManagement

/// Manages the "launch at login" preference.
///
/// Uses `SMAppService` on macOS 13+. On macOS 12 the API is unavailable, so the
/// feature is a no-op there (the Settings toggle reflects this).
enum LaunchAtLoginManager {
    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Whether the current OS supports toggling launch at login.
    static var isSupported: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    /// Registers or unregisters the app as a login item.
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            Log.app.info("Launch at login requires macOS 13+")
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("Launch-at-login toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
