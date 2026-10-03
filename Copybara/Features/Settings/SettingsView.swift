import ApplicationServices
import KeyboardShortcuts
import SwiftUI

/// Scrollable preferences hosted by the settings window controller or scene.
struct SettingsView: View {
    @StateObject private var oo = SettingsOO()
    private let refreshTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        scrollableForm
        .frame(width: 480, height: 600)
        .onReceive(refreshTimer) { _ in oo.refreshExternalState() }
    }

    @ViewBuilder
    private var scrollableForm: some View {
        if #available(macOS 13.0, *) {
            settingsForm.formStyle(.grouped)
        } else {
            ScrollView {
                settingsForm
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var settingsForm: some View {
        Form {
            Section(header: Text("Shortcut")) {
                KeyboardShortcuts.Recorder("Toggle Copybara", name: .togglePopup)
            }

            Section(header: Text("History")) {
                Stepper(value: $oo.historySize, in: 10...1000, step: 10) {
                    Text(L10n.format("Keep %ld items", oo.historySize))
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

            Section(header: Text("Snippets")) {
                Text("Reusable text templates, always shown in the popup. Placeholders: ${date}, ${time}, ${datetime}, ${clipboard}, ${uuid}.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ForEach($oo.snippets) { $snippet in
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Title", text: $snippet.title)
                            .font(.system(size: 12, weight: .medium))
                        TextEditor(text: $snippet.content)
                            .font(.system(size: 12))
                            .frame(minHeight: 44, maxHeight: 90)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { oo.deleteSnippets(at: $0) }
                Button("Add Snippet") { oo.addSnippet() }
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
                    Text(L10n.string(oo.accessibilityGranted ? "Granted" : "Not granted"))
                        .font(.caption)
                        .foregroundColor(oo.accessibilityGranted ? .secondary : .orange)
                }
                Text("Needed to paste into the app you were using.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Open Accessibility Settings") {
                    OnboardingController.openAccessibilitySettings()
                }
            }
        }
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView()
}
#endif
