import Foundation

/// Text translation/rewrite via the KeyGlot backend (KeyGlot mode). Same `AIProvider` surface as
/// the direct providers, so the keyboard/share code is unaware it's talking to a backend.
struct KeyGlotProvider: AIProvider {
    let session: KeyGlotSession
    var http: URLSession = .shared

    func generate(text: String, systemPrompt: String) async throws -> String {
        struct Req: Encodable { let text: String; let systemPrompt: String }
        struct Res: Decodable { let text: String }
        let data = try await KeyGlotHTTP.post("v1/translate",
                                              body: Req(text: text, systemPrompt: systemPrompt),
                                              session: session, http: http)
        let out = try JSONDecoder().decode(Res.self, from: data)
            .text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !out.isEmpty else { throw ProviderError.emptyOutput }
        return out
    }
}

/// Audio transcription+translation via the KeyGlot backend (KeyGlot mode).
struct KeyGlotAudioTranslator: AudioTranslating {
    let session: KeyGlotSession
    var http: URLSession = .shared

    func translate(fileURL: URL, mimeType: String, targetLanguage: String, sourceHint: String?) async throws -> AudioTranslation {
        let audioBase64: String
        do { audioBase64 = try Data(contentsOf: fileURL).base64EncodedString() }
        catch { throw ProviderError.transport(error) }

        struct Req: Encodable {
            let audioBase64: String
            let mimeType: String
            let targetLanguage: String
            let sourceHint: String?
        }
        struct Res: Decodable { let transcript: String; let translation: String }
        let data = try await KeyGlotHTTP.post(
            "v1/audio",
            body: Req(audioBase64: audioBase64, mimeType: mimeType, targetLanguage: targetLanguage, sourceHint: sourceHint),
            session: session, http: http
        )
        let res = try JSONDecoder().decode(Res.self, from: data)
        return AudioTranslation(transcript: res.transcript, translation: res.translation)
    }
}

/// Shared POST helper: attaches the session bearer token and, on a 401, refreshes it once and
/// retries. Backend error bodies are mapped to `ProviderError.http` (no provider details leak).
enum KeyGlotHTTP {
    static func post<Body: Encodable>(
        _ path: String,
        body: Body,
        session: KeyGlotSession,
        http: URLSession
    ) async throws -> Data {
        let payload = try JSONEncoder().encode(body)
        var token = try await session.authorizedToken()

        for attempt in 0..<2 {
            var request = URLRequest(url: Configuration.keyglotBackendBaseURL.appendingPathComponent(path))
            request.httpMethod = "POST"
            request.timeoutInterval = 90
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.httpBody = payload

            let data: Data
            let response: URLResponse
            do { (data, response) = try await http.data(for: request) }
            catch { throw ProviderError.transport(error) }

            guard let httpResp = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }

            if httpResp.statusCode == 401, attempt == 0 {
                token = try await session.refreshedToken()
                continue
            }
            guard (200..<300).contains(httpResp.statusCode) else {
                throw ProviderError.http(status: httpResp.statusCode,
                                         message: KeyGlotSession.errorMessage(data) ?? "request failed")
            }
            return data
        }
        throw ProviderError.invalidResponse
    }
}
