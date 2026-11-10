import XCTest
@testable import CountdownCore

final class LibraryTests: XCTestCase {
    func date(_ y: Int, _ m: Int, _ d: Int) -> EventDate { EventDate(year: y, month: m, day: d)! }
    let stamp = Date(timeIntervalSince1970: 1_800_000_000)

    func item(_ title: String, _ y: Int, _ m: Int, _ d: Int, created: TimeInterval = 0) -> SavedCountdown {
        SavedCountdown(title: title, eventDate: date(y, m, d), createdAt: stamp.addingTimeInterval(created))
    }

    func testUpsertAddsThenReplaces() {
        var library = CountdownLibrary()
        var a = item("Holiday", 2026, 12, 15)
        library.upsert(a)
        XCTAssertEqual(library.items.count, 1)
        a.title = "Family Holiday"
        library.upsert(a)
        XCTAssertEqual(library.items.count, 1)
        XCTAssertEqual(library.item(id: a.id)?.title, "Family Holiday")
    }

    func testRemove() {
        var library = CountdownLibrary()
        let a = item("A", 2026, 12, 15)
        library.upsert(a)
        library.remove(id: a.id)
        XCTAssertTrue(library.items.isEmpty)
    }

    func testSortingUpcomingFirstThenPast() {
        var library = CountdownLibrary()
        library.upsert(item("Later", 2027, 1, 1))
        library.upsert(item("Old", 2026, 1, 1))
        library.upsert(item("Today", 2026, 11, 9))
        library.upsert(item("Sooner", 2026, 12, 1))
        library.upsert(item("Older", 2025, 6, 1))
        let titles = library.sorted(today: date(2026, 11, 9)).map(\.title)
        XCTAssertEqual(titles, ["Today", "Sooner", "Later", "Old", "Older"])
    }

    func testFullLibraryDropsTheOldest() {
        var library = CountdownLibrary()
        for i in 0..<CountdownLibrary.maxItems {
            library.upsert(item("n\(i)", 2027, 1, 1, created: TimeInterval(i + 1)))
        }
        let oldest = library.items.first!
        library.upsert(item("newest", 2027, 1, 2, created: 10_000))
        XCTAssertEqual(library.items.count, CountdownLibrary.maxItems)
        XCTAssertNil(library.item(id: oldest.id))
        XCTAssertTrue(library.items.contains { $0.title == "newest" })
    }

    func testFileStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("lib-\(UUID().uuidString)")
        let store = LibraryFileStore(url: dir.appendingPathComponent("nested/countdowns.json"))
        XCTAssertTrue(store.load().items.isEmpty)

        var library = CountdownLibrary()
        library.upsert(SavedCountdown(title: "Wedding 💍", eventDate: date(2027, 3, 20), emoji: "💍",
                                      mode: .fixed, style: CountdownStyle.Preset.celebration.style,
                                      createdAt: stamp))
        try store.save(library)
        XCTAssertEqual(store.load(), library)
        try? FileManager.default.removeItem(at: dir)
    }

    func testCorruptFileLoadsEmpty() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bad-\(UUID().uuidString).json")
        try Data("nope".utf8).write(to: url)
        XCTAssertTrue(LibraryFileStore(url: url).load().items.isEmpty)
        try? FileManager.default.removeItem(at: url)
    }

    func testEachSendGetsAFreshPayloadID() {
        let saved = item("Party", 2026, 12, 15)
        XCTAssertNotEqual(saved.payload().id, saved.payload().id)
        XCTAssertEqual(saved.payload().title, "Party")
        XCTAssertEqual(saved.payload(id: saved.id).id, saved.id)
    }
}
