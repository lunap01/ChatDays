import Foundation

public enum CountdownState: Equatable, Sendable {
    /// Two or more days to go.
    case daysRemaining(Int)
    case tomorrow
    case today
    case passed(daysAgo: Int)

    /// Big-number text, matching the spec's wording table.
    public var headline: String {
        switch self {
        case .daysRemaining(let n): return "\(n) DAYS"
        case .tomorrow: return "TOMORROW"
        case .today: return "TODAY!"
        case .passed: return "EVENT PASSED"
        }
    }

    /// Whole days until the event; negative once it has passed.
    public var signedDays: Int {
        switch self {
        case .daysRemaining(let n): return n
        case .tomorrow: return 1
        case .today: return 0
        case .passed(let n): return -n
        }
    }
}

public enum CountdownCalculator {
    /// Calendar-day countdown as seen by someone in `timeZone` at instant `now`.
    ///
    /// Works on y/m/d values rather than elapsed seconds, so a 23- or 25-hour
    /// DST day still counts as one day, and 23:59 vs 00:01 rolls over exactly
    /// at the viewer's local midnight.
    public static func state(for event: EventDate,
                             now: Date = Date(),
                             timeZone: TimeZone = .current) -> CountdownState {
        let today = EventDate(date: now, timeZone: timeZone)
        return state(for: event, today: today)
    }

    public static func state(for event: EventDate, today: EventDate) -> CountdownState {
        let seconds = event.utcMidnight.timeIntervalSince(today.utcMidnight)
        let days = Int((seconds / 86_400).rounded())
        switch days {
        case ..<0: return .passed(daysAgo: -days)
        case 0: return .today
        case 1: return .tomorrow
        default: return .daysRemaining(days)
        }
    }

    /// The start of the next local day after `now`. Live bubbles refresh here
    /// (once a day) instead of ticking every second.
    public static func nextMidnight(after now: Date, timeZone: TimeZone = .current) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let start = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: 1, to: start) ?? now.addingTimeInterval(86_400)
    }
}
