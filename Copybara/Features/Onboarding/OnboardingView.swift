import SwiftUI

/// First-run welcome screen: explains how Copybara works and the single
/// Accessibility permission it needs to paste into other apps.
struct OnboardingView: View {
    var onGrant: () -> Void
    var onOpenSettings: () -> Void
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)

            VStack(spacing: 6) {
                Text("Welcome to Copybara")
                    .font(.system(size: 20, weight: .semibold))
                Text("Your clipboard history, one keystroke away.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                row("keyboard", "Press ⌘⇧V, type to search, press ↩ to paste.")
                row("lock.shield", "Everything stays on your Mac — no cloud, no accounts.")
                row("hand.raised", "Passwords and secret clips are ignored automatically.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("One permission")
                    .font(.system(size: 13, weight: .semibold))
                Text("To paste into the app you were using, Copybara needs Accessibility access. It never reads your screen.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Grant Accessibility…", action: onGrant)
                    Button("Open Settings", action: onOpenSettings)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onFinish) {
                Text("Get Started").frame(maxWidth: .infinity)
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 420)
    }

    private func row(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 13))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
