import Foundation

/// OpenRouter — an OpenAI-compatible gateway that fronts many models (`chat/completions`).
///
/// Raw-HTTP `URLSession` client. `final` + immutable `Sendable` stored properties make it
/// `Sendable` for the keyboard's off-main-actor network call.
final class OpenRouterProvider: AIProvider {

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func generate(text: String, systemPrompt: String) async throws -> String {
        var request = URLRequest(url: Configuration.openRouterURL)
        request.httpMethod = "POST"
        request.timeoutInterval = Configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // Optional attribution headers OpenRouter uses for ranking.
        request.setValue(Configuration.openRouterReferer, forHTTPHeaderField: "HTTP-Referer")
        request.setValue(Configuration.openRouterTitle, forHTTPHeaderField: "X-Title")

        let payload = RequestBody(
            model: Configuration.openRouterModel,
            messages: [
                RequestBody.Message(role: "system", content: systemPrompt),
                RequestBody.Message(role: "user", content: text),
            ]
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

    /// OpenRouter errors come back as `{"error":{"message":"..."}}`.
    private static func decodeErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct APIError: Decodable { let message: String? }
            let error: APIError?
        }
        return (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error?.message
    }
}

// MARK: - Wire format (OpenAI chat-completions shape)

private struct RequestBody: Encodable {
    let model: String
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ResponseBody: Decodable {
    let choices: [Choice]?

    struct Choice: Decodable {
        let message: Message?
    }

    struct Message: Decodable {
        let content: String?
    }

    var extractedText: String {
        choices?.first?.message?.content ?? ""
    }
}
