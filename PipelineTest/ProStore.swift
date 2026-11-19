import Foundation
import Observation
import StoreKit

enum ProError: LocalizedError {
    case productUnavailable
    case unverified

    var errorDescription: String? {
        switch self {
        case .productUnavailable: return "Pro-Produkt ist derzeit nicht verfügbar."
        case .unverified: return "Kauf konnte nicht verifiziert werden."
        }
    }
}

/// Einmalige Pro-Freischaltung (Non-Consumable) über StoreKit 2.
/// In diesem Testprojekt nur gegen die lokale Datei StoreKit/Products.storekit geprüft.
@MainActor
@Observable
final class ProStore {
    static let productID = "digital.lumvero.pipelinetest.pro"

    private(set) var isPro = false
    private(set) var product: Product?
    var lastError: String?

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            if product == nil { lastError = ProError.productUnavailable.localizedDescription }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    /// - Returns: `true`, wenn der Kauf abgeschlossen und verifiziert wurde.
    @discardableResult
    func purchase() async throws -> Bool {
        if product == nil { await loadProduct() }
        guard let product else { throw ProError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { throw ProError.unverified }
            await transaction.finish()
            await refreshEntitlements()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshEntitlements()
                }
            }
        }
    }
}
