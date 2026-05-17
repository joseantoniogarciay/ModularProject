import Core
import Foundation
import Security

struct KeychainTokenStore: TokenStore {
    private let service: String
    private let account: String

    init(service: String = "com.modular.app.auth", account: String = "tokens") {
        self.service = service
        self.account = account
    }

    func load() async -> AuthTokens? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        guard let payload = try? JSONDecoder().decode(StoredTokens.self, from: data) else { return nil }
        return AuthTokens(
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            accessTokenExpiresAt: payload.accessTokenExpiresAt
        )
    }

    func save(_ tokens: AuthTokens) async {
        let payload = StoredTokens(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            accessTokenExpiresAt: tokens.accessTokenExpiresAt
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            for (key, value) in attributes {
                addQuery[key] = value
            }
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func clear() async {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private struct StoredTokens: Codable {
        let accessToken: String
        let refreshToken: String
        let accessTokenExpiresAt: Date?
    }
}
