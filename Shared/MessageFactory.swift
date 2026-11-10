import Foundation
import Messages
import UIKit
import SwiftUI
import CountdownCore

/// Builds the MSMessage for a countdown. Shared by the Messages extension and
/// the host app (which tests sending through MFMessageComposeViewController).
@MainActor
enum MessageFactory {

    static func make(payload: CountdownPayload,
                     now: Date = Date(),
                     timeZone: TimeZone = .current) -> MSMessage {
        var outgoing = payload
        let today = EventDate(date: now, timeZone: timeZone)
        outgoing.sentOn = today
        let state = CountdownCalculator.state(for: outgoing.eventDate, now: now, timeZone: timeZone)

        let message = MSMessage(session: MSSession())
        message.url = outgoing.encodedURL()
        // Conversation list and notifications: the event, never a (stale) number.
        message.summaryText = outgoing.summaryText()
        message.accessibilityLabel = outgoing.accessibilityDescription()

        switch outgoing.mode {
        case .fixed:
            // Static: a picture of the countdown as it stands today.
            message.layout = template(for: outgoing,
                                      content: .countdown(state),
                                      subcaption: "As of \(today.displayString(short: true))")
        case .live:
            // Dynamic: people with ChatDays see the live bubble; everyone else
            // sees this event-and-date card with a download prompt.
            let fallback = template(for: outgoing,
                                    content: .fallback,
                                    subcaption: outgoing.eventDate.displayString())
            message.layout = MSMessageLiveLayout(alternateLayout: fallback)
        }
        return message
    }

    private static func template(for payload: CountdownPayload,
                                 content: CardContent,
                                 subcaption: String) -> MSMessageTemplateLayout {
        let card = CountdownCardView(content: content,
                                     title: payload.title,
                                     emoji: payload.emoji,
                                     eventDate: payload.eventDate,
                                     style: payload.style)
        let layout = MSMessageTemplateLayout()
        layout.image = render(card)
        layout.caption = payload.title
        layout.subcaption = subcaption
        return layout
    }

    private static func render(_ card: CountdownCardView) -> UIImage? {
        let renderer = ImageRenderer(content: card.frame(width: 300, height: 200))
        renderer.scale = 3
        return renderer.uiImage
    }
}
