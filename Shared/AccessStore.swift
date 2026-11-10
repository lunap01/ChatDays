import Foundation
import Combine
import StoreKit
import CountdownCore

enum AppGroup {
    /// Must match the App Groups capability on BOTH the ChatDays and ChatDaysMessages targets.
    static let id = "group.com.paul.ChatDays"
}

enum Products {
    /// Non-consumable in-app purchase. Create the same ID in App Store Connect.
    static let unlockID = "com.paul.ChatDays.unlock"
}

enum AccessPolicy {
    /// false: a countdown uses a free slot when the person taps Send (didStartSending).
    /// true: it uses a slot as soon as it is inserted into the message field.
    /// Flip this if didStartSending turns out not to fire reliably on device.
    static let countAtInsert = false
}

/// Free allowance plus the one-time unlock. Shared by the app and the extension.
@MainActor
final class AccessStore: ObservableObject {
    @Published private(set) var ledger: UsageLedger
    @Published private(set) var isUnlocked: Bool
    @Published private(set) var priceText: String?
    @Published private(set) var isWorking = false
    @Published var message: String?

    private let storage: UsageStorage
    private var product: Product?
    private var storeKitUnlocked: Bool

    init() {
        let defaults = UserDefaults(suiteName: AppGroup.id) ?? .standard
        storage = UsageStorage(defaults: defaults)
        ledger = storage.loadLedger()
        storeKitUnlocked = storage.cachedUnlocked
        isUnlocked = storage.cachedUnlocked || storage.developerUnlocked

        // Purchases that complete outside the app (Ask to Buy approvals, other devices).
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    // MARK: Allowance

    var canSend: Bool { ledger.canSend(unlocked: isUnlocked) }
    var remainingFree: Int { ledger.remainingFree }

    func recordSend(_ id: UUID) {
        guard !isUnlocked else { return }
        var updated = ledger
        if updated.record(id) {
            ledger = updated
            storage.saveLedger(updated)
        }
    }

    /// The app and the extension are separate processes; pick up what the other wrote.
    func reloadFromDisk() {
        ledger = storage.loadLedger()
        storeKitUnlocked = storage.cachedUnlocked
        recomputeUnlocked()
    }

    // MARK: Testing aids (the controls that call these exist only in debug builds)

    var isDeveloperUnlocked: Bool { storage.developerUnlocked }

    func setDeveloperUnlocked(_ on: Bool) {
        storage.developerUnlocked = on
        recomputeUnlocked()
    }

    func resetUsage() {
        storage.resetLedger()
        ledger = UsageLedger()
    }

    // MARK: StoreKit

    func refresh() async {
        do {
            product = try await Product.products(for: [Products.unlockID]).first
            priceText = product?.displayPrice
            if product == nil {
                #if DEBUG
                message = "Product \(Products.unlockID) wasn't found. Check that the scheme you ran has the StoreKit Configuration set."
                #else
                message = "The unlock isn't available right now. Please try again later."
                #endif
            } else {
                message = nil
            }
        } catch {
            message = "Couldn't load the price. Check your connection."
        }
        await updateEntitlement()
    }

    func purchase() async {
        guard let product else {
            message = "The unlock isn't available right now."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
            case .userCancelled:
                break
            case .pending:
                message = "Your purchase is waiting for approval."
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
            await updateEntitlement()
            if !isUnlocked { message = "No previous purchase was found for this Apple Account." }
        } catch {
            message = "Couldn't restore purchases. Please try again."
        }
    }

    private func updateEntitlement() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Products.unlockID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        setStoreKitUnlocked(unlocked)
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            message = "The purchase couldn't be verified."
            return
        }
        if transaction.productID == Products.unlockID {
            setStoreKitUnlocked(transaction.revocationDate == nil)
        }
        await transaction.finish()
    }

    private func setStoreKitUnlocked(_ value: Bool) {
        storeKitUnlocked = value
        storage.cachedUnlocked = value
        recomputeUnlocked()
    }

    private func recomputeUnlocked() {
        isUnlocked = storeKitUnlocked || storage.developerUnlocked
    }
}
