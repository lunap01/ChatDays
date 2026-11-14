import XCTest
@testable import CountdownCore

final class ShareTests: XCTestCase {
    let site = URL(string: "https://example.github.io/chatdays-support/")!
    let date = EventDate(year: 2026, month: 12, day: 15)!

    func testNoSiteAddressMeansNoLink() {
        let payload = CountdownPayload(title: "Party", eventDate: date)
        XCTAssertNil(payload.shareURL(base: nil))
    }

    func testShareLinkIsAnHTTPSAddressWithTheDetailsInTheFragment() throws {
        let payload = CountdownPayload(title: "Family Holiday", eventDate: date, emoji: "🏖️",
                                       style: CountdownStyle.Preset.holiday.style)
        let url = try XCTUnwrap(payload.shareURL(base: site))
        // URLComponents keeps the trailing slash; URL.path strips it.
        let comps = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(comps.scheme, "https")
        XCTAssertEqual(comps.host, "example.github.io")
        XCTAssertEqual(comps.path, "/chatdays-support/")
        XCTAssertNil(comps.query, "details must not be sent to the server")

        // The fragment is percent-encoded, so parse it rather than string-match.
        let fragment = try XCTUnwrap(comps.percentEncodedFragment)
        let items = try XCTUnwrap(URLComponents(string: "?" + fragment)?.queryItems)
        let values = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(values["t"], "Family Holiday")
        XCTAssertEqual(values["d"], "2026-12-15")
        XCTAssertEqual(values["bg"], "C2410C")
        XCTAssertEqual(values["bg2"], "BE123C")
        XCTAssertEqual(values["fg"], "FFFFFF")
        XCTAssertFalse((values["e"] ?? "").isEmpty)
    }

    func testShareLinkLeavesOutInternalDetails() throws {
        let payload = CountdownPayload(title: "Party", eventDate: date, sentOn: date)
        let fragment = try XCTUnwrap(payload.shareURL(base: site)?.fragment)
        XCTAssertFalse(fragment.contains(payload.id.uuidString))
        XCTAssertFalse(fragment.contains("s="))
        XCTAssertFalse(fragment.contains("i="))
    }

    func testAwkwardTitlesAreEncoded() throws {
        let payload = CountdownPayload(title: "Sarah & James #1 + party", eventDate: date)
        let url = try XCTUnwrap(payload.shareURL(base: site))
        let raw = url.absoluteString
        XCTAssertFalse(raw.contains(" "))
        // Exactly one '#', the start of the fragment.
        XCTAssertEqual(raw.filter { $0 == "#" }.count, 1)
    }

    func testBaseWithItsOwnQueryIsReplaced() throws {
        let noisy = URL(string: "https://example.github.io/chatdays-support/?utm=x")!
        let url = try XCTUnwrap(CountdownPayload(title: "Hi", eventDate: date).shareURL(base: noisy))
        XCTAssertNil(url.query)
    }

    func testSentences() {
        XCTAssertEqual(CountdownState.daysRemaining(42).sentence(about: "Family Holiday"), "42 days until Family Holiday")
        XCTAssertEqual(CountdownState.tomorrow.sentence(about: "Concert"), "Concert is tomorrow")
        XCTAssertEqual(CountdownState.today.sentence(about: "Concert"), "Concert is today!")
        XCTAssertEqual(CountdownState.passed(daysAgo: 1).sentence(about: "Concert"), "Concert was yesterday")
        XCTAssertEqual(CountdownState.passed(daysAgo: 3).sentence(about: "Concert"), "Concert was 3 days ago")
    }
}

