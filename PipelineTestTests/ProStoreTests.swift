import StoreKit
import StoreKitTest
import XCTest
@testable import PipelineTest

/// StoreKit-2-Tests gegen die lokale Konfiguration StoreKit/Products.storekit.
/// Es wird kein echtes Produkt und kein echtes Apple-Konto verwendet.
@MainActor
final class ProStoreTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        session = try makeSession()
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    /// `configurationFileNamed` sucht nur im App-Bundle und bricht auf dem
    /// Test-Host stillschweigend auf eine leere Produktliste aus. Die URL aus
    /// dem Bundle, das die Datei wirklich enthält, lädt die Konfiguration.
    private func makeSession() throws -> SKTestSession {
        let bundles = [Bundle(for: ProStoreTests.self), Bundle.main]
        for bundle in bundles {
            let url = bundle.url(forResource: "Products", withExtension: "storekit")
                ?? bundle.url(forResource: "Products", withExtension: "storekit", subdirectory: "StoreKit")
            if let url {
                return try SKTestSession(contentsOf: url)
            }
        }
        XCTFail("Products.storekit weder im Test- noch im App-Bundle")
        throw ProError.productUnavailable
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
    }

    private func loadedStore() async throws -> ProStore {
        let store = ProStore()
        // Produkte können beim ersten Abruf im Simulator verzögert erscheinen
        for _ in 0..<5 where store.product == nil {
            await store.loadProduct()
            if store.product == nil { try await Task.sleep(nanoseconds: 500_000_000) }
        }
        return store
    }

    func testProductLoadsFromConfiguration() async throws {
        let store = try await loadedStore()
        let product = try XCTUnwrap(store.product, store.lastError ?? "Produkt nicht geladen")
        XCTAssertEqual(product.id, ProStore.productID)
        XCTAssertEqual(product.type, .nonConsumable)
        XCTAssertEqual(product.price, Decimal(string: "4.99"))
    }

    func testPurchaseGrantsEntitlementAndRestoresInFreshInstance() async throws {
        let store = try await loadedStore()
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro, "Vor dem Kauf darf Pro nicht aktiv sein")

        let completed = try await store.purchase()
        XCTAssertTrue(completed)
        XCTAssertTrue(store.isPro)

        // "Neustart": neue Instanz liest Berechtigungen aus Transaction.currentEntitlements
        let restored = ProStore()
        await restored.refreshEntitlements()
        XCTAssertTrue(restored.isPro, "Kauf muss nach Neustart wiederhergestellt werden")
    }

    func testRestorePurchasesViaAppStoreSync() async throws {
        let store = try await loadedStore()
        try await store.purchase()
        let other = ProStore()
        try await other.restore()
        XCTAssertTrue(other.isPro)
    }

    func testRefundRevokesEntitlement() async throws {
        let store = try await loadedStore()
        try await store.purchase()
        XCTAssertTrue(store.isPro)
        let transaction = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == ProStore.productID })
        try session.refundTransaction(identifier: transaction.identifier)
        try await Task.sleep(nanoseconds: 500_000_000)
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro, "Nach Erstattung darf Pro nicht mehr aktiv sein")
    }

    func testNoPurchaseMeansFreeVersion() async throws {
        let store = try await loadedStore()
        await store.refreshEntitlements()
        XCTAssertFalse(store.isPro)
    }
}
