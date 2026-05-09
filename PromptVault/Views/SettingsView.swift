import SwiftUI

struct SettingsView: View {
    @Environment(PromptStore.self) private var store
    @Environment(IAPManager.self) private var iap
    @Environment(LocalizationManager.self) private var l10n
    @Environment(\.dismiss) private var dismiss

    @AppStorage(iCloudSyncManager.cellularDefaultsKey) private var syncOverCellular: Bool = false
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

                iCloudSyncSection(syncOverCellular: $syncOverCellular)

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

/// Free-tier feature: shows iCloud KVStore availability, the timestamp of the
/// last successful sync, the lifetime sync count, and a cellular toggle.
/// Reads the timestamps directly from UserDefaults (written by iCloudSyncManager
/// on every push/pull) so the UI stays in sync without observing the manager.
private struct iCloudSyncSection: View {
    @Binding var syncOverCellular: Bool

    @AppStorage(iCloudSyncManager.lastSyncDefaultsKey) private var lastSyncRaw: Double = 0
    @AppStorage(iCloudSyncManager.syncCountDefaultsKey) private var syncCount: Int = 0

    var body: some View {
        Section {
            HStack {
                Label(LocalizedStringKey("Status"), systemImage: "icloud")
                Spacer()
                if iCloudSyncManager.isAvailable {
                    Text(LocalizedStringKey("Active"))
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Text(LocalizedStringKey("Unavailable"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Text(LocalizedStringKey("Last sync"))
                Spacer()
                Text(lastSyncDisplay)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(LocalizedStringKey("Sync count"))
                Spacer()
                Text("\(syncCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Toggle(isOn: $syncOverCellular) {
                Label(LocalizedStringKey("Sync over cellular"), systemImage: "antenna.radiowaves.left.and.right")
            }
        } header: {
            Text(LocalizedStringKey("iCloud Sync Status"))
        } footer: {
            Text(LocalizedStringKey("Prompts sync across your devices via iCloud. Disable cellular to save data."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var lastSyncDisplay: String {
        guard lastSyncRaw > 0 else {
            return NSLocalizedString("Never", comment: "iCloud sync — never synced yet")
        }
        let date = Date(timeIntervalSince1970: lastSyncRaw)
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
