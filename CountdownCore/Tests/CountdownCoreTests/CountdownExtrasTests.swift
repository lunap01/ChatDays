import XCTest
@testable import CountdownCore

final class CountdownExtrasTests: XCTestCase {
    let melbourne = TimeZone(identifier: "Australia/Melbourne")!

    func instant(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = melbourne
        return cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: nextMidnight

    func testNextMidnightIsStartOfNextLocalDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = melbourne
        let next = CountdownCalculator.nextMidnight(after: instant(2026, 11, 3, 15), timeZone: melbourne)
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: next)
        XCTAssertEqual([c.year, c.month, c.day, c.hour, c.minute], [2026, 11, 4, 0, 0])
    }

    func testNextMidnightOnDSTStartDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = melbourne
        // 4 Oct 2026 is a 23-hour day in Melbourne.
        let next = CountdownCalculator.nextMidnight(after: instant(2026, 10, 4, 12), timeZone: melbourne)
        let c = cal.dateComponents([.month, .day, .hour], from: next)
        XCTAssertEqual([c.month, c.day, c.hour], [10, 5, 0])
    }

    // MARK: EventDate helpers

    func testComparable() {
        let a = EventDate(year: 2026, month: 12, day: 15)!
        let b = EventDate(year: 2027, month: 1, day: 1)!
        XCTAssertTrue(a < b)
        XCTAssertFalse(b < a)
        XCTAssertTrue(a <= a)
    }

    func testAddingDays() {
        XCTAssertEqual(EventDate(year: 2026, month: 12, day: 31)!.adding(days: 1).isoString, "2027-01-01")
        XCTAssertEqual(EventDate(year: 2028, month: 2, day: 28)!.adding(days: 1).isoString, "2028-02-29")
        XCTAssertEqual(EventDate(year: 2028, month: 2, day: 28)!.adding(days: 2).isoString, "2028-03-01")
        XCTAssertEqual(EventDate(year: 2026, month: 3, day: 1)!.adding(days: -1).isoString, "2026-02-28")
    }

    func testDisplayString() {
        let gb = Locale(identifier: "en_GB")
        let d = EventDate(year: 2026, month: 12, day: 15)!
        XCTAssertEqual(d.displayString(locale: gb), "15 December 2026")
        XCTAssertEqual(d.displayString(short: true, locale: gb), "15 Dec")
    }

    // MARK: Colours

    func testHexParsing() {
        XCTAssertEqual(HexColor(hex: "#12204a")?.hex, "12204A")
        XCTAssertEqual(HexColor(hex: "FFFFFF"), HexColor.white)
        XCTAssertNil(HexColor(hex: "12345"))
        XCTAssertNil(HexColor(hex: "GGGGGG"))
        XCTAssertNil(HexColor(hex: "+12345"))
    }

    func testContrastExtremes() {
        XCTAssertEqual(HexColor.white.contrastRatio(with: .black), 21, accuracy: 0.01)
        XCTAssertEqual(HexColor.white.contrastRatio(with: .white), 1, accuracy: 0.001)
    }

    func testAllPresetsAreReadable() {
        for preset in CountdownStyle.Preset.allCases {
            XCTAssertTrue(preset.style.isReadable, "\(preset) should be readable")
            XCTAssertEqual(preset.style.effectiveText, preset.style.text)
        }
    }

    func testUnreadableChoiceIsCorrected() {
        let yellowOnWhite = CountdownStyle(background: .white, text: HexColor(hex: "FFEB3B")!)
        XCTAssertFalse(yellowOnWhite.isReadable)
        XCTAssertEqual(yellowOnWhite.effectiveText, .black)

        let darkOnNavy = CountdownStyle(background: HexColor(hex: "12204A")!, text: HexColor(hex: "222222")!)
        XCTAssertFalse(darkOnNavy.isReadable)
        XCTAssertEqual(darkOnNavy.effectiveText, .white)
    }

    func testGradientChecksEveryStop() {
        // White text is fine on the dark stop but not on the pale one.
        let style = CountdownStyle(background: HexColor(hex: "12204A")!,
                                   background2: HexColor(hex: "F5F5F7")!,
                                   text: .white)
        XCTAssertFalse(style.isReadable)
    }
}
