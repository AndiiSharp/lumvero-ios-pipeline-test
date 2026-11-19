import XCTest
@testable import PipelineTest

final class NoteStoreTests: XCTestCase {
    private var dir: URL!
    private var fileURL: URL { dir.appendingPathComponent("notes.json") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testSaveAndRestoreRoundTrip() throws {
        let store = NoteStore(fileURL: fileURL)
        let a = try store.add("Erste Notiz", isPro: false)
        let b = try store.add("Zweite Notiz", isPro: false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let restored = NoteStore(fileURL: fileURL)
        XCTAssertEqual(restored.notes, [a, b])
        XCTAssertNil(restored.loadError)
    }

    func testMissingFileStartsEmpty() {
        let store = NoteStore(fileURL: fileURL)
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertNil(store.loadError)
    }

    func testEmptyAndWhitespaceInputRejected() {
        XCTAssertThrowsError(try NoteStore.validate("")) { XCTAssertEqual($0 as? NoteValidationError, .empty) }
        XCTAssertThrowsError(try NoteStore.validate("   \n\t ")) { XCTAssertEqual($0 as? NoteValidationError, .empty) }
        let store = NoteStore(fileURL: fileURL)
        XCTAssertThrowsError(try store.add("  ", isPro: false))
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testInputIsTrimmed() throws {
        XCTAssertEqual(try NoteStore.validate("  Hallo Welt \n"), "Hallo Welt")
    }

    func testTooLongInputRejected() throws {
        let ok = String(repeating: "a", count: NoteStore.maxLength)
        XCTAssertEqual(try NoteStore.validate(ok), ok)
        XCTAssertThrowsError(try NoteStore.validate(ok + "b")) {
            XCTAssertEqual($0 as? NoteValidationError, .tooLong(max: NoteStore.maxLength))
        }
    }

    func testUmlautsAndEmojiPersist() throws {
        let store = NoteStore(fileURL: fileURL)
        try store.add("Größe ÄÖÜ ß 🚀", isPro: false)
        XCTAssertEqual(NoteStore(fileURL: fileURL).notes.first?.text, "Größe ÄÖÜ ß 🚀")
    }

    func testFreeLimitAndProBypass() throws {
        let store = NoteStore(fileURL: fileURL)
        for i in 1...NoteStore.freeLimit { try store.add("Notiz \(i)", isPro: false) }
        XCTAssertThrowsError(try store.add("Zu viel", isPro: false)) {
            XCTAssertEqual($0 as? NoteValidationError, .freeLimitReached(limit: NoteStore.freeLimit))
        }
        XCTAssertEqual(store.notes.count, NoteStore.freeLimit)
        try store.add("Mit Pro erlaubt", isPro: true)
        XCTAssertEqual(store.notes.count, NoteStore.freeLimit + 1)
    }

    func testDeletePersists() throws {
        let store = NoteStore(fileURL: fileURL)
        try store.add("A", isPro: false)
        try store.add("B", isPro: false)
        store.delete(at: IndexSet(integer: 0))
        XCTAssertEqual(NoteStore(fileURL: fileURL).notes.map(\.text), ["B"])
    }

    func testCorruptFileRecoversWithError() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("kein json {".utf8).write(to: fileURL)
        let store = NoteStore(fileURL: fileURL)
        XCTAssertTrue(store.notes.isEmpty)
        XCTAssertNotNil(store.loadError)
        // Danach wieder normal benutzbar
        try store.add("Neu", isPro: false)
        XCTAssertEqual(NoteStore(fileURL: fileURL).notes.map(\.text), ["Neu"])
    }
}
