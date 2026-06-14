import Foundation

/// Future provider: the OpenAI Responses API. Not the default, but fully wired up so that
/// enabling it is purely a settings change.
///
/// Transparently retries with a fallback model if the default model is rejected by the account.
final class OpenAIProvider: AIProvider {

    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func translate(text: String, targetLanguage: TargetLanguage) async throws -> String {
        let instructions = targetLanguage.prompt
        do {
            return try await send(text: text, model: Configuration.openAIDefaultModel, instructions: instructions)
        } catch let error as ProviderError where error.isModelRejection {
            return try await send(text: text, model: Configuration.openAIFallbackModel, instructions: instructions)
        }
    }

    private func send(text: String, model: String, instructions: String) async throws -> String {
        var request = URLRequest(url: Configuration.openAIResponsesURL)
        request.httpMethod = "POST"
        request.timeoutInterval = Configuration.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = RequestBody(
            model: model,
            instructions: instructions,
            input: text,
            reasoning: Configuration.openAIReasoningEffort.map { RequestBody.Reasoning(effort: $0) }
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
    let instructions: String
    let input: String
    let reasoning: Reasoning?

    struct Reasoning: Encodable {
        let effort: String
    }
}

/// Responses API output: assistant text lives in `output[].content[]` entries of type
/// `output_text`.
private struct ResponseBody: Decodable {
    let output: [OutputItem]?

    struct OutputItem: Decodable {
        let type: String?
        let content: [ContentPart]?
    }

    struct ContentPart: Decodable {
        let type: String?
        let text: String?
    }

    var extractedText: String {
        guard let output else { return "" }
        return output
            .flatMap { $0.content ?? [] }
            .filter { $0.type == "output_text" }
            .compactMap { $0.text }
            .joined()
    }
}
