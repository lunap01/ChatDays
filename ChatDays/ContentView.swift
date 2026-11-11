import Foundation
import SwiftUI
import UIKit
import MessageUI
import CountdownCore

/// "My countdowns": create, edit, delete and send from the main app.
struct ContentView: View {
    @StateObject private var access = AccessStore()
    @StateObject private var library = LibraryStore()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("chatdays.hasSeenWelcome") private var hasSeenWelcome = false

    @State private var showWelcome = false
    @State private var sheet: ActiveSheet?
    @State private var notice: String?
    @State private var tab: Tab = .upcoming

    enum Tab: String, CaseIterable, Identifiable {
        case upcoming = "Upcoming"
        case past = "Past"
        var id: String { rawValue }
    }

    enum ActiveSheet: Identifiable {
        case editor(SavedCountdown?)
        case send(CountdownPayload)
        case paywall

        var id: String {
            switch self {
            case .editor(let item): return "editor-\(item?.id.uuidString ?? "new")"
            case .send(let payload): return "send-\(payload.id.uuidString)"
            case .paywall: return "paywall"
            }
        }
    }

    private var today: EventDate { EventDate(date: Date(), timeZone: .current) }
    private var upcoming: [SavedCountdown] { library.items.filter { $0.eventDate >= today } }
    private var past: [SavedCountdown] { library.items.filter { $0.eventDate < today } }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    Picker("Show", selection: $tab) {
                        ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    content
                    allowanceCard
                    footerLinks

                    #if DEBUG
                    developerCard
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) {
                Button {
                    sheet = .editor(nil)
                } label: {
                    Label("New countdown", systemImage: "plus")
                }
                .buttonStyle(AccentPillButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(.bar)
            }
            .fullScreenCover(isPresented: $showWelcome) {
                WelcomeView(
                    onCreate: {
                        hasSeenWelcome = true
                        showWelcome = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { sheet = .editor(nil) }
                    },
                    onClose: {
                        hasSeenWelcome = true
                        showWelcome = false
                    }
                )
            }
        }
        .task { await access.refresh() }
        .onAppear {
            if !hasSeenWelcome { showWelcome = true }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                library.reload()
                access.reloadFromDisk()
            }
        }
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .editor(let item):
                EditorSheet(
                    draft: item.map { CountdownDraft($0) } ?? CountdownDraft.new(),
                    isNew: item == nil,
                    onSave: { draft in
                        library.save(draft)
                        self.sheet = nil
                    },
                    onSaveAndSend: { draft in
                        let saved = library.save(draft)
                        self.sheet = nil
                        // Let the editor finish closing before the Messages sheet opens.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { send(saved) }
                    },
                    onCancel: { self.sheet = nil }
                )
            case .send(let payload):
                MessageComposeSheet(payload: payload) { result in
                    if result == .sent { access.recordSend(payload.id) }
                    self.sheet = nil
                }
                .ignoresSafeArea()
            case .paywall:
                PaywallView(access: access) { self.sheet = nil }
            }
        }
        .alert("ChatDays", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notice ?? "")
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .center) {
            Text("ChatDays")
                .font(.system(size: 34, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if !access.isUnlocked {
                Button {
                    sheet = .paywall
                } label: {
                    Text("\(access.remainingFree) of \(UsageLedger.freeLimit) free left")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        if library.items.isEmpty {
            emptyState
        } else if tab == .upcoming {
            if let first = upcoming.first {
                HeroCountdownCard(
                    item: first,
                    onSend: { send(first) },
                    onEdit: { sheet = .editor(first) },
                    onDelete: { library.delete(first.id) }
                )
                ForEach(Array(upcoming.dropFirst())) { item in
                    CompactCountdownCard(
                        item: item,
                        onSend: { send(item) },
                        onEdit: { sheet = .editor(item) },
                        onDelete: { library.delete(item.id) }
                    )
                }
            } else {
                note("Nothing coming up. Create a new countdown, or look in Past.")
            }
        } else {
            if past.isEmpty {
                note("No past countdowns yet.")
            } else {
                ForEach(past) { item in
                    PastCountdownRow(
                        item: item,
                        onEdit: { sheet = .editor(item) },
                        onDelete: { library.delete(item.id) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("Make your first countdown")
                .font(.title3.bold())
            Text("Pick a template, choose a date, and send it to a chat.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Create a countdown") { sheet = .editor(nil) }
                .buttonStyle(AccentPillButtonStyle())
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(ChatDaysTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    @ViewBuilder
    private var allowanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if access.isUnlocked {
                Label("ChatDays unlocked", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
            } else {
                Text("\(access.remainingFree) of \(UsageLedger.freeLimit) free countdowns left")
                    .font(.subheadline.weight(.semibold))
                Text("Unlock once to send as many as you like. No subscription.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Unlock ChatDays") { sheet = .paywall }
                    .buttonStyle(.borderedProminent)
            }
            if let message = access.message {
                Text(message).font(.footnote).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChatDaysTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button("Restore Purchases") { Task { await access.restore() } }
                .disabled(access.isWorking)
            Button("How ChatDays works") { showWelcome = true }
        }
        .font(.footnote)
        .padding(.top, 4)
    }

    #if DEBUG
    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaption("Developer (debug builds only)")
            Toggle("Pretend unlocked", isOn: Binding(
                get: { access.isDeveloperUnlocked },
                set: { access.setDeveloperUnlocked($0) }
            ))
            Button("Reset free count") { access.resetUsage() }
        }
        .font(.footnote)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ChatDaysTheme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
    #endif

    // MARK: Actions

    private func send(_ item: SavedCountdown) {
        guard MFMessageComposeViewController.canSendText() else {
            notice = "This device can't send messages."
            return
        }
        guard access.canSend else {
            sheet = .paywall
            return
        }
        sheet = .send(item.payload())
    }
}

/// Create or edit one countdown.
struct EditorSheet: View {
    @State private var draft: CountdownDraft
    let isNew: Bool
    let onSave: (CountdownDraft) -> Void
    let onSaveAndSend: (CountdownDraft) -> Void
    let onCancel: () -> Void

    init(draft: CountdownDraft,
         isNew: Bool,
         onSave: @escaping (CountdownDraft) -> Void,
         onSaveAndSend: @escaping (CountdownDraft) -> Void,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.isNew = isNew
        self.onSave = onSave
        self.onSaveAndSend = onSaveAndSend
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CountdownFormView(draft: $draft)
                    Button {
                        onSaveAndSend(draft)
                    } label: {
                        Label("Save and send in Messages", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(AccentPillButtonStyle())
                    .disabled(draft.cleanTitle.isEmpty)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isNew ? "New countdown" : "Edit countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .disabled(draft.cleanTitle.isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
