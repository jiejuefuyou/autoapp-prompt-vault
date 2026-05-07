import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - JSON payload schema v1
// { "version": 1, "title": String, "body": String, "tags": [String] }

struct PromptShareView: View {
    @Environment(IAPManager.self) private var iap
    @Environment(\.dismiss) private var dismiss

    let prompt: Prompt

    @State private var qrImage: UIImage?
    @State private var showPaywall = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            Group {
                if iap.isPremium {
                    premiumContent
                } else {
                    freeContent
                }
            }
            .navigationTitle("Share Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear { generateQRIfNeeded() }
        }
    }

    // MARK: - Premium: QR Code view

    @ViewBuilder
    private var premiumContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Scan this QR code on another device\nrunning PromptVault to import the prompt.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.horizontal)

                if let img = qrImage {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 280, height: 280)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .accessibilityLabel("QR code for prompt: \(prompt.title)")
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemFill))
                        .frame(width: 280, height: 280)
                        .overlay {
                            ProgressView()
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(prompt.title)
                        .font(.headline)
                    Text(prompt.body)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    if !prompt.tags.isEmpty {
                        Text(prompt.tags.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                copyTextButton
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .padding(.top, 16)
        }
    }

    // MARK: - Free tier: text-only fallback

    @ViewBuilder
    private var freeContent: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "qrcode")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            Text("Premium Feature")
                .font(.title2.bold())

            Text("QR code sharing is a Premium feature. Upgrade once to share and import prompts between devices, or copy the prompt text below for free.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            copyTextButton
                .padding(.horizontal, 32)

            Button {
                showPaywall = true
            } label: {
                Label("Upgrade to Premium", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Shared copy-text button

    @ViewBuilder
    private var copyTextButton: some View {
        Button {
            UIPasteboard.general.string = prompt.body
            Haptics.success()
            copied = true
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                copied = false
            }
        } label: {
            Label(copied ? "Copied!" : "Copy text to clipboard",
                  systemImage: copied ? "checkmark" : "doc.on.doc")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(copied ? .green : .primary)
        }
        .animation(.easeInOut(duration: 0.2), value: copied)
    }

    // MARK: - QR generation

    private func generateQRIfNeeded() {
        guard iap.isPremium else { return }
        qrImage = Self.generateQRCode(for: prompt)
    }

    /// Builds a versioned JSON payload and returns a 320×320 UIImage QR code, or nil on failure.
    static func generateQRCode(for prompt: Prompt) -> UIImage? {
        let payload: [String: Any] = [
            "version": 1,
            "title": prompt.title,
            "body": prompt.body,
            "tags": prompt.tags
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return nil }

        // Step 1: Generate raw QR CIImage via CIFilter.qrCodeGenerator()
        let qrFilter = CIFilter.qrCodeGenerator()
        qrFilter.message = Data(jsonString.utf8)
        qrFilter.correctionLevel = "M"
        guard let rawCIImage = qrFilter.outputImage else { return nil }

        // Step 2: Scale to 320×320 using CILanczosScaleTransform
        let targetSize: CGFloat = 320.0
        let scaleX = targetSize / rawCIImage.extent.width
        let scaleY = targetSize / rawCIImage.extent.height
        guard let scaleFilter = CIFilter(name: "CILanczosScaleTransform") else { return nil }
        scaleFilter.setValue(rawCIImage, forKey: kCIInputImageKey)
        scaleFilter.setValue(scaleX, forKey: kCIInputScaleKey)
        scaleFilter.setValue(scaleY / scaleX, forKey: kCIInputAspectRatioKey)
        guard let scaledCIImage = scaleFilter.outputImage else { return nil }

        // Step 3: Render to UIImage (nearest-neighbor to preserve crisp pixels)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(scaledCIImage, from: scaledCIImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    PromptShareView(
        prompt: Prompt(title: "Translate text", body: "Translate the following to natural English: {{text}}", tags: ["writing", "translation"])
    )
    .environment(IAPManager())
}
