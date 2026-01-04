import Foundation
import UIKit

struct PushTokenPayload: Encodable {
    let token: String
    let platform: String
    let provider: String
    let deviceId: String
    let environment: String
    let appVersion: String
    let locale: String
    let timeZone: String
}

actor PushTokenManager {
    static let shared = PushTokenManager()

    private let tokenKey = "apnsDeviceToken"
    private let defaults = SharedContainer.userDefaults

    func didRegister(deviceToken: Data) async {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        defaults.set(token, forKey: tokenKey)
        await syncIfPossible()
    }

    func syncIfPossible() async {
        guard let token = defaults.string(forKey: tokenKey), !token.isEmpty else { return }
        guard await APIClient.shared.hasToken() else { return }

        let payload = PushTokenPayload(
            token: token,
            platform: "ios",
            provider: "apns",
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown",
            environment: buildEnvironment(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                as? String ?? "0",
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier
        )

        do {
            try await APIClient.shared.registerPushToken(payload)
        } catch {
            print("❌ Push token sync failed: \(error)")
        }
    }

    private func buildEnvironment() -> String {
        #if DEBUG
            return "development"
        #else
            return "production"
        #endif
    }
}
