import Foundation
import CryptoKit
#if canImport(DeviceCheck)
import DeviceCheck
#endif

/// App Attest client. Proves to the KeyGlot backend that a request comes from a genuine, unmodified
/// instance of this app on a real Apple device, the client is open source, so a valid StoreKit JWS
/// alone is not proof of a real app instance.
///
/// The device key is generated + attested once (bound to the install, key id cached in the shared
/// Keychain); every session mint then carries a fresh, challenge-bound assertion. Best-effort by
/// design: on the Simulator, on error, or where App Attest is unsupported it returns `nil` and the
/// caller mints the session without an assertion, the backend decides whether to require one
/// (`REQUIRE_APP_ATTEST`).
struct AppAttestClient {
    let baseURL: URL
    let credentials: CredentialStore
    let http: URLSession

    /// Keychain account for the attested key id (shared so the app owns attestation; extensions
    /// reuse the session token the app mints, they never attest themselves).
    private static let keyIDAccount = "keyglot_appattest_keyid"

    init(
        baseURL: URL = Configuration.keyglotBackendBaseURL,
        credentials: CredentialStore = .shared,
        http: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.credentials = credentials
        self.http = http
    }

    struct Assertion {
        let keyID: String
        let assertionBase64: String
        let challenge: String
    }

    /// An assertion binding `boundValue` (the StoreKit JWS) to a fresh server challenge, or `nil`
    /// if App Attest is unavailable. Never throws, the session mint must still work unattested
    /// while `REQUIRE_APP_ATTEST` is off.
    func assertion(binding boundValue: String) async -> Assertion? {
#if canImport(DeviceCheck)
        let service = DCAppAttestService.shared
        guard service.isSupported else { return nil }
        do {
            let keyID = try await ensureAttestedKey(service)
            let challenge = try await fetchChallenge()
            let clientData = Data("\(challenge).\(boundValue)".utf8)
            let clientDataHash = Data(SHA256.hash(data: clientData))
            let assertion = try await service.generateAssertion(keyID, clientDataHash: clientDataHash)
            return Assertion(keyID: keyID, assertionBase64: assertion.base64EncodedString(), challenge: challenge)
        } catch {
            return nil
        }
#else
        return nil
#endif
    }

#if canImport(DeviceCheck)
    /// The attested key id, generating + attesting a new key on first use.
    private func ensureAttestedKey(_ service: DCAppAttestService) async throws -> String {
        if let existing = credentials.secret(Self.keyIDAccount) { return existing }
        let keyID = try await service.generateKey()
        let challenge = try await fetchChallenge()
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation = try await service.attestKey(keyID, clientDataHash: clientDataHash)
        try await postAttestation(keyID: keyID, attestationBase64: attestation.base64EncodedString(), challenge: challenge)
        _ = credentials.setSecret(keyID, account: Self.keyIDAccount)
        return keyID
    }
#endif

    private func fetchChallenge() async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/challenge"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProviderError.invalidResponse
        }
        struct Body: Decodable { let challenge: String }
        return try JSONDecoder().decode(Body.self, from: data).challenge
    }

    private func postAttestation(keyID: String, attestationBase64: String, challenge: String) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/attest"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode([
            "keyId": keyID,
            "attestation": attestationBase64,
            "challenge": challenge,
        ])
        let (data, response) = try await http.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ProviderError.http(status: status, message: KeyGlotSession.errorMessage(data) ?? "attest failed")
        }
    }
}
