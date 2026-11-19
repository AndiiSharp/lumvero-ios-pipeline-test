import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(NoteStore.self) private var store
    @State private var selection: Note.ID?
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad (und große iPhones quer): Liste links, Detail rechts
            NavigationSplitView(columnVisibility: $columns) {
                NoteListView(layout: "split", selection: $selection)
            } detail: {
                if let id = selection, let note = store.notes.first(where: { $0.id == id }) {
                    NoteDetailView(note: note)
                } else {
                    Text("Notiz auswählen")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("detailPlaceholder")
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            // iPhone: klassischer Stack
            NavigationStack {
                NoteListView(layout: "stack", selection: nil)
                    .navigationDestination(for: Note.self) { NoteDetailView(note: $0) }
            }
        }
    }
}

struct NoteListView: View {
    let layout: String
    let selection: Binding<Note.ID?>?

    @Environment(NoteStore.self) private var store
    @Environment(ProStore.self) private var pro
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var draft = ""
    @State private var errorText: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Group {
            if let selection {
                List(selection: selection) { content }
            } else {
                List { content }
            }
        }
        .navigationTitle("PipelineTest")
    }

    @ViewBuilder private var content: some View {
        Section("Neue Notiz") {
            TextField("Notiztext", text: $draft)
                .focused($fieldFocused)
                .submitLabel(.done)
                .onSubmit(add)
                .accessibilityIdentifier("noteField")
            Button("Hinzufügen", action: add)
                .accessibilityIdentifier("addButton")
            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("errorLabel")
            }
            if let loadError = store.loadError {
                Text(loadError).foregroundStyle(.orange)
            }
        }
        Section("Notizen (\(store.notes.count))") {
            if store.notes.isEmpty {
                Text("Noch keine Notizen").foregroundStyle(.secondary)
            }
            ForEach(store.notes) { note in
                if selection != nil {
                    NavigationLink(value: note.id) { Text(note.text) }
                } else {
                    NavigationLink(value: note) { Text(note.text) }
                }
            }
            .onDelete { store.delete(at: $0) }
        }
        Section("Pro") {
            Text(pro.isPro ? "Pro aktiv" : "Gratis-Version (max. \(NoteStore.freeLimit) Notizen)")
                .accessibilityIdentifier("proStatus")
            if !pro.isPro {
                Button(pro.product.map { "Pro freischalten – \($0.displayPrice)" } ?? "Pro freischalten") {
                    Task { await buy() }
                }
                .accessibilityIdentifier("buyPro")
            }
            Button("Käufe wiederherstellen") { Task { await restore() } }
                .accessibilityIdentifier("restorePurchases")
            if let message = pro.lastError {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        Section {
            Text("Layout: \(layout) · Schrift: \(typeSize.isAccessibilitySize ? "groß" : "normal")")
                .font(.footnote)
                .accessibilityIdentifier("layoutInfo")
        }
    }

    private func add() {
        do {
            try store.add(draft, isPro: pro.isPro)
            draft = ""
            errorText = nil
            fieldFocused = false
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func buy() async {
        do { try await pro.purchase() } catch { pro.lastError = error.localizedDescription }
    }

    private func restore() async {
        do { try await pro.restore() } catch { pro.lastError = error.localizedDescription }
    }
}

struct NoteDetailView: View {
    let note: Note

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(note.text)
                    .font(.title2)
                    .accessibilityIdentifier("detailText")
                Text(note.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Notiz")
    }
}
