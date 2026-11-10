import Foundation
import SwiftUI
import CountdownCore

/// Shown when the free countdowns are used up, or from the main app's unlock button.
struct PaywallView: View {
    @ObservedObject var access: AccessStore
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Unlock ChatDays")
                .font(.title2.bold())
            Text("You've used your \(UsageLedger.freeLimit) free countdowns. Unlock once to send as many as you like. There's no subscription, and receiving or viewing countdowns is always free.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                Task { await access.purchase() }
            } label: {
                Text(access.priceText.map { "Unlock for \($0)" } ?? "Price unavailable")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(access.priceText == nil || access.isWorking)

            Button("Restore Purchases") {
                Task { await access.restore() }
            }
            .disabled(access.isWorking)

            Button("Not now", action: onClose)
                .foregroundStyle(.secondary)

            if let message = access.message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .task { await access.refresh() }
        .onChange(of: access.isUnlocked) { unlocked in
            if unlocked { onClose() }
        }
    }
}
