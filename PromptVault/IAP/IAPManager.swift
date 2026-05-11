import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class IAPManager {
    // Must match the IAP product ID configured in App Store Connect for PromptVault.
    static let premiumProductID = "com.jiejuefuyou.promptvault.premium"

    /// Hard ceiling for product lookup. Sandbox StoreKit can stall silently;
    /// any wait beyond this and we surface a graceful empty state instead of
    /// an indefinite spinner. Ported from AutoChoice round-3 2.1(b) fix.
    static let productsLoadTimeout: Duration = .seconds(5)

    enum LoadingState: Equatable {
        case loading
        case loaded
        case empty   // products query returned, but list empty (sandbox region with no IAP record)
        case timedOut
        case failed
    }

    /// Preempt port of AutoChoice round-4 (v1.0.5 build 16, 2.1(b), 2026-05-11)
    /// PurchaseState UI surface fix. The previous implementation swallowed
    /// `product.purchase()` errors into a single `lastError` string with no
    /// alert and no distinction between cancelled / pending / failed. This
    /// explicit state machine drives a visible, actionable UI on every branch
    /// so reviewers can recover or move on without a phantom failure.
    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)
        case cancelled
        case pending
    }

    enum PurchaseError: LocalizedError {
        case productNotFound
        case verificationFailed
        case purchasePending
        case userCancelled
        case unknownResult
        case storeError(String)

        var errorDescription: String? {
            switch self {
            case .productNotFound:
                return String(localized: "Product unavailable. Please try again later.")
            case .verificationFailed:
                return String(localized: "Purchase verification failed. Please contact support.")
            case .purchasePending:
                return String(localized: "Purchase pending. We'll complete it shortly.")
            case .userCancelled:
                return String(localized: "Purchase canceled.")
            case .unknownResult:
                return String(localized: "Unknown purchase result. Please try again.")
            case .storeError(let message):
                return message
            }
        }
    }

    var isPremium: Bool = false
    var products: [Product] = []
    var purchaseInProgress: Bool = false
    var lastError: String?
    var loadingState: LoadingState = .loading
    var purchaseState: PurchaseState = .idle

    private nonisolated(unsafe) var listenerTask: Task<Void, Never>?

    init() {
        listenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let t) = update else { continue }
                await t.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    deinit { listenerTask?.cancel() }

    func refresh() async {
        await drainUnfinishedTransactions()
        await loadProducts()
        await refreshEntitlements()
    }

    /// StoreKit 2 best practice: drain any unfinished transactions at launch
    /// so a stale pending purchase from a prior session doesn't block the
    /// next `product.purchase()` call. Without this, sandbox reviewers on
    /// fresh installs can hit "an error appeared" on second-tap purchases
    /// because the StoreKit queue still references the previous attempt.
    private func drainUnfinishedTransactions() async {
        for await result in Transaction.unfinished {
            guard case .verified(let t) = result else { continue }
            await t.finish()
        }
    }

    func loadProducts() async {
        loadingState = .loading
        lastError = nil
        do {
            let fetched = try await withThrowingTaskGroup(of: [Product].self) { group in
                group.addTask {
                    try await Product.products(for: [Self.premiumProductID])
                }
                group.addTask {
                    try await Task.sleep(for: Self.productsLoadTimeout)
                    throw IAPLoadError.timedOut
                }
                guard let first = try await group.next() else {
                    throw IAPLoadError.timedOut
                }
                group.cancelAll()
                return first
            }
            products = fetched
            loadingState = fetched.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            // Caller-initiated cancel (e.g. view dismissed). Treat as empty
            // rather than failed so we don't surface a misleading error.
            loadingState = .empty
        } catch IAPLoadError.timedOut {
            loadingState = .timedOut
        } catch {
            lastError = error.localizedDescription
            loadingState = .failed
        }
    }

    private enum IAPLoadError: Error {
        case timedOut
    }

    func purchase() async {
        // Idle -> purchasing transition is gated to prevent double-tap
        // re-entry which Apple Review has flagged on iPadOS 26.4.2 sandbox.
        guard !purchaseInProgress else { return }

        guard let product = products.first(where: { $0.id == Self.premiumProductID }) else {
            // Try once more in case loadProducts hadn't completed yet.
            await loadProducts()
            if products.first(where: { $0.id == Self.premiumProductID }) == nil {
                let msg = PurchaseError.productNotFound.errorDescription ?? ""
                purchaseState = .failed(msg)
                lastError = msg
                return
            }
            // Recovered, fall through and retry with the freshly loaded product.
            await purchase()
            return
        }

        purchaseState = .purchasing
        purchaseInProgress = true
        defer { purchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let t):
                    await t.finish()
                    await refreshEntitlements()
                    purchaseState = .success
                case .unverified(let t, _):
                    // Finish the unverified transaction so it doesn't linger
                    // in the queue and block subsequent attempts.
                    await t.finish()
                    let msg = PurchaseError.verificationFailed.errorDescription ?? ""
                    purchaseState = .failed(msg)
                    lastError = msg
                }
            case .userCancelled:
                purchaseState = .cancelled
            case .pending:
                purchaseState = .pending
            @unknown default:
                let msg = PurchaseError.unknownResult.errorDescription ?? ""
                purchaseState = .failed(msg)
                lastError = msg
            }
        } catch {
            // Surface every StoreKit error verbatim so reviewers see why
            // the purchase did not complete, instead of a silent dismiss.
            let msg = error.localizedDescription
            purchaseState = .failed(msg)
            lastError = msg
        }
    }

    func restore() async {
        purchaseState = .idle
        do {
            try await AppStore.sync()
        } catch {
            let msg = error.localizedDescription
            lastError = msg
            purchaseState = .failed(msg)
        }
        await refreshEntitlements()
    }

    /// Allow the view to clear a stale failed/cancelled state once the user
    /// has acknowledged the alert. Without this, the failure banner sticks
    /// around forever and a subsequent successful purchase looks ambiguous.
    func resetPurchaseState() {
        purchaseState = .idle
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.premiumProductID,
               t.revocationDate == nil {
                entitled = true
            }
        }
        isPremium = entitled
    }
}
