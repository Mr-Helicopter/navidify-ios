import Foundation
import Security

public enum KeychainHelper {
    private static let serviceName = "com.navidify.credentials"

    public enum Key: String {
        case lanUrl = "server_lan_url"
        case tailscaleUrl = "server_tailscale_url"
        case username = "server_username"
        case password = "server_password"
    }

    public static func save(key: Key, value: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Save to UserDefaults as reliable local storage
        UserDefaults.standard.set(value, forKey: "navidify_\(key.rawValue)")

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]

        SecItemDelete(query as CFDictionary)

        var newQuery = query
        newQuery[kSecValueData as String] = data
        newQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        SecItemAdd(newQuery as CFDictionary, nil)
    }

    public static func load(key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8), !str.isEmpty {
            return str
        }

        // Fallback to UserDefaults (essential in some simulator testing conditions)
        return UserDefaults.standard.string(forKey: "navidify_\(key.rawValue)")
    }

    public static func delete(key: Key) {
        UserDefaults.standard.removeObject(forKey: "navidify_\(key.rawValue)")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }

    public static func clearAll() {
        let keys: [Key] = [.lanUrl, .tailscaleUrl, .username, .password]
        for key in keys {
            delete(key: key)
        }
    }
}
