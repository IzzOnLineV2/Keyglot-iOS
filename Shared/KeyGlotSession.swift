import Foundation
import StoreKit

/// Manages the KeyGlot backend session token: mints it, caches it in the shared Keychain so the
/// app and its extensions reuse the same token, and refreshes it when expired or rejected.
///
/// Production: the session is built from the active StoreKit subscription (a signed transaction,
/// JWS, verified server-side, with App Attest). The token is cached in the shared Keychain so the
/// keyboard/share extensions reuse it.
struct KeyGlotSession: Sendable {

    /// Keychain account for the temporary dev key pasted in Settings (Step 2 only).
    static let devKeyAccount = "keyglot_dev_key"
    /// Keychain account for the cached session token.
    private static let tokenAccount = "keyglot_session_token"

    let storage: AppGroupStorage
    let credentials: CredentialStore
    var baseURL: URL
    var http: URLSession

    init(
        storage: AppGroupStorage = .shared,
        credentials: CredentialStore = .shared,
        baseURL: URL = Configuration.keyglotBackendBaseURL,
        http: URLSession = .shared
    ) {
        self.storage = storage
        self.credentials = credentials
        self.baseURL = baseURL
        self.http = http
    }

    enum SessionError: Error, LocalizedError {
        case notConfigured
        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return String(localized: "KeyGlot needs an active Pro subscription. Subscribe, or switch to Custom in Advanced with your own AI key.")
            }
        }
    }

    /// A valid bearer token, cached if still fresh, otherwise freshly minted.
    func authorizedToken() async throws -> String {
        if let cached = credentials.secret(Self.tokenAccount), !Self.isExpired(cached) {
            return cached
        }
        return try await mint()
    }

    /// Force a brand-new token (e.g. after a 401).
    func refreshedToken() async throws -> String {
        try await mint()
    }

    /// Exchange a StoreKit signed transaction (JWS) for a session token (production path). Called
    /// by the app while subscribed; the resulting token is cached in the shared Keychain so the
    /// keyboard/share extensions reuse it.
    @discardableResult
    func exchange(jws: String) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/session"))
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // App Attest (Step 4): prove this is a genuine app instance. Best-effort, if attestation is
        // unavailable we mint unattested and the backend decides whether to require it.
        if let att = await AppAttestClient(baseURL: baseURL, credentials: credentials, http: http).assertion(binding: jws) {
            request.setValue(att.keyID, forHTTPHeaderField: "x-attest-key-id")
            request.setValue(att.assertionBase64, forHTTPHeaderField: "x-attest-assertion")
            request.setValue(att.challenge, forHTTPHeaderField: "x-attest-challenge")
        }

        request.httpBody = try JSONEncoder().encode(["jws": jws])
        return try await complete(request)
    }

    private func mint() async throws -> String {
        // Production: build the session from the active StoreKit subscription (JWS verified
        // server-side, with App Attest). This makes the session self-sufficient, so it works even
        // if the user opens a feature before the app's startup refresh has run.
        if let jws = await Self.currentEntitlementJWS() {
            return try await exchange(jws: jws)
        }

#if DEBUG
        // Dev-only shortcut to exercise the backend without a subscription (backend DEV_MODE=1).
        if let devKey = credentials.secret(Self.devKeyAccount) {
            var request = URLRequest(url: baseURL.appendingPathComponent("v1/session"))
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(devKey, forHTTPHeaderField: "x-dev-key")
            request.httpBody = try JSONEncoder().encode(["devSubject": storage.installID])
            return try await complete(request)
        }
#endif

        throw SessionError.notConfigured
    }

    /// The signed JWS of the active KeyGlot subscription entitlement, if any (StoreKit 2). Available
    /// from the app and the extensions, so the session can be built wherever it's first needed.
    static func currentEntitlementJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result,
                  Configuration.subscriptionProductIDs.contains(t.productID),
                  t.revocationDate == nil else { continue }
            return result.jwsRepresentation
        }
        return nil
    }

    /// Send a `/v1/session` request, decode `{ session }`, cache the token, and return it.
    private func complete(_ request: URLRequest) async throws -> String {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await http.data(for: request) }
        catch { throw ProviderError.transport(error) }

        guard let httpResp = response as? HTTPURLResponse else { throw ProviderError.invalidResponse }
        guard (200..<300).contains(httpResp.statusCode) else {
            throw ProviderError.http(status: httpResp.statusCode, message: Self.errorMessage(data) ?? "session failed")
        }

        struct Body: Decodable { let session: String }
        let token = try JSONDecoder().decode(Body.self, from: data).session
        credentials.setSecret(token, account: Self.tokenAccount)
        return token
    }

    /// Decode the JWT `exp` claim and treat the token as expired 60s early. Unparseable → expired.
    static func isExpired(_ jwt: String) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return true }
        var b64 = String(parts[1]).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = obj["exp"] as? Double else { return true }
        return Date().timeIntervalSince1970 >= (exp - 60)
    }

    /// Pull the `{ error: { message } }` string from a backend error body, if present.
    static func errorMessage(_ data: Data) -> String? {
        struct Envelope: Decodable {
            struct APIError: Decodable { let code: String?; let message: String? }
            let error: APIError?
        }
        let decoded = try? JSONDecoder().decode(Envelope.self, from: data)
        return decoded?.error?.message ?? decoded?.error?.code
    }
}
