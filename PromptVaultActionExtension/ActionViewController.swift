import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Entry point for the PromptVault Action Extension.
/// Extracts selected text from the host app, presents a SwiftUI
/// prompt-picker + variable-fill UI, then copies the rendered prompt
/// to the system clipboard and signals completion to the host.
final class ActionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        extractSharedText { [weak self] sharedText in
            guard let self else { return }
            let host = UIHostingController(rootView: ActionExtensionRootView(
                sharedText: sharedText,
                onComplete: { [weak self] filledPrompt in
                    UIPasteboard.general.string = filledPrompt
                    self?.completeRequest()
                },
                onCancel: { [weak self] in
                    self?.cancelRequest()
                }
            ))
            self.addChild(host)
            host.view.frame = self.view.bounds
            host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.addSubview(host.view)
            host.didMove(toParent: self)
        }
    }

    // MARK: - Text Extraction

    private func extractSharedText(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            completion("")
            return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                DispatchQueue.main.async {
                    completion((data as? String) ?? "")
                }
            }
        } else {
            completion("")
        }
    }

    // MARK: - Extension Lifecycle

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func cancelRequest() {
        extensionContext?.cancelRequest(
            withError: NSError(domain: "com.jiejuefuyou.promptvault.ActionExtension",
                               code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "User cancelled"])
        )
    }
}
