//
//  DashboardView.swift
//  FasterFoods
//
//  Created by Ritvik Joshi on 11/04/25.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var app: AppState

    private var greeting: String {
        if let user = app.currentUser {
            return "Welcome back, \(user.firstName) \(user.lastName)"
        }
        return "Welcome to FasterFoods"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(greeting)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardCard(title: "Today's Overview", systemImage: "sun.max") {
                        Text("Calories, macros, and hydration at a glance.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    DashboardCard(title: "Goals In Progress", systemImage: "target") {
                        VStack(alignment: .leading, spacing: 12) {
                            ProgressRow(label: "Calorie Target", value: 0.62)
                            ProgressRow(label: "Protein Goal", value: 0.48, tint: .purple)
                            ProgressRow(label: "Hydration", value: 0.75, tint: .teal)
                        }
                    }

                    // Goals Section
                    GoalsSection()

                    DashboardCard(title: "Next Up", systemImage: "calendar") {
                        VStack(alignment: .leading, spacing: 12) {
                            DashboardListRow(title: "Plan your shopping list", detail: "Add items for the week ahead")
                            DashboardListRow(title: "Schedule a workout", detail: "Keep momentum with a 30 min session")
                            DashboardListRow(title: "Review custom metrics", detail: "Track what's working for you")
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 24)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct DashboardCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ProgressRow: View {
    let label: String
    let value: Double
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: value)
                .tint(tint)
        }
    }
}

struct DashboardListRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontWeight(.medium)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Goals Section
struct GoalsSection: View {
    @State private var goalDescription = ""
    @State private var savedGoals: [Goal] = []
    @State private var recommendations: [GoalRecommendation] = []
    @State private var isSubmitting = false
    @State private var isLoading = true
    @State private var isLoadingRecommendations = true
    @State private var statusMessage: String?
    @State private var isSuccess = false
    @State private var selectedRecommendation: GoalRecommendation?
    
    var body: some View {
        DashboardCard(title: "Goal Setting", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 16) {
                // Description
                Text("Capture your long-form fitness goals and get inspired by community suggestions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    // Text Editor
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your long-form goal")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $goalDescription)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                                .onChange(of: goalDescription) { newValue in
                                    // Clear selected recommendation if user types manually
                                    if let selected = selectedRecommendation {
                                        let selectedText = selected.title ?? selected.description
                                        if newValue != selectedText && newValue != selected.description {
                                            selectedRecommendation = nil
                                        }
                                    }
                                }
                            
                            if goalDescription.isEmpty {
                                Text("Describe your goal in detail...")
                                    .foregroundStyle(.secondary.opacity(0.5))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                        
                        Text("We'll keep this goal pinned to your dashboard so you can stay accountable.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Status Message
                    if let message = statusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(isSuccess ? .green : .red)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(isSuccess ? .green : .red)
                        }
                    }
                    
                    // Save Button
                    Button(action: saveGoal) {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            }
                            Image(systemName: "sparkles")
                            Text(isSubmitting ? "Saving..." : "Save Goal")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                    
                    // Recommendations
                    if !recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.secondary)
                                Text("Popular community goals")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                if isLoadingRecommendations {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recommendations) { recommendation in
                                        Button(action: {
                                            let text = recommendation.description
                                            goalDescription = text
                                            selectedRecommendation = recommendation
                                        }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                if let title = recommendation.title {
                                                    Text(title)
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .lineLimit(2)
                                                }
                                                Text(recommendation.description)
                                                    .font(.caption2)
                                                    .lineLimit(3)
                                                if let count = recommendation.usageCount {
                                                    Text("\(count) keeping this")
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .frame(width: 200, alignment: .leading)
                                            .background(selectedRecommendation?.id == recommendation.id ? Color.accentColor : Color.secondary.opacity(0.2))
                                            .foregroundStyle(selectedRecommendation?.id == recommendation.id ? .white : .primary)
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Saved Goals
                    if !savedGoals.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "target")
                                    .foregroundStyle(.secondary)
                                Text("Your active goals")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            
                            ForEach(savedGoals) { goal in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal.description)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        if let createdAt = goal.createdAt {
                                            Text("Added \(formatDate(createdAt))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadData()
            }
        }
    }
    
    @MainActor
    private func loadData() async {
        isLoading = true
        isLoadingRecommendations = true
        
        // Load goals first
        do {
            let goals = try await APIClient.shared.getGoals()
            savedGoals = goals
        } catch {
            print("Error loading goals: \(error)")
            savedGoals = []
        }
        isLoading = false
        
        // Then load recommendations
        do {
            let recs = try await APIClient.shared.getGoalRecommendations()
            recommendations = recs
        } catch {
            print("Error loading goal recommendations: \(error)")
            recommendations = []
        }
        isLoadingRecommendations = false
    }
    
    private func saveGoal() {
        guard !goalDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        statusMessage = nil
        
        Task {
            do {
                let trimmedDescription = goalDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                let title = selectedRecommendation?.title
                let source = selectedRecommendation != nil ? "dashboard-recommendation" : "dashboard-manual"
                
                let newGoal = try await APIClient.shared.createGoal(
                    title: title,
                    description: trimmedDescription,
                    source: source
                )
                
                await MainActor.run {
                    savedGoals.insert(newGoal, at: 0)
                    goalDescription = ""
                    selectedRecommendation = nil
                    isSubmitting = false
                    isSuccess = true
                    statusMessage = "Goal saved. Keep up the great work!"
                    
                    // Clear success message after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            statusMessage = nil
                            isSuccess = false
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    isSuccess = false
                    statusMessage = "Could not save goal. Please try again."
                    
                    // Clear error message after 3 seconds
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        await MainActor.run {
                            statusMessage = nil
                        }
                    }
                }
                print("Error saving goal: \(error)")
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

