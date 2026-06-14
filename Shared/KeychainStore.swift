import Foundation
import Security

/// Minimal wrapper around the iOS Keychain for storing secrets.
///
/// Items are written to a **shared Keychain access group** so that both the main app and the
/// keyboard extension (same team, same `keychain-access-groups` entitlement) can read them.
///
/// We deliberately do **not** pass `kSecAttrAccessGroup` in the queries: when it's omitted,
/// the system uses the *first* entry of the target's `keychain-access-groups` entitlement as
/// the default group. Both targets list exactly one group — the shared one — so the item lands
/// in (and is read from) the shared group on each, with no hard-coded team-ID prefix in code.
///
/// Accessibility is `AfterFirstUnlockThisDeviceOnly`: the key stays on this device and is
/// readable by the extension after the first unlock following a reboot.
struct KeychainStore: Sendable {

    static let shared = KeychainStore()

    /// Namespaces our items within the shared access group.
    private let service = "com.smartapibox.keyglot.credentials"

    /// Read a secret for `account`, or `nil` if absent.
    func string(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    /// Store (or, with `nil`/empty, remove) a secret for `account`.
    @discardableResult
    func set(_ value: String?, account: String) -> Bool {
        guard let value, !value.isEmpty else {
            return delete(account: account)
        }

        let data = Data(value.utf8)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            let addQuery = base.merging(attributes) { _, new in new }
            return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    @discardableResult
    func delete(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
