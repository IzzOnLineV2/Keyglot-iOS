import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Principal class of the share extension.
///
/// Receives a shared audio file — e.g. a WhatsApp voice note sent via *Forward → Share* — then
/// transcribes and translates it into the user's language via `AudioShareModel`.
final class ShareViewController: UIViewController {

    private let model = AudioShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let root = AudioShareView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        extractAudio()
    }

    private func extractAudio() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap { $0.attachments }
            .flatMap { $0 } ?? []

        let audioType = UTType.audio.identifier
        let provider = providers.first { $0.hasItemConformingToTypeIdentifier(audioType) } ?? providers.first

        guard let provider else {
            model.fail(String(localized: "No audio found to translate."))
            return
        }

        let typeID = provider.hasItemConformingToTypeIdentifier(audioType)
            ? audioType
            : (provider.registeredTypeIdentifiers.first ?? audioType)

        provider.loadFileRepresentation(forTypeIdentifier: typeID) { [weak self] url, error in
            guard let self else { return }
            guard let url else {
                Task { @MainActor in
                    self.model.fail(error?.localizedDescription ?? String(localized: "Couldn't read the audio."))
                }
                return
            }

            // The system-provided URL is temporary and removed once this block returns, so copy
            // the file somewhere we control before the async upload. Preserve the real extension
            // (WhatsApp voice notes are often .opus) so OpenAI can detect the audio format.
            let ext = url.pathExtension.isEmpty
                ? (UTType(typeID)?.preferredFilenameExtension ?? "m4a")
                : url.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            do {
                try FileManager.default.copyItem(at: url, to: dest)
            } catch {
                Task { @MainActor in self.model.fail(error.localizedDescription) }
                return
            }

            Task { await self.model.run(fileURL: dest) }
        }
    }
}
