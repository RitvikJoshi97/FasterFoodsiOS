import Foundation
import SwiftUI
import AuthenticationServices
import GoogleSignIn

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var isBootstrapping: Bool = true
    @Published var currentUser: User?
    @Published var settings: UserSettings?
    @Published var savedItems: [GroceryItem] = []
    @Published var sharedItems: [SharedItem] = []
    @Published var familyMembers: [FamilyMember] = []
    @Published var shoppingLists: [ShoppingList] = []
    @Published var shoppingRecommendations: [ShoppingRecommendation] = []
    @Published var pantryItems: [PantryItem] = []
    @Published var pantryRecommendations: [ShoppingRecommendation] = []
    @Published var foodLogItems: [FoodLogItem] = []
    @Published var foodLogRecommendations: [ShoppingRecommendation] = []
    @Published var workoutItems: [WorkoutLogItem] = []
    @Published var workoutRecommendations: [ShoppingRecommendation] = []
    @Published var customMetrics: [CustomMetric] = []
    @Published var customMetricRecommendations: [ShoppingRecommendation] = []
    @Published var foodLoggingLevel: FoodLoggingLevel = .beginner
    private let credentialStore = CredentialStore()
    private let foodLoggingLevelKey = "foodLoggingLevel"

    init() {
        if let savedLevel = UserDefaults.standard.string(forKey: foodLoggingLevelKey),
           let level = FoodLoggingLevel(rawValue: savedLevel) {
            foodLoggingLevel = level
        }
        Task { await bootstrap() }
    }

    private func applySettings(_ incoming: UserSettings) {
        settings = incoming
        updateFoodLoggingLevel(incoming.foodLoggingLevel)
    }

    private func bootstrap() async {
        // Track start time to ensure minimum splash screen display
        let startTime = Date()
        
        print("🚀 Bootstrap: Starting authentication check...")
        
        // Perform bootstrap operations
        if await APIClient.shared.hasToken() {
            print("✅ Bootstrap: Found existing API token, validating...")
            if await APIClient.shared.validateToken() {
                print("✅ Bootstrap: Token is valid, fetching user data...")
                do {
                    currentUser = try await APIClient.shared.getCurrentUser()
                    if let fetchedSettings = try? await APIClient.shared.getSettings() {
                        applySettings(fetchedSettings)
                    } else {
                        settings = nil
                    }
                    isAuthenticated = true
                    print("✅ Bootstrap: User authenticated successfully")
                    await refreshAll()
                } catch {
                    print("❌ Bootstrap: Failed to fetch user data: \(error)")
                    await APIClient.shared.clearToken()
                    currentUser = nil
                    settings = nil
                    isAuthenticated = false
                }
            } else {
                print("⚠️ Bootstrap: Token validation failed, clearing token and attempting credential login...")
                await APIClient.shared.clearToken()
                await attemptCredentialLogin()
            }
        } else {
            print("⚠️ Bootstrap: No API token found, attempting credential login...")
            await attemptCredentialLogin()
        }
        
        // Ensure splash screen shows for at least 1.5 seconds
        let elapsed = Date().timeIntervalSince(startTime)
        let minimumDisplayTime: TimeInterval = 1.5
        if elapsed < minimumDisplayTime {
            let remainingTime = minimumDisplayTime - elapsed
            try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
        }
        
        print("🏁 Bootstrap: Complete. Authenticated: \(isAuthenticated)")
        isBootstrapping = false
    }

    private func attemptCredentialLogin() async {
        guard let credentials = credentialStore.load() else {
            print("⚠️ Credential Login: No stored credentials found")
            return
        }
        
        // Check if this is an OAuth login (Apple or Google)
        if let appleUserId = credentials.appleUserId, !appleUserId.isEmpty {
            print("🍎 Credential Login: Found Apple Sign In credentials, attempting restoration...")
            // Attempt Apple Sign In restoration
            await attemptAppleCredentialLogin(userIdentifier: appleUserId, email: credentials.email)
        } else if let googleUserId = credentials.googleUserId, !googleUserId.isEmpty {
            print("🔍 Credential Login: Found Google Sign In credentials, attempting restoration...")
            // Attempt Google Sign In restoration
            await attemptGoogleCredentialLogin(userID: googleUserId, email: credentials.email)
        } else if !credentials.password.isEmpty {
            print("📧 Credential Login: Found email/password credentials, attempting login...")
            // Attempt email/password login
            do {
                try await login(email: credentials.email, password: credentials.password)
                print("✅ Credential Login: Email/password login successful")
            } catch {
                print("❌ Credential Login: Email/password login failed: \(error)")
                credentialStore.clear()
                await APIClient.shared.clearToken()
                currentUser = nil
                settings = nil
                isAuthenticated = false
            }
        }
    }
    
    private func attemptAppleCredentialLogin(userIdentifier: String, email: String) async {
        // Check the credential state with Apple
        let provider = ASAuthorizationAppleIDProvider()
        
        do {
            let credentialState = try await provider.credentialState(forUserID: userIdentifier)
            
            switch credentialState {
            case .authorized:
                // User is still authorized with Apple, but we can't get a new identity token silently
                // Apple's security model requires explicit user interaction to get a new token
                // If we're here, it means the API token expired and user needs to sign in again
                print("⚠️ Apple credentials still authorized but API token expired - user needs to sign in again")
                // Don't clear credentials - let the user tap "Sign in with Apple" to continue
            case .revoked:
                // User explicitly revoked access in Settings
                print("❌ Apple credentials revoked by user - clearing stored credentials")
                credentialStore.clear()
            case .notFound:
                // Credentials not found with Apple
                print("❌ Apple credentials not found - clearing stored credentials")
                credentialStore.clear()
            case .transferred:
                // User's Apple ID was transferred to another device
                print("⚠️ Apple credentials transferred to another device")
                credentialStore.clear()
            @unknown default:
                print("⚠️ Unknown Apple credential state")
            }
        } catch {
            print("❌ Error checking Apple credential state: \(error)")
            // Don't clear credentials on error - might be a temporary network issue
        }
    }
    
    private func attemptGoogleCredentialLogin(userID: String, email: String) async {
        // Try to restore Google Sign In silently
        // Configuration is already set in FasterFoodsApp.init()
        
        // Check if there's a current user that can be restored
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            do {
                print("Attempting to restore previous Google Sign In session...")
                let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
                
                // Get a fresh ID token
                guard let idToken = user.idToken?.tokenString else {
                    print("❌ Could not get Google ID token from restored session")
                    credentialStore.clear()
                    return
                }
                
                print("✅ Successfully restored Google Sign In, attempting backend authentication...")
                
                // Attempt to log in with the restored credentials
                try await loginWithGoogle(
                    idToken: idToken,
                    userID: user.userID ?? userID,
                    email: user.profile?.email ?? email,
                    firstName: user.profile?.givenName,
                    lastName: user.profile?.familyName
                )
                
                print("✅ Successfully authenticated with backend using restored Google session")
            } catch {
                print("❌ Failed to restore Google Sign In: \(error)")
                credentialStore.clear()
            }
        } else {
            print("⚠️ No previous Google Sign In session found - user will need to sign in again")
            // Don't clear credentials yet - let the user try to sign in again
        }
    }

    func login(email: String, password: String) async throws {
        let res = try await APIClient.shared.login(email: email, password: password)
        currentUser = try await APIClient.shared.getCurrentUser()
        if let incomingSettings = res.settings {
            applySettings(incomingSettings)
        } else {
            if let fetchedSettings = try? await APIClient.shared.getSettings() {
                applySettings(fetchedSettings)
            } else {
                settings = nil
            }
        }
        isAuthenticated = true
        credentialStore.save(email: email, password: password)
        await refreshAll()
    }

    func loginWithApple(identityToken: String, userIdentifier: String, email: String?, firstName: String?, lastName: String?, authorizationCode: String?) async throws {
        let res = try await APIClient.shared.loginWithApple(
            identityToken: identityToken,
            userIdentifier: userIdentifier,
            email: email,
            firstName: firstName,
            lastName: lastName,
            authorizationCode: authorizationCode
        )
        currentUser = try await APIClient.shared.getCurrentUser()
        if let incomingSettings = res.settings {
            applySettings(incomingSettings)
        } else {
            if let fetchedSettings = try? await APIClient.shared.getSettings() {
                applySettings(fetchedSettings)
            } else {
                settings = nil
            }
        }
        isAuthenticated = true
        // Store Apple user identifier for future authentication
        credentialStore.saveAppleCredentials(userIdentifier: userIdentifier, email: email)
        await refreshAll()
    }
    
    func loginWithGoogle(idToken: String, userID: String, email: String?, firstName: String?, lastName: String?) async throws {
        let res = try await APIClient.shared.loginWithGoogle(
            idToken: idToken,
            userID: userID,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
        currentUser = try await APIClient.shared.getCurrentUser()
        if let incomingSettings = res.settings {
            applySettings(incomingSettings)
        } else {
            if let fetchedSettings = try? await APIClient.shared.getSettings() {
                applySettings(fetchedSettings)
            } else {
                settings = nil
            }
        }
        isAuthenticated = true
        // Store Google user ID for future authentication
        credentialStore.saveGoogleCredentials(userID: userID, email: email)
        await refreshAll()
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws {
        try await APIClient.shared.register(email: email, password: password, firstName: firstName, lastName: lastName)
    }

    func resendVerification(email: String) async throws {
        try await APIClient.shared.resendVerification(email: email)
    }

    func forgotPassword(email: String) async throws {
        try await APIClient.shared.forgotPassword(email: email)
    }

    func resetPassword(token: String, newPassword: String) async throws {
        try await APIClient.shared.resetPassword(token: token, newPassword: newPassword)
    }

    func logout() async {
        // Sign out from Google if signed in
        GIDSignIn.sharedInstance.signOut()
        
        await APIClient.shared.clearToken()
        isAuthenticated = false
        currentUser = nil
        settings = nil
        savedItems = []
        sharedItems = []
        familyMembers = []
        shoppingLists = []
        shoppingRecommendations = []
        pantryItems = []
        pantryRecommendations = []
        foodLogItems = []
        foodLogRecommendations = []
        workoutItems = []
        workoutRecommendations = []
        customMetrics = []
        customMetricRecommendations = []
        credentialStore.clear()
        updateFoodLoggingLevel(.beginner)
    }

    func refreshAll() async {
        do {
            savedItems = try await APIClient.shared.getSavedMacros()
        } catch {
            savedItems = []
        }

        do {
            familyMembers = try await APIClient.shared.getFamilyMembers()
        } catch {
            familyMembers = []
        }

        do {
            sharedItems = try await APIClient.shared.getSharedItems()
        } catch {
            sharedItems = []
        }

        do {
            shoppingLists = try await APIClient.shared.getShoppingLists()
        } catch {
            shoppingLists = []
        }

        do {
            try await loadShoppingRecommendations()
        } catch {
            shoppingRecommendations = []
        }

        do {
            pantryItems = try await APIClient.shared.getPantryItems()
        } catch {
            pantryItems = []
        }

        do {
            try await loadPantryRecommendations()
        } catch {
            pantryRecommendations = []
        }

        do {
            foodLogItems = try await APIClient.shared.getFoodLogItems()
        } catch {
            foodLogItems = []
        }

        do {
            try await loadFoodLogRecommendations()
        } catch {
            foodLogRecommendations = []
        }

        do {
            workoutItems = try await APIClient.shared.getWorkoutItems()
            print("✅ Loaded \(workoutItems.count) workout items from API")
        } catch {
            print("❌ Failed to load workout items: \(error)")
            workoutItems = []
        }

        do {
            customMetrics = try await APIClient.shared.getCustomMetricItems()
            print("✅ Loaded \(customMetrics.count) custom metrics from API")
        } catch {
            print("❌ Failed to load custom metrics: \(error)")
            customMetrics = []
        }

        do {
            workoutRecommendations = try await APIClient.shared.getWorkoutRecommendations()
            print("✅ Loaded \(workoutRecommendations.count) workout recommendations from API")
        } catch {
            print("❌ Failed to load workout recommendations: \(error)")
            workoutRecommendations = []
        }

        do {
            customMetricRecommendations = try await APIClient.shared.getCustomMetricRecommendations()
            print("✅ Loaded \(customMetricRecommendations.count) custom metric recommendations from API")
        } catch {
            print("❌ Failed to load custom metric recommendations: \(error)")
            customMetricRecommendations = []
        }
    }

    func loadShoppingLists() async throws {
        let lists = try await APIClient.shared.getShoppingLists()
        shoppingLists = lists
    }

    @discardableResult
    func createShoppingList(name: String) async throws -> ShoppingList {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = try await APIClient.shared.createShoppingList(name: trimmed)
        var lists = shoppingLists
        lists.append(list)
        shoppingLists = lists
        return list
    }

    @discardableResult
    func addShoppingItem(to listId: String, name: String, quantity: String? = nil, unit: String? = nil, listLabel: String? = nil) async throws -> ShoppingItem {
        let item = try await APIClient.shared.addShoppingItem(toList: listId, name: name, quantity: quantity, unit: unit, listLabel: listLabel)
        if let index = shoppingLists.firstIndex(where: { $0.id == listId }) {
            var updatedList = shoppingLists[index]
            updatedList.items.append(item)
            var lists = shoppingLists
            lists[index] = updatedList
            shoppingLists = lists
        } else {
            try await loadShoppingLists()
        }
        return item
    }

    @discardableResult
    func toggleShoppingItem(listId: String, itemId: String, checked: Bool) async throws -> ShoppingItem {
        var payload: [String: Any] = ["checked": checked]
        if checked {
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            payload["checkedAt"] = timestamp
        }
        let updatedItem = try await APIClient.shared.updateShoppingItem(listId: listId, itemId: itemId, updates: payload)
        if let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) {
            var updatedList = shoppingLists[listIndex]
            if let itemIndex = updatedList.items.firstIndex(where: { $0.id == itemId }) {
                updatedList.items[itemIndex] = updatedItem
                var lists = shoppingLists
                lists[listIndex] = updatedList
                shoppingLists = lists
            }
        }
        return updatedItem
    }

    func deleteShoppingItem(listId: String, itemId: String) async throws {
        try await APIClient.shared.deleteShoppingItem(listId: listId, itemId: itemId)
        guard let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) else { return }
        var updatedList = shoppingLists[listIndex]
        updatedList.items.removeAll { $0.id == itemId }
        var lists = shoppingLists
        if updatedList.items.isEmpty {
            lists.remove(at: listIndex)
        } else {
            lists[listIndex] = updatedList
        }
        shoppingLists = lists
    }

    func deleteShoppingList(id: String) async throws {
        try await APIClient.shared.deleteShoppingList(id: id)
        shoppingLists.removeAll { $0.id == id }
    }

    func loadShoppingRecommendations() async throws {
        shoppingRecommendations = try await APIClient.shared.getShoppingRecommendations()
    }

    func sendShoppingRecommendationFeedback(id: String, action: RecommendationFeedbackAction) async throws {
        try await APIClient.shared.sendShoppingRecommendationFeedback(id: id, action: action.rawValue)
        shoppingRecommendations.removeAll { $0.id == id }
    }

    // MARK: - Pantry

    func loadPantryItems() async throws {
        pantryItems = try await APIClient.shared.getPantryItems()
    }

    @discardableResult
    func addPantryItem(name: String, quantity: String?, unit: String?, expiryDate: String?) async throws -> PantryItem {
        let item = try await APIClient.shared.createPantryItem(name: name, quantity: quantity, unit: unit, expiryDate: expiryDate)
        pantryItems.append(item)
        return item
    }

    @discardableResult
    func updatePantryItem(id: String, name: String? = nil, quantity: String? = nil, unit: String? = nil, expiryDate: String? = nil) async throws -> PantryItem {
        var payload: [String: Any] = [:]
        if let name { payload["name"] = name }
        if let quantity { payload["quantity"] = quantity }
        if let unit { payload["unit"] = unit }
        if let expiryDate { payload["expiryDate"] = expiryDate }
        let updated = try await APIClient.shared.updatePantryItem(id: id, updates: payload)
        if let index = pantryItems.firstIndex(where: { $0.id == id }) {
            pantryItems[index] = updated
        }
        return updated
    }

    func deletePantryItem(id: String) async throws {
        try await APIClient.shared.deletePantryItem(id: id)
        pantryItems.removeAll { $0.id == id }
    }

    @discardableResult
    func togglePantryItem(id: String) async throws -> PantryItem {
        let updated = try await APIClient.shared.togglePantryItem(id: id)
        if let index = pantryItems.firstIndex(where: { $0.id == id }) {
            pantryItems[index] = updated
        }
        return updated
    }

    func checkAllPantryItems() async {
        let unchecked = pantryItems.filter { !$0.checked }
        if !unchecked.isEmpty {
            pantryItems = pantryItems.map { item in
                var updated = item
                if !updated.checked { updated.checked = true }
                return updated
            }
        }
        await withTaskGroup(of: Void.self) { group in
            for item in unchecked {
                group.addTask {
                    try? await APIClient.shared.updatePantryItem(id: item.id, updates: ["checked": true])
                }
            }
        }
        await loadPantryItemsSafely()
    }

    private func loadPantryItemsSafely() async {
        do {
            pantryItems = try await APIClient.shared.getPantryItems()
        } catch {
            // ignore
        }
    }

    func loadPantryRecommendations() async throws {
        do {
            pantryRecommendations = try await APIClient.shared.getPantryRecommendations()
        } catch {
            pantryRecommendations = []
            throw error
        }
    }

    func sendPantryRecommendationFeedback(id: String, action: RecommendationFeedbackAction) async throws {
        try await APIClient.shared.sendPantryRecommendationFeedback(id: id, action: action.rawValue)
        pantryRecommendations.removeAll { $0.id == id }
    }

    // MARK: - Food Log

    func loadFoodLogItems() async throws {
        foodLogItems = try await APIClient.shared.getFoodLogItems()
    }

    @discardableResult
    func addFoodLogItem(_ request: FoodLogCreateRequest) async throws -> FoodLogItem {
        let item = try await APIClient.shared.createFoodLogItem(request)
        foodLogItems.insert(item, at: 0)
        return item
    }

    func deleteFoodLogItem(id: String) async throws {
        try await APIClient.shared.deleteFoodLogItem(id: id)
        foodLogItems.removeAll { $0.id == id }
    }

    func loadFoodLogRecommendations() async throws {
        do {
            foodLogRecommendations = try await APIClient.shared.getFoodLogRecommendations()
        } catch {
            foodLogRecommendations = []
            throw error
        }
    }

    func sendFoodLogRecommendationFeedback(id: String, action: RecommendationFeedbackAction) async throws {
        try await APIClient.shared.sendFoodLogRecommendationFeedback(id: id, action: action.rawValue)
        foodLogRecommendations.removeAll { $0.id == id }
    }

    func updateFoodLoggingLevel(_ level: FoodLoggingLevel) {
        foodLoggingLevel = level
        settings?.foodLoggingLevel = level
        UserDefaults.standard.set(level.rawValue, forKey: foodLoggingLevelKey)
    }

    func syncSettings(_ settings: UserSettings) {
        applySettings(settings)
    }

    // MARK: - Workouts

    @discardableResult
    func addWorkout(_ item: WorkoutLogItem) async throws -> WorkoutLogItem {
        let request = WorkoutCreateRequest(
            name: item.name,
            activity: item.activity,
            category: item.category,
            duration: item.duration,
            calories: item.calories,
            parameters: item.parameters, // Already AnyCodableValue
            datetime: item.datetime
        )
        let createdItem = try await APIClient.shared.createWorkoutItem(request)
        workoutItems.insert(createdItem, at: 0)
        return createdItem
    }

    func deleteWorkout(id: String) async throws {
        try await APIClient.shared.deleteWorkoutItem(id: id)
        workoutItems.removeAll { $0.id == id }
    }

    // MARK: - Custom Metrics

    @discardableResult
    func addCustomMetric(_ metric: CustomMetric) async throws -> CustomMetric {
        let createdMetric = try await APIClient.shared.createCustomMetricItem(
            name: metric.name,
            value: metric.value,
            unit: metric.unit,
            date: metric.date,
            metricType: metric.metricType
        )
        customMetrics.insert(createdMetric, at: 0)
        return createdMetric
    }

    func deleteCustomMetric(id: String) async throws {
        try await APIClient.shared.deleteCustomMetricItem(id: id)
        customMetrics.removeAll { $0.id == id }
    }

    func loadWorkoutRecommendations() async throws {
        workoutRecommendations = try await APIClient.shared.getWorkoutRecommendations()
    }

    func sendWorkoutRecommendationFeedback(id: String, action: RecommendationFeedbackAction) async throws {
        try await APIClient.shared.sendWorkoutRecommendationFeedback(id: id, action: action.rawValue)
        workoutRecommendations.removeAll { $0.id == id }
    }

    func loadCustomMetricRecommendations() async throws {
        customMetricRecommendations = try await APIClient.shared.getCustomMetricRecommendations()
    }

    func sendCustomMetricRecommendationFeedback(id: String, action: RecommendationFeedbackAction) async throws {
        try await APIClient.shared.sendCustomMetricRecommendationFeedback(id: id, action: action.rawValue)
        customMetricRecommendations.removeAll { $0.id == id }
    }
}

enum RecommendationFeedbackAction: String {
    case accepted
    case dismissed
}
