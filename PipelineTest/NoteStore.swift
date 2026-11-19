import Foundation
import Observation

struct Note: Codable, Identifiable, Hashable {
    let id: UUID
    var text: String
    let createdAt: Date
}

enum NoteValidationError: LocalizedError, Equatable {
    case empty
    case tooLong(max: Int)
    case freeLimitReached(limit: Int)

    var errorDescription: String? {
        switch self {
        case .empty:
            return "Bitte Text eingeben."
        case .tooLong(let max):
            return "Maximal \(max) Zeichen."
        case .freeLimitReached(let limit):
            return "Gratis-Version: höchstens \(limit) Notizen. Pro hebt das Limit auf."
        }
    }
}

/// Lokale Speicherung als JSON in Application Support – kein Server, keine Fremddienste.
@Observable
final class NoteStore {
    static let maxLength = 200
    static let freeLimit = 3

    private(set) var notes: [Note] = []
    private(set) var loadError: String?
    let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
        load()
    }

    static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("notes.json")
    }

    static func validate(_ raw: String) throws -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw NoteValidationError.empty }
        guard text.count <= maxLength else { throw NoteValidationError.tooLong(max: maxLength) }
        return text
    }

    @discardableResult
    func add(_ raw: String, isPro: Bool) throws -> Note {
        let text = try Self.validate(raw)
        if !isPro && notes.count >= Self.freeLimit {
            throw NoteValidationError.freeLimitReached(limit: Self.freeLimit)
        }
        let note = Note(id: UUID(), text: text, createdAt: Date())
        notes.append(note)
        try save()
        return note
    }

    func delete(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where notes.indices.contains(index) {
            notes.remove(at: index)
        }
        try? save()
    }

    func save() throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(notes)
        try data.write(to: fileURL, options: .atomic)
    }

    func load() {
        loadError = nil
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            notes = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            notes = try JSONDecoder().decode([Note].self, from: data)
        } catch {
            notes = []
            loadError = "Gespeicherte Daten beschädigt – leere Liste geladen."
        }
    }
}
