import Foundation

/// A "floating" calendar date (year-month-day) with no time zone attached.
///
/// A countdown to 15 Dec means 15 Dec on *each viewer's* calendar, so the same
/// message never shows different dates to different people. Only the viewer's
/// "today" depends on their time zone.
public struct EventDate: Hashable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Returns nil for impossible dates (e.g. 29 Feb 2027, 31 Apr).
    public init?(year: Int, month: Int, day: Int) {
        guard EventDate.isValid(year: year, month: month, day: day) else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses "yyyy-MM-dd".
    public init?(isoString: String) {
        let parts = isoString.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    /// The date a viewer in `timeZone` sees on their calendar at instant `date`.
    public init(date: Date, timeZone: TimeZone) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        self.year = c.year!
        self.month = c.month!
        self.day = c.day!
    }

    public var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// This date moved by a whole number of calendar days (negative goes back).
    public func adding(days: Int) -> EventDate {
        EventDate(date: utcMidnight.addingTimeInterval(Double(days) * 86_400),
                  timeZone: EventDate.utcCalendar.timeZone)
    }

    /// Locale-aware text, e.g. "15 December 2026" or, with `short`, "15 Dec".
    public func displayString(short: Bool = false, locale: Locale = .current) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = EventDate.utcCalendar.timeZone
        f.setLocalizedDateFormatFromTemplate(short ? "d MMM" : "d MMMM yyyy")
        return f.string(from: utcMidnight)
    }

    // MARK: - Internals

    /// Gregorian calendar pinned to UTC. Used only for pure date arithmetic,
    /// so DST and the viewer's calendar system can never affect the result.
    static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// `DateComponents -> Date` is lenient (it rolls 31 Apr into 1 May), so
    /// round-trip the components to reject anything that was adjusted.
    private static func isValid(year: Int, month: Int, day: Int) -> Bool {
        guard let date = utcCalendar.date(from: DateComponents(year: year, month: month, day: day)) else { return false }
        let back = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return back.year == year && back.month == month && back.day == day
    }

    /// UTC midnight of this date, for day arithmetic.
    var utcMidnight: Date {
        EventDate.utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

extension EventDate: Comparable {
    public static func < (lhs: EventDate, rhs: EventDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension EventDate: Codable {
    public init(from decoder: Decoder) throws {
        let s = try decoder.singleValueContainer().decode(String.self)
        guard let value = EventDate(isoString: s) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid event date: \(s)"))
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(isoString)
    }
}
