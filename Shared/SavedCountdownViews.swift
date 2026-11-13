import Foundation
import SwiftUI
import CountdownCore

/// "34 DAYS", "TOMORROW", and so on, as of now.
func countdownHeadline(for item: SavedCountdown) -> String {
    CountdownCalculator.state(for: item.eventDate).headline
}

private func cardGradient(_ style: CountdownStyle) -> LinearGradient {
    LinearGradient(colors: [Color(style.background), Color(style.background2 ?? style.background)],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
}

private func titleLine(_ item: SavedCountdown) -> String {
    [item.emoji, item.title].compactMap { $0 }.joined(separator: " ")
}

/// A compact card for the "send again" strip in the Messages composer.
struct CountdownChip: View {
    let item: SavedCountdown

    var body: some View {
        let style = item.style
        VStack(spacing: 2) {
            Text(countdownHeadline(for: item))
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(titleLine(item))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(Color(style.effectiveText))
        .padding(8)
        .frame(width: 130, height: 64)
        .background(cardGradient(style), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(countdownHeadline(for: item))")
    }
}

/// Send, share, edit and delete, behind a "more" button.
struct CountdownActionsMenu: View {
    var onSend: (() -> Void)? = nil
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onShareImage: (() -> Void)? = nil
    var onShareLink: (() -> Void)? = nil

    var body: some View {
        Menu {
            if let onSend {
                Button { onSend() } label: { Label("Send in Messages", systemImage: "paperplane") }
            }
            if let onShareImage {
                Button { onShareImage() } label: { Label("Share as image", systemImage: "photo") }
            }
            if let onShareLink {
                Button { onShareLink() } label: { Label("Share link", systemImage: "link") }
            }
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More actions")
    }
}

/// A translucent pill used for the actions on a card.
private func pillLabel(_ title: String, systemImage: String, tint: Color) -> some View {
    Label(title, systemImage: systemImage)
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(tint.opacity(0.18), in: Capsule())
}

/// The next upcoming countdown, big.
struct HeroCountdownCard: View {
    let item: SavedCountdown
    let onSend: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onShareImage: (() -> Void)? = nil
    var onShareLink: (() -> Void)? = nil

    var body: some View {
        let style = item.style
        let tint = Color(style.effectiveText)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NEXT UP")
                    .font(.caption.weight(.bold))
                    .tracking(1.5)
                Spacer()
                CountdownActionsMenu(onSend: onSend, onEdit: onEdit, onDelete: onDelete,
                                     onShareImage: onShareImage, onShareLink: onShareLink)
                    .padding(.trailing, -10)
            }
            Spacer(minLength: 12)
            Text(countdownHeadline(for: item))
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(titleLine(item))
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .padding(.top, 4)
            Text(item.eventDate.displayString())
                .font(.subheadline)
            HStack(spacing: 10) {
                Button(action: onSend) {
                    pillLabel("Send", systemImage: "paperplane.fill", tint: tint)
                }
                .buttonStyle(.plain)

                if onShareImage != nil || onShareLink != nil {
                    Menu {
                        if let onShareImage {
                            Button { onShareImage() } label: { Label("Share as image", systemImage: "photo") }
                        }
                        if let onShareLink {
                            Button { onShareLink() } label: { Label("Share link", systemImage: "link") }
                        }
                    } label: {
                        pillLabel("Share", systemImage: "square.and.arrow.up", tint: tint)
                    }
                }
            }
            .padding(.top, 14)
        }
        .foregroundStyle(tint)
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 230, alignment: .leading)
        .background(cardGradient(style), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onTapGesture(perform: onEdit)
    }
}

/// Every upcoming countdown after the first.
struct CompactCountdownCard: View {
    let item: SavedCountdown
    let onSend: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    var onShareImage: (() -> Void)? = nil
    var onShareLink: (() -> Void)? = nil

    var body: some View {
        let style = item.style
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titleLine(item))
                    .font(.headline)
                    .lineLimit(1)
                Text(item.eventDate.displayString())
                    .font(.footnote)
            }
            Spacer(minLength: 8)
            Text(countdownHeadline(for: item))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            CountdownActionsMenu(onSend: onSend, onEdit: onEdit, onDelete: onDelete,
                                 onShareImage: onShareImage, onShareLink: onShareLink)
                .padding(.trailing, -8)
        }
        .foregroundStyle(Color(style.effectiveText))
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(cardGradient(style), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: onEdit)
    }
}

/// A quiet row for events that have already happened.
struct PastCountdownRow: View {
    let item: SavedCountdown
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var agoText: String {
        if case .passed(let days) = CountdownCalculator.state(for: item.eventDate) {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        return countdownHeadline(for: item)
    }

    var body: some View {
        let style = item.style
        HStack(spacing: 12) {
            Text(item.emoji ?? "")
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(cardGradient(style), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.headline).lineLimit(1)
                Text(item.eventDate.displayString()).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(agoText).font(.footnote).foregroundStyle(.secondary)
            CountdownActionsMenu(onEdit: onEdit, onDelete: onDelete)
                .foregroundStyle(.secondary)
                .padding(.trailing, -8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ChatDaysTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onEdit)
    }
}

