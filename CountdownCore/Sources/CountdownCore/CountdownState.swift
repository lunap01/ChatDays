import Foundation

public enum CountdownState: Equatable, Sendable {
    /// Two or more days to go.
    case daysRemaining(Int)
    case tomorrow
    case today
    case passed(daysAgo: Int)
    /// A countdown that keeps counting after its date (anniversaries): time since.
    /// `years` and `months` are whole calendar years and the whole months beyond them.
    case elapsed(days: Int, years: Int, months: Int)

    /// Big-number text, matching the spec's wording table.
    public var headline: String {
        switch self {
        case .daysRemaining(let n): return "\(n) DAYS"
        case .tomorrow: return "TOMORROW"
        case .today: return "TODAY!"
        case .passed: return "EVENT PASSED"
        case .elapsed(let days, let years, let months):
            return CountdownState.elapsedText(days: days, years: years, months: months).uppercased()
        }
    }

    /// "1,250 days", shown beside a years-and-months headline. Nil under a year,
    /// where the headline is already the number of days.
    public func elapsedDaysText(locale: Locale = .current) -> String? {
        guard case .elapsed(let days, let years, _) = self, years >= 1 else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        return "\(formatter.string(from: NSNumber(value: days)) ?? String(days)) days"
    }

    /// "1 year, 1 month", "3 years", or "212 days" under a year.
    private static func elapsedText(days: Int, years: Int, months: Int) -> String {
        if years >= 1 {
            let y = years == 1 ? "1 year" : "\(years) years"
            if months == 0 { return y }
            return months == 1 ? "\(y), 1 month" : "\(y), \(months) months"
        }
        return days == 1 ? "1 day" : "\(days) days"
    }

    /// A plain sentence for sharing, such as "42 days until Family Holiday".
    public func sentence(about name: String) -> String {
        switch self {
        case .daysRemaining(let n): return "\(n) days until \(name)"
        case .tomorrow: return "\(name) is tomorrow"
        case .today: return "\(name) is today!"
        case .passed(let n): return n == 1 ? "\(name) was yesterday" : "\(name) was \(n) days ago"
        case .elapsed(let days, let years, let months):
            return "\(CountdownState.elapsedText(days: days, years: years, months: months)) since \(name)"
        }
    }

    /// Whole days until the event; negative once it has passed.
    public var signedDays: Int {
        switch self {
        case .daysRemaining(let n): return n
        case .tomorrow: return 1
        case .today: return 0
        case .passed(let n): return -n
        case .elapsed(let days, _, _): return -days
        }
    }
}

public enum CountdownCalculator {
    /// Calendar-day countdown as seen by someone in `timeZone` at instant `now`.
    ///
    /// Works on y/m/d values rather than elapsed seconds, so a 23- or 25-hour
    /// DST day still counts as one day, and 23:59 vs 00:01 rolls over exactly
    /// at the viewer's local midnight. With `countsUp`, once the date has passed
    /// it reports days since instead of "event passed".
    public static func state(for event: EventDate,
                             now: Date = Date(),
                             timeZone: TimeZone = .current,
                             countsUp: Bool = false) -> CountdownState {
        let today = EventDate(date: now, timeZone: timeZone)
        return state(for: event, today: today, countsUp: countsUp)
    }

    public static func state(for event: EventDate, today: EventDate, countsUp: Bool = false) -> CountdownState {
        let seconds = event.utcMidnight.timeIntervalSince(today.utcMidnight)
        let days = Int((seconds / 86_400).rounded())
        switch days {
        case ..<0:
            guard countsUp else { return .passed(daysAgo: -days) }
            // Whole calendar years, then whole months beyond them (leap years and month lengths handled by the calendar).
            let parts = EventDate.utcCalendar.dateComponents([.year, .month], from: event.utcMidnight, to: today.utcMidnight)
            return .elapsed(days: -days, years: parts.year ?? 0, months: parts.month ?? 0)
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

