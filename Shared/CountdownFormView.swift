import Foundation
import SwiftUI
import CountdownCore

/// Preview and fields for creating or editing a countdown. Used by the Messages
/// extension's composer and the main app's editor, so both look the same.
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
        VStack(alignment: .leading, spacing: 22) {
            preview
            templates
            details
            look
            typeChoice
        }
    }

    // MARK: Sections

    /// Exactly the card that will be sent.
    private var preview: some View {
        CountdownCardView(
            content: .countdown(CountdownCalculator.state(for: draft.eventDate, countsUp: draft.countsUp)),
            title: draft.cleanTitle.isEmpty ? "Event name" : draft.cleanTitle,
            emoji: draft.emoji.isEmpty ? nil : String(draft.emoji.prefix(1)),
            eventDate: draft.eventDate,
            style: draft.style
        )
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }

    private var templates: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCaption("Start from a template")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(CountdownTemplate.allCases) { template in
                        Button {
                            draft.apply(template)
                        } label: {
                            Text("\(template.emoji) \(template.name)")
                                .font(.subheadline)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(ChatDaysTheme.panel, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionCaption("Details")
            VStack(spacing: 0) {
                TextField("Event name", text: $draft.title)
                    .padding(14)
                Divider()
                TextField("Emoji (optional)", text: $draft.emoji)
                    .padding(14)
                Divider()
                Group {
                    if draft.countsUp {
                        DatePicker("Date", selection: $draft.date, displayedComponents: .date)
                    } else {
                        DatePicker("Date", selection: $draft.date, in: earliestDate..., displayedComponents: .date)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                Divider()
                Toggle("Keep counting after the date", isOn: $draft.countsUp)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .background(ChatDaysTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if draft.countsUp {
                Text("Shows how many days it's been since the date. Great for anniversaries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var look: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaption("Look")
            HStack(spacing: 14) {
                ForEach(CountdownStyle.Preset.allCases) { preset in
                    let selected = draft.style == preset.style
                    Button {
                        draft.style = preset.style
                    } label: {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color(preset.style.background),
                                         Color(preset.style.background2 ?? preset.style.background)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Circle().stroke(Color.primary.opacity(0.15)))
                            .frame(width: 40, height: 40)
                            .padding(4)
                            .overlay(Circle().stroke(Color.primary, lineWidth: selected ? 2.5 : 0))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            VStack(spacing: 0) {
                ColorPicker("Background", selection: backgroundBinding, supportsOpacity: false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                Divider()
                ColorPicker("Text", selection: textBinding, supportsOpacity: false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .background(ChatDaysTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if !draft.style.isReadable {
                Text("Those colours are hard to read together, so the text colour will be adjusted automatically.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var typeChoice: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaption("Type")
            HStack(spacing: 10) {
                typeOption(.live, title: "Live", detail: "Updates every day for friends with ChatDays.")
                typeOption(.fixed, title: "Static", detail: "A fixed picture of today. Works for everyone.")
            }
        }
    }

    private func typeOption(_ mode: CountdownMode, title: String, detail: String) -> some View {
        let selected = draft.mode == mode
        return Button {
            draft.mode = mode
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
            .background(selected ? Color.primary.opacity(0.12) : ChatDaysTheme.panel,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

