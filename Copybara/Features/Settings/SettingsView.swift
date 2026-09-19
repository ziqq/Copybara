import ApplicationServices
import KeyboardShortcuts
import SwiftUI

/// The preferences window, shown via the standard Settings scene.
struct SettingsView: View {
    @StateObject private var oo = SettingsOO()

    var body: some View {
        Form {
            Section(header: Text("Shortcut")) {
                KeyboardShortcuts.Recorder("Toggle Copybara", name: .togglePopup)
            }

            Section(header: Text("History")) {
                Stepper(value: $oo.historySize, in: 10...1000, step: 10) {
                    Text("Keep \(oo.historySize) items")
                }
                Picker("Sort by", selection: $oo.sortMode) {
                    ForEach(SortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Picker("Keep for", selection: $oo.historyRetentionDays) {
                    Text("Forever").tag(0)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                }
            }

            Section(header: Text("Search")) {
                Picker("Match", selection: $oo.searchMode) {
                    ForEach(SearchMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(header: Text("Appearance")) {
                Picker("Show icon in", selection: $oo.iconVisibility) {
                    ForEach(IconVisibility.allCases) { visibility in
                        Text(visibility.title).tag(visibility)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Open popup at", selection: $oo.popupPosition) {
                    ForEach(PopupPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }

                Toggle("Liquid Glass", isOn: $oo.useLiquidGlass)
                    .disabled(!oo.liquidGlassSupported)
                if !oo.liquidGlassSupported {
                    Text("Requires macOS 26 or later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Privacy")) {
                Toggle("Ignore all copies", isOn: $oo.ignoreAllCopies)

                if oo.blockedBundleIDs.isEmpty {
                    Text("No blocked apps. Copies from blocked apps are never recorded.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(oo.blockedBundleIDs, id: \.self) { bundleID in
                        HStack {
                            Text(AppIconProvider.name(forBundleID: bundleID) ?? bundleID)
                            Spacer()
                            Button {
                                oo.removeBlockedApp(bundleID)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Add App to Blocklist…") { oo.addBlockedApp() }
            }

            Section(header: Text("Startup")) {
                Toggle("Launch at login", isOn: $oo.launchAtLogin)
                    .disabled(!oo.launchAtLoginSupported)
                if !oo.launchAtLoginSupported {
                    Text("Requires macOS 13 or later.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Permissions")) {
                HStack {
                    Text("Accessibility")
                    Spacer()
                    let granted = AXIsProcessTrusted()
                    Text(granted ? "Granted" : "Not granted")
                        .font(.caption)
                        .foregroundColor(granted ? .secondary : .orange)
                }
                Text("Needed to paste into the app you were using.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Open Accessibility Settings") {
                    OnboardingController.openAccessibilitySettings()
                }
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView()
}
#endif
