import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                        .padding(.top, 24)

                    Text(LocalizedStringKey("PromptVault Premium")).font(.largeTitle.bold())

                    Text(LocalizedStringKey("One-time purchase. No subscription. Unlock everything forever."))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 14) {
                        // First feature interpolates the free-tier limit; SwiftUI Text
                        // auto-localizes and substitutes %lld from the strings file.
                        feature(icon: "infinity",
                                view: AnyView(Text("Unlimited prompts (free tier: \(PromptStore.freePromptLimit))")))
                        feature(icon: "books.vertical",
                                view: AnyView(Text(LocalizedStringKey("200+ curated starter prompts"))))
                        feature(icon: "tag.fill",
                                view: AnyView(Text(LocalizedStringKey("Unlimited tags per prompt"))))
                        feature(icon: "textformat.abc",
                                view: AnyView(Text(LocalizedStringKey("{{variable}} substitution preview"))))
                        feature(icon: "doc.on.clipboard",
                                view: AnyView(Text(LocalizedStringKey("One-tap copy with usage stats"))))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    purchaseButton.padding(.horizontal)

                    Button(LocalizedStringKey("Restore Purchase")) { Task { await iap.restore() } }.font(.footnote)

                    if let err = iap.lastError {
                        Text(err).font(.caption).foregroundStyle(.red).padding(.horizontal)
                    }

                    VStack(spacing: 4) {
                        Label(LocalizedStringKey("No subscription. No data collected. Ever."), systemImage: "lock.shield.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey("Payment will be charged to your Apple ID. This is a one-time purchase that unlocks all premium features for the lifetime of your Apple ID."))
                            .font(.caption2).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal).padding(.bottom)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button(LocalizedStringKey("Close")) { dismiss() } }
            }
            .onChange(of: iap.isPremium) { _, v in if v { dismiss() } }
            .task { await iap.loadProducts() }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if iap.isPremium {
            Label(LocalizedStringKey("Premium unlocked"), systemImage: "checkmark.seal.fill")
                .font(.headline).frame(maxWidth: .infinity).padding()
                .background(Color.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.green)
        } else if let product = iap.products.first {
            Button { Task { await iap.purchase() } } label: {
                HStack {
                    if iap.purchaseInProgress { ProgressView().tint(.white) }
                    if iap.purchaseInProgress {
                        Text(LocalizedStringKey("Processing…")).font(.headline)
                    } else {
                        Text("Unlock for \(product.displayPrice)").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity).padding()
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
            }
            .disabled(iap.purchaseInProgress)
        } else {
            ProgressView().frame(maxWidth: .infinity).padding()
        }
    }

    private func feature(icon: String, view: AnyView) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.tint).frame(width: 28)
            view
            Spacer()
        }
    }
}

#Preview {
    PaywallView().environment(IAPManager())
}
