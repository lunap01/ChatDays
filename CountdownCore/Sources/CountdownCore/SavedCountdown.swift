import Foundation

/// A countdown kept in "My countdowns" so it can be sent again or edited.
/// Each send gets a fresh payload ID (see `payload(id:)`), so sending a saved
/// countdown to another chat is counted as a new send.
public struct SavedCountdown: Equatable, Codable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var eventDate: EventDate
    public var emoji: String?
    public var mode: CountdownMode
    public var style: CountdownStyle
    public var createdAt: Date

    public init(id: UUID = UUID(),
                title: String,
                eventDate: EventDate,
                emoji: String? = nil,
                mode: CountdownMode = .live,
                style: CountdownStyle = CountdownStyle.Preset.modern.style,
                createdAt: Date = Date()) {
        self.id = id
        self.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(CountdownPayload.maxTitleLength))
        if let first = emoji?.first { self.emoji = String(first) } else { self.emoji = nil }
        self.eventDate = eventDate
        self.mode = mode
        self.style = style
        self.createdAt = createdAt
    }

    /// What to send. Pass no ID to get a new one for every send.
    public func payload(id: UUID = UUID()) -> CountdownPayload {
        CountdownPayload(id: id, title: title, eventDate: eventDate, emoji: emoji, mode: mode, style: style)
    }
}

public struct CountdownLibrary: Equatable, Codable, Sendable {
    public static let maxItems = 200

    public private(set) var items: [SavedCountdown]

    public init(items: [SavedCountdown] = []) {
        self.items = items
    }

    /// Replaces the countdown with the same ID, or adds it. When the library is
    /// full, the oldest countdown is dropped.
    public mutating func upsert(_ item: SavedCountdown) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.append(item)
            if items.count > CountdownLibrary.maxItems,
               let oldest = items.enumerated().min(by: { $0.element.createdAt < $1.element.createdAt }) {
                items.remove(at: oldest.offset)
            }
        }
    }

    public mutating func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    public func item(id: UUID) -> SavedCountdown? {
        items.first { $0.id == id }
    }

    /// Upcoming and today first, soonest on top; then past ones, most recent first.
    public func sorted(today: EventDate) -> [SavedCountdown] {
        let upcoming = items
            .filter { $0.eventDate >= today }
            .sorted { ($0.eventDate, $0.title) < ($1.eventDate, $1.title) }
        let past = items
            .filter { $0.eventDate < today }
            .sorted { $0.eventDate > $1.eventDate }
        return upcoming + past
    }
}

/// Reads and writes the library as one JSON file. The app and the Messages
/// extension point this at the same file in the App Group container.
public struct LibraryFileStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> CountdownLibrary {
        guard let data = try? Data(contentsOf: url) else { return CountdownLibrary() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(CountdownLibrary.self, from: data)) ?? CountdownLibrary()
    }

    public func save(_ library: CountdownLibrary) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(library)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
