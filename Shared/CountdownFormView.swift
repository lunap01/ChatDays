import Foundation
import SwiftUI
import CountdownCore

/// Preview and fields for creating or editing a countdown. Used by the Messages
/// extension's composer and the main app's editor.
struct CountdownFormView: View {
    @Binding var draft: CountdownDraft

    private var backgroundBinding: Binding<Color> {
        Binding(
            get: { Color(draft.style.background) },
            set: { if let hex = HexColor(color: $0) { draft.style.background = hex; draft.style.background2 = nil } }
        )
    }

    private var textBinding: Binding<Color> {
        Binding(
            get: { Color(draft.style.text) },
            set: { if let hex = HexColor(color: $0) { draft.style.text = hex } }
        )
    }

    /// Today or later for new countdowns; an older saved date stays selectable.
    private var earliestDate: Date {
        min(Calendar.current.startOfDay(for: Date()), draft.date)
    }

    var body: some View {
        VStack(spacing: 14) {
            CountdownCardView(
                content: .countdown(CountdownCalculator.state(for: draft.eventDate)),
                title: draft.cleanTitle.isEmpty ? "Event name" : draft.cleanTitle,
                emoji: draft.emoji.isEmpty ? nil : String(draft.emoji.prefix(1)),
                eventDate: draft.eventDate,
                style: draft.style
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("Templates")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CountdownTemplate.allCases) { template in
                            Button {
                                draft.apply(template)
                            } label: {
                                Text("\(template.emoji) \(template.name)")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.secondary.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("Event name", text: $draft.title)
                .textFieldStyle(.roundedBorder)
            TextField("Emoji (optional)", text: $draft.emoji)
                .textFieldStyle(.roundedBorder)
            DatePicker("Date", selection: $draft.date, in: earliestDate..., displayedComponents: .date)

            HStack(spacing: 8) {
                ForEach(CountdownStyle.Preset.allCases) { preset in
                    Button {
                        draft.style = preset.style
                    } label: {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(preset.style.background),
                                         Color(preset.style.background2 ?? preset.style.background)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 36)
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.secondary.opacity(0.4)))
                    }
                    .accessibilityLabel(preset.title)
                }
            }
            ColorPicker("Background", selection: backgroundBinding, supportsOpacity: false)
            ColorPicker("Text", selection: textBinding, supportsOpacity: false)
            if !draft.style.isReadable {
                Text("Those colours are hard to read together, so the text colour will be adjusted automatically.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Picker("Type", selection: $draft.mode) {
                Text("Live").tag(CountdownMode.live)
                Text("Static").tag(CountdownMode.fixed)
            }
            .pickerStyle(.segmented)
            Text(draft.mode == .live
                 ? "Updates every day. Friends without ChatDays see the event and date, with a prompt to get the app."
                 : "A fixed picture of the countdown as it is today. Works for everyone.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
