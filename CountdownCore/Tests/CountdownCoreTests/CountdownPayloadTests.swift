import XCTest
@testable import CountdownCore

final class CountdownPayloadTests: XCTestCase {
    let date = EventDate(year: 2026, month: 12, day: 15)!

    func testRoundTrip() throws {
        var style = CountdownStyle.Preset.holiday.style
        style.packID = "beach"
        let original = CountdownPayload(title: "Family Holiday", eventDate: date, emoji: "🏖️",
                                        mode: .fixed, style: style,
                                        sentOn: EventDate(year: 2026, month: 11, day: 3))
        XCTAssertEqual(try CountdownPayload(url: original.encodedURL()), original)
    }

    func testSolidColourRoundTrip() throws {
        let original = CountdownPayload(title: "Solid", eventDate: date, style: CountdownStyle.Preset.minimal.style)
        let decoded = try CountdownPayload(url: original.encodedURL())
        XCTAssertNil(decoded.style.background2)
        XCTAssertEqual(decoded, original)
    }

    func testAwkwardTitleCharactersSurvive() throws {
        let title = "Sarah & James = 💍 + Party? #1 100% / ünïcode"
        let decoded = try CountdownPayload(url: CountdownPayload(title: title, eventDate: date).encodedURL())
        XCTAssertEqual(decoded.title, title)
    }

    func testTitleIsTrimmedAndTruncated() {
        let long = String(repeating: "a", count: 200)
        XCTAssertEqual(CountdownPayload(title: long, eventDate: date).title.count, CountdownPayload.maxTitleLength)
        XCTAssertEqual(CountdownPayload(title: "  Padded  ", eventDate: date).title, "Padded")
    }

    func testEmojiKeepsOneCharacter() {
        XCTAssertEqual(CountdownPayload(title: "x", eventDate: date, emoji: "🎉🎂").emoji, "🎉")
        XCTAssertEqual(CountdownPayload(title: "x", eventDate: date, emoji: "👨‍👩‍👧").emoji, "👨‍👩‍👧")
        XCTAssertNil(CountdownPayload(title: "x", eventDate: date, emoji: "").emoji)
    }

    func testWorstCaseStaysFarUnderMessageURLLimit() {
        let emojiTitle = String(repeating: "🎉", count: CountdownPayload.maxTitleLength)
        var style = CountdownStyle.Preset.celebration.style
        style.packID = String(repeating: "p", count: 32)
        let p = CountdownPayload(title: emojiTitle, eventDate: date, emoji: "👨‍👩‍👧", mode: .fixed, style: style, sentOn: date)
        XCTAssertLessThan(p.encodedURL().absoluteString.utf8.count, 2000)
    }

    func testRejectsForeignURLs() {
        XCTAssertThrowsError(try CountdownPayload(url: URL(string: "https://example.com")!)) {
            XCTAssertEqual($0 as? CountdownPayloadError, .notACountdownURL)
        }
    }

    func testMissingAndInvalidFields() {
        XCTAssertThrowsError(try CountdownPayload(url: URL(string: "?v=1&i=\(UUID().uuidString)&t=Hi")!)) {
            XCTAssertEqual($0 as? CountdownPayloadError, .missingField("d"))
        }
        XCTAssertThrowsError(try CountdownPayload(url: URL(string: "?v=1&i=\(UUID().uuidString)&t=Hi&d=2027-02-29")!)) {
            XCTAssertEqual($0 as? CountdownPayloadError, .invalidField("d"))
        }
    }

    func testNewerVersionIsReportedNotMisread() {
        let url = URL(string: "?v=99&i=\(UUID().uuidString)&t=Hi&d=2026-12-15")!
        XCTAssertThrowsError(try CountdownPayload(url: url)) {
            XCTAssertEqual($0 as? CountdownPayloadError, .unsupportedVersion(99))
        }
    }

    func testMissingOrBadStyleFallsBackToModernLive() throws {
        let plain = URL(string: "?v=1&i=\(UUID().uuidString)&t=Hi&d=2026-12-15")!
        let p = try CountdownPayload(url: plain)
        XCTAssertEqual(p.style, CountdownStyle.Preset.modern.style)
        XCTAssertEqual(p.mode, .live)

        let bad = URL(string: "?v=1&i=\(UUID().uuidString)&t=Hi&d=2026-12-15&bg=nope&fg=zzz&m=x")!
        let q = try CountdownPayload(url: bad)
        XCTAssertEqual(q.style, CountdownStyle.Preset.modern.style)
        XCTAssertEqual(q.mode, .live)
    }

    func testSummaryAndAccessibilityTextNeverContainADayCount() {
        let gb = Locale(identifier: "en_GB")
        let p = CountdownPayload(title: "Party", eventDate: date, emoji: "🎉")
        XCTAssertEqual(p.summaryText(locale: gb), "🎉 Party \u{00B7} 15 Dec")
        XCTAssertEqual(CountdownPayload(title: "Party", eventDate: date).summaryText(locale: gb), "Party \u{00B7} 15 Dec")
        XCTAssertEqual(p.accessibilityDescription(locale: gb), "Countdown to Party on 15 December 2026")
        XCTAssertFalse(p.summaryText(locale: gb).uppercased().contains("DAYS"))
    }

    // MARK: Link format (what people without the app open when they tap a bubble)

    func testDefaultLinkIsQueryItemsOnly() {
        guard CountdownLink.base == nil else { return }
        let url = CountdownPayload(title: "Party", eventDate: date).encodedURL()
        XCTAssertNil(url.scheme)
        XCTAssertTrue(url.absoluteString.hasPrefix("?v=1"))
    }

    func testLinkIsARealHTTPSAddress() {
        guard CountdownLink.base != nil else { return }
        let url = CountdownPayload(title: "Party", eventDate: date).encodedURL()
        XCTAssertEqual(url.scheme, "https")
        XCTAssertFalse((url.host ?? "").isEmpty)
    }

    func testDetailsTravelInTheFragmentSoServersNeverSeeThem() {
        guard CountdownLink.base != nil, CountdownLink.style == .fragment else { return }
        let url = CountdownPayload(title: "Secret surprise party", eventDate: date).encodedURL()
        XCTAssertNil(url.query)
        XCTAssertTrue(url.fragment?.contains("Secret surprise party") ?? false)
        XCTAssertFalse(url.absoluteString.contains("?"))
    }

    func testStillDecodesQueryStyleLinks() throws {
        let id = UUID()
        let url = URL(string: "https://example.com/c?v=1&i=\(id.uuidString)&t=Old&d=2026-12-15")!
        let p = try CountdownPayload(url: url)
        XCTAssertEqual(p.title, "Old")
        XCTAssertEqual(p.id, id)
    }

    func testFragmentWinsOverUnrelatedQueryItems() throws {
        let id = UUID()
        let url = URL(string: "https://example.com/c?utm_source=x#v=1&i=\(id.uuidString)&t=Hi&d=2026-12-15")!
        XCTAssertEqual(try CountdownPayload(url: url).title, "Hi")
    }
}
