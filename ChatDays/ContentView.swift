import Foundation
import SwiftUI
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

    var body: some View {
        NavigationStack {
            List {
                Section {
                    allowanceRows
                }

                Section("My countdowns") {
                    if library.items.isEmpty {
                        Text("No countdowns yet. Tap + to create one.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(library.items) { item in
                        Button { sheet = .editor(item) } label: { CountdownRow(item: item) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { library.delete(item.id) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button { send(item) } label: { Label("Send", systemImage: "paperplane") }
                                    .tint(.blue)
                            }
                    }
                }

                Section {
                    Button("How ChatDays works") { showWelcome = true }
                }

                #if DEBUG
                Section("Developer (debug builds only)") {
                    Toggle("Pretend unlocked", isOn: Binding(
                        get: { access.isDeveloperUnlocked },
                        set: { access.setDeveloperUnlocked($0) }
                    ))
                    Button("Reset free count") { access.resetUsage() }
                }
                #endif
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
            .navigationTitle("ChatDays")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { sheet = .editor(nil) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New countdown")
                }
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

    @ViewBuilder
    private var allowanceRows: some View {
        if access.isUnlocked {
            Label("ChatDays unlocked. Send as many countdowns as you like.", systemImage: "checkmark.seal")
        } else {
            Text("\(access.remainingFree) of \(UsageLedger.freeLimit) free countdowns left")
            Button("Unlock ChatDays") { sheet = .paywall }
        }
        Button("Restore Purchases") { Task { await access.restore() } }
            .disabled(access.isWorking)
        if let message = access.message {
            Text(message).font(.footnote).foregroundStyle(.orange)
        }
    }

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
                VStack(spacing: 16) {
                    CountdownFormView(draft: $draft)
                    Button {
                        onSaveAndSend(draft)
                    } label: {
                        Label("Save and send in Messages", systemImage: "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draft.cleanTitle.isEmpty)
                }
                .padding()
            }
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
