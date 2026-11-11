import Foundation
import SwiftUI

/// Shared look: the warm orange from the app icon, rounded cards, quiet captions.
enum ChatDaysTheme {
    static let accent = Color(red: 1.0, green: 0.651, blue: 0.169)
    /// Dark text that reads well on `accent`.
    static let onAccent = Color(red: 0.11, green: 0.078, blue: 0.0)
    /// A soft panel that works on both white and grouped-grey backgrounds, in light and dark mode.
    static let panel = Color.primary.opacity(0.06)
}

/// The main call to action: a full-width orange pill.
struct AccentPillButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        PillBody(configuration: configuration)
    }

    private struct PillBody: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(ChatDaysTheme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(ChatDaysTheme.accent.opacity(configuration.isPressed ? 0.8 : 1),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(isEnabled ? 1 : 0.4)
        }
    }
}

/// Small uppercase heading above a group of controls.
struct SectionCaption: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}
