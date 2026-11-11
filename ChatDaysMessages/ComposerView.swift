import Foundation
import SwiftUI
import CountdownCore

/// The creation screen shown when ChatDays is opened from the Messages drawer.
struct ComposerView: View {
    @ObservedObject var access: AccessStore
    @ObservedObject var library: LibraryStore
    let onInsert: (CountdownPayload) -> Void

    @State private var draft = CountdownDraft.new()
    @State private var saveToLibrary = true
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !library.items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionCaption("Send again")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(library.items) { item in
                                    Button { draft = CountdownDraft(item) } label: { CountdownChip(item: item) }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                CountdownFormView(draft: $draft)

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Save to My countdowns", isOn: $saveToLibrary)
                        .font(.subheadline)
                    Text(access.isUnlocked
                         ? "ChatDays unlocked"
                         : "\(access.remainingFree) of \(UsageLedger.freeLimit) free countdowns left")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    if access.canSend {
                        if saveToLibrary { library.save(draft) }
                        onInsert(draft.payload())
                    } else {
                        showPaywall = true
                    }
                } label: {
                    Text(access.canSend ? "Insert into message" : "Unlock to send more")
                }
                .buttonStyle(AccentPillButtonStyle())
                .disabled(access.canSend && draft.cleanTitle.isEmpty)
            }
            .padding()
        }
        .onAppear {
            access.reloadFromDisk()
            library.reload()
        }
        .task { await access.refresh() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(access: access) { showPaywall = false }
        }
    }
}

