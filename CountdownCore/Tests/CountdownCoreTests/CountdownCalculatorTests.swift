import XCTest
@testable import CountdownCore

final class CountdownCalculatorTests: XCTestCase {
    let melbourne = TimeZone(identifier: "Australia/Melbourne")!
    let losAngeles = TimeZone(identifier: "America/Los_Angeles")!

    /// A real instant for a wall-clock time in a given zone.
    func instant(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0, in tz: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func event(_ y: Int, _ m: Int, _ d: Int) -> EventDate { EventDate(year: y, month: m, day: d)! }

    func state(_ e: EventDate, now: Date, tz: TimeZone) -> CountdownState {
        CountdownCalculator.state(for: e, now: now, timeZone: tz)
    }

    // MARK: Basic states

    func testSpecExample42Days() {
        let now = instant(2026, 11, 3, in: melbourne)
        XCTAssertEqual(state(event(2026, 12, 15), now: now, tz: melbourne), .daysRemaining(42))
        XCTAssertEqual(CountdownState.daysRemaining(42).headline, "42 DAYS")
    }

    func testTomorrowTodayPassed() {
        let now = instant(2026, 11, 3, in: melbourne)
        XCTAssertEqual(state(event(2026, 11, 4), now: now, tz: melbourne), .tomorrow)
        XCTAssertEqual(state(event(2026, 11, 3), now: now, tz: melbourne), .today)
        XCTAssertEqual(state(event(2026, 10, 31), now: now, tz: melbourne), .passed(daysAgo: 3))
        XCTAssertEqual(CountdownState.tomorrow.headline, "TOMORROW")
        XCTAssertEqual(CountdownState.today.headline, "TODAY!")
        XCTAssertEqual(CountdownState.passed(daysAgo: 1).headline, "EVENT PASSED")
    }

    func testRollsOverAtLocalMidnight() {
        let e = event(2026, 12, 15)
        XCTAssertEqual(state(e, now: instant(2026, 12, 14, 23, 59, in: melbourne), tz: melbourne), .tomorrow)
        XCTAssertEqual(state(e, now: instant(2026, 12, 15, 0, 0, in: melbourne), tz: melbourne), .today)
        XCTAssertEqual(state(e, now: instant(2026, 12, 15, 23, 59, in: melbourne), tz: melbourne), .today)
        XCTAssertEqual(state(e, now: instant(2026, 12, 16, 0, 0, in: melbourne), tz: melbourne), .passed(daysAgo: 1))
    }

    // MARK: Months and leap years

    func testMonthBoundaries() {
        XCTAssertEqual(state(event(2026, 3, 1), now: instant(2026, 1, 31, in: melbourne), tz: melbourne), .daysRemaining(29))
        XCTAssertEqual(state(event(2028, 3, 1), now: instant(2028, 1, 31, in: melbourne), tz: melbourne), .daysRemaining(30))
    }

    func testLeapDay() {
        XCTAssertEqual(state(event(2028, 2, 29), now: instant(2028, 2, 28, in: melbourne), tz: melbourne), .tomorrow)
        XCTAssertEqual(state(event(2027, 3, 1), now: instant(2027, 2, 28, in: melbourne), tz: melbourne), .tomorrow)
        XCTAssertNil(EventDate(year: 2027, month: 2, day: 29))
        XCTAssertNotNil(EventDate(year: 2028, month: 2, day: 29))
        XCTAssertNil(EventDate(year: 2026, month: 4, day: 31))
    }

    func testYearBoundary() {
        XCTAssertEqual(state(event(2027, 1, 1), now: instant(2026, 12, 25, in: melbourne), tz: melbourne), .daysRemaining(7))
    }

    // MARK: Daylight saving (Melbourne: starts Sun 4 Oct 2026, ends Sun 5 Apr 2026)

    func testAcrossDSTStart() {
        XCTAssertEqual(state(event(2026, 10, 8), now: instant(2026, 10, 1, in: melbourne), tz: melbourne), .daysRemaining(7))
        XCTAssertEqual(state(event(2026, 10, 5), now: instant(2026, 10, 3, 23, 0, in: melbourne), tz: melbourne), .daysRemaining(2))
        XCTAssertEqual(state(event(2026, 10, 5), now: instant(2026, 10, 4, 0, 30, in: melbourne), tz: melbourne), .tomorrow)
    }

    func testAcrossDSTEnd() {
        XCTAssertEqual(state(event(2026, 4, 6), now: instant(2026, 4, 4, 23, 30, in: melbourne), tz: melbourne), .daysRemaining(2))
        XCTAssertEqual(state(event(2026, 4, 12), now: instant(2026, 4, 5, in: melbourne), tz: melbourne), .daysRemaining(7))
    }

    // MARK: Different viewers, same instant

    func testRecipientsInDifferentZonesSeeTheirOwnToday() {
        let moment = ISO8601DateFormatter().date(from: "2026-11-03T20:00:00Z")!
        let e = event(2026, 11, 5)
        XCTAssertEqual(state(e, now: moment, tz: melbourne), .tomorrow)
        XCTAssertEqual(state(e, now: moment, tz: losAngeles), .daysRemaining(2))
        XCTAssertEqual(e.isoString, "2026-11-05")
    }

    // MARK: EventDate

    func testEventDateParsing() {
        XCTAssertEqual(EventDate(isoString: "2026-12-15")?.isoString, "2026-12-15")
        XCTAssertNil(EventDate(isoString: "2026-13-01"))
        XCTAssertNil(EventDate(isoString: "2026-1-5"))
        XCTAssertNil(EventDate(isoString: "garbage"))
    }
}
