import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Principal class of the share extension. Translates two kinds of shared content into the user's
/// language:
/// - **audio** (e.g. a WhatsApp voice note via *Forward → Share*) → transcribed + translated by Gemini
/// - **text** (a selection, a note, a link) → translated by the selected provider
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        route()
    }

    private var providers: [NSItemProvider] {
        (extensionContext?.inputItems as? [NSExtensionItem])?
            .compactMap { $0.attachments }
            .flatMap { $0 } ?? []
    }

    private func route() {
        // Prefer text when present (a selection / note / link); otherwise treat it as audio.
        if let textProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.text.identifier) }) {
            handleText(textProvider)
        } else if let audioProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.audio.identifier) }) ?? providers.first {
            handleAudio(audioProvider)
        } else {
            let model = TextShareModel()
            install(TextShareView(model: model, onClose: closeAction))
            model.fail(String(localized: "Nothing to translate here."))
        }
    }

    // MARK: - Text

    private func handleText(_ provider: NSItemProvider) {
        let model = TextShareModel()
        install(TextShareView(model: model, onClose: closeAction))

        provider.loadItem(forTypeIdentifier: UTType.text.identifier) { item, error in
            // Reduce the non-Sendable item to a plain String here, then hop to the main actor
            // with only Sendable values (Swift 6 strict concurrency).
            let text: String?
            switch item {
            case let s as String: text = s
            case let url as URL: text = try? String(contentsOf: url, encoding: .utf8)
            case let data as Data: text = String(data: data, encoding: .utf8)
            default: text = nil
            }
            let failure = error?.localizedDescription
            Task { @MainActor in
                if let text {
                    await model.translate(text)
                } else {
                    model.fail(failure ?? String(localized: "Nothing to translate here."))
                }
            }
        }
    }

    // MARK: - Audio

    private func handleAudio(_ provider: NSItemProvider) {
        let model = AudioShareModel()
        install(AudioShareView(model: model, onClose: closeAction))

        let audioType = UTType.audio.identifier
        let typeID = provider.hasItemConformingToTypeIdentifier(audioType)
            ? audioType
            : (provider.registeredTypeIdentifiers.first ?? audioType)

        provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, error in
            guard let url else {
                Task { @MainActor in
                    model.fail(error?.localizedDescription ?? String(localized: "Couldn't read the audio."))
                }
                return
            }

            // The system URL is temporary — copy it, preserving the real extension so the MIME is
            // detected correctly (WhatsApp voice notes are .m4a / .opus).
            let ext = url.pathExtension.isEmpty
                ? (UTType(typeID)?.preferredFilenameExtension ?? "m4a")
                : url.pathExtension
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(ext)
            do {
                try FileManager.default.copyItem(at: url, to: dest)
            } catch {
                Task { @MainActor in model.fail(error.localizedDescription) }
                return
            }

            Task { @MainActor in model.start(fileURL: dest) }
        }
    }

    // MARK: - Hosting

    private var closeAction: () -> Void {
        { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }
    }

    private func install(_ rootView: some View) {
        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}
