import Foundation

struct APIError: LocalizedError, Sendable {
    let statusCode: Int?
    let message: String
    let unverified: Bool

    var errorDescription: String? { message }
}

private struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
    let detail: String?
    let details: [String]?
    let unverified: Bool?
    let errors: [String: [String]]?
}

actor APIClient {
    static let shared = APIClient()

    private let tokenKey = "authToken"
    private let defaults = SharedContainer.userDefaults

    private var token: String? {
        get { defaults.string(forKey: tokenKey) }
        set {
            if let value = newValue, !value.isEmpty {
                defaults.set(value, forKey: tokenKey)
            } else {
                defaults.removeObject(forKey: tokenKey)
            }
        }
    }

    var baseURL: URL {
        let envValue = ProcessInfo.processInfo.environment["API_BASE_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let envValue, !envValue.isEmpty {
            if let url = URL(string: envValue), url.scheme != nil {
                return url
            }
            if let url = URL(string: "https://\(envValue)") {
                return url
            }
        }
        return URL(string: "https://api.fasterfoods.co.uk")!
    }

    func setToken(_ value: String) { token = value }
    func clearToken() { token = nil }
    func hasToken() -> Bool { !(token?.isEmpty ?? true) }
    func currentToken() -> String? { token }

    private func request(_ path: String, method: String = "GET", body: Data? = nil, contentType: String? = nil, authorized: Bool = false) async throws -> (Data, HTTPURLResponse) {
        let url: URL
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            url = absoluteURL
        } else {
            let normalized = path.hasPrefix("/") ? path : "/\(path)"
            guard let resolved = URL(string: normalized, relativeTo: baseURL)?.absoluteURL else {
                throw APIError(statusCode: nil, message: "Invalid URL path: \(path)", unverified: false)
            }
            url = resolved
        }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let contentType { req.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        if authorized {
            guard let token, !token.isEmpty else {
                throw APIError(statusCode: nil, message: "Authentication required. Please log in again.", unverified: false)
            }
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError(statusCode: nil, message: error.localizedDescription, unverified: false)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError(statusCode: nil, message: "Invalid server response.", unverified: false)
        }
        guard (200..<300).contains(http.statusCode) else {
            let message: String
            var unverifiedFlag = false
            if let errorPayload = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                if let joined = errorPayload.details {
                    message = joined.joined(separator: ", ")
                } else if let errors = errorPayload.errors {
                    message = errors.values.flatMap { $0 }.joined(separator: ", ")
                } else {
                    message = errorPayload.error ?? errorPayload.message ?? errorPayload.detail ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                }
                unverifiedFlag = errorPayload.unverified ?? false
            } else if !data.isEmpty, let bodyString = String(data: data, encoding: .utf8) {
                message = bodyString
            } else {
                message = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            }
            throw APIError(statusCode: http.statusCode, message: message, unverified: unverifiedFlag)
        }
        return (data, http)
    }

    func validateToken() async -> Bool {
        guard hasToken() else { return false }
        do {
            _ = try await request("/validate", authorized: true)
            return true
        } catch {
            return false
        }
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        let payload = ["email": email, "password": password, "firstName": firstName, "lastName": lastName]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (_, http) = try await request("/register", method: "POST", body: body, contentType: "application/json")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func resendVerification(email: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["email": email])
        let (_, http) = try await request("/resend-verification", method: "POST", body: body, contentType: "application/json")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func verifyEmail(token: String) async throws {
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        let path = "/verify-email?token=\(encoded)"
        let (_, http) = try await request(path, method: "GET")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func login(email: String, password: String) async throws -> LoginResponse {
        let payload = ["email": email, "password": password]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, http) = try await request("/login", method: "POST", body: body, contentType: "application/json")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.userAuthenticationRequired) }
        let res = try JSONDecoder().decode(LoginResponse.self, from: data)
        setToken(res.token)
        return res
    }

    func loginWithApple(identityToken: String, userIdentifier: String, email: String?, firstName: String?, lastName: String?, authorizationCode: String?) async throws -> LoginResponse {
        var payload: [String: Any] = [
            "identityToken": identityToken,
            "userIdentifier": userIdentifier
        ]
        if let email { payload["email"] = email }
        if let firstName { payload["firstName"] = firstName }
        if let lastName { payload["lastName"] = lastName }
        if let authorizationCode { payload["authorizationCode"] = authorizationCode }
        
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, http) = try await request("/auth/apple", method: "POST", body: body, contentType: "application/json")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.userAuthenticationRequired) }
        let res = try JSONDecoder().decode(LoginResponse.self, from: data)
        setToken(res.token)
        return res
    }
    
    func loginWithGoogle(idToken: String, userID: String, email: String?, firstName: String?, lastName: String?) async throws -> LoginResponse {
        var payload: [String: Any] = [
            "idToken": idToken,
            "userID": userID
        ]
        if let email { payload["email"] = email }
        if let firstName { payload["firstName"] = firstName }
        if let lastName { payload["lastName"] = lastName }
        
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, http) = try await request("/auth/google", method: "POST", body: body, contentType: "application/json")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.userAuthenticationRequired) }
        let res = try JSONDecoder().decode(LoginResponse.self, from: data)
        setToken(res.token)
        return res
    }

    func getCurrentUser() async throws -> User {
        let (data, http) = try await request("/user", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.userAuthenticationRequired) }
        return try JSONDecoder().decode(User.self, from: data)
    }

    func getSettings() async throws -> UserSettings {
        let (data, http) = try await request("/settings", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([String:UserSettings].self, from: data)["settings"] ?? UserSettings()
    }

    func updateSettings(_ settings: UserSettings) async throws -> UserSettings {
        let body = try JSONEncoder().encode(settings)
        let (data, http) = try await request("/settings", method: "PUT", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([String:UserSettings].self, from: data)["settings"] ?? settings
    }

    func getSavedMacros() async throws -> [GroceryItem] {
        let (data, http) = try await request("/saved_macros", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([GroceryItem].self, from: data)
    }

    func uploadImage(_ data: Data, forPath path: String) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        let (respData, http) = try await request(path, method: "POST", body: body, contentType: "multipart/form-data; boundary=\(boundary)", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return respData
    }

    func changePassword(current: String, new: String) async throws {
        let payload = ["currentPassword": current, "newPassword": new]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (_, http) = try await request("/change-password", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func forgotPassword(email: String) async throws {
        let payload = ["email": email]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (_, http) = try await request("/forgot-password", method: "POST", body: body, contentType: "application/json")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func resetPassword(token: String, newPassword: String) async throws {
        let payload = ["token": token, "newPassword": newPassword]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (_, http) = try await request("/reset-password", method: "POST", body: body, contentType: "application/json")
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func getFamilyMembers() async throws -> [FamilyMember] {
        let (data, http) = try await request("/user/family-members", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(FamilyMembersResponse.self, from: data).familyMembers
    }

    func generateInvite() async throws -> (code: String, expiry: String) {
        let (data, http) = try await request("/user/generate-family-invite", method: "POST", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let code = obj?["inviteCode"] as? String ?? ""
        let expiry = obj?["expiryTime"] as? String ?? ""
        return (code, expiry)
    }

    func joinFamily(code: String) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: ["inviteCode": code])
        let (data, http) = try await request("/user/join-family", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return obj?["message"] as? String ?? ""
    }

    func getSharedItems() async throws -> [SharedItem] {
        let (data, http) = try await request("/shared-items", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(SharedItemsResponse.self, from: data).sharedItems
    }

    func verifySharedItem(id: Int, accepted: Bool) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["verified": accepted])
        let (_, http) = try await request("/verify-shared-item/\(id)", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func shareItem(itemId: Int, userIds: [Int]) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["itemId": itemId, "sharedUserIds": userIds])
        let (_, http) = try await request("/share-item", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    // MARK: - Shopping Lists

    func getShoppingLists() async throws -> [ShoppingList] {
        let (data, http) = try await request("/shopping-lists", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([ShoppingList].self, from: data)
    }

    func createShoppingList(name: String) async throws -> ShoppingList {
        let body = try JSONSerialization.data(withJSONObject: ["name": name])
        let (data, http) = try await request("/shopping-lists", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ShoppingList.self, from: data)
    }

    func deleteShoppingList(id: String) async throws {
        let (_, http) = try await request("/shopping-lists/\(id)", method: "DELETE", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func addShoppingItem(toList listId: String, name: String, quantity: String? = nil, unit: String? = nil, listLabel: String? = nil) async throws -> ShoppingItem {
        var payload: [String: Any] = ["name": name]
        if let quantity, !quantity.isEmpty { payload["quantity"] = quantity }
        if let unit, !unit.isEmpty { payload["unit"] = unit }
        if let listLabel, !listLabel.isEmpty { payload["list"] = listLabel }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, http) = try await request("/shopping-lists/\(listId)/items", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ShoppingItem.self, from: data)
    }

    func updateShoppingItem(listId: String, itemId: String, updates: [String: Any]) async throws -> ShoppingItem {
        let body = try JSONSerialization.data(withJSONObject: updates)
        let (data, http) = try await request("/shopping-lists/\(listId)/items/\(itemId)", method: "PATCH", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(ShoppingItem.self, from: data)
    }

    func deleteShoppingItem(listId: String, itemId: String) async throws {
        let (_, http) = try await request("/shopping-lists/\(listId)/items/\(itemId)", method: "DELETE", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    // MARK: - Shopping Recommendations

    func getShoppingRecommendations() async throws -> [ShoppingRecommendation] {
        let (data, http) = try await request("/shopping/recommendations", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([ShoppingRecommendation].self, from: data) {
            return direct
        }

        if let envelope = try? decoder.decode(ShoppingRecommendationEnvelope.self, from: data) {
            if let recs = envelope.recommendations, !recs.isEmpty { return recs }
            if let dataRecs = envelope.data, !dataRecs.isEmpty { return dataRecs }
        }

        return []
    }

    func sendShoppingRecommendationFeedback(id: String, action: String) async throws {
        let body = try JSONSerialization.data(withJSONObject: ["action": action])
        let (_, http) = try await request("/recommendations/\(id)/feedback", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    // MARK: - Pantry

    func getPantryItems() async throws -> [PantryItem] {
        let (data, http) = try await request("/pantry/items", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([PantryItem].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode([String: [PantryItem]].self, from: data),
           let items = wrapped["items"] {
            return items
        }
        if let single = try? decoder.decode([String: PantryItem].self, from: data),
           let item = single.values.first {
            return [item]
        }
        throw APIError(statusCode: nil, message: "Unexpected pantry response", unverified: false)
    }

    func createPantryItem(name: String, quantity: String?, unit: String?, expiryDate: String?) async throws -> PantryItem {
        var payload: [String: Any] = ["name": name]
        if let quantity, !quantity.isEmpty { payload["quantity"] = quantity }
        if let unit, !unit.isEmpty { payload["unit"] = unit }
        if let expiryDate, !expiryDate.isEmpty { payload["expiryDate"] = expiryDate }
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, http) = try await request("/pantry/items", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        if let item = try? decoder.decode(PantryItem.self, from: data) {
            return item
        }
        if let wrapped = try? decoder.decode([String: PantryItem].self, from: data),
           let item = wrapped.values.first {
            return item
        }
        throw APIError(statusCode: nil, message: "Unexpected pantry response", unverified: false)
    }

    func updatePantryItem(id: String, updates: [String: Any]) async throws -> PantryItem {
        let body = try JSONSerialization.data(withJSONObject: updates)
        let (data, http) = try await request("/pantry/items/\(id)", method: "PUT", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        if let item = try? decoder.decode(PantryItem.self, from: data) {
            return item
        }
        if let wrapped = try? decoder.decode([String: PantryItem].self, from: data),
           let item = wrapped.values.first {
            return item
        }
        throw APIError(statusCode: nil, message: "Unexpected pantry response", unverified: false)
    }

    func deletePantryItem(id: String) async throws {
        let (_, http) = try await request("/pantry/items/\(id)", method: "DELETE", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func togglePantryItem(id: String) async throws -> PantryItem {
        let (data, http) = try await request("/pantry/items/\(id)/toggle", method: "PATCH", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(PantryItem.self, from: data)
    }

    func getPantryRecommendations() async throws -> [ShoppingRecommendation] {
        let (data, http) = try await request("/pantry/recommendations", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([ShoppingRecommendation].self, from: data) {
            return direct
        }

        if let envelope = try? decoder.decode(ShoppingRecommendationEnvelope.self, from: data) {
            if let recs = envelope.recommendations, !recs.isEmpty { return recs }
            if let dataRecs = envelope.data, !dataRecs.isEmpty { return dataRecs }
        }

        return []
    }

    func sendPantryRecommendationFeedback(id: String, action: String) async throws {
        try await sendShoppingRecommendationFeedback(id: id, action: action)
    }

    // MARK: - Food Log

    func getFoodLogItems() async throws -> [FoodLogItem] {
        let (data, http) = try await request("/food-log/items", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([FoodLogItem].self, from: data) {
            return direct
        }
        if let wrapped = try? decoder.decode([String: [FoodLogItem]].self, from: data), let items = wrapped["items"] {
            return items
        }
        if let wrappedResponse = try? decoder.decode([String: FoodLogResponse].self, from: data), let response = wrappedResponse.values.first {
            return response.items
        }
        if let response = try? decoder.decode(FoodLogResponse.self, from: data) {
            return response.items
        }
        if let single = try? decoder.decode([String: FoodLogItem].self, from: data), let item = single.values.first {
            return [item]
        }
        throw APIError(statusCode: nil, message: "Unexpected food log response", unverified: false)
    }

    func createFoodLogItem(_ requestBody: FoodLogCreateRequest) async throws -> FoodLogItem {
        let encoder = JSONEncoder()
        let body = try encoder.encode(requestBody)
        let (data, http) = try await request("/food-log/items", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        if let item = try? decoder.decode(FoodLogItem.self, from: data) {
            return item
        }
        if let wrapped = try? decoder.decode([String: FoodLogItem].self, from: data), let item = wrapped.values.first {
            return item
        }
        if let wrappedResponse = try? decoder.decode([String: FoodLogResponse].self, from: data), let response = wrappedResponse.values.first, let first = response.items.first {
            return first
        }
        if let response = try? decoder.decode(FoodLogResponse.self, from: data), let first = response.items.first {
            return first
        }
        return FoodLogItem(request: requestBody)
    }

    func deleteFoodLogItem(id: String) async throws {
        let (_, http) = try await request("/food-log/items/\(id)", method: "DELETE", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func getFoodLogRecommendations() async throws -> [ShoppingRecommendation] {
        let (data, http) = try await request("/food-log/recommendations", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([ShoppingRecommendation].self, from: data) {
            return direct
        }

        if let envelope = try? decoder.decode(ShoppingRecommendationEnvelope.self, from: data) {
            if let recs = envelope.recommendations, !recs.isEmpty { return recs }
            if let dataRecs = envelope.data, !dataRecs.isEmpty { return dataRecs }
        }

        return []
    }

    func sendFoodLogRecommendationFeedback(id: String, action: String) async throws {
        try await sendShoppingRecommendationFeedback(id: id, action: action)
    }

    // MARK: - Workouts

    func getWorkoutItems() async throws -> [WorkoutLogItem] {
        let (data, http) = try await request("/workout/items", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        
        // Debug: Print raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Workout API Response: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        
        // Try to decode directly as array
        if let direct = try? decoder.decode([WorkoutLogItem].self, from: data) {
            print("✅ Decoded as direct array")
            return direct
        }
        
        // Try wrapped in "items" key
        if let wrapped = try? decoder.decode([String: [WorkoutLogItem]].self, from: data),
           let items = wrapped["items"] {
            print("✅ Decoded from 'items' wrapper")
            return items
        }
        
        // Try paginated response
        struct PaginatedResponse: Decodable {
            let items: [WorkoutLogItem]
        }
        if let paginated = try? decoder.decode(PaginatedResponse.self, from: data) {
            print("✅ Decoded from paginated response")
            return paginated.items
        }
        
        // If empty object or array, return empty
        if data.isEmpty || data.count < 3 {
            print("⚠️ Empty or minimal response, returning empty array")
            return []
        }
        
        print("❌ Could not decode workout response with any known format")
        throw APIError(statusCode: nil, message: "Unexpected workout response", unverified: false)
    }

    func createWorkoutItem(_ request: WorkoutCreateRequest) async throws -> WorkoutLogItem {
        let encoder = JSONEncoder()
        let body = try encoder.encode(request)
        let (data, http) = try await self.request("/workout/items", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        
        if let item = try? decoder.decode(WorkoutLogItem.self, from: data) {
            return item
        }
        
        if let wrapped = try? decoder.decode([String: WorkoutLogItem].self, from: data),
           let item = wrapped.values.first {
            return item
        }
        
        throw APIError(statusCode: nil, message: "Unexpected workout response", unverified: false)
    }

    func deleteWorkoutItem(id: String) async throws {
        let (_, http) = try await request("/workout/items/\(id)", method: "DELETE", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func getWorkoutRecommendations() async throws -> [ShoppingRecommendation] {
        let (data, http) = try await request("/workout/recommendations", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([ShoppingRecommendation].self, from: data) {
            return direct
        }

        if let envelope = try? decoder.decode(ShoppingRecommendationEnvelope.self, from: data) {
            if let recs = envelope.recommendations, !recs.isEmpty { return recs }
            if let dataRecs = envelope.data, !dataRecs.isEmpty { return dataRecs }
        }

        return []
    }

    func sendWorkoutRecommendationFeedback(id: String, action: String) async throws {
        try await sendShoppingRecommendationFeedback(id: id, action: action)
    }

    // MARK: - Custom Metrics

    func getCustomMetricItems() async throws -> [CustomMetric] {
        let (data, http) = try await request("/custom-metrics/items", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        
        // Debug: Print raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("🔍 Custom Metrics API Response: \(jsonString)")
        }
        
        let decoder = JSONDecoder()
        
        // Try to decode directly as array
        if let direct = try? decoder.decode([CustomMetric].self, from: data) {
            print("✅ Decoded as direct array")
            return direct
        }
        
        // Try wrapped in "items" key
        if let wrapped = try? decoder.decode([String: [CustomMetric]].self, from: data),
           let items = wrapped["items"] {
            print("✅ Decoded from 'items' wrapper")
            return items
        }
        
        // Try paginated response
        struct PaginatedResponse: Decodable {
            let items: [CustomMetric]
        }
        if let paginated = try? decoder.decode(PaginatedResponse.self, from: data) {
            print("✅ Decoded from paginated response")
            return paginated.items
        }
        
        // If empty object or array, return empty
        if data.isEmpty || data.count < 3 {
            print("⚠️ Empty or minimal response, returning empty array")
            return []
        }
        
        print("❌ Could not decode custom metric response with any known format")
        throw APIError(statusCode: nil, message: "Unexpected custom metric response", unverified: false)
    }

    func createCustomMetricItem(name: String, value: String, unit: String, date: String, metricType: String) async throws -> CustomMetric {
        let payload: [String: Any] = [
            "name": name,
            "value": value,
            "unit": unit,
            "date": date,
            "metricType": metricType
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let (data, http) = try await request("/custom-metrics/items", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        let decoder = JSONDecoder()
        
        if let item = try? decoder.decode(CustomMetric.self, from: data) {
            return item
        }
        
        if let wrapped = try? decoder.decode([String: CustomMetric].self, from: data),
           let item = wrapped.values.first {
            return item
        }
        
        throw APIError(statusCode: nil, message: "Unexpected custom metric response", unverified: false)
    }

    func deleteCustomMetricItem(id: String) async throws {
        let (_, http) = try await request("/custom-metrics/items/\(id)", method: "DELETE", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }

    func getCustomMetricRecommendations() async throws -> [ShoppingRecommendation] {
        let (data, http) = try await request("/custom-metrics/recommendations", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }

        let decoder = JSONDecoder()
        if let direct = try? decoder.decode([ShoppingRecommendation].self, from: data) {
            return direct
        }

        if let envelope = try? decoder.decode(ShoppingRecommendationEnvelope.self, from: data) {
            if let recs = envelope.recommendations, !recs.isEmpty { return recs }
            if let dataRecs = envelope.data, !dataRecs.isEmpty { return dataRecs }
        }

        return []
    }

    func sendCustomMetricRecommendationFeedback(id: String, action: String) async throws {
        try await sendShoppingRecommendationFeedback(id: id, action: action)
    }

    // MARK: - Goals API
    func getGoals() async throws -> [Goal] {
        let (data, http) = try await request("/goals", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        
        // Try to decode as array first
        if let goals = try? JSONDecoder().decode([Goal].self, from: data) {
            return goals
        }
        
        // Try to decode as response envelope
        if let response = try? JSONDecoder().decode(GoalResponse.self, from: data) {
            return response.goals ?? []
        }
        
        return []
    }

    func createGoal(title: String?, description: String, source: String?) async throws -> Goal {
        let request = GoalCreateRequest(title: title, description: description, source: source)
        let body = try JSONEncoder().encode(request)
        let (data, http) = try await self.request("/goals", method: "POST", body: body, contentType: "application/json", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        
        // Try to decode as direct Goal
        if let goal = try? JSONDecoder().decode(Goal.self, from: data) {
            return goal
        }
        
        // Try to decode as response envelope
        if let response = try? JSONDecoder().decode(GoalResponse.self, from: data),
           let goal = response.goal {
            return goal
        }
        
        throw URLError(.cannotParseResponse)
    }

    func getGoalRecommendations() async throws -> [GoalRecommendation] {
        let (data, http) = try await request("/getGoalRecommendations", authorized: true)
        guard (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        
        // Always use the manual dictionary parsing to avoid initialization failures
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            // Try to decode as array of GoalRecommendation
            let decoder = JSONDecoder()
            if let recommendations = try? decoder.decode([GoalRecommendation].self, from: data) {
                return recommendations.filter { !$0.description.isEmpty }
            }
            // Try response envelope
            if let response = try? decoder.decode(GoalRecommendationsResponse.self, from: data),
               let goals = response.goals {
                return goals.filter { !$0.description.isEmpty }
            }
            return []
        }
        
        // Manual parsing - decode each item individually to avoid partial failures
        var recommendations: [GoalRecommendation] = []
        for dict in jsonArray {
            guard let description = dict["description"] as? String, !description.isEmpty else {
                continue
            }
            
            let id = dict["id"] as? String
            let title = dict["title"] as? String
            let intent = dict["intent"] as? String
            let usageCount = dict["usageCount"] as? Int
            
            // Create recommendation safely
            let recommendation = GoalRecommendation(
                id: id,
                title: title,
                description: description,
                intent: intent,
                usageCount: usageCount
            )
            recommendations.append(recommendation)
        }
        
        return recommendations
    }
}
