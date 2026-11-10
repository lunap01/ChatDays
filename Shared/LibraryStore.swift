import Foundation
import Combine
import CountdownCore

/// "My countdowns", shared between the app and the Messages extension through
/// a JSON file in the App Group container.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var library = CountdownLibrary()
    private let file: LibraryFileStore

    init() {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                             appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        file = LibraryFileStore(url: base.appendingPathComponent("countdowns.json"))
        library = file.load()
    }

    var items: [SavedCountdown] {
        library.sorted(today: EventDate(date: Date(), timeZone: .current))
    }

    /// The app and the extension are separate processes; pick up what the other saved.
    func reload() {
        library = file.load()
    }

    @discardableResult
    func save(_ draft: CountdownDraft) -> SavedCountdown {
        reload()
        var saved = draft.saved()
        if let existing = library.item(id: saved.id) { saved.createdAt = existing.createdAt }
        library.upsert(saved)
        persist()
        return saved
    }

    func delete(_ id: UUID) {
        reload()
        library.remove(id: id)
        persist()
    }

    private func persist() {
        try? file.save(library)
    }
}
