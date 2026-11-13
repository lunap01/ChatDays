import Foundation
import SwiftUI
import UIKit
import CountdownCore

/// Something to hand to the system share sheet.
struct ShareRequest: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// The standard iOS share sheet.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// The picture that gets shared: the countdown card with a small credit line.
struct ShareCardView: View {
    let item: SavedCountdown

    var body: some View {
        ZStack(alignment: .bottom) {
            CountdownCardView(
                content: .countdown(CountdownCalculator.state(for: item.eventDate, countsUp: item.countsUp)),
                title: item.title,
                emoji: item.emoji,
                eventDate: item.eventDate,
                style: item.style
            )
            Text("Made with ChatDays")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(item.style.effectiveText).opacity(0.75))
                .padding(.bottom, 12)
        }
        .frame(width: 360, height: 240)
    }
}

/// "Share anywhere": a picture or a link that works in any app, on any phone.
@MainActor
enum ShareSupport {
    /// Link sharing needs your site address (see `CountdownLink.shareBase`).
    static var canShareLink: Bool { CountdownLink.shareBase != nil }

    static func imageRequest(for item: SavedCountdown) -> ShareRequest? {
        let renderer = ImageRenderer(content: ShareCardView(item: item))
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { return nil }
        let safeName = String(item.title.map { $0.isLetter || $0.isNumber ? $0 : "-" }.prefix(30))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ChatDays-\(safeName).png")
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return nil
        }
        return ShareRequest(items: [url])
    }

    static func linkRequest(for item: SavedCountdown) -> ShareRequest? {
        guard let url = item.payload().shareURL() else { return nil }
        let name = [item.emoji, item.title].compactMap { $0 }.joined(separator: " ")
        let sentence = CountdownCalculator.state(for: item.eventDate, countsUp: item.countsUp).sentence(about: name)
        return ShareRequest(items: ["\(sentence). Watch the countdown: \(url.absoluteString)"])
    }
}

