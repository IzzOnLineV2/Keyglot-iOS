import Foundation

/// Sends a voice message to Google Gemini, which "listens" to the audio and returns both a
/// transcript and a translation in a single call.
///
/// This beats literal speech-to-text (Whisper/`gpt-4o-transcribe`) on regional dialects such as
/// Moroccan Darija: Gemini interprets the audio holistically instead of transcribing phonetically.
/// The audio file is sent inline; pick the MIME type from the file (m4a → `audio/mp4`,
/// opus → `audio/ogg`), the wrong MIME makes Gemini mis-decode the audio.
struct GeminiAudioTranslator: AudioTranslating, Sendable {

    let apiKey: String
    let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// - Parameters:
    ///   - fileURL: the shared audio file.
    ///   - mimeType: Gemini audio MIME (e.g. `audio/mp4`, `audio/ogg`).
    ///   - targetLanguage: English name of the language to translate into (e.g. "Italian").
    ///   - sourceHint: optional English name of the likely source language (from the picker).
    func translate(fileURL: URL, mimeType: String, targetLanguage: String, sourceHint: String?) async throws -> AudioTranslation {
        let audioBase64: String
        do {
            audioBase64 = try Data(contentsOf: fileURL).base64EncodedString()
        } catch {
            throw ProviderError.transport(error)
        }

        let hint = sourceHint.map { " The audio is likely in \($0)." } ?? ""
        let prompt = """
        You are given a short voice message, e.g. a WhatsApp voice note. It may be informal or in \
        a regional dialect such as Moroccan Darija.\(hint) Listen to it and reply EXACTLY in this \
        format and nothing else:
        TRANSCRIPT: <a faithful transcription in the original language and its native script>
        TRANSLATION: <a natural translation into \(targetLanguage)>
        """

        var request = URLRequest(url: Configuration.geminiURL(model: Configuration.geminiAudioModel))
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        let payload = RequestBody(contents: [
            .init(parts: [
                .init(text: prompt, inlineData: nil),
                .init(text: nil, inlineData: .init(mimeType: mimeType, data: audioBase64)),
            ])
        ])
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, http) = try await sendWithRetry(request)
        guard (200..<300).contains(http.statusCode) else {
            let message = Self.decodeErrorMessage(from: data) ?? "request failed"
            throw ProviderError.http(status: http.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        let text = decoded.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw ProviderError.emptyOutput }
        return Self.parse(text)
    }

    /// Send the request, retrying a few times when Gemini is momentarily overloaded.
    ///
    /// Gemini's `*-latest` alias points at a preview model that returns transient **503 "high
    /// demand"** (and occasionally 429/500/502/504) during traffic spikes. Those clear on their
    /// own, so a short exponential backoff turns a first-try failure into a success instead of an
    /// error in the user's face. Timeouts are retried too. Non-transient HTTP errors return their
    /// response so the caller can surface the real message.
    private func sendWithRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let maxAttempts = 3
        var lastTransport: Error?
        for attempt in 0..<maxAttempts {
            let isLast = attempt == maxAttempts - 1
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
                if Self.isTransient(http.statusCode), !isLast {
                    try? await Task.sleep(nanoseconds: Self.backoffNanos(attempt))
                    continue
                }
                return (data, http)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastTransport = error
                if isLast { throw ProviderError.transport(error) }
                try? await Task.sleep(nanoseconds: Self.backoffNanos(attempt))
            }
        }
        throw ProviderError.transport(lastTransport ?? URLError(.unknown))
    }

    /// Server-side hiccups worth retrying: rate limit and the 5xx family (503 = "high demand").
    private static func isTransient(_ status: Int) -> Bool {
        status == 429 || status == 500 || status == 502 || status == 503 || status == 504
    }

    /// Exponential backoff with jitter: ~1s, then ~2s. Keeps total added wait under ~3s so the
    /// share sheet still feels responsive.
    private static func backoffNanos(_ attempt: Int) -> UInt64 {
        let base = pow(2.0, Double(attempt))          // 1s, 2s, 4s…
        let jitter = Double.random(in: 0...0.4)
        return UInt64((base + jitter) * 1_000_000_000)
    }

    /// Split the "TRANSCRIPT: … / TRANSLATION: …" reply. If the model didn't follow the format,
    /// fall back to showing the whole reply as the translation.
    static func parse(_ text: String) -> AudioTranslation {
        var transcript = "", translation = ""
        var bucket = 0   // 1 = transcript, 2 = translation
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if let r = line.range(of: "TRANSCRIPT:", options: .caseInsensitive) {
                bucket = 1; transcript += line[r.upperBound...].trimmingCharacters(in: .whitespaces)
            } else if let r = line.range(of: "TRANSLATION:", options: .caseInsensitive) {
                bucket = 2; translation += line[r.upperBound...].trimmingCharacters(in: .whitespaces)
            } else {
                switch bucket {
                case 1: transcript += "\n" + line
                case 2: translation += "\n" + line
                default: break
                }
            }
        }
        transcript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        return AudioTranslation(
            transcript: transcript.isEmpty ? text : transcript,
            translation: translation.isEmpty ? text : translation
        )
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
    let contents: [Content]

    struct Content: Encodable {
        let parts: [Part]
    }
    struct Part: Encodable {
        let text: String?
        let inlineData: InlineData?
        enum CodingKeys: String, CodingKey { case text; case inlineData = "inline_data" }
    }
    struct InlineData: Encodable {
        let mimeType: String
        let data: String
        enum CodingKeys: String, CodingKey { case mimeType = "mime_type"; case data }
    }
}

private struct ResponseBody: Decodable {
    let candidates: [Candidate]?
    struct Candidate: Decodable { let content: Content? }
    struct Content: Decodable { let parts: [Part]? }
    struct Part: Decodable { let text: String? }
    var extractedText: String {
        (candidates?.first?.content?.parts ?? []).compactMap { $0.text }.joined()
    }
}
