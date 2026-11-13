import XCTest
@testable import CountdownCore

final class CountUpTests: XCTestCase {
    func date(_ y: Int, _ m: Int, _ d: Int) -> EventDate { EventDate(year: y, month: m, day: d)! }

    func elapsed(from event: EventDate, to today: EventDate) -> CountdownState {
        CountdownCalculator.state(for: event, today: today, countsUp: true)
    }

    // MARK: Direction

    func testPassedDateCountsUpWhenAsked() {
        let event = date(2026, 11, 1)
        let today = date(2026, 11, 3)
        XCTAssertEqual(elapsed(from: event, to: today), .elapsed(days: 2, years: 0, months: 0))
        XCTAssertEqual(CountdownCalculator.state(for: event, today: today, countsUp: false), .passed(daysAgo: 2))
    }

    func testFutureAndTodayAreUnchangedByCountingUp() {
        let today = date(2026, 11, 3)
        XCTAssertEqual(elapsed(from: date(2026, 12, 15), to: today), .daysRemaining(42))
        XCTAssertEqual(elapsed(from: date(2026, 11, 4), to: today), .tomorrow)
        XCTAssertEqual(elapsed(from: today, to: today), .today)
    }

    // MARK: Years and months

    func testUnderAYearShowsDays() {
        // 364 days: still days, even though it is nearly a year.
        let state = elapsed(from: date(2025, 11, 13), to: date(2026, 11, 12))
        XCTAssertEqual(state.headline, "364 DAYS")
        XCTAssertNil(state.elapsedDaysText(locale: Locale(identifier: "en_US")))
        XCTAssertEqual(elapsed(from: date(2026, 11, 11), to: date(2026, 11, 12)).headline, "1 DAY")
    }

    func testExactlyOneYear() {
        let state = elapsed(from: date(2025, 11, 12), to: date(2026, 11, 12))
        XCTAssertEqual(state, .elapsed(days: 365, years: 1, months: 0))
        XCTAssertEqual(state.headline, "1 YEAR")
    }

    func testYearsAndMonths() {
        let one = elapsed(from: date(2025, 10, 12), to: date(2026, 11, 12))
        XCTAssertEqual(one, .elapsed(days: 396, years: 1, months: 1))
        XCTAssertEqual(one.headline, "1 YEAR, 1 MONTH")

        let long = elapsed(from: date(2019, 3, 13), to: date(2026, 11, 12))
        XCTAssertEqual(long, .elapsed(days: 2801, years: 7, months: 7))
        XCTAssertEqual(long.headline, "7 YEARS, 7 MONTHS")
        XCTAssertEqual(long.sentence(about: "Us"), "7 years, 7 months since Us")
        XCTAssertEqual(long.elapsedDaysText(locale: Locale(identifier: "en_US")), "2,801 days")
    }

    func testWholeYearsDropTheMonths() {
        // 1 Jan 2020 to 1 Jan 2026: six years, two of them leap.
        let state = elapsed(from: date(2020, 1, 1), to: date(2026, 1, 1))
        XCTAssertEqual(state, .elapsed(days: 2192, years: 6, months: 0))
        XCTAssertEqual(state.headline, "6 YEARS")
    }

    func testBeforeTheMonthIsCompleteItIsNotCounted() {
        // 13 March to 12 November: the seventh month isn't complete until the 13th.
        let state = elapsed(from: date(2019, 3, 13), to: date(2026, 11, 12))
        if case .elapsed(_, _, let months) = state { XCTAssertEqual(months, 7) } else { XCTFail("expected elapsed") }
        let next = elapsed(from: date(2019, 3, 13), to: date(2026, 11, 13))
        if case .elapsed(_, _, let months) = next { XCTAssertEqual(months, 8) } else { XCTFail("expected elapsed") }
    }

    // MARK: Wording

    func testWording() {
        XCTAssertEqual(CountdownState.elapsed(days: 1, years: 0, months: 0).sentence(about: "Us"), "1 day since Us")
        XCTAssertEqual(CountdownState.elapsed(days: 30, years: 0, months: 1).sentence(about: "Us"), "30 days since Us")
        XCTAssertEqual(CountdownState.elapsed(days: 3000, years: 8, months: 2).headline, "8 YEARS, 2 MONTHS")
        XCTAssertEqual(CountdownState.elapsed(days: 30, years: 0, months: 1).signedDays, -30)
    }

    // MARK: Payload and sharing

    func testPayloadCarriesTheFlag() throws {
        let on = CountdownPayload(title: "Us", eventDate: date(2019, 3, 13), countsUp: true)
        XCTAssertTrue(on.encodedURL().absoluteString.contains("u=1"))
        XCTAssertTrue(try CountdownPayload(url: on.encodedURL()).countsUp)

        let off = CountdownPayload(title: "Us", eventDate: date(2019, 3, 13))
        XCTAssertFalse(off.encodedURL().absoluteString.contains("u="))
        XCTAssertFalse(try CountdownPayload(url: off.encodedURL()).countsUp)
    }

    func testShareLinkCarriesTheFlag() throws {
        let site = URL(string: "https://example.github.io/chatdays-support/")!
        let fragment = try XCTUnwrap(CountdownPayload(title: "Us", eventDate: date(2019, 3, 13), countsUp: true)
            .shareURL(base: site)?.fragment)
        XCTAssertTrue(fragment.contains("u=1"))
    }

    func testAccessibilityDescriptionForCountUp() {
        let gb = Locale(identifier: "en_GB")
        let p = CountdownPayload(title: "Us", eventDate: date(2019, 3, 13), countsUp: true)
        XCTAssertEqual(p.accessibilityDescription(locale: gb), "Days since Us, from 13 March 2019")
    }

    // MARK: Saved countdowns

    func testOldSavedLibrariesStillLoad() throws {
        let json = """
        {"items":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Old","eventDate":"2026-12-15","mode":"l",
        "style":{"background":{"red":18,"green":32,"blue":74},"text":{"red":255,"green":255,"blue":255}},
        "createdAt":"2026-11-01T00:00:00Z"}]}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let library = try decoder.decode(CountdownLibrary.self, from: Data(json.utf8))
        XCTAssertEqual(library.items.count, 1)
        XCTAssertFalse(library.items[0].countsUp)
        XCTAssertNil(library.items[0].emoji)
    }

    func testSavedCountdownRoundTripKeepsTheFlag() throws {
        let saved = SavedCountdown(title: "Us", eventDate: date(2019, 3, 13), countsUp: true,
                                   createdAt: Date(timeIntervalSince1970: 1_800_000_000))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let back = try decoder.decode(SavedCountdown.self, from: try encoder.encode(saved))
        XCTAssertEqual(back, saved)
        XCTAssertTrue(back.payload().countsUp)
    }

    func testCountingUpItemsSortBetweenUpcomingAndPast() {
        let stamp = Date(timeIntervalSince1970: 1_800_000_000)
        func item(_ title: String, _ d: EventDate, up: Bool = false) -> SavedCountdown {
            SavedCountdown(title: title, eventDate: d, countsUp: up, createdAt: stamp)
        }
        var library = CountdownLibrary()
        library.upsert(item("Old event", date(2025, 6, 1)))
        library.upsert(item("Anniversary", date(2019, 3, 13), up: true))
        library.upsert(item("Soon", date(2026, 12, 1)))
        library.upsert(item("Newer anniversary", date(2024, 5, 5), up: true))
        let titles = library.sorted(today: date(2026, 11, 9)).map(\.title)
        XCTAssertEqual(titles, ["Soon", "Newer anniversary", "Anniversary", "Old event"])
    }

    func testOnlyTheAnniversaryTemplateCountsUp() {
        for template in CountdownTemplate.allCases {
            XCTAssertEqual(template.countsUp, template == .anniversary)
        }
    }
}

