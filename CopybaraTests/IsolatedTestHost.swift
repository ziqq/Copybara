// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import CoreData
import Foundation
import XCTest

enum IsolatedTestHost {
    static func require() throws {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).standardizedFileURL
        guard Bundle.main.bundleIdentifier?.hasPrefix("dev.ustinoff.copybara.coverage.") == true,
              home.lastPathComponent == "CopybaraTestsHome",
              NSPersistentContainer.defaultDirectoryURL().standardizedFileURL.path.hasPrefix(home.path + "/") else {
            throw XCTSkip("Shared-state tests require the isolated test command in CONTRIBUTING.md")
        }
    }
}
