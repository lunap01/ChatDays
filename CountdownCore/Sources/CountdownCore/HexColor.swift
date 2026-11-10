import Foundation

/// An sRGB colour that travels in the message URL as "RRGGBB".
public struct HexColor: Hashable, Sendable, Codable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public static let white = HexColor(red: 255, green: 255, blue: 255)
    public static let black = HexColor(red: 0, green: 0, blue: 0)

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Accepts "RRGGBB" or "#RRGGBB" (any case). Returns nil for anything else.
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, s.allSatisfy({ $0.isHexDigit }), let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: UInt8((v >> 16) & 0xFF), green: UInt8((v >> 8) & 0xFF), blue: UInt8(v & 0xFF))
    }

    /// Upper-case "RRGGBB".
    public var hex: String {
        String(format: "%02X%02X%02X", UInt32(red), UInt32(green), UInt32(blue))
    }

    /// WCAG relative luminance, 0 (black) to 1 (white).
    public var relativeLuminance: Double {
        func linear(_ v: UInt8) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, from 1 (identical) to 21 (black on white).
    public func contrastRatio(with other: HexColor) -> Double {
        let a = relativeLuminance
        let b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
