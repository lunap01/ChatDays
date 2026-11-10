import Foundation

/// `live` is the dynamic countdown (a live bubble that recomputes the days
/// each time it is shown). `fixed` is the static one (a picture of the
/// countdown on the day it was sent).
public enum CountdownMode: String, Sendable, CaseIterable, Codable {
    case live = "l"
    case fixed = "f"
}

public enum CountdownPayloadError: Error, Equatable {
    case notACountdownURL
    case missingField(String)
    case invalidField(String)
    /// Sent by a newer app version. Show the fallback bubble instead.
    case unsupportedVersion(Int)
}

/// How the countdown details are written into `MSMessage.url`.
///
/// Testing showed that when someone WITHOUT the app taps a bubble, Messages
/// opens the App Store (the app's page once it is published) and does not open
/// the message URL, so the URL only needs to carry data for the extension. With
/// `base` nil the details are plain query items (`?v=1&t=...`), the format
/// proven to work. Set `base` to a web address only for a future "share as
/// link" feature; the details then ride in the fragment (after the `#`), which
/// browsers never send to a server.
public enum CountdownLink {
    public enum Style: Sendable {
        /// `https://host/path#v=1&t=...` (private).
        case fragment
        /// `https://host/path?v=1&t=...`
        case query
    }

    public static let base: URL? = nil
    public static let style: Style = .fragment
}

/// Everything needed to rebuild a countdown from an `MSMessage.url`.
///
/// The details travel as compact `key=value` items (see `CountdownLink`).
/// Messages caps the URL at a few KB (documented as 5120 bytes), so images
/// never travel in here.
public struct CountdownPayload: Equatable, Sendable {
    public static let currentVersion = 1
    public static let maxTitleLength = 60

    public var id: UUID
    public var title: String
    public var eventDate: EventDate
    public var emoji: String?
    public var mode: CountdownMode
    public var style: CountdownStyle
    /// The sender's local date when the message was sent.
    public var sentOn: EventDate?

    public init(id: UUID = UUID(),
                title: String,
                eventDate: EventDate,
                emoji: String? = nil,
                mode: CountdownMode = .live,
                style: CountdownStyle = CountdownStyle.Preset.modern.style,
                sentOn: EventDate? = nil) {
        self.id = id
        self.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(CountdownPayload.maxTitleLength))
        // Keep a single emoji (one Character, so ZWJ sequences stay intact).
        if let first = emoji?.first { self.emoji = String(first) } else { self.emoji = nil }
        self.eventDate = eventDate
        self.mode = mode
        self.style = style
        self.sentOn = sentOn
    }

    // MARK: - Text shown by Messages itself

    /// What the conversation list and notifications show. Deliberately the
    /// event, never a day count: those surfaces are not live.
    public func summaryText(locale: Locale = .current) -> String {
        let date = eventDate.displayString(short: true, locale: locale)
        let name = emoji.map { "\($0) \(title)" } ?? title
        return "\(name) \u{00B7} \(date)"
    }

    public func accessibilityDescription(locale: Locale = .current) -> String {
        "Countdown to \(title) on \(eventDate.displayString(locale: locale))"
    }

    // MARK: - URL encoding

    public func encodedURL() -> URL {
        var items: [URLQueryItem] = [
            .init(name: "v", value: String(CountdownPayload.currentVersion)),
            .init(name: "i", value: id.uuidString),
            .init(name: "t", value: title),
            .init(name: "d", value: eventDate.isoString),
            .init(name: "m", value: mode.rawValue),
            .init(name: "bg", value: style.background.hex),
            .init(name: "fg", value: style.text.hex)
        ]
        if let bg2 = style.background2 { items.append(.init(name: "bg2", value: bg2.hex)) }
        if let pack = style.packID { items.append(.init(name: "pk", value: pack)) }
        if let emoji { items.append(.init(name: "e", value: emoji)) }
        if let sentOn { items.append(.init(name: "s", value: sentOn.isoString)) }

        var payload = URLComponents()
        payload.queryItems = items
        let encoded = payload.percentEncodedQuery ?? ""

        guard let base = CountdownLink.base,
              var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            // Default: query items only, no scheme or host.
            var plain = URLComponents()
            plain.percentEncodedQuery = encoded
            return plain.url!
        }
        switch CountdownLink.style {
        case .fragment:
            comps.percentEncodedFragment = encoded
        case .query:
            comps.percentEncodedQuery = encoded
        }
        return comps.url!
    }

    public init(url: URL) throws {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CountdownPayloadError.notACountdownURL
        }
        // Prefer the fragment (current format); fall back to query items, which
        // is how earlier builds and `.query` style links carry the details.
        var queryItems: [URLQueryItem] = []
        if let fragment = comps.percentEncodedFragment, !fragment.isEmpty {
            var parser = URLComponents()
            parser.percentEncodedQuery = fragment
            queryItems = parser.queryItems ?? []
        }
        if queryItems.isEmpty { queryItems = comps.queryItems ?? [] }
        guard !queryItems.isEmpty else { throw CountdownPayloadError.notACountdownURL }

        var values: [String: String] = [:]
        for item in queryItems {
            if let v = item.value { values[item.name] = v }
        }

        func required(_ key: String) throws -> String {
            guard let v = values[key], !v.isEmpty else { throw CountdownPayloadError.missingField(key) }
            return v
        }

        let version = Int(try required("v")) ?? -1
        guard version >= 1 else { throw CountdownPayloadError.invalidField("v") }
        guard version <= CountdownPayload.currentVersion else {
            throw CountdownPayloadError.unsupportedVersion(version)
        }

        guard let id = UUID(uuidString: try required("i")) else { throw CountdownPayloadError.invalidField("i") }
        guard let date = EventDate(isoString: try required("d")) else { throw CountdownPayloadError.invalidField("d") }
        let title = try required("t")

        // Anything optional or unknown degrades gracefully.
        let mode = values["m"].flatMap(CountdownMode.init(rawValue:)) ?? .live
        var style = CountdownStyle.Preset.modern.style
        if let bg = values["bg"].flatMap(HexColor.init(hex:)),
           let fg = values["fg"].flatMap(HexColor.init(hex:)) {
            style = CountdownStyle(background: bg,
                                   background2: values["bg2"].flatMap(HexColor.init(hex:)),
                                   text: fg,
                                   packID: values["pk"])
        }
        let sentOn = values["s"].flatMap(EventDate.init(isoString:))

        self.init(id: id, title: title, eventDate: date, emoji: values["e"],
                  mode: mode, style: style, sentOn: sentOn)
    }
}
