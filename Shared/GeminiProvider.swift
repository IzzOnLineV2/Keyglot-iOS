import Foundation

/// Google Gemini via the Generative Language API (`generateContent`).
///
/// Raw-HTTP `URLSession` client. `final` + immutable `Sendable` stored properties make it
/// `Sendable` for the keyboard's off-main-actor network call.
final class GeminiProvider: AIProvider {

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func translate(text: String, targetLanguage: TargetLanguage) async throws -> String {
        var request = URLRequest(url: Configuration.geminiURL())
        request.httpMethod = "POST"
        request.timeoutInterval = Configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let payload = RequestBody(
            systemInstruction: .init(parts: [.init(text: targetLanguage.prompt)]),
            contents: [.init(role: "user", parts: [.init(text: text)])]
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.decodeErrorMessage(from: data) ?? "request failed"
            throw ProviderError.http(status: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let result = decoded.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { throw ProviderError.emptyOutput }
        return result
    }

    /// Gemini errors come back as `{"error":{"message":"..."}}`.
    private static func decodeErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct APIError: Decodable { let message: String? }
            let error: APIError?
        }
        return (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error?.message
    }
}

// MARK: - Wire format

private struct RequestBody: Encodable {
    let systemInstruction: Content
    let contents: [Content]

    struct Content: Encodable {
        var role: String? = nil   // omitted for `systemInstruction`; "user" for `contents`
        let parts: [Part]
    }

    struct Part: Encodable {
        let text: String
    }
}

/// Assistant text lives in `candidates[].content.parts[].text`.
private struct ResponseBody: Decodable {
    let candidates: [Candidate]?

    struct Candidate: Decodable {
        let content: Content?
    }

    struct Content: Decodable {
        let parts: [Part]?
    }

    struct Part: Decodable {
        let text: String?
    }

    var extractedText: String {
        (candidates?.first?.content?.parts ?? [])
            .compactMap { $0.text }
            .joined()
    }
}
