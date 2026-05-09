import Foundation
import Network

/// Wraps NSUbiquitousKeyValueStore for prompt iCloud sync.
/// - Push: encodes prompts to KVStore under a single JSON key.
/// - Pull: observes didChangeExternallyNotification and merges via PromptStore.
/// - Status: tracks last sync timestamp and successful sync count for the
///   Settings status indicator. Honours the user's cellular preference: when
///   `syncOverCellular` is false, push/pull are skipped while on cellular.
@MainActor
final class iCloudSyncManager {
    private static let kvKey = "promptvault.prompts.v1"
    static let lastSyncDefaultsKey = "promptvault.icloud.lastSync"
    static let syncCountDefaultsKey = "promptvault.icloud.syncCount"
    static let cellularDefaultsKey = "promptvault.icloud.syncOverCellular"

    private weak var store: PromptStore?
    private var observer: NSObjectProtocol?
    private let pathMonitor = NWPathMonitor()
    private var isOnCellular: Bool = false

    init(store: PromptStore) {
        self.store = store
        pathMonitor.pathUpdateHandler = { [weak self] path in
            // Pure value extraction — never touch UI from here.
            let cellular = path.usesInterfaceType(.cellular) && !path.usesInterfaceType(.wifi)
            DispatchQueue.main.async { self?.isOnCellular = cellular }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { [weak self] _ in
            self?.pull()
        }
        NSUbiquitousKeyValueStore.default.synchronize()
        pull()
    }

    func stopObserving() {
        if let o = observer {
            NotificationCenter.default.removeObserver(o)
            observer = nil
        }
    }

    func push(_ prompts: [Prompt]) {
        guard shouldSync else { return }
        guard let data = try? JSONEncoder().encode(prompts) else { return }
        NSUbiquitousKeyValueStore.default.set(data, forKey: Self.kvKey)
        NSUbiquitousKeyValueStore.default.synchronize()
        recordSync()
    }

    private func pull() {
        guard shouldSync else { return }
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: Self.kvKey),
              let remote = try? JSONDecoder().decode([Prompt].self, from: data) else { return }
        store?.mergeFromiCloud(remote)
        recordSync()
    }

    private var shouldSync: Bool {
        let allowCellular = UserDefaults.standard.bool(forKey: Self.cellularDefaultsKey)
        if isOnCellular && !allowCellular { return false }
        return true
    }

    private func recordSync() {
        let defaults = UserDefaults.standard
        // Stored as a Double (timeIntervalSince1970) so SwiftUI @AppStorage
        // can bind to it without a custom Date adapter.
        defaults.set(Date().timeIntervalSince1970, forKey: Self.lastSyncDefaultsKey)
        defaults.set(defaults.integer(forKey: Self.syncCountDefaultsKey) + 1,
                     forKey: Self.syncCountDefaultsKey)
    }

    /// Returns false when iCloud KVStore is not available (e.g., no account, device restrictions).
    static var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    deinit {
        pathMonitor.cancel()
        if let o = observer {
            NotificationCenter.default.removeObserver(o)
        }
    }
}
