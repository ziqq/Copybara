// Copyright (c) 2026 Anton Ustinoff. All rights reserved.
// Use and redistribution are subject to LICENSE.

import AppKit
import Sparkle
import SwiftUI

/// Checks for updates on demand and lets Sparkle verify, install, and relaunch.
@MainActor
final class UpdaterController {
    private let driver: CompactUpdateUserDriver
    private let updater: SPUUpdater
    private var startError: Error?

    init(hostBundle: Bundle = .main) {
        let driver = CompactUpdateUserDriver(hostBundle: hostBundle)
        self.driver = driver
        self.updater = SPUUpdater(hostBundle: hostBundle, applicationBundle: .main,
                                  userDriver: driver, delegate: nil)
        do { try updater.start() }
        catch {
            startError = error
            Log.app.error("Cannot start updater: \(error.localizedDescription, privacy: .public)")
        }
    }

    func checkForUpdates() {
        // Present update UI after the status menu finishes tracking.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let error = self.startError {
                self.driver.showUpdaterError(error) {}
                return
            }
            guard self.updater.canCheckForUpdates else { return }
            self.updater.checkForUpdates()
        }
    }
}

/// Uses Sparkle's installer and progress UI, with a compact prompt for the
/// simple two-choice update shown when the feed contains no release notes.
@MainActor
final class CompactUpdateUserDriver: SPUStandardUserDriver {
    private var updatePanel: UpdateDialogPanel?
    private let runModal: @MainActor (NSPanel) -> NSApplication.ModalResponse

    init(hostBundle: Bundle, runModal: @escaping @MainActor (NSPanel) -> NSApplication.ModalResponse = {
        NSApp.runModal(for: $0)
    }) {
        self.runModal = runModal
        super.init(hostBundle: hostBundle, delegate: nil)
    }

    private func makePanel(version: String, current: String) -> UpdateDialogPanel {
        let bundle = Bundle(for: SPUStandardUserDriver.self)
        let view = UpdateDialogView(
            title: L10n.string("Update available"),
            message: L10n.format("Copybara %@ is available — you have %@.", version, current),
            installTitle: bundle.localizedString(forKey: "Install Update", value: nil, table: "Sparkle"),
            skipTitle: bundle.localizedString(forKey: "Skip This Version", value: nil, table: "Sparkle"),
            onInstall: { NSApp.stopModal(withCode: .alertFirstButtonReturn) },
            onSkip: { NSApp.stopModal(withCode: .alertSecondButtonReturn) }
        )
        let host = NSHostingView(rootView: view)
        let panel = UpdateDialogPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                                      styleMask: .borderless, backing: .buffered, defer: false)
        panel.title = view.title
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = host
        panel.center()
        return panel
    }

    override func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState,
                                  reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard !appcastItem.isInformationOnlyUpdate, !appcastItem.isMajorUpgrade,
              !appcastItem.isCriticalUpdate, appcastItem.releaseNotesURL == nil,
              appcastItem.itemDescription == nil, state.stage == .notDownloaded else {
            super.showUpdateFound(with: appcastItem, state: state, reply: reply)
            return
        }
        showCompactUpdate(version: appcastItem.displayVersionString, current: UpdateChecker.current(), reply: reply)
    }

    func showCompactUpdate(version: String, current: String, reply: (SPUUserUpdateChoice) -> Void) {
        // Reset the standard driver's checking UI before taking over this
        // not-yet-downloaded update. The updater's session stays in Sparkle.
        super.dismissUpdateInstallation()
        let panel = makePanel(version: version, current: current)
        updatePanel = panel
        NSApp.unhideWithoutActivation()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        let result = runModal(panel)
        panel.orderOut(nil)
        updatePanel = nil
        switch result {
        case .alertFirstButtonReturn: reply(.install)
        case .alertSecondButtonReturn: reply(.skip)
        default: reply(.dismiss)
        }
    }

    override func dismissUpdateInstallation() {
        if let updatePanel, NSApp.modalWindow === updatePanel {
            NSApp.abortModal()
        }
        updatePanel?.orderOut(nil)
        super.dismissUpdateInstallation()
    }

    override func showUpdateInFocus() {
        guard let updatePanel else { super.showUpdateInFocus(); return }
        NSApp.activate(ignoringOtherApps: true)
        updatePanel.makeKeyAndOrderFront(nil)
    }
}

private final class UpdateDialogPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        if NSApp.modalWindow === self {
            NSApp.stopModal(withCode: .cancel)
        }
    }
}

struct UpdateDialogView: View {
    let title: String
    let message: String
    let installTitle: String
    let skipTitle: String
    let onInstall: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Image(nsImage: AppIconProvider.applicationIcon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
                    .padding(.bottom, 4)
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)

            VStack(spacing: 6) {
                Button(installTitle, action: onInstall)
                    .buttonStyle(UpdateActionStyle(isDefault: true))
                    .keyboardShortcut(.defaultAction)
                Button(skipTitle, action: onSkip)
                    .buttonStyle(UpdateActionStyle(isDefault: false))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .frame(width: 304)
        .background {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(.primary.opacity(0.10), lineWidth: 1)
                }
        }
    }
}

private struct UpdateActionStyle: ButtonStyle {
    let isDefault: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isDefault ? Color.white : Color.primary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, minHeight: 28)
            .background(isDefault
                        ? Color(nsColor: .controlAccentColor).opacity(configuration.isPressed ? 0.75 : 1)
                        : Color.primary.opacity(configuration.isPressed ? 0.15 : 0.07), in: Capsule())
            .contentShape(Capsule())
    }
}
