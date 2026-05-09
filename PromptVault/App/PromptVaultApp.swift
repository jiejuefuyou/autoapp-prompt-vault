import SwiftUI

@main
struct PromptVaultApp: App {
    @State private var store = PromptStore()
    @State private var iap = IAPManager()
    @State private var l10n = LocalizationManager.shared
    @State private var icloud: iCloudSyncManager?

    init() {
        // Snapshot mode: skip onboarding so UI tests land on the main screen.
        if ProcessInfo.processInfo.arguments.contains("-FASTLANE_SNAPSHOT") {
            UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(iap)
                .environment(l10n)
                .environment(\.locale, l10n.currentLocale)
                .task {
                    await iap.refresh()
                    if iCloudSyncManager.isAvailable, icloud == nil {
                        let mgr = iCloudSyncManager(store: store)
                        store.attachiCloudSync(mgr)
                        mgr.startObserving()
                        icloud = mgr
                    }
                }
                .tint(.accentColor)
        }
    }
}
