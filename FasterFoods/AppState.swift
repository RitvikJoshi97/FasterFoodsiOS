import AuthenticationServices
import Foundation
import GoogleSignIn
import SwiftUI

enum GamePlanStatus: Equatable {
    case idle
    case loading
    case preparing
    case ready
    case failed(String)

    var isPreparing: Bool {
        switch self {
        case .preparing, .loading:
            return true
        default:
            return false
        }
    }
}

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
    @Published var latestGamePlan: GamePlan?
    @Published var gamePlanContent: GamePlanContent?
    @Published var gamePlanStatus: GamePlanStatus = .idle
    @Published var gamePlanUpdateNotice = false
    @Published var foodLoggingLevel: FoodLoggingLevel = .beginner
    @Published var isOffline: Bool = false
    @Published var showAssistant: Bool = false
    @Published var assistantScript: AssistantScript = .onboarding()
    @Published var assistantTitle: String = "Assistant"
    @Published var assistantMode: AssistantMode = .assistant
    private let onboardingChatKey = "hasSeenOnboardingChat"
    private let onboardingNextLaunchKey = "showOnboardingNextLaunch"
    private var hasSeenOnboardingChat: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingChatKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingChatKey) }
    }
    private var showOnboardingNextLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: onboardingNextLaunchKey) }
        set { UserDefaults.standard.set(newValue, forKey: onboardingNextLaunchKey) }
    }
    private var deferOnboardingThisSession = false
    private let credentialStore = CredentialStore()
    private let foodLoggingLevelKey = "foodLoggingLevel"
    private let cachedGamePlanKey = "cachedGamePlanExternal"
    private let cacheWindowDays = 14
    private let cache = LocalCache.shared
    private let outbox = OfflineOutbox.shared
    private let networkMonitor = NetworkMonitor.shared
    private var isSyncingOutbox = false
    private var gamePlanPollTask: Task<Void, Never>?
    private static let isoFormatterFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoFormatterBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    private static let cacheDateFormatters: [DateFormatter] = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateTimeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return [dateFormatter, dateTimeFormatter]
    }()

    init() {
        if let savedLevel = UserDefaults.standard.string(forKey: foodLoggingLevelKey),
            let level = FoodLoggingLevel(rawValue: savedLevel)
        {
            foodLoggingLevel = level
        }
        loadCachedGamePlan()
        isOffline = !networkMonitor.isConnected
        networkMonitor.onStatusChange = { [weak self] connected in
            Task { @MainActor in
                self?.isOffline = !connected
                if connected {
                    await self?.syncOutbox()
                }
            }
        }
        Task { await bootstrap() }
    }

    private func applySettings(_ incoming: UserSettings) {
        settings = incoming
        updateFoodLoggingLevel(incoming.foodLoggingLevel)
    }

    private func shouldPreserveOnError(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            return apiError.isNetworkError
        }
        return (error as? URLError) != nil
    }

    private func markNetworkFailureIfNeeded(_ error: Error) {
        if shouldPreserveOnError(error) {
            isOffline = true
        }
    }

    private func markNetworkSuccess() {
        if isOffline {
            isOffline = false
        }
    }

    private func parseCacheDate(_ value: String) -> Date? {
        if let date = Self.isoFormatterFractional.date(from: value) {
            return date
        }
        if let date = Self.isoFormatterBasic.date(from: value) {
            return date
        }
        for formatter in Self.cacheDateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private func isWithinCacheWindow(_ value: String) -> Bool {
        guard
            let threshold = Calendar.current.date(
                byAdding: .day, value: -cacheWindowDays, to: Date())
        else {
            return true
        }
        guard let date = parseCacheDate(value) else {
            return true
        }
        return date >= threshold
    }

    private func windowedFoodLogItems() -> [FoodLogItem] {
        foodLogItems.filter { isWithinCacheWindow($0.datetime) }
    }

    private func windowedWorkoutItems() -> [WorkoutLogItem] {
        workoutItems.filter { isWithinCacheWindow($0.datetime) }
    }

    private func windowedCustomMetrics() -> [CustomMetric] {
        customMetrics.filter { isWithinCacheWindow($0.date) }
    }

    private func loadCachedSnapshot() async {
        guard let snapshot = await cache.loadSnapshot() else { return }
        currentUser = snapshot.user ?? currentUser
        if let cachedSettings = snapshot.settings {
            applySettings(cachedSettings)
        }
        pantryItems = snapshot.pantryItems
        shoppingLists = snapshot.shoppingLists
        foodLogItems = snapshot.foodLogItems
        workoutItems = snapshot.workoutItems
        customMetrics = snapshot.customMetrics
    }

    private func persistCache() {
        let snapshot = CachedSnapshot(
            cachedAt: Date(),
            user: currentUser,
            settings: settings,
            pantryItems: pantryItems,
            shoppingLists: shoppingLists,
            foodLogItems: windowedFoodLogItems(),
            workoutItems: windowedWorkoutItems(),
            customMetrics: windowedCustomMetrics()
        )
        Task { await cache.saveSnapshot(snapshot) }
    }

    private func makeTempId() -> String {
        "local-\(UUID().uuidString)"
    }

    private func isTempId(_ id: String) -> Bool {
        id.hasPrefix("local-")
    }

    private func replaceShoppingListId(oldId: String, with list: ShoppingList) {
        if let index = shoppingLists.firstIndex(where: { $0.id == oldId }) {
            var updated = list
            updated.items = shoppingLists[index].items
            shoppingLists[index] = updated
        }
        for index in shoppingLists.indices {
            if shoppingLists[index].id == list.id {
                shoppingLists[index].items = shoppingLists[index].items.map { item in
                    var updated = item
                    if updated.shoppingListId == oldId {
                        updated.shoppingListId = list.id
                    }
                    return updated
                }
            }
        }
    }

    private func replaceShoppingItemId(listId: String, oldId: String, with item: ShoppingItem) {
        guard let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) else { return }
        if let itemIndex = shoppingLists[listIndex].items.firstIndex(where: { $0.id == oldId }) {
            shoppingLists[listIndex].items[itemIndex] = item
        }
    }

    private func replacePantryItemId(oldId: String, with item: PantryItem) {
        if let index = pantryItems.firstIndex(where: { $0.id == oldId }) {
            pantryItems[index] = item
        }
    }

    private func replaceFoodLogId(oldId: String, with item: FoodLogItem) {
        if let index = foodLogItems.firstIndex(where: { $0.id == oldId }) {
            foodLogItems[index] = item
        }
    }

    private func replaceWorkoutId(oldId: String, with item: WorkoutLogItem) {
        if let index = workoutItems.firstIndex(where: { $0.id == oldId }) {
            workoutItems[index] = item
        }
    }

    private func replaceCustomMetricId(oldId: String, with item: CustomMetric) {
        if let index = customMetrics.firstIndex(where: { $0.id == oldId }) {
            customMetrics[index] = item
        }
    }

    private func syncOutbox() async {
        guard !isOffline, !isSyncingOutbox else { return }
        isSyncingOutbox = true
        defer { isSyncingOutbox = false }
        let ops = await outbox.all()
        guard !ops.isEmpty else { return }

        for operation in ops {
            do {
                switch operation.kind {
                case .createShoppingList:
                    guard
                        let payload = await outbox.decodePayload(
                            CreateShoppingListPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    let list = try await APIClient.shared.createShoppingList(name: payload.name)
                    replaceShoppingListId(oldId: payload.tempId, with: list)
                    await outbox.replaceShoppingListId(oldId: payload.tempId, newId: list.id)
                case .addShoppingItem:
                    guard
                        let payload = await outbox.decodePayload(
                            AddShoppingItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    let item = try await APIClient.shared.addShoppingItem(
                        toList: payload.listId,
                        name: payload.name,
                        quantity: payload.quantity,
                        unit: payload.unit,
                        listLabel: payload.listLabel
                    )
                    replaceShoppingItemId(
                        listId: payload.listId, oldId: payload.tempItemId, with: item)
                    await outbox.replaceShoppingItemId(oldId: payload.tempItemId, newId: item.id)
                case .toggleShoppingItem:
                    guard
                        let payload = await outbox.decodePayload(
                            ToggleShoppingItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    var updates: [String: Any] = ["checked": payload.checked]
                    if let checkedAt = payload.checkedAt {
                        updates["checkedAt"] = checkedAt
                    }
                    _ = try await APIClient.shared.updateShoppingItem(
                        listId: payload.listId, itemId: payload.itemId, updates: updates)
                case .deleteShoppingItem:
                    guard
                        let payload = await outbox.decodePayload(
                            DeleteShoppingItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    try await APIClient.shared.deleteShoppingItem(
                        listId: payload.listId, itemId: payload.itemId)
                case .deleteShoppingList:
                    guard
                        let payload = await outbox.decodePayload(
                            DeleteShoppingListPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    try await APIClient.shared.deleteShoppingList(id: payload.listId)
                case .addPantryItem:
                    guard
                        let payload = await outbox.decodePayload(
                            AddPantryItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    let item = try await APIClient.shared.createPantryItem(
                        name: payload.name,
                        quantity: payload.quantity,
                        unit: payload.unit,
                        expiryDate: payload.expiryDate
                    )
                    replacePantryItemId(oldId: payload.tempId, with: item)
                    await outbox.replacePantryItemId(oldId: payload.tempId, newId: item.id)
                case .updatePantryItem:
                    guard
                        let payload = await outbox.decodePayload(
                            UpdatePantryItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    var updates: [String: Any] = [:]
                    if let name = payload.name { updates["name"] = name }
                    if let quantity = payload.quantity { updates["quantity"] = quantity }
                    if let unit = payload.unit { updates["unit"] = unit }
                    if let expiryDate = payload.expiryDate { updates["expiryDate"] = expiryDate }
                    let updated = try await APIClient.shared.updatePantryItem(
                        id: payload.id, updates: updates
                    )
                    replacePantryItemId(oldId: updated.id, with: updated)
                case .togglePantryItem:
                    guard
                        let payload = await outbox.decodePayload(
                            TogglePantryItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    let updated = try await APIClient.shared.togglePantryItem(id: payload.id)
                    replacePantryItemId(oldId: payload.id, with: updated)
                case .deletePantryItem:
                    guard
                        let payload = await outbox.decodePayload(
                            DeletePantryItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    try await APIClient.shared.deletePantryItem(id: payload.id)
                case .addFoodLogItem:
                    guard
                        let payload = await outbox.decodePayload(
                            AddFoodLogItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    let created = try await APIClient.shared.createFoodLogItem(payload.request)
                    replaceFoodLogId(oldId: payload.tempId, with: created)
                    await outbox.replaceFoodLogId(oldId: payload.tempId, newId: created.id)
                case .deleteFoodLogItem:
                    guard
                        let payload = await outbox.decodePayload(
                            DeleteFoodLogItemPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    try await APIClient.shared.deleteFoodLogItem(id: payload.id)
                case .addWorkout:
                    guard
                        let payload = await outbox.decodePayload(
                            AddWorkoutPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    let request = WorkoutCreateRequest(
                        name: payload.item.name,
                        activity: payload.item.activity,
                        category: payload.item.category,
                        duration: payload.item.duration,
                        calories: payload.item.calories,
                        parameters: payload.item.parameters,
                        datetime: payload.item.datetime
                    )
                    let created = try await APIClient.shared.createWorkoutItem(request)
                    replaceWorkoutId(oldId: payload.tempId, with: created)
                    await outbox.replaceWorkoutId(oldId: payload.tempId, newId: created.id)
                case .deleteWorkout:
                    guard
                        let payload = await outbox.decodePayload(
                            DeleteWorkoutPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    try await APIClient.shared.deleteWorkoutItem(id: payload.id)
                case .addCustomMetric:
                    guard
                        let payload = await outbox.decodePayload(
                            AddCustomMetricPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    let created = try await APIClient.shared.createCustomMetricItem(
                        name: payload.metric.name,
                        value: payload.metric.value,
                        unit: payload.metric.unit,
                        date: payload.metric.date,
                        metricType: payload.metric.metricType
                    )
                    replaceCustomMetricId(oldId: payload.tempId, with: created)
                    await outbox.replaceCustomMetricId(oldId: payload.tempId, newId: created.id)
                case .deleteCustomMetric:
                    guard
                        let payload = await outbox.decodePayload(
                            DeleteCustomMetricPayload.self, from: operation.payload)
                    else {
                        await outbox.remove(operation.id)
                        continue
                    }
                    try await APIClient.shared.deleteCustomMetricItem(id: payload.id)
                }

                await outbox.remove(operation.id)
                persistCache()
                markNetworkSuccess()
            } catch {
                markNetworkFailureIfNeeded(error)
                if shouldPreserveOnError(error) {
                    break
                }
                await outbox.remove(operation.id)
            }
        }
    }

    private func bootstrap() async {
        // Track start time to ensure minimum splash screen display
        let startTime = Date()

        print("🚀 Bootstrap: Starting authentication check...")

        // Perform bootstrap operations
        let hasToken = await APIClient.shared.hasToken()
        if hasToken {
            isAuthenticated = true
            await loadCachedSnapshot()
            if isOffline {
                print("⚠️ Bootstrap: Offline at launch, skipping token validation")
                await gotoBootstrapDelay(startTime: startTime)
                return
            }
            print("✅ Bootstrap: Found existing API token, validating...")
            switch await APIClient.shared.validateToken() {
            case .valid:
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
                    if shouldPreserveOnError(error) {
                        print(
                            "⚠️ Bootstrap: Network error while fetching user data, keeping cached state"
                        )
                    } else {
                        print("❌ Bootstrap: Failed to fetch user data: \(error)")
                        await APIClient.shared.clearToken()
                        currentUser = nil
                        settings = nil
                        isAuthenticated = false
                        await cache.clear()
                    }
                }
            case .invalid:
                print(
                    "⚠️ Bootstrap: Token validation failed, clearing token and attempting credential login..."
                )
                await APIClient.shared.clearToken()
                currentUser = nil
                settings = nil
                isAuthenticated = false
                await cache.clear()
                await attemptCredentialLogin()
            case .networkError:
                print(
                    "⚠️ Bootstrap: Token validation deferred due to network error; keeping cached session"
                )
            }
        } else {
            print("⚠️ Bootstrap: No API token found, attempting credential login...")
            await attemptCredentialLogin()
        }

        await gotoBootstrapDelay(startTime: startTime)
    }

    private func gotoBootstrapDelay(startTime: Date) async {
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
                if shouldPreserveOnError(error) {
                    print("⚠️ Credential Login: Network error, keeping stored credentials")
                    return
                }
                credentialStore.clear()
                await APIClient.shared.clearToken()
                currentUser = nil
                settings = nil
                isAuthenticated = false
                await cache.clear()
            }
        }
    }

    private func attemptAppleCredentialLogin(userIdentifier: String, email: String) async {
        // Check the credential state with Apple
        let provider = ASAuthorizationAppleIDProvider()
        if isOffline {
            print("⚠️ Apple Sign In restoration skipped while offline")
            return
        }

        do {
            let credentialState = try await provider.credentialState(forUserID: userIdentifier)

            switch credentialState {
            case .authorized:
                // User is still authorized with Apple, but we can't get a new identity token silently
                // Apple's security model requires explicit user interaction to get a new token
                // If we're here, it means the API token expired and user needs to sign in again
                print(
                    "⚠️ Apple credentials still authorized but API token expired - user needs to sign in again"
                )
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
        if isOffline {
            print("⚠️ Google Sign In restoration skipped while offline")
            return
        }

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

                print(
                    "✅ Successfully restored Google Sign In, attempting backend authentication...")

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
                if shouldPreserveOnError(error) {
                    print("⚠️ Google Sign In: Network error, keeping stored credentials")
                    return
                }
                credentialStore.clear()
            }
        } else {
            print("⚠️ No previous Google Sign In session found - user will need to sign in again")
            // Don't clear credentials yet - let the user try to sign in again
        }
    }

    func login(email: String, password: String) async throws {
        if isOffline {
            throw APIError(
                statusCode: nil, message: "No internet connection.", unverified: false,
                isNetworkError: true)
        }
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
        presentOnboardingIfNeeded()
    }

    func loginWithApple(
        identityToken: String, userIdentifier: String, email: String?, firstName: String?,
        lastName: String?, authorizationCode: String?
    ) async throws {
        if isOffline {
            throw APIError(
                statusCode: nil, message: "No internet connection.", unverified: false,
                isNetworkError: true)
        }
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
        presentOnboardingIfNeeded()
    }

    func loginWithGoogle(
        idToken: String, userID: String, email: String?, firstName: String?, lastName: String?
    ) async throws {
        if isOffline {
            throw APIError(
                statusCode: nil, message: "No internet connection.", unverified: false,
                isNetworkError: true)
        }
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
        presentOnboardingIfNeeded()
    }

    func register(email: String, password: String, firstName: String, lastName: String) async throws
    {
        try await APIClient.shared.register(
            email: email, password: password, firstName: firstName, lastName: lastName)
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
        latestGamePlan = nil
        gamePlanContent = nil
        gamePlanStatus = .idle
        gamePlanUpdateNotice = false
        cachedGamePlanExternal = nil
        credentialStore.clear()
        updateFoodLoggingLevel(.beginner)
        showAssistant = false
        assistantMode = .assistant
        gamePlanPollTask?.cancel()
        await cache.clear()
    }

    func presentOnboardingIfNeeded() {
        guard isAuthenticated, !deferOnboardingThisSession else { return }
        if case .idle = gamePlanStatus { return }
        if case .loading = gamePlanStatus { return }
        let hasStoredGamePlan: Bool = {
            if let cached = cachedGamePlanExternal?.trimmingCharacters(in: .whitespacesAndNewlines),
                !cached.isEmpty
            {
                return true
            }
            return gamePlanContent != nil || latestGamePlan != nil
        }()
        let isDevOverride = showOnboardingNextLaunch && currentUser?.role == "ADMIN"
        guard !hasStoredGamePlan || isDevOverride else { return }
        let shouldShow = !hasSeenOnboardingChat || isDevOverride
        guard shouldShow else { return }
        showOnboardingNextLaunch = false
        assistantMode = .onboarding
        assistantTitle = "Welcome to FasterFoods"
        assistantScript = .empty()
        showAssistant = true
    }

    func presentAssistant(title: String, script: AssistantScript) {
        assistantMode = .assistant
        assistantTitle = title
        assistantScript = script
        showAssistant = true
    }

    func markOnboardingComplete() {
        hasSeenOnboardingChat = true
    }

    func onboardingNextLaunchEnabled() -> Bool {
        showOnboardingNextLaunch
    }

    func setOnboardingNextLaunchEnabled(_ enabled: Bool) {
        showOnboardingNextLaunch = enabled
        if enabled {
            hasSeenOnboardingChat = false
            deferOnboardingThisSession = true
        }
    }

    func consumeGamePlanUpdateNotice() {
        gamePlanUpdateNotice = false
    }

    func refreshLatestGamePlan(force: Bool = false) async {
        if isOffline {
            if gamePlanContent == nil {
                gamePlanStatus = .failed("No internet connection.")
            }
            return
        }
        if gamePlanStatus == .loading && !force { return }
        gamePlanStatus = .loading
        do {
            let plan = try await APIClient.shared.getLatestGamePlan()
            let trimmedExternal = plan.external.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cached = cachedGamePlanExternal?.trimmingCharacters(in: .whitespacesAndNewlines),
                !cached.isEmpty,
                cached != trimmedExternal
            {
                gamePlanUpdateNotice = true
            }
            cachedGamePlanExternal = trimmedExternal.isEmpty ? nil : trimmedExternal
            latestGamePlan = plan
            gamePlanContent = GamePlanContent.from(markdown: plan.external)
            gamePlanStatus = .ready
            markNetworkSuccess()
        } catch let apiError as APIError where apiError.statusCode == 404 {
            latestGamePlan = nil
            gamePlanContent = nil
            gamePlanStatus = .preparing
            cachedGamePlanExternal = nil
        } catch {
            if shouldPreserveOnError(error) {
                markNetworkFailureIfNeeded(error)
                if latestGamePlan == nil {
                    gamePlanStatus = .failed(
                        (error as? APIError)?.message ?? "Unable to load game plan."
                    )
                } else {
                    gamePlanStatus = .ready
                }
                return
            }
            latestGamePlan = nil
            gamePlanContent = nil
            gamePlanStatus = .failed(
                (error as? APIError)?.message ?? "Unable to load game plan."
            )
        }
    }

    func beginGamePlanPolling() {
        gamePlanPollTask?.cancel()
        gamePlanPollTask = Task { [weak self] in
            await self?.pollForLatestGamePlan()
        }
    }

    private func pollForLatestGamePlan(
        maxAttempts: Int = 6,
        initialDelaySeconds: Double = 2,
        maxDelaySeconds: Double = 15
    ) async {
        var delay = initialDelaySeconds
        for _ in 0..<maxAttempts {
            if Task.isCancelled { return }
            if isOffline { return }
            await refreshLatestGamePlan(force: true)
            if gamePlanStatus == .ready {
                return
            }
            let sleepNanos = UInt64(delay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: sleepNanos)
            delay = min(delay * 2, maxDelaySeconds)
        }
    }

    private var cachedGamePlanExternal: String? {
        get { SharedContainer.userDefaults.string(forKey: cachedGamePlanKey) }
        set {
            if let value = newValue, !value.isEmpty {
                SharedContainer.userDefaults.set(value, forKey: cachedGamePlanKey)
            } else {
                SharedContainer.userDefaults.removeObject(forKey: cachedGamePlanKey)
            }
        }
    }

    private func loadCachedGamePlan() {
        guard let cached = cachedGamePlanExternal, !cached.isEmpty else { return }
        if let content = GamePlanContent.from(markdown: cached) {
            gamePlanContent = content
            gamePlanStatus = .ready
        }
    }

    func refreshAll() async {
        if isOffline {
            persistCache()
            return
        }
        var hadSuccess = false
        do {
            savedItems = try await APIClient.shared.getSavedMacros()
            hadSuccess = true
        } catch {
            if !shouldPreserveOnError(error) {
                savedItems = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            familyMembers = try await APIClient.shared.getFamilyMembers()
            hadSuccess = true
        } catch {
            if !shouldPreserveOnError(error) {
                familyMembers = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            sharedItems = try await APIClient.shared.getSharedItems()
            hadSuccess = true
        } catch {
            if !shouldPreserveOnError(error) {
                sharedItems = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            shoppingLists = try await APIClient.shared.getShoppingLists()
            hadSuccess = true
        } catch {
            if !shouldPreserveOnError(error) {
                shoppingLists = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            try await loadShoppingRecommendations()
        } catch {
            shoppingRecommendations = []
        }

        do {
            pantryItems = try await APIClient.shared.getPantryItems()
            hadSuccess = true
        } catch {
            if !shouldPreserveOnError(error) {
                pantryItems = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            try await loadPantryRecommendations()
        } catch {
            pantryRecommendations = []
        }

        do {
            foodLogItems = try await APIClient.shared.getFoodLogItems()
            hadSuccess = true
        } catch {
            if !shouldPreserveOnError(error) {
                foodLogItems = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            try await loadFoodLogRecommendations()
        } catch {
            foodLogRecommendations = []
        }

        do {
            workoutItems = try await APIClient.shared.getWorkoutItems()
            print("✅ Loaded \(workoutItems.count) workout items from API")
            hadSuccess = true
        } catch {
            print("❌ Failed to load workout items: \(error)")
            if !shouldPreserveOnError(error) {
                workoutItems = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            customMetrics = try await APIClient.shared.getCustomMetricItems()
            print("✅ Loaded \(customMetrics.count) custom metrics from API")
            hadSuccess = true
        } catch {
            print("❌ Failed to load custom metrics: \(error)")
            if !shouldPreserveOnError(error) {
                customMetrics = []
            }
            markNetworkFailureIfNeeded(error)
        }

        do {
            workoutRecommendations = try await APIClient.shared.getWorkoutRecommendations()
            print("✅ Loaded \(workoutRecommendations.count) workout recommendations from API")
        } catch {
            print("❌ Failed to load workout recommendations: \(error)")
            workoutRecommendations = []
        }

        do {
            customMetricRecommendations = try await APIClient.shared
                .getCustomMetricRecommendations()
            print(
                "✅ Loaded \(customMetricRecommendations.count) custom metric recommendations from API"
            )
            hadSuccess = true
        } catch {
            print("❌ Failed to load custom metric recommendations: \(error)")
            customMetricRecommendations = []
            markNetworkFailureIfNeeded(error)
        }
        await refreshLatestGamePlan()
        persistCache()
        if hadSuccess {
            markNetworkSuccess()
            await syncOutbox()
        }
    }

    func loadShoppingLists() async throws {
        if isOffline { return }
        let lists = try await APIClient.shared.getShoppingLists()
        shoppingLists = lists
        persistCache()
        markNetworkSuccess()
    }

    @discardableResult
    func createShoppingList(name: String) async throws -> ShoppingList {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if isOffline {
            let tempId = makeTempId()
            let list = ShoppingList(id: tempId, name: trimmed, items: [])
            shoppingLists.append(list)
            persistCache()
            let payload = CreateShoppingListPayload(tempId: tempId, name: trimmed)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .createShoppingList, payload: data)
                )
            }
            return list
        }
        do {
            let list = try await APIClient.shared.createShoppingList(name: trimmed)
            var lists = shoppingLists
            lists.append(list)
            shoppingLists = lists
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return list
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            let tempId = makeTempId()
            let list = ShoppingList(id: tempId, name: trimmed, items: [])
            shoppingLists.append(list)
            persistCache()
            let payload = CreateShoppingListPayload(tempId: tempId, name: trimmed)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .createShoppingList, payload: data)
                )
            }
            return list
        }
    }

    @discardableResult
    func addShoppingItem(
        to listId: String, name: String, quantity: String? = nil, unit: String? = nil,
        listLabel: String? = nil
    ) async throws -> ShoppingItem {
        if isOffline {
            let tempId = makeTempId()
            let localItem = ShoppingItem(
                id: tempId,
                name: name,
                quantity: quantity,
                unit: unit,
                list: listLabel,
                checked: false,
                addedAt: Date().timeIntervalSince1970 * 1000,
                checkedAt: nil,
                shoppingListId: listId,
                createdAt: nil,
                updatedAt: nil
            )
            if let index = shoppingLists.firstIndex(where: { $0.id == listId }) {
                shoppingLists[index].items.append(localItem)
            }
            persistCache()
            let payload = AddShoppingItemPayload(
                tempItemId: tempId,
                listId: listId,
                name: name,
                quantity: quantity,
                unit: unit,
                listLabel: listLabel
            )
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addShoppingItem, payload: data)
                )
            }
            return localItem
        }
        do {
            let item = try await APIClient.shared.addShoppingItem(
                toList: listId, name: name, quantity: quantity, unit: unit, listLabel: listLabel)
            if let index = shoppingLists.firstIndex(where: { $0.id == listId }) {
                var updatedList = shoppingLists[index]
                updatedList.items.append(item)
                var lists = shoppingLists
                lists[index] = updatedList
                shoppingLists = lists
            } else {
                try await loadShoppingLists()
            }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return item
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            let tempId = makeTempId()
            let localItem = ShoppingItem(
                id: tempId,
                name: name,
                quantity: quantity,
                unit: unit,
                list: listLabel,
                checked: false,
                addedAt: Date().timeIntervalSince1970 * 1000,
                checkedAt: nil,
                shoppingListId: listId,
                createdAt: nil,
                updatedAt: nil
            )
            if let index = shoppingLists.firstIndex(where: { $0.id == listId }) {
                shoppingLists[index].items.append(localItem)
            }
            persistCache()
            let payload = AddShoppingItemPayload(
                tempItemId: tempId,
                listId: listId,
                name: name,
                quantity: quantity,
                unit: unit,
                listLabel: listLabel
            )
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addShoppingItem, payload: data)
                )
            }
            return localItem
        }
    }

    @discardableResult
    func toggleShoppingItem(listId: String, itemId: String, checked: Bool) async throws
        -> ShoppingItem
    {
        var payload: [String: Any] = ["checked": checked]
        var checkedAt: Int?
        if checked {
            let timestamp = Int(Date().timeIntervalSince1970 * 1000)
            payload["checkedAt"] = timestamp
            checkedAt = timestamp
        }
        if isTempId(itemId) {
            if let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) {
                if let itemIndex = shoppingLists[listIndex].items.firstIndex(where: {
                    $0.id == itemId
                }) {
                    shoppingLists[listIndex].items[itemIndex].checked = checked
                    if checked {
                        shoppingLists[listIndex].items[itemIndex].checkedAt =
                            Double(checkedAt ?? Int(Date().timeIntervalSince1970 * 1000))
                    } else {
                        shoppingLists[listIndex].items[itemIndex].checkedAt = nil
                    }
                }
            }
            persistCache()
            let payload = ToggleShoppingItemPayload(
                listId: listId, itemId: itemId, checked: checked, checkedAt: checkedAt)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .toggleShoppingItem, payload: data)
                )
            }
            guard
                let updated = shoppingLists.first(where: { $0.id == listId })?
                    .items.first(where: { $0.id == itemId })
            else {
                throw APIError(
                    statusCode: nil, message: "Item not found.", unverified: false,
                    isNetworkError: true)
            }
            return updated
        }
        if isOffline {
            if let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) {
                if let itemIndex = shoppingLists[listIndex].items.firstIndex(where: {
                    $0.id == itemId
                }) {
                    shoppingLists[listIndex].items[itemIndex].checked = checked
                    if checked {
                        shoppingLists[listIndex].items[itemIndex].checkedAt =
                            Double(checkedAt ?? Int(Date().timeIntervalSince1970 * 1000))
                    } else {
                        shoppingLists[listIndex].items[itemIndex].checkedAt = nil
                    }
                }
            }
            persistCache()
            let payload = ToggleShoppingItemPayload(
                listId: listId, itemId: itemId, checked: checked, checkedAt: checkedAt)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .toggleShoppingItem, payload: data)
                )
            }
            guard
                let updated = shoppingLists.first(where: { $0.id == listId })?
                    .items.first(where: { $0.id == itemId })
            else {
                throw APIError(
                    statusCode: nil, message: "Item not found.", unverified: false,
                    isNetworkError: true)
            }
            return updated
        }
        do {
            let updatedItem = try await APIClient.shared.updateShoppingItem(
                listId: listId, itemId: itemId, updates: payload)
            if let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) {
                var updatedList = shoppingLists[listIndex]
                if let itemIndex = updatedList.items.firstIndex(where: { $0.id == itemId }) {
                    updatedList.items[itemIndex] = updatedItem
                    var lists = shoppingLists
                    lists[listIndex] = updatedList
                    shoppingLists = lists
                }
            }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return updatedItem
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            if let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) {
                if let itemIndex = shoppingLists[listIndex].items.firstIndex(where: {
                    $0.id == itemId
                }) {
                    shoppingLists[listIndex].items[itemIndex].checked = checked
                    if checked {
                        shoppingLists[listIndex].items[itemIndex].checkedAt =
                            Double(checkedAt ?? Int(Date().timeIntervalSince1970 * 1000))
                    } else {
                        shoppingLists[listIndex].items[itemIndex].checkedAt = nil
                    }
                }
            }
            persistCache()
            let payload = ToggleShoppingItemPayload(
                listId: listId, itemId: itemId, checked: checked, checkedAt: checkedAt)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .toggleShoppingItem, payload: data)
                )
            }
            guard
                let updated = shoppingLists.first(where: { $0.id == listId })?
                    .items.first(where: { $0.id == itemId })
            else {
                throw error
            }
            return updated
        }
    }

    func deleteShoppingItem(listId: String, itemId: String) async throws {
        if isTempId(itemId) {
            if let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) {
                shoppingLists[listIndex].items.removeAll { $0.id == itemId }
            }
            persistCache()
            await outbox.removeOperations(forTempShoppingItemId: itemId)
            return
        }
        if isOffline {
            guard let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) else {
                return
            }
            shoppingLists[listIndex].items.removeAll { $0.id == itemId }
            persistCache()
            let payload = DeleteShoppingItemPayload(listId: listId, itemId: itemId)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteShoppingItem, payload: data)
                )
            }
            return
        }
        do {
            try await APIClient.shared.deleteShoppingItem(listId: listId, itemId: itemId)
            guard let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) else {
                return
            }
            var updatedList = shoppingLists[listIndex]
            updatedList.items.removeAll { $0.id == itemId }
            var lists = shoppingLists
            if updatedList.items.isEmpty {
                lists.remove(at: listIndex)
            } else {
                lists[listIndex] = updatedList
            }
            shoppingLists = lists
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            guard let listIndex = shoppingLists.firstIndex(where: { $0.id == listId }) else {
                return
            }
            shoppingLists[listIndex].items.removeAll { $0.id == itemId }
            persistCache()
            if isTempId(itemId) {
                await outbox.removeOperations(forTempShoppingItemId: itemId)
                return
            }
            let payload = DeleteShoppingItemPayload(listId: listId, itemId: itemId)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteShoppingItem, payload: data)
                )
            }
        }
    }

    func deleteShoppingList(id: String) async throws {
        if isTempId(id) {
            shoppingLists.removeAll { $0.id == id }
            persistCache()
            await outbox.removeOperations(forTempShoppingListId: id)
            return
        }
        if isOffline {
            shoppingLists.removeAll { $0.id == id }
            persistCache()
            let payload = DeleteShoppingListPayload(listId: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteShoppingList, payload: data)
                )
            }
            return
        }
        do {
            try await APIClient.shared.deleteShoppingList(id: id)
            shoppingLists.removeAll { $0.id == id }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            shoppingLists.removeAll { $0.id == id }
            persistCache()
            if isTempId(id) {
                await outbox.removeOperations(forTempShoppingListId: id)
                return
            }
            let payload = DeleteShoppingListPayload(listId: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteShoppingList, payload: data)
                )
            }
        }
    }

    func loadShoppingRecommendations() async throws {
        if isOffline { return }
        shoppingRecommendations = try await APIClient.shared.getShoppingRecommendations()
        markNetworkSuccess()
    }

    func sendShoppingRecommendationFeedback(id: String, action: RecommendationFeedbackAction)
        async throws
    {
        try await APIClient.shared.sendShoppingRecommendationFeedback(
            id: id, action: action.rawValue)
        shoppingRecommendations.removeAll { $0.id == id }
    }

    // MARK: - Pantry

    func loadPantryItems() async throws {
        if isOffline { return }
        pantryItems = try await APIClient.shared.getPantryItems()
        persistCache()
        markNetworkSuccess()
    }

    @discardableResult
    func addPantryItem(name: String, quantity: String?, unit: String?, expiryDate: String?)
        async throws -> PantryItem
    {
        let normalizedQuantity = quantity?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedUnit = unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalQuantity = (normalizedQuantity?.isEmpty == false) ? normalizedQuantity : "1"
        let finalUnit = (normalizedUnit?.isEmpty == false) ? normalizedUnit : "pieces"
        if isOffline {
            let tempId = makeTempId()
            let item = PantryItem(
                id: tempId, name: name, quantity: finalQuantity, unit: finalUnit,
                expiryDate: expiryDate,
                addedOn: nil, checked: false)
            pantryItems.append(item)
            persistCache()
            let payload = AddPantryItemPayload(
                tempId: tempId, name: name, quantity: finalQuantity, unit: finalUnit,
                expiryDate: expiryDate)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addPantryItem, payload: data)
                )
            }
            return item
        }
        do {
            let item = try await APIClient.shared.createPantryItem(
                name: name, quantity: finalQuantity, unit: finalUnit, expiryDate: expiryDate)
            pantryItems.append(item)
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return item
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            let tempId = makeTempId()
            let item = PantryItem(
                id: tempId, name: name, quantity: finalQuantity, unit: finalUnit,
                expiryDate: expiryDate,
                addedOn: nil, checked: false)
            pantryItems.append(item)
            persistCache()
            let payload = AddPantryItemPayload(
                tempId: tempId, name: name, quantity: finalQuantity, unit: finalUnit,
                expiryDate: expiryDate)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addPantryItem, payload: data)
                )
            }
            return item
        }
    }

    @discardableResult
    func updatePantryItem(
        id: String, name: String? = nil, quantity: String? = nil, unit: String? = nil,
        expiryDate: String? = nil
    ) async throws -> PantryItem {
        var payload: [String: Any] = [:]
        if let name { payload["name"] = name }
        if let quantity { payload["quantity"] = quantity }
        if let unit { payload["unit"] = unit }
        if let expiryDate { payload["expiryDate"] = expiryDate }
        if isTempId(id) {
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                if let name { pantryItems[index].name = name }
                if let quantity { pantryItems[index].quantity = quantity }
                if let unit { pantryItems[index].unit = unit }
                if let expiryDate { pantryItems[index].expiryDate = expiryDate }
            }
            persistCache()
            let payload = UpdatePantryItemPayload(
                id: id, name: name, quantity: quantity, unit: unit, expiryDate: expiryDate)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .updatePantryItem, payload: data)
                )
            }
            guard let updated = pantryItems.first(where: { $0.id == id }) else {
                throw APIError(
                    statusCode: nil, message: "Item not found.", unverified: false,
                    isNetworkError: true)
            }
            return updated
        }
        if isOffline {
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                if let name { pantryItems[index].name = name }
                if let quantity { pantryItems[index].quantity = quantity }
                if let unit { pantryItems[index].unit = unit }
                if let expiryDate { pantryItems[index].expiryDate = expiryDate }
            }
            persistCache()
            let payload = UpdatePantryItemPayload(
                id: id, name: name, quantity: quantity, unit: unit, expiryDate: expiryDate)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .updatePantryItem, payload: data)
                )
            }
            guard let updated = pantryItems.first(where: { $0.id == id }) else {
                throw APIError(
                    statusCode: nil, message: "Item not found.", unverified: false,
                    isNetworkError: true)
            }
            return updated
        }
        do {
            let updated = try await APIClient.shared.updatePantryItem(id: id, updates: payload)
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                pantryItems[index] = updated
            }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return updated
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                if let name { pantryItems[index].name = name }
                if let quantity { pantryItems[index].quantity = quantity }
                if let unit { pantryItems[index].unit = unit }
                if let expiryDate { pantryItems[index].expiryDate = expiryDate }
            }
            persistCache()
            let payload = UpdatePantryItemPayload(
                id: id, name: name, quantity: quantity, unit: unit, expiryDate: expiryDate)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .updatePantryItem, payload: data)
                )
            }
            guard let updated = pantryItems.first(where: { $0.id == id }) else { throw error }
            return updated
        }
    }

    func deletePantryItem(id: String) async throws {
        if isTempId(id) {
            pantryItems.removeAll { $0.id == id }
            persistCache()
            await outbox.removeOperations(forTempPantryItemId: id)
            return
        }
        if isOffline {
            pantryItems.removeAll { $0.id == id }
            persistCache()
            let payload = DeletePantryItemPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deletePantryItem, payload: data)
                )
            }
            return
        }
        do {
            try await APIClient.shared.deletePantryItem(id: id)
            pantryItems.removeAll { $0.id == id }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            pantryItems.removeAll { $0.id == id }
            persistCache()
            if isTempId(id) {
                await outbox.removeOperations(forTempPantryItemId: id)
                return
            }
            let payload = DeletePantryItemPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deletePantryItem, payload: data)
                )
            }
        }
    }

    @discardableResult
    func togglePantryItem(id: String) async throws -> PantryItem {
        if isTempId(id) {
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                pantryItems[index].checked.toggle()
            }
            persistCache()
            let payload = TogglePantryItemPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .togglePantryItem, payload: data)
                )
            }
            guard let updated = pantryItems.first(where: { $0.id == id }) else {
                throw APIError(
                    statusCode: nil, message: "Item not found.", unverified: false,
                    isNetworkError: true)
            }
            return updated
        }
        if isOffline {
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                pantryItems[index].checked.toggle()
            }
            persistCache()
            let payload = TogglePantryItemPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .togglePantryItem, payload: data)
                )
            }
            guard let updated = pantryItems.first(where: { $0.id == id }) else {
                throw APIError(
                    statusCode: nil, message: "Item not found.", unverified: false,
                    isNetworkError: true)
            }
            return updated
        }
        do {
            let updated = try await APIClient.shared.togglePantryItem(id: id)
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                pantryItems[index] = updated
            }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return updated
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            if let index = pantryItems.firstIndex(where: { $0.id == id }) {
                pantryItems[index].checked.toggle()
            }
            persistCache()
            let payload = TogglePantryItemPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .togglePantryItem, payload: data)
                )
            }
            guard let updated = pantryItems.first(where: { $0.id == id }) else { throw error }
            return updated
        }
    }

    func checkAllPantryItems() async {
        let unchecked = pantryItems.filter { !$0.checked }
        if !unchecked.isEmpty {
            pantryItems = pantryItems.map { item in
                var updated = item
                if !updated.checked { updated.checked = true }
                return updated
            }
            persistCache()
        }
        if isOffline {
            for item in unchecked {
                let payload = TogglePantryItemPayload(id: item.id)
                if let data = try? JSONEncoder().encode(payload) {
                    await outbox.enqueue(
                        OutboxOperation(kind: .togglePantryItem, payload: data)
                    )
                }
            }
            return
        }
        await withTaskGroup(of: Void.self) { group in
            for item in unchecked {
                if isTempId(item.id) {
                    let payload = TogglePantryItemPayload(id: item.id)
                    if let data = try? JSONEncoder().encode(payload) {
                        await outbox.enqueue(
                            OutboxOperation(kind: .togglePantryItem, payload: data)
                        )
                    }
                    continue
                }
                group.addTask {
                    do {
                        try await APIClient.shared.updatePantryItem(
                            id: item.id, updates: ["checked": true])
                    } catch {
                        // Silently handle errors for batch operations
                        print("Error updating pantry item \(item.id): \(error)")
                    }
                }
            }
        }
        await loadPantryItemsSafely()
    }

    private func loadPantryItemsSafely() async {
        do {
            if isOffline { return }
            pantryItems = try await APIClient.shared.getPantryItems()
            persistCache()
            markNetworkSuccess()
        } catch {
            // ignore
            markNetworkFailureIfNeeded(error)
        }
    }

    func loadPantryRecommendations() async throws {
        if isOffline { return }
        do {
            pantryRecommendations = try await APIClient.shared.getPantryRecommendations()
            markNetworkSuccess()
        } catch {
            pantryRecommendations = []
            markNetworkFailureIfNeeded(error)
            throw error
        }
    }

    func sendPantryRecommendationFeedback(id: String, action: RecommendationFeedbackAction)
        async throws
    {
        try await APIClient.shared.sendPantryRecommendationFeedback(id: id, action: action.rawValue)
        pantryRecommendations.removeAll { $0.id == id }
    }

    // MARK: - Food Log

    func loadFoodLogItems() async throws {
        if isOffline { return }
        foodLogItems = try await APIClient.shared.getFoodLogItems()
        persistCache()
        markNetworkSuccess()
    }

    @discardableResult
    func addFoodLogItem(_ request: FoodLogCreateRequest) async throws -> FoodLogItem {
        if isOffline {
            let tempId = makeTempId()
            let item = FoodLogItem(id: tempId, request: request)
            foodLogItems.insert(item, at: 0)
            persistCache()
            let payload = AddFoodLogItemPayload(tempId: tempId, request: request)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addFoodLogItem, payload: data)
                )
            }
            return item
        }
        do {
            let item = try await APIClient.shared.createFoodLogItem(request)
            foodLogItems.insert(item, at: 0)
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return item
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            let tempId = makeTempId()
            let item = FoodLogItem(id: tempId, request: request)
            foodLogItems.insert(item, at: 0)
            persistCache()
            let payload = AddFoodLogItemPayload(tempId: tempId, request: request)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addFoodLogItem, payload: data)
                )
            }
            return item
        }
    }

    func deleteFoodLogItem(id: String) async throws {
        if isTempId(id) {
            foodLogItems.removeAll { $0.id == id }
            persistCache()
            await outbox.removeOperations(forTempFoodLogId: id)
            return
        }
        if isOffline {
            foodLogItems.removeAll { $0.id == id }
            persistCache()
            let payload = DeleteFoodLogItemPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteFoodLogItem, payload: data)
                )
            }
            return
        }
        do {
            try await APIClient.shared.deleteFoodLogItem(id: id)
            foodLogItems.removeAll { $0.id == id }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            foodLogItems.removeAll { $0.id == id }
            persistCache()
            if isTempId(id) {
                await outbox.removeOperations(forTempFoodLogId: id)
                return
            }
            let payload = DeleteFoodLogItemPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteFoodLogItem, payload: data)
                )
            }
        }
    }

    func loadFoodLogRecommendations() async throws {
        if isOffline { return }
        do {
            foodLogRecommendations = try await APIClient.shared.getFoodLogRecommendations()
            markNetworkSuccess()
        } catch {
            foodLogRecommendations = []
            markNetworkFailureIfNeeded(error)
            throw error
        }
    }

    func sendFoodLogRecommendationFeedback(id: String, action: RecommendationFeedbackAction)
        async throws
    {
        try await APIClient.shared.sendFoodLogRecommendationFeedback(
            id: id, action: action.rawValue)
        foodLogRecommendations.removeAll { $0.id == id }
    }

    func updateFoodLoggingLevel(_ level: FoodLoggingLevel) {
        foodLoggingLevel = level
        settings?.foodLoggingLevel = level
        UserDefaults.standard.set(level.rawValue, forKey: foodLoggingLevelKey)
    }

    func syncSettings(_ settings: UserSettings) {
        applySettings(settings)
        persistCache()
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
            parameters: item.parameters,  // Already AnyCodableValue
            datetime: item.datetime
        )
        if isOffline {
            let tempId = makeTempId()
            let localItem = WorkoutLogItem(
                id: tempId,
                name: item.name,
                activity: item.activity,
                category: item.category,
                duration: item.duration,
                calories: item.calories,
                parameters: item.parameters,
                datetime: item.datetime,
                userId: item.userId,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt
            )
            workoutItems.insert(localItem, at: 0)
            persistCache()
            let payload = AddWorkoutPayload(tempId: tempId, item: localItem)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addWorkout, payload: data)
                )
            }
            return localItem
        }
        do {
            let createdItem = try await APIClient.shared.createWorkoutItem(request)
            workoutItems.insert(createdItem, at: 0)
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return createdItem
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            let tempId = makeTempId()
            let localItem = WorkoutLogItem(
                id: tempId,
                name: item.name,
                activity: item.activity,
                category: item.category,
                duration: item.duration,
                calories: item.calories,
                parameters: item.parameters,
                datetime: item.datetime,
                userId: item.userId,
                createdAt: item.createdAt,
                updatedAt: item.updatedAt
            )
            workoutItems.insert(localItem, at: 0)
            persistCache()
            let payload = AddWorkoutPayload(tempId: tempId, item: localItem)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addWorkout, payload: data)
                )
            }
            return localItem
        }
    }

    func deleteWorkout(id: String) async throws {
        if isTempId(id) {
            workoutItems.removeAll { $0.id == id }
            persistCache()
            await outbox.removeOperations(forTempWorkoutId: id)
            return
        }
        if isOffline {
            workoutItems.removeAll { $0.id == id }
            persistCache()
            let payload = DeleteWorkoutPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteWorkout, payload: data)
                )
            }
            return
        }
        do {
            try await APIClient.shared.deleteWorkoutItem(id: id)
            workoutItems.removeAll { $0.id == id }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            workoutItems.removeAll { $0.id == id }
            persistCache()
            if isTempId(id) {
                await outbox.removeOperations(forTempWorkoutId: id)
                return
            }
            let payload = DeleteWorkoutPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteWorkout, payload: data)
                )
            }
        }
    }

    // MARK: - Custom Metrics

    @discardableResult
    func addCustomMetric(_ metric: CustomMetric) async throws -> CustomMetric {
        if isOffline {
            let tempId = makeTempId()
            let localMetric = CustomMetric(
                id: tempId,
                name: metric.name,
                value: metric.value,
                unit: metric.unit,
                date: metric.date,
                metricType: metric.metricType,
                userId: metric.userId,
                createdAt: metric.createdAt,
                updatedAt: metric.updatedAt
            )
            customMetrics.insert(localMetric, at: 0)
            persistCache()
            let payload = AddCustomMetricPayload(tempId: tempId, metric: localMetric)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addCustomMetric, payload: data)
                )
            }
            return localMetric
        }
        do {
            let createdMetric = try await APIClient.shared.createCustomMetricItem(
                name: metric.name,
                value: metric.value,
                unit: metric.unit,
                date: metric.date,
                metricType: metric.metricType
            )
            customMetrics.insert(createdMetric, at: 0)
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
            return createdMetric
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            let tempId = makeTempId()
            let localMetric = CustomMetric(
                id: tempId,
                name: metric.name,
                value: metric.value,
                unit: metric.unit,
                date: metric.date,
                metricType: metric.metricType,
                userId: metric.userId,
                createdAt: metric.createdAt,
                updatedAt: metric.updatedAt
            )
            customMetrics.insert(localMetric, at: 0)
            persistCache()
            let payload = AddCustomMetricPayload(tempId: tempId, metric: localMetric)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .addCustomMetric, payload: data)
                )
            }
            return localMetric
        }
    }

    func deleteCustomMetric(id: String) async throws {
        if isTempId(id) {
            customMetrics.removeAll { $0.id == id }
            persistCache()
            await outbox.removeOperations(forTempCustomMetricId: id)
            return
        }
        if isOffline {
            customMetrics.removeAll { $0.id == id }
            persistCache()
            let payload = DeleteCustomMetricPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteCustomMetric, payload: data)
                )
            }
            return
        }
        do {
            try await APIClient.shared.deleteCustomMetricItem(id: id)
            customMetrics.removeAll { $0.id == id }
            persistCache()
            markNetworkSuccess()
            await syncOutbox()
        } catch {
            markNetworkFailureIfNeeded(error)
            guard shouldPreserveOnError(error) else { throw error }
            customMetrics.removeAll { $0.id == id }
            persistCache()
            if isTempId(id) {
                await outbox.removeOperations(forTempCustomMetricId: id)
                return
            }
            let payload = DeleteCustomMetricPayload(id: id)
            if let data = try? JSONEncoder().encode(payload) {
                await outbox.enqueue(
                    OutboxOperation(kind: .deleteCustomMetric, payload: data)
                )
            }
        }
    }

    func loadWorkoutRecommendations() async throws {
        if isOffline { return }
        workoutRecommendations = try await APIClient.shared.getWorkoutRecommendations()
        markNetworkSuccess()
    }

    func sendWorkoutRecommendationFeedback(id: String, action: RecommendationFeedbackAction)
        async throws
    {
        try await APIClient.shared.sendWorkoutRecommendationFeedback(
            id: id, action: action.rawValue)
        workoutRecommendations.removeAll { $0.id == id }
    }

    func loadCustomMetricRecommendations() async throws {
        if isOffline { return }
        customMetricRecommendations = try await APIClient.shared.getCustomMetricRecommendations()
        markNetworkSuccess()
    }

    func sendCustomMetricRecommendationFeedback(id: String, action: RecommendationFeedbackAction)
        async throws
    {
        try await APIClient.shared.sendCustomMetricRecommendationFeedback(
            id: id, action: action.rawValue)
        customMetricRecommendations.removeAll { $0.id == id }
    }
}

enum RecommendationFeedbackAction: String {
    case accepted
    case dismissed
}
