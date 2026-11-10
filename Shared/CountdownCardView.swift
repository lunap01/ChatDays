import Foundation
import SwiftUI
import UIKit
import CountdownCore

// MARK: - Colour bridging

extension Color {
    init(_ hex: HexColor) {
        self.init(.sRGB,
                  red: Double(hex.red) / 255,
                  green: Double(hex.green) / 255,
                  blue: Double(hex.blue) / 255,
                  opacity: 1)
    }
}

extension HexColor {
    /// From a SwiftUI colour (e.g. a ColorPicker). Returns nil if it can't be read as RGB.
    init?(color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        func byte(_ v: CGFloat) -> UInt8 { UInt8(max(0, min(255, (v * 255).rounded()))) }
        self.init(red: byte(r), green: byte(g), blue: byte(b))
    }
}

// MARK: - The card

enum CardContent: Equatable {
    /// Shows the day count.
    case countdown(CountdownState)
    /// Event and date only, plus a prompt to get the app. Used as the fallback
    /// for people without ChatDays, because a frozen day count would mislead.
    case fallback
}

/// One card, used for the live bubble, the picture inside static and fallback
/// bubbles, and the preview in the composer.
struct CountdownCardView: View {
    let content: CardContent
    let title: String
    let emoji: String?
    let eventDate: EventDate
    let style: CountdownStyle

    private var headline: String {
        switch content {
        case .countdown(let state): return state.headline
        case .fallback: return eventDate.displayString(short: true).uppercased()
        }
    }

    var body: some View {
        let text = Color(style.effectiveText)
        ZStack {
            LinearGradient(
                colors: [Color(style.background), Color(style.background2 ?? style.background)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 6) {
                Text(headline)
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text([emoji, title].compactMap { $0 }.joined(separator: " "))
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                switch content {
                case .countdown:
                    Text(eventDate.displayString())
                        .font(.system(size: 14))
                        .opacity(0.85)
                case .fallback:
                    Text("Get ChatDays for the live countdown")
                        .font(.system(size: 13, weight: .medium))
                        .opacity(0.9)
                        .multilineTextAlignment(.center)
                }
            }
            .foregroundStyle(text)
            .padding(16)
        }
    }
}
