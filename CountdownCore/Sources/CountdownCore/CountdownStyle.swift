import Foundation

/// How a countdown looks: background (solid or two-colour gradient) and text.
/// `packID` is reserved for future paid packs (artwork ships inside the app,
/// the message only carries the ID).
public struct CountdownStyle: Equatable, Sendable, Codable {
    public var background: HexColor
    public var background2: HexColor?
    public var text: HexColor
    public var packID: String?

    /// WCAG AA for normal text.
    public static let minimumContrast = 4.5

    public init(background: HexColor, background2: HexColor? = nil, text: HexColor, packID: String? = nil) {
        self.background = background
        self.background2 = background2
        self.text = text
        self.packID = packID
    }

    private var backgrounds: [HexColor] {
        if let background2 { return [background, background2] }
        return [background]
    }

    /// True when the chosen text colour reads well on every background colour.
    public var isReadable: Bool {
        backgrounds.allSatisfy { text.contrastRatio(with: $0) >= CountdownStyle.minimumContrast }
    }

    /// The text colour that should actually be drawn: the chosen one if it is
    /// readable, otherwise white or black, whichever reads better. Bubbles can
    /// therefore never end up unreadable, whatever the sender picked.
    public var effectiveText: HexColor {
        if isReadable { return text }
        func worst(_ c: HexColor) -> Double {
            backgrounds.map { c.contrastRatio(with: $0) }.min() ?? 1
        }
        return worst(.white) >= worst(.black) ? .white : .black
    }

    // MARK: - Presets

    public enum Preset: String, CaseIterable, Identifiable, Sendable {
        case modern, holiday, celebration, sport, minimal

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .modern: return "Modern"
            case .holiday: return "Holiday"
            case .celebration: return "Celebration"
            case .sport: return "Sport"
            case .minimal: return "Minimal"
            }
        }

        public var style: CountdownStyle {
            func h(_ s: String) -> HexColor { HexColor(hex: s)! }
            switch self {
            case .modern:
                return CountdownStyle(background: h("12204A"), background2: h("2E52A0"), text: .white)
            case .holiday:
                return CountdownStyle(background: h("C2410C"), background2: h("BE123C"), text: .white)
            case .celebration:
                return CountdownStyle(background: h("7E22CE"), background2: h("BE185D"), text: .white)
            case .sport:
                return CountdownStyle(background: h("047857"), background2: h("0F766E"), text: .white)
            case .minimal:
                return CountdownStyle(background: h("F5F5F7"), text: h("1D1D1F"))
            }
        }
    }
}
