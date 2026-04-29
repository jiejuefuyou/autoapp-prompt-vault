import SwiftUI

@main
struct PromptVaultApp: App {
    @State private var store = PromptStore()
    @State private var iap = IAPManager()

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
                .task { await iap.refresh() }
                .tint(.accentColor)
        }
    }
}
