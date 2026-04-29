import SwiftUI

struct SettingsView: View {
    @Environment(PromptStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Premium") {
                    if iap.isPremium {
                        Label("Premium unlocked", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        HStack {
                            Text("Free tier")
                            Spacer()
                            Text("\(store.prompts.count) / \(PromptStore.freePromptLimit) prompts used")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button { showPaywall = true } label: { Label("Unlock Premium", systemImage: "sparkles") }
                    }
                    Button("Restore Purchase") { Task { await iap.restore() } }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Build",   value: buildNumber)
                    Link("Privacy Policy", destination: URL(string: "https://github.com/jiejuefuyou/autoapp-prompt-vault/blob/main/PRIVACY.md")!)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    private var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }
}
