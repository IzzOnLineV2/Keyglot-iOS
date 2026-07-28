import Foundation

/// Transcribes an audio file with OpenAI's Whisper endpoint (`/v1/audio/transcriptions`).
///
/// Used by the share extension to turn a received voice message (e.g. a WhatsApp voice note
/// shared via *Forward → Share*) into text, which is then translated. Whisper auto-detects the
/// spoken language, so the user never has to specify it. Reuses `ProviderError` for errors.
struct OpenAITranscriptionService: Sendable {

    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func transcribe(fileURL: URL, language: String? = nil) async throws -> String {
        let boundary = "keyglot-\(UUID().uuidString)"

        var request = URLRequest(url: Configuration.openAITranscriptionURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData: Data
        do {
            fileData = try Data(contentsOf: fileURL)
        } catch {
            throw ProviderError.transport(error)
        }

        var body = Data()
        func appendField(_ text: String) { body.append(Data(text.utf8)) }

        // model
        appendField("--\(boundary)\r\n")
        appendField("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        appendField("\(Configuration.openAITranscriptionModel)\r\n")
        // language hint (optional ISO-639-1) — greatly improves accuracy for dialects like
        // Moroccan Darija (transcribe as "ar") when auto-detect gets the language wrong.
        if let language, !language.isEmpty {
            appendField("--\(boundary)\r\n")
            appendField("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            appendField("\(language)\r\n")
        }
        // file
        appendField("--\(boundary)\r\n")
        appendField("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n")
        appendField("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        appendField("\r\n--\(boundary)--\r\n")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.upload(for: request, from: body)
        } catch {
            throw ProviderError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.decodeErrorMessage(from: data) ?? "transcription failed"
            throw ProviderError.http(status: http.statusCode, message: message)
        }

        struct TranscriptionResponse: Decodable { let text: String }
        guard let decoded = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) else {
            throw ProviderError.invalidResponse
        }
        return decoded.text
    }

    private static func decodeErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct APIError: Decodable { let message: String? }
            let error: APIError?
        }
        return (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error?.message
    }
}
