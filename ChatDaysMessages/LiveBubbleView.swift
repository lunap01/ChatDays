import Foundation
import SwiftUI
import CountdownCore

/// Refreshes once at each local midnight, not every second.
struct MidnightSchedule: TimelineSchedule {
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> UnfoldFirstSequence<Date> {
        sequence(first: startDate) { CountdownCalculator.nextMidnight(after: $0) }
    }
}

/// What the transcript shows for a dynamic countdown on a phone with ChatDays.
struct LiveBubbleView: View {
    let payload: CountdownPayload
    var onTap: () -> Void = {}

    var body: some View {
        TimelineView(MidnightSchedule()) { context in
            CountdownCardView(
                content: .countdown(CountdownCalculator.state(for: payload.eventDate, now: context.date,
                                                              countsUp: payload.countsUp)),
                title: payload.title,
                emoji: payload.emoji,
                eventDate: payload.eventDate,
                style: payload.style
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)   // a live bubble swallows taps; ask Messages to open ChatDays
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(payload.accessibilityDescription())
        .accessibilityAddTraits(.isButton)
    }
}

/// Shown only if a transcript instance can't read its message.
struct PlaceholderBubble: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(CountdownStyle.Preset.modern.style.background),
                                    Color(CountdownStyle.Preset.modern.style.background2 ?? CountdownStyle.Preset.modern.style.background)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text("ChatDays")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

