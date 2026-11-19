import SwiftUI

@main
struct PipelineTestApp: App {
    @State private var noteStore: NoteStore
    @State private var proStore = ProStore()
    @State private var updatesTask: Task<Void, Never>?

    /// UI-Tests starten die App mit `-uiTesting` (StoreKit wird dann nicht kontaktiert).
    /// Unit-Tests laufen im App-Host; dort übernimmt SKTestSession StoreKit.
    private static var storeKitDisabled: Bool {
        let info = ProcessInfo.processInfo
        return info.arguments.contains("-uiTesting")
            || info.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        let url = NoteStore.defaultFileURL()
        if ProcessInfo.processInfo.arguments.contains("-resetData") {
            try? FileManager.default.removeItem(at: url)
        }
        _noteStore = State(initialValue: NoteStore(fileURL: url))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(noteStore)
                .environment(proStore)
                .task {
                    guard !Self.storeKitDisabled else { return }
                    updatesTask = proStore.listenForTransactions()
                    await proStore.loadProduct()
                    await proStore.refreshEntitlements()
                }
        }
    }
}
