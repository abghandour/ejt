import Foundation
import Security

/// Thin wrapper around iOS Keychain Services for securely storing, retrieving, and deleting tokens.
struct KeychainStore {

    // MARK: - Key Constants

    static let patreonAccessToken = "patreon_access_token"
    static let patreonRefreshToken = "patreon_refresh_token"
    static let patreonTokenExpiry = "patreon_token_expiry"

    // MARK: - Operations

    /// Saves data to the Keychain for the given key.
    /// If an entry already exists for the key, it is updated.
    /// - Returns: `true` if the save (or update) succeeded.
    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        // Delete any existing item first to avoid errSecDuplicateItem
        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Loads data from the Keychain for the given key.
    /// - Returns: The stored `Data`, or `nil` if no entry exists or the read fails.
    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Deletes the Keychain entry for the given key.
    /// - Returns: `true` if the deletion succeeded or the item didn't exist.
    @discardableResult
    static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
