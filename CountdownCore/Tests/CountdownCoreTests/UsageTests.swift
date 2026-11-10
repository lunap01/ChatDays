import XCTest
@testable import CountdownCore

final class UsageTests: XCTestCase {

    func testFiveFreeThenBlocked() {
        var ledger = UsageLedger()
        XCTAssertEqual(ledger.remainingFree, 5)
        for used in 0..<5 {
            XCTAssertTrue(ledger.canSend(unlocked: false), "slot \(used + 1) should be allowed")
            ledger.record(UUID())
        }
        XCTAssertEqual(ledger.sentCount, 5)
        XCTAssertEqual(ledger.remainingFree, 0)
        XCTAssertFalse(ledger.canSend(unlocked: false))
    }

    func testUnlockedAlwaysCanSend() {
        var ledger = UsageLedger()
        for _ in 0..<20 { ledger.record(UUID()) }
        XCTAssertTrue(ledger.canSend(unlocked: true))
    }

    func testSameCountdownIsCountedOnce() {
        var ledger = UsageLedger()
        let id = UUID()
        XCTAssertTrue(ledger.record(id))
        XCTAssertFalse(ledger.record(id))
        XCTAssertEqual(ledger.sentCount, 1)
    }

    func testTrimmingNeverReopensTheFreeAllowance() {
        var ledger = UsageLedger()
        for _ in 0..<(UsageLedger.maxTracked + 25) { ledger.record(UUID()) }
        XCTAssertEqual(ledger.sentCount, UsageLedger.maxTracked)
        XCTAssertFalse(ledger.canSend(unlocked: false))
    }

    func testStorageRoundTrip() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let storage = UsageStorage(defaults: defaults)
        XCTAssertEqual(storage.loadLedger(), UsageLedger())
        XCTAssertFalse(storage.cachedUnlocked)

        var ledger = UsageLedger()
        ledger.record(UUID())
        ledger.record(UUID())
        storage.saveLedger(ledger)
        storage.cachedUnlocked = true

        let reopened = UsageStorage(defaults: defaults)
        XCTAssertEqual(reopened.loadLedger(), ledger)
        XCTAssertTrue(reopened.cachedUnlocked)
    }

    func testDeveloperUnlockAndReset() {
        let storage = UsageStorage(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        XCTAssertFalse(storage.developerUnlocked)
        storage.developerUnlocked = true
        XCTAssertTrue(storage.developerUnlocked)

        var ledger = UsageLedger()
        ledger.record(UUID())
        storage.saveLedger(ledger)
        storage.resetLedger()
        XCTAssertEqual(storage.loadLedger().sentCount, 0)
    }

    func testCorruptStorageStartsFresh() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        defaults.set(Data("not json".utf8), forKey: "chatdays.usage.v1")
        XCTAssertEqual(UsageStorage(defaults: defaults).loadLedger(), UsageLedger())
    }
}
