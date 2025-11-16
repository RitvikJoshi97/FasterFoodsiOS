import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FoodLogView: View {
    @EnvironmentObject private var app: AppState
    @StateObject private var viewModel = FoodLogViewModel()
    @State private var mealDate = Date()
    @State private var isSubmitting = false
    @State private var isLoading = false
    @State private var didLoadOnce = false
    @State private var isLoadingRecommendations = false
    @State private var didLoadRecommendations = false
    @State private var recommendationsError: String?
    @State private var selectedRecommendation: ShoppingRecommendation?
    @State private var usingRecommendationId: String?
    @State private var dismissingRecommendationId: String?
    @State private var alertMessage: String?
    @State private var didInitialize = false

    private let staticSuggestions = [
        "Oatmeal", "Greek Yogurt", "Salad", "Grilled Chicken", "Salmon",
        "Brown Rice", "Smoothie", "Nuts", "Apple", "Sandwich"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FoodLogFormView(
                        viewModel: viewModel,
                        loggingLevel: app.foodLoggingLevel,
                        mealDate: $mealDate,
                        isSubmitting: isSubmitting,
                        onSubmit: logMeal
                    )
                }

                Section {
                    FoodLogSuggestionsView(
                        staticSuggestions: staticSuggestions,
                        aiSuggestions: app.foodLogRecommendations,
                        isLoading: isLoadingRecommendations,
                        onRefresh: { Task { await loadRecommendations(force: true) } },
                        onSelectSuggestion: viewModel.applySuggestion,
                        onSelectRecommendation: { recommendation in
                            selectedRecommendation = recommendation
                        }
                    )
                    if let recommendationsError,
                       !recommendationsError.isEmpty {
                        Text(recommendationsError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section(header: Text("Food History")) {
                    if isLoading {
                        ProgressView("Loading meals…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        FoodLogHistoryView(items: app.foodLogItems) { item in
                            Task { await delete(item) }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Food Log")
        }
        .onAppear {
            if !didInitialize {
                viewModel.reset(for: app.foodLoggingLevel)
                didInitialize = true
            }
        }
        .onChange(of: app.foodLoggingLevel) { oldLevel, newLevel in
            viewModel.reset(for: newLevel)
        }
        .task { await loadFoodLogIfNeeded() }
        .task { await loadRecommendationsIfNeeded() }
        .refreshable {
            await loadFoodLog(force: true)
            await loadRecommendations(force: true)
        }
        .alert("Something went wrong", isPresented: Binding<Bool>(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .sheet(item: $selectedRecommendation) { recommendation in
            RecommendationDetailSheet(
                recommendation: recommendation,
                isUsing: usingRecommendationId == recommendation.id,
                isDismissing: dismissingRecommendationId == recommendation.id,
                onUse: {
                    Task { await accept(recommendation) }
                },
                onDismiss: {
                    Task { await dismiss(recommendation) }
                }
            )
            .withDetents()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { hideKeyboard() }
            }
        }
    }

    private func logMeal() {
        guard viewModel.canLogEntry else { return }
        isSubmitting = true
        let request = viewModel.request(for: app.foodLoggingLevel, date: mealDate)
        Task { @MainActor in
            do {
                _ = try await app.addFoodLogItem(request)
                viewModel.reset(for: app.foodLoggingLevel)
                mealDate = Date()
                hideKeyboard()
            } catch {
                alertMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    private func loadFoodLogIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await loadFoodLog(force: false)
    }

    @MainActor
    private func loadFoodLog(force: Bool) async {
        if isLoading && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await app.loadFoodLogItems()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func loadRecommendationsIfNeeded() async {
        guard !didLoadRecommendations else { return }
        await loadRecommendations(force: false)
    }

    @MainActor
    private func loadRecommendations(force: Bool) async {
        if isLoadingRecommendations && !force { return }
        isLoadingRecommendations = true
        defer { isLoadingRecommendations = false }
        do {
            try await app.loadFoodLogRecommendations()
            recommendationsError = nil
            didLoadRecommendations = true
        } catch {
            recommendationsError = error.localizedDescription
        }
    }

    private func delete(_ item: FoodLogItem) async {
        do {
            try await app.deleteFoodLogItem(id: item.id)
        } catch {
            await MainActor.run { alertMessage = error.localizedDescription }
        }
    }

    private func accept(_ recommendation: ShoppingRecommendation) async {
        await MainActor.run {
            usingRecommendationId = recommendation.id
            viewModel.applySuggestion(recommendation.title)
        }
        defer {
            Task { @MainActor in
                usingRecommendationId = nil
                selectedRecommendation = nil
            }
        }
        try? await app.sendFoodLogRecommendationFeedback(id: recommendation.id, action: .accepted)
    }

    private func dismiss(_ recommendation: ShoppingRecommendation) async {
        await MainActor.run { dismissingRecommendationId = recommendation.id }
        defer {
            Task { @MainActor in
                dismissingRecommendationId = nil
                selectedRecommendation = nil
            }
        }
        try? await app.sendFoodLogRecommendationFeedback(id: recommendation.id, action: .dismissed)
    }

    private func hideKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}
