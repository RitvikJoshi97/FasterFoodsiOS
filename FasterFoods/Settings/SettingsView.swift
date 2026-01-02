import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var theme: ThemePreference = .light
    @State private var unitSystem: UnitSystem = .imperial
    @State private var notificationsEnabled = true
    @State private var language: String = "en"
    @State private var loggingLevel: FoodLoggingLevel = .beginner
    @State private var previousLoggingLevel: FoodLoggingLevel = .beginner
    @State private var hasLoaded = false
    @State private var statusMessage: StatusMessage?
    @State private var showDeleteAlert = false
    @State private var showOnboardingNextLaunch = false

    private let languageOptions: [(code: String, label: String)] = [
        ("en", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es", "Spanish"),
    ]
    private let settingsStorageKey = "localUserSettings"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    settingsCard(
                        title: "Help", systemImage: "questionmark.circle",
                        description: "Get quick guidance when you are stuck."
                    ) {
                        settingsActionButton(
                            title: "Get help", systemImage: "message.fill"
                        ) {
                            app.presentAssistant(
                                title: "Help",
                                script: .sampleAssistant()
                            )
                        }
                    }

                    settingsCard(
                        title: "Preferences", systemImage: "slider.horizontal.3",
                        description:
                            "Control how FasterFoods looks, communicates, and logs your meals."
                    ) {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .center, spacing: 12) {
                                settingLabel(
                                    "Dark Mode",
                                    subtitle: "Use the darker interface across FasterFoods.")
                                Spacer()
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { theme == .dark },
                                        set: { theme = $0 ? .dark : .light }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                settingLabel(
                                    "Unit system",
                                    subtitle: "Choose how measurements are shown.")
                                Picker("Unit system", selection: $unitSystem) {
                                    ForEach(UnitSystem.allCases) { system in
                                        Text(system.label).tag(system)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            Divider()

                            HStack(alignment: .center, spacing: 12) {
                                settingLabel(
                                    "Notifications",
                                    subtitle:
                                        "Stay informed about new insights and reminders.")
                                Spacer()
                                Toggle("", isOn: $notificationsEnabled)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }

                            Divider()

                            HStack(alignment: .center, spacing: 12) {
                                settingLabel("Language", subtitle: "Pick your preferred language.")
                                Spacer()
                                Picker("Language", selection: $language) {
                                    ForEach(languageOptions, id: \.code) { option in
                                        Text(option.label).tag(option.code)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                settingLabel(
                                    "Food logging level",
                                    subtitle: "Match tracking depth to your comfort level.")
                                Picker("Food logging level", selection: $loggingLevel) {
                                    ForEach(FoodLoggingLevel.allCases, id: \.self) { level in
                                        Text(levelDisplayName(level)).tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)

                                Text(levelDescription(loggingLevel))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    settingsCard(
                        title: "Data & Privacy", systemImage: "tray.and.arrow.down.fill",
                        description: "Manage how your data is stored and shared."
                    ) {
                        VStack(spacing: 12) {
                            settingsActionButton(
                                title: "Export data", systemImage: "square.and.arrow.up"
                            ) {
                                statusMessage = StatusMessage(
                                    title: "Coming soon",
                                    message: "Data export will be available in a future update.")
                            }
                            settingsActionButton(
                                title: "Import from JSON", systemImage: "tray.and.arrow.down"
                            ) {
                                statusMessage = StatusMessage(
                                    title: "Coming soon",
                                    message: "Data import will be available in a future update.")
                            }
                            settingsActionButton(title: "Clear synced data", systemImage: "trash") {
                                statusMessage = StatusMessage(
                                    title: "Heads up",
                                    message:
                                        "Clearing synced data will be supported in a future release."
                                )
                            }
                        }
                    }

                    if app.currentUser?.role == "ADMIN" {
                        settingsCard(
                            title: "Dev tools", systemImage: "hammer.fill",
                            description: "Debug and QA helpers."
                        ) {
                            Toggle("Show onboarding next time", isOn: $showOnboardingNextLaunch)
                                .toggleStyle(.switch)
                                .onChange(of: showOnboardingNextLaunch) { _, newValue in
                                    app.setOnboardingNextLaunchEnabled(newValue)
                                }
                        }
                    }

                    settingsCard(
                        title: "Account", systemImage: "person.crop.circle",
                        description: "Log out or request account deletion."
                    ) {
                        VStack(spacing: 12) {
                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                Label("Delete account", systemImage: "minus.circle")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)

                            Button {
                                Task { await app.logout() }
                            } label: {
                                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Settings")
            .alert(item: $statusMessage) { message in
                Alert(
                    title: Text(message.title), message: Text(message.message),
                    dismissButton: .default(Text("OK")))
            }
            .alert("Delete account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { showDeleteAlert = false }
                Button("Delete", role: .destructive) {
                    statusMessage = StatusMessage(
                        title: "Coming soon",
                        message: "Account deletion will be available in a future update.")
                }
            } message: {
                Text("We\'ll guide you through the deletion flow once it\'s ready.")
            }
            .onAppear(perform: loadSettings)
            .onChange(of: theme) { _, _ in saveSettings() }
            .onChange(of: unitSystem) { _, _ in saveSettings() }
            .onChange(of: notificationsEnabled) { _, _ in saveSettings() }
            .onChange(of: language) { _, _ in saveSettings() }
            .onChange(of: loggingLevel) { oldValue, newValue in
                guard hasLoaded else { return }
                if newValue == .advanced {
                    loggingLevel = previousLoggingLevel
                    statusMessage = StatusMessage(
                        title: "Coming soon",
                        message: "Advanced logging is coming soon. We'll keep you posted!"
                    )
                    return
                }
                previousLoggingLevel = newValue
                app.updateFoodLoggingLevel(newValue)
                saveSettings()
            }
        }
    }

    private func loadSettings() {
        guard !hasLoaded else { return }
        if let stored = loadLocalSettings() {
            theme = stored.theme
            unitSystem = stored.unitSystem
            notificationsEnabled = stored.notificationsEnabled
            language = stored.language
            loggingLevel = stored.foodLoggingLevel
            app.settings = stored
        } else if let existing = app.settings {
            theme = existing.theme
            unitSystem = existing.unitSystem
            notificationsEnabled = existing.notificationsEnabled
            language = existing.language
            loggingLevel = existing.foodLoggingLevel
        } else {
            let defaults = UserSettings()
            theme = defaults.theme
            unitSystem = defaults.unitSystem
            notificationsEnabled = defaults.notificationsEnabled
            language = defaults.language
            loggingLevel = defaults.foodLoggingLevel
        }
        app.updateFoodLoggingLevel(loggingLevel)
        showOnboardingNextLaunch = app.onboardingNextLaunchEnabled()
        previousLoggingLevel = loggingLevel
        hasLoaded = true
    }

    private func saveSettings() {
        guard hasLoaded else { return }
        let payload = UserSettings(
            theme: theme,
            unitSystem: unitSystem,
            notificationsEnabled: notificationsEnabled,
            language: language,
            foodLoggingLevel: loggingLevel
        )

        persistLocalSettings(payload)
        app.syncSettings(payload)
    }

    private func levelDisplayName(_ level: FoodLoggingLevel) -> String {
        switch level {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    private func levelDescription(_ level: FoodLoggingLevel) -> String {
        switch level {
        case .beginner:
            return "Simple logging with the essentials to help you build the habit."
        case .intermediate:
            return "Adds macro tracking, portion guidance, and meal timing details."
        case .advanced:
            return "Full experience with advanced metrics and mindfulness prompts — coming soon."
        }
    }

    @ViewBuilder
    private func settingsCard<Content: View>(
        title: String, systemImage: String, description: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    if let description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(.separator).opacity(0.2))
        )
    }

    private func settingLabel(_ title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func settingsActionButton(
        title: String, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private struct StatusMessage: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private func persistLocalSettings(_ settings: UserSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsStorageKey)
        }
    }

    private func loadLocalSettings() -> UserSettings? {
        guard let data = UserDefaults.standard.data(forKey: settingsStorageKey) else { return nil }
        return try? JSONDecoder().decode(UserSettings.self, from: data)
    }
}
