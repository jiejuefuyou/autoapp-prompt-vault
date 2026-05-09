import SwiftUI

struct SettingsView: View {
    @Environment(PromptStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("Premium")) {
                    if iap.isPremium {
                        Label(LocalizedStringKey("Premium unlocked"), systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        HStack {
                            Text(LocalizedStringKey("Free tier"))
                            Spacer()
                            Text("\(store.prompts.count) / \(PromptStore.freePromptLimit) prompts used")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button { showPaywall = true } label: { Label(LocalizedStringKey("Unlock Premium"), systemImage: "sparkles") }
                    }
                    Button(LocalizedStringKey("Restore Purchase")) { Task { await iap.restore() } }
                }

                Section(LocalizedStringKey("Language")) {
                    LanguagePicker()
                }

                Section(LocalizedStringKey("About")) {
                    LabeledContent(LocalizedStringKey("Version"), value: appVersion)
                    LabeledContent(LocalizedStringKey("Build"),   value: buildNumber)
                    Link(LocalizedStringKey("Privacy Policy"), destination: URL(string: "https://github.com/jiejuefuyou/autoapp-prompt-vault/blob/main/PRIVACY.md")!)
                }
            }
            .navigationTitle(Text("Settings"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(LocalizedStringKey("Done")) { dismiss() } }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var appVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—" }
    private var buildNumber: String { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—" }
}

private struct LanguagePicker: View {
    @Environment(LocalizationManager.self) private var l10n

    var body: some View {
        Picker(LocalizedStringKey("Language"), selection: Binding(
            get: { l10n.override },
            set: { l10n.setOverride($0) }
        )) {
            Text(LocalizedStringKey("System default")).tag("")
            ForEach(LocalizationManager.supportedLanguages, id: \.self) { code in
                Text(LocalizationManager.displayName(for: code)).tag(code)
            }
        }
        .pickerStyle(.menu)
    }
}
