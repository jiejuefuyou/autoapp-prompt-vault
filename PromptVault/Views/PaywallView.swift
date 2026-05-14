import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: PaywallTier = .subscription

    enum PaywallTier { case oneTime, subscription }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    featureList
                    tierSelector
                    purchaseStatusBanner
                        .padding(.horizontal)
                    purchaseButton
                        .padding(.horizontal)
                    secondaryActions
                    complianceFooter
                }
                .padding(.vertical)
                .padding(.horizontal)
            }
            .navigationTitle(LocalizedStringKey("Upgrade"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Close")) { dismiss() }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
            }
            .onChange(of: iap.hasAnyEntitlement) { _, v in if v { dismiss() } }
            .onChange(of: iap.purchaseState) { _, newState in
                handlePurchaseStateChange(newState)
            }
            .alert(
                Text(alertTitle),
                isPresented: $showAlert
            ) {
                Button(LocalizedStringKey("OK")) {
                    iap.resetPurchaseState()
                }
            } message: {
                Text(alertMessage)
            }
            .task { await iap.loadProducts() }
        }
    }

    // MARK: - Alert state

    @State private var showAlert: Bool = false
    @State private var alertTitle: LocalizedStringKey = ""
    @State private var alertMessage: String = ""

    private func handlePurchaseStateChange(_ state: IAPManager.PurchaseState) {
        switch state {
        case .failed(let message):
            alertTitle = LocalizedStringKey("Purchase Issue")
            alertMessage = message
            showAlert = true
        case .pending:
            alertTitle = LocalizedStringKey("Purchase pending")
            alertMessage = String(localized: "Purchase pending. We'll complete it shortly.")
            showAlert = true
        case .idle, .purchasing, .success, .cancelled, .unverified:
            break
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 8)
                .accessibilityHidden(true)

            Text(LocalizedStringKey("Unlock PromptVault Pro"))
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(LocalizedStringKey("200+ AI workflows. Variable templates. Action Extension."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Feature list

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "doc.text.below.ecg",
                       text: LocalizedStringKey("200+ Pro prompts (5 categories)"))
            featureRow(icon: "curlybraces",
                       text: LocalizedStringKey("Variable templates {{name:type=default}}"))
            featureRow(icon: "square.and.arrow.up.on.square",
                       text: LocalizedStringKey("Action Extension (share sheet)"))
            featureRow(icon: "icloud.fill",
                       text: LocalizedStringKey("iCloud sync across devices"))
            featureRow(icon: "tag",
                       text: LocalizedStringKey("Unlimited tags"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func featureRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)
                .accessibilityHidden(true)
            Text(text).font(.body)
            Spacer()
        }
    }

    // MARK: - Tier selector

    private var tierSelector: some View {
        VStack(spacing: 12) {
            // Subscription tier with free trial badge
            Button {
                selectedTier = .subscription
            } label: {
                tierCard(
                    title: LocalizedStringKey("Pro Monthly"),
                    price: iap.subscriptionPrice ?? "$0.99",
                    badge: LocalizedStringKey("7 DAYS FREE"),
                    subtitle: String(
                        format: NSLocalizedString(
                            "Then %@/month. Cancel anytime.",
                            comment: "Subscription tier card subtitle"
                        ),
                        iap.subscriptionPrice ?? "$0.99"
                    ),
                    isSelected: selectedTier == .subscription
                )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedTier == .subscription ? [.isSelected] : [])

            // One-time lifetime tier
            Button {
                selectedTier = .oneTime
            } label: {
                tierCard(
                    title: LocalizedStringKey("Lifetime"),
                    price: iap.oneTimePrice ?? "$4.99",
                    badge: nil,
                    subtitle: NSLocalizedString(
                        "One-time. Yours forever.",
                        comment: "Lifetime tier card subtitle"
                    ),
                    isSelected: selectedTier == .oneTime
                )
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selectedTier == .oneTime ? [.isSelected] : [])
        }
    }

    private func tierCard(
        title: LocalizedStringKey,
        price: String,
        badge: LocalizedStringKey?,
        subtitle: String,
        isSelected: Bool
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.green, in: Capsule())
                    }
                }
                Text(price)
                    .font(.title2.weight(.heavy))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
        .padding()
        .background(
            isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSelected ? Color.accentColor : Color.gray.opacity(0.2),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }

    // MARK: - Purchase status banner (inline, visible to reviewers)

    /// Apple Review round-4 (2.1(b)) lesson: every purchase outcome needs a
    /// visible UI surface. This banner sits above the CTA button and surfaces
    /// failed / cancelled / pending / unverified states inline so the reviewer
    /// (and real user) immediately sees what happened.
    @ViewBuilder
    private var purchaseStatusBanner: some View {
        switch iap.purchaseState {
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Label(LocalizedStringKey("Purchase failed"), systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .unverified:
            VStack(alignment: .leading, spacing: 6) {
                Label(LocalizedStringKey("Purchase Issue"), systemImage: "exclamationmark.shield.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(LocalizedStringKey("Purchase verification failed. Please contact support."))
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .cancelled:
            Label(LocalizedStringKey("Purchase canceled."), systemImage: "xmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

        case .pending:
            VStack(spacing: 6) {
                Label(LocalizedStringKey("Purchase pending"), systemImage: "clock.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(LocalizedStringKey("Purchase pending. We'll complete it shortly."))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(12)
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .idle, .purchasing, .success:
            EmptyView()
        }
    }

    // MARK: - Purchase CTA

    @ViewBuilder
    private var purchaseButton: some View {
        Button {
            Task {
                if selectedTier == .subscription {
                    await iap.purchaseSubscription()
                } else {
                    await iap.purchaseOneTime()
                }
            }
        } label: {
            Group {
                if case .purchasing = iap.purchaseState {
                    ProgressView().tint(.white)
                } else if case .failed = iap.purchaseState {
                    Text(LocalizedStringKey("Try again")).font(.headline)
                } else {
                    Text(selectedTier == .subscription
                         ? LocalizedStringKey("Start 7-day free trial")
                         : LocalizedStringKey("Buy lifetime"))
                        .font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(iap.purchaseState == .purchasing)
        .accessibilityLabel(
            selectedTier == .subscription
            ? Text(
                String(
                    format: NSLocalizedString(
                        "Start 7 day free trial then %@ per month",
                        comment: "Subscription CTA accessibility label"
                    ),
                    iap.subscriptionPrice ?? "$0.99"
                )
            )
            : Text(
                String(
                    format: NSLocalizedString(
                        "Buy lifetime for %@",
                        comment: "Lifetime CTA accessibility label"
                    ),
                    iap.oneTimePrice ?? "$4.99"
                )
            )
        )
    }

    // MARK: - Secondary actions (Restore + Manage Subscription)

    private var secondaryActions: some View {
        VStack(spacing: 12) {
            // Apple 3.1.2: Restore button must be visible on the paywall
            Button(LocalizedStringKey("Restore Purchases")) {
                Task { await iap.restorePurchases() }
            }
            .font(.subheadline)
            .frame(minWidth: 60, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityHint(Text(LocalizedStringKey("Restores a previous purchase or subscription")))

            // Deep link to Apple subscription management — shown when user is
            // already a subscriber so they can cancel / modify from within app.
            if iap.isProSubscriber {
                // swiftlint:disable:next force_unwrapping
                Link(LocalizedStringKey("Manage Subscription"),
                     destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!)
                    .font(.subheadline)
                    .frame(minWidth: 60, minHeight: 44)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: - Compliance footer (Apple 3.1.2 mandatory)

    /// Apple 3.1.2 requires: auto-renewal disclosure, Terms of Use link,
    /// Privacy Policy link. All three must be visible on the paywall for
    /// any app that sells auto-renewable subscriptions.
    private var complianceFooter: some View {
        VStack(spacing: 8) {
            if selectedTier == .subscription {
                Text(LocalizedStringKey(
                    "Subscription auto-renews monthly. Cancel anytime in your Apple ID settings at least 24 hours before the period ends. Trial ends automatically if not canceled before 7-day mark."
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }

            HStack(spacing: 20) {
                // swiftlint:disable:next force_unwrapping
                Link(LocalizedStringKey("Terms of Use"),
                     destination: URL(string: "https://jiejuefuyou.github.io/promptvault-terms")!)

                // swiftlint:disable:next force_unwrapping
                Link(LocalizedStringKey("Privacy Policy"),
                     destination: URL(string: "https://jiejuefuyou.github.io/promptvault-privacy")!)
            }
            .font(.caption2)
        }
        .padding(.top, 4)
        .padding(.bottom, 16)
    }
}

#Preview {
    PaywallView().environment(IAPManager())
}
