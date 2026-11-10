import Foundation
import SwiftUI

/// Shown on first launch, and from "How ChatDays works". Most people won't
/// find the Messages extension on their own, so this says where it lives.
struct WelcomeView: View {
    var onCreate: () -> Void
    var onClose: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Countdowns that stay correct in your chats")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)

                Text("Share a countdown in Messages. For friends with ChatDays, the number of days updates by itself.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 18) {
                    step(1, "Open a chat in Messages", "Tap the + button next to the message box.")
                    step(2, "Find ChatDays", "Not in the list? Tap More, then turn on ChatDays.")
                    step(3, "Make a countdown and send it", "Pick a template, choose a date and tap Insert into message.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    Button(action: onCreate) {
                        Text("Create my first countdown").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Open Messages") {
                        if let url = URL(string: "sms:") { openURL(url) }
                    }

                    Button("Skip", action: onClose)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
