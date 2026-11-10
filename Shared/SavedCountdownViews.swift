import Foundation
import SwiftUI
import CountdownCore

private func headline(for item: SavedCountdown) -> String {
    CountdownCalculator.state(for: item.eventDate).headline
}

/// A compact card for the "send again" strip in the Messages composer.
struct CountdownChip: View {
    let item: SavedCountdown

    var body: some View {
        let style = item.style
        ZStack {
            LinearGradient(colors: [Color(style.background), Color(style.background2 ?? style.background)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 2) {
                Text(headline(for: item))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text([item.emoji, item.title].compactMap { $0 }.joined(separator: " "))
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(Color(style.effectiveText))
            .padding(8)
        }
        .frame(width: 130, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(headline(for: item))")
    }
}

/// A row for the main app's list.
struct CountdownRow: View {
    let item: SavedCountdown

    var body: some View {
        let style = item.style
        HStack(spacing: 12) {
            ZStack {
                LinearGradient(colors: [Color(style.background), Color(style.background2 ?? style.background)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(item.emoji ?? "📅").font(.title3)
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.headline).foregroundStyle(.primary).lineLimit(1)
                Text(item.eventDate.displayString()).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            Text(headline(for: item))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
