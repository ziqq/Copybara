import SwiftUI

/// The preferences window, shown via the standard Settings scene.
struct SettingsView: View {
    @StateObject private var oo = SettingsOO()

    var body: some View {
        Form {
            Section(header: Text("History")) {
                Stepper(value: $oo.historySize, in: 10...1000, step: 10) {
                    Text("Keep \(oo.historySize) items")
                }
            }

            Section(header: Text("Appearance")) {
                Picker("Show icon in", selection: $oo.iconVisibility) {
                    ForEach(IconVisibility.allCases) { visibility in
                        Text(visibility.title).tag(visibility)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
