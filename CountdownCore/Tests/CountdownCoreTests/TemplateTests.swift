import XCTest
@testable import CountdownCore

final class TemplateTests: XCTestCase {
    func testEveryTemplateHasOneEmojiAndAReadableLook() {
        for template in CountdownTemplate.allCases {
            XCTAssertEqual(template.emoji.count, 1, "\(template) should use a single emoji")
            XCTAssertTrue(template.style.isReadable, "\(template) should be readable")
            XCTAssertFalse(template.suggestedTitle.isEmpty)
        }
    }

    func testTemplateIDsAreUnique() {
        let ids = CountdownTemplate.allCases.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testEmptyOrSuggestedTitlesAreReplaced() {
        XCTAssertEqual(CountdownTemplate.birthday.title(replacing: ""), "Birthday")
        XCTAssertEqual(CountdownTemplate.birthday.title(replacing: "   "), "Birthday")
        XCTAssertEqual(CountdownTemplate.wedding.title(replacing: "Birthday"), "Wedding")
        XCTAssertEqual(CountdownTemplate.gameDay.title(replacing: " Party "), "Game day")
    }

    func testTypedTitlesAreKept() {
        XCTAssertEqual(CountdownTemplate.holiday.title(replacing: "Sarah's 40th"), "Sarah's 40th")
        XCTAssertEqual(CountdownTemplate.concert.title(replacing: "Taylor Swift"), "Taylor Swift")
    }
}
