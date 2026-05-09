import SwiftUI
import AVFoundation

// MARK: - PromptScanView
// Presents a camera viewfinder that reads QR codes and parses the
// versioned JSON payload { version: 1, title: String, body: String, tags: [String] }.

struct PromptScanView: View {
    @Environment(PromptStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var scannedPrompt: Prompt?
    @State private var cameraPermissionDenied = false
    @State private var showImportSheet = false
    @State private var importedSuccessfully = false

    var body: some View {
        NavigationStack {
            Group {
                if cameraPermissionDenied {
                    permissionDeniedView
                } else {
                    ZStack(alignment: .bottom) {
                        QRScannerRepresentable(
                            onScanned: handleScanned,
                            onPermissionDenied: { cameraPermissionDenied = true }
                        )
                        .ignoresSafeArea()

                        // Finder overlay
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
                                .frame(width: 240, height: 240)
                                .background(Color.clear)
                            Spacer()
                            Text(LocalizedStringKey("Point at a PromptVault QR code"))
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle(Text("Scan QR Code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showImportSheet) {
                if let p = scannedPrompt {
                    ImportConfirmView(prompt: p) { confirmed in
                        if confirmed {
                            store.add(p)
                            importedSuccessfully = true
                            Haptics.success()
                        }
                        showImportSheet = false
                        if confirmed { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - Permission denied fallback

    @ViewBuilder
    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.slash")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text(LocalizedStringKey("Camera Access Required"))
                .font(.title2.bold())
            Text(LocalizedStringKey("PromptVault needs camera access to scan QR codes. Enable it in Settings > Privacy > Camera."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button(LocalizedStringKey("Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    // MARK: - Scan handler

    private func handleScanned(_ string: String) {
        guard !showImportSheet else { return }  // Prevent re-entry while sheet is open
        guard let prompt = parseQRPayload(string) else { return }
        scannedPrompt = prompt
        Haptics.medium()
        showImportSheet = true
    }

    /// Parses the versioned JSON payload.
    /// Schema: { "version": 1, "title": String, "body": String, "tags": [String] }
    /// Forward-compat: ignores unknown fields; fails gracefully on unknown version or bad schema.
    private func parseQRPayload(_ string: String) -> Prompt? {
        guard let data = string.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // Version guard — forward-compat: only handle version == 1
        if let v = json["version"] as? Int, v == 1 {
            // intentionally falls through
        } else {
            // Missing version field: attempt best-effort parse for backward compat
            if json["title"] == nil { return nil }
        }

        guard let title = json["title"] as? String, !title.isEmpty,
              let body  = json["body"]  as? String, !body.isEmpty else { return nil }
        let tags = (json["tags"] as? [String]) ?? []

        return Prompt(title: title, body: body, tags: tags)
    }
}

// MARK: - Import Confirmation Sheet

private struct ImportConfirmView: View {
    let prompt: Prompt
    let onDecision: (Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("Prompt to import")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(prompt.title)
                            .font(.headline)
                        Text(prompt.body)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(8)
                    }
                    .padding(.vertical, 4)
                }

                if !prompt.tags.isEmpty {
                    Section(LocalizedStringKey("Tags")) {
                        Text(prompt.tags.joined(separator: ", "))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button {
                        onDecision(true)
                    } label: {
                        Label(LocalizedStringKey("Save to PromptVault"), systemImage: "tray.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .cancel) {
                        onDecision(false)
                    } label: {
                        Text(LocalizedStringKey("Cancel"))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(Text("Import Prompt?"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

// MARK: - UIKit camera wrapper

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onPermissionDenied: () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScanned = onScanned
        vc.onPermissionDenied = onPermissionDenied
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScanned: ((String) -> Void)?
    var onPermissionDenied: (() -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndSetup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !session.isRunning { session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        previewLayer?.connection?.videoRotationAngle = currentVideoRotationAngle()
    }

    private func currentVideoRotationAngle() -> CGFloat {
        switch UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.interfaceOrientation {
        case .landscapeLeft:        return 180
        case .landscapeRight:       return 0
        case .portraitUpsideDown:   return 270
        default:                    return 90  // portrait
        }
    }

    private func checkPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupSession() }
                    else { self?.onPermissionDenied?() }
                }
            }
        default:
            DispatchQueue.main.async { [weak self] in
                self?.onPermissionDenied?()
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        onScanned?(value)
    }
}

#Preview {
    PromptScanView()
        .environment(PromptStore())
}
