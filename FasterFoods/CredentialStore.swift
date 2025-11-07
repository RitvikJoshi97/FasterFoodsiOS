import Foundation
import Security

struct CredentialStore {
    private let service = "com.fasterfoods.app.credentials"
    private let account = "primary"
    private let appleUserIdKey = "com.fasterfoods.app.appleUserId"

    struct Credentials: Codable {
        let email: String
        let password: String
        let appleUserId: String?
        let googleUserId: String?
        
        init(email: String, password: String, appleUserId: String? = nil, googleUserId: String? = nil) {
            self.email = email
            self.password = password
            self.appleUserId = appleUserId
            self.googleUserId = googleUserId
        }
    }

    func save(email: String, password: String, appleUserId: String? = nil, googleUserId: String? = nil) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let credentials = Credentials(email: trimmedEmail, password: password, appleUserId: appleUserId, googleUserId: googleUserId)
        guard let data = try? JSONEncoder().encode(credentials) else { return }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        SecItemAdd(query as CFDictionary, nil)
    }
    
    func saveAppleCredentials(userIdentifier: String, email: String?) {
        let emailToStore = email ?? ""
        save(email: emailToStore, password: "", appleUserId: userIdentifier)
    }
    
    func saveGoogleCredentials(userID: String, email: String?) {
        let emailToStore = email ?? ""
        save(email: emailToStore, password: "", googleUserId: userID)
    }

    func load() -> Credentials? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return nil
        }
        return credentials
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
