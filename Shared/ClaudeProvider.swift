import Foundation

/// Default provider: the Anthropic Messages API (Claude Sonnet).
///
/// Swift has no official Anthropic SDK, so this is a minimal raw-HTTP client over `URLSession`.
/// `final` + immutable `Sendable` stored properties make it `Sendable` for the keyboard's
/// off-main-actor network call.
final class ClaudeProvider: AIProvider {

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func generate(text: String, systemPrompt: String) async throws -> String {
        var request = URLRequest(url: Configuration.anthropicMessagesURL)
        request.httpMethod = "POST"
        request.timeoutInterval = Configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Configuration.anthropicVersion, forHTTPHeaderField: "anthropic-version")

        let payload = RequestBody(
            model: Configuration.claudeModel,
            maxTokens: Configuration.claudeMaxTokens,
            system: systemPrompt,
            messages: [RequestBody.Message(role: "user", content: text)]
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

    /// Anthropic errors come back as `{"type":"error","error":{"message":"..."}}`.
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
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

/// Subset of the Messages API response. Assistant text lives in `content` entries of
/// type `text`; we ignore everything else (and treat a `refusal` stop reason as empty output).
private struct ResponseBody: Decodable {
    let content: [Block]?

    struct Block: Decodable {
        let type: String?
        let text: String?
    }

    var extractedText: String {
        (content ?? [])
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined()
    }
}
