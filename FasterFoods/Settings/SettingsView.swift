import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var app: AppState
    @State private var theme: ThemePreference = .light
    @State private var unitSystem: UnitSystem = .imperial
    @State private var notificationsEnabled = true
    @State private var language: String = "en"
    @State private var loggingLevel: FoodLoggingLevel = .beginner
    @State private var previousLoggingLevel: FoodLoggingLevel = .beginner
    @State private var isSaving = false
    @State private var hasLoaded = false
    @State private var statusMessage: StatusMessage?
    @State private var showDeleteAlert = false

    private let languageOptions: [(code: String, label: String)] = [
        ("en", "English (US)"),
        ("en-GB", "English (UK)"),
        ("es", "Spanish")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    settingsCard(title: "Appearance", systemImage: theme == .dark ? "moon.fill" : "sun.max.fill", description: "Switch between light and dark themes to match your workspace.") {
                        Toggle(isOn: Binding(
                            get: { theme == .dark },
                            set: { theme = $0 ? .dark : .light }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Dark Mode")
                                Text("Use the darker interface across FasterFoods.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }

                    settingsCard(title: "Units & Notifications", systemImage: "ruler", description: "Choose your preferred measurement system and notification style.") {
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unit system")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Picker("Unit system", selection: $unitSystem) {
                                    ForEach(UnitSystem.allCases) { system in
                                        Text(system.label).tag(system)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            Toggle(isOn: $notificationsEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notifications")
                                    Text("Stay informed about new insights and reminders.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.switch)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Language")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Picker("Language", selection: $language) {
                                    ForEach(languageOptions, id: \.code) { option in
                                        Text(option.label).tag(option.code)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    settingsCard(title: "Food Logging", systemImage: "book.fill", description: "Adjust the depth of tracking to match your comfort level.") {
                        VStack(alignment: .leading, spacing: 12) {
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

                    settingsCard(title: "Data & Privacy", systemImage: "tray.and.arrow.down.fill", description: "Manage how your data is stored and shared.") {
                        VStack(spacing: 12) {
                            settingsActionButton(title: "Export data", systemImage: "square.and.arrow.up") {
                                statusMessage = StatusMessage(title: "Coming soon", message: "Data export will be available in a future update.")
                            }
                            settingsActionButton(title: "Import from JSON", systemImage: "tray.and.arrow.down") {
                                statusMessage = StatusMessage(title: "Coming soon", message: "Data import will be available in a future update.")
                            }
                            settingsActionButton(title: "Clear synced data", systemImage: "trash") {
                                statusMessage = StatusMessage(title: "Heads up", message: "Clearing synced data will be supported in a future release.")
                            }
                        }
                    }

                    settingsCard(title: "Account", systemImage: "person.crop.circle", description: "Log out or request account deletion.") {
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

                    Button(action: saveSettings) {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Save changes", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView()
                    }
                }
            }
            .alert(item: $statusMessage) { message in
                Alert(title: Text(message.title), message: Text(message.message), dismissButton: .default(Text("OK")))
            }
            .alert("Delete account?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { showDeleteAlert = false }
                Button("Delete", role: .destructive) {
                    statusMessage = StatusMessage(title: "Coming soon", message: "Account deletion will be available in a future update.")
                }
            } message: {
                Text("We\'ll guide you through the deletion flow once it\'s ready.")
            }
            .onAppear(perform: loadSettings)
            .onChange(of: loggingLevel) { newValue in
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
            }
        }
    }

    private func loadSettings() {
        guard !hasLoaded else { return }
        if let existing = app.settings {
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
        previousLoggingLevel = loggingLevel
        hasLoaded = true
    }

    private func saveSettings() {
        let payload = UserSettings(
            theme: theme,
            unitSystem: unitSystem,
            notificationsEnabled: notificationsEnabled,
            language: language,
            foodLoggingLevel: loggingLevel
        )

        Task {
            isSaving = true
            defer { isSaving = false }
            do {
                let updated = try await APIClient.shared.updateSettings(payload)
                await MainActor.run {
                    app.syncSettings(updated)
                    theme = updated.theme
                    unitSystem = updated.unitSystem
                    notificationsEnabled = updated.notificationsEnabled
                    language = updated.language
                    loggingLevel = updated.foodLoggingLevel
                    statusMessage = StatusMessage(title: "Saved", message: "Your preferences have been updated.")
                }
            } catch {
                await MainActor.run {
                    statusMessage = StatusMessage(title: "Error", message: error.localizedDescription)
                }
            }
        }
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
    private func settingsCard<Content: View>(title: String, systemImage: String, description: String? = nil, @ViewBuilder content: () -> Content) -> some View {
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

    private func settingsActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
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
}
