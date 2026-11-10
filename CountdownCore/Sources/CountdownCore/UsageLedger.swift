import Foundation

/// Which countdowns have been sent, used to enforce the free allowance.
/// Counting by countdown ID (not a bare number) means a repeated callback for
/// the same message can never use up two free slots.
public struct UsageLedger: Equatable, Codable, Sendable {
    public static let freeLimit = 5
    /// Older IDs are dropped beyond this; the count stays above `freeLimit`.
    static let maxTracked = 50

    public private(set) var countedIDs: [UUID]

    public init(countedIDs: [UUID] = []) {
        self.countedIDs = countedIDs
    }

    public var sentCount: Int { countedIDs.count }
    public var remainingFree: Int { max(0, UsageLedger.freeLimit - sentCount) }

    public func canSend(unlocked: Bool) -> Bool {
        unlocked || sentCount < UsageLedger.freeLimit
    }

    /// Returns true if this was a new countdown that used a free slot.
    @discardableResult
    public mutating func record(_ id: UUID) -> Bool {
        guard !countedIDs.contains(id) else { return false }
        countedIDs.append(id)
        if countedIDs.count > UsageLedger.maxTracked {
            countedIDs.removeFirst(countedIDs.count - UsageLedger.maxTracked)
        }
        return true
    }
}

/// Reads and writes usage in a `UserDefaults` suite. The app and the Messages
/// extension share one suite through an App Group.
public struct UsageStorage {
    private let defaults: UserDefaults
    private static let ledgerKey = "chatdays.usage.v1"
    private static let unlockedKey = "chatdays.unlocked.v1"
    private static let developerKey = "chatdays.devunlock.v1"

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public func loadLedger() -> UsageLedger {
        guard let data = defaults.data(forKey: UsageStorage.ledgerKey),
              let ledger = try? JSONDecoder().decode(UsageLedger.self, from: data) else {
            return UsageLedger()
        }
        return ledger
    }

    public func saveLedger(_ ledger: UsageLedger) {
        if let data = try? JSONEncoder().encode(ledger) {
            defaults.set(data, forKey: UsageStorage.ledgerKey)
        }
    }

    /// Testing aid: treat the app as unlocked without a purchase. Only the
    /// debug build's developer controls ever set this.
    public var developerUnlocked: Bool {
        get { defaults.bool(forKey: UsageStorage.developerKey) }
        nonmutating set { defaults.set(newValue, forKey: UsageStorage.developerKey) }
    }

    /// Testing aid: forget which countdowns were sent.
    public func resetLedger() {
        defaults.removeObject(forKey: UsageStorage.ledgerKey)
    }

    /// The last purchase state StoreKit reported, so screens can show it instantly.
    /// StoreKit remains the source of truth and refreshes this.
    public var cachedUnlocked: Bool {
        get { defaults.bool(forKey: UsageStorage.unlockedKey) }
        nonmutating set { defaults.set(newValue, forKey: UsageStorage.unlockedKey) }
    }
}
