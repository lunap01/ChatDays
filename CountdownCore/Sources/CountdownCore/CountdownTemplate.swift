import Foundation

/// Starting points for common events: an emoji, a suggested title and a look.
public enum CountdownTemplate: String, CaseIterable, Identifiable, Sendable {
    case birthday, wedding, holiday, concert, party, gameDay

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .birthday: return "Birthday"
        case .wedding: return "Wedding"
        case .holiday: return "Holiday"
        case .concert: return "Concert"
        case .party: return "Party"
        case .gameDay: return "Game day"
        }
    }

    public var emoji: String {
        switch self {
        case .birthday: return "🎂"
        case .wedding: return "💍"
        case .holiday: return "🏖️"
        case .concert: return "🎤"
        case .party: return "🎉"
        case .gameDay: return "⚽"
        }
    }

    public var suggestedTitle: String { name }

    public var preset: CountdownStyle.Preset {
        switch self {
        case .birthday: return .celebration
        case .wedding: return .minimal
        case .holiday: return .holiday
        case .concert: return .modern
        case .party: return .celebration
        case .gameDay: return .sport
        }
    }

    public var style: CountdownStyle { preset.style }

    /// True for an empty title or one that is just another template's suggestion,
    /// so choosing a template never overwrites something the person typed.
    public static func isSuggestedTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || allCases.contains { $0.suggestedTitle == trimmed }
    }

    /// The title to use after choosing this template.
    public func title(replacing current: String) -> String {
        CountdownTemplate.isSuggestedTitle(current) ? suggestedTitle : current
    }
}
