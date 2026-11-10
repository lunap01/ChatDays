import Foundation
import CountdownCore

/// The values being edited in the form, in the shapes the controls need
/// (a `Date` for the date picker, a `String` for the emoji field).
struct CountdownDraft: Equatable {
    /// Set when this started from a saved countdown, so saving updates it.
    var savedID: UUID?
    var title: String
    var emoji: String
    var date: Date
    var mode: CountdownMode
    var style: CountdownStyle

    init(savedID: UUID? = nil,
         title: String = "",
         emoji: String = "",
         date: Date,
         mode: CountdownMode = .live,
         style: CountdownStyle = CountdownStyle.Preset.modern.style) {
        self.savedID = savedID
        self.title = title
        self.emoji = emoji
        self.date = date
        self.mode = mode
        self.style = style
    }

    /// A blank draft dated tomorrow.
    static func new() -> CountdownDraft {
        CountdownDraft(date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    init(_ saved: SavedCountdown) {
        // Noon local time, so the same calendar day comes back out of the picker.
        let noon = Calendar.current.date(from: DateComponents(
            year: saved.eventDate.year, month: saved.eventDate.month, day: saved.eventDate.day, hour: 12)) ?? Date()
        self.init(savedID: saved.id, title: saved.title, emoji: saved.emoji ?? "",
                  date: noon, mode: saved.mode, style: saved.style)
    }

    var cleanTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var eventDate: EventDate { EventDate(date: date, timeZone: .current) }

    /// Fills in emoji, look and (if nothing custom was typed) the title.
    mutating func apply(_ template: CountdownTemplate) {
        title = template.title(replacing: title)
        emoji = template.emoji
        style = template.style
    }

    /// What to send: a new ID every time.
    func payload() -> CountdownPayload {
        CountdownPayload(id: UUID(), title: cleanTitle, eventDate: eventDate,
                         emoji: emoji.isEmpty ? nil : emoji, mode: mode, style: style)
    }

    func saved(createdAt: Date = Date()) -> SavedCountdown {
        SavedCountdown(id: savedID ?? UUID(), title: cleanTitle, eventDate: eventDate,
                       emoji: emoji.isEmpty ? nil : emoji, mode: mode, style: style, createdAt: createdAt)
    }
}
