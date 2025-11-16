import SwiftUI

struct AddFoodLogItemSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodLogViewModel()
    @State private var mealDate = Date()
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @FocusState private var isItemNameFocused: Bool
    
    private let mealTimeOptions = FoodLogViewModel.MealTime.allCases
    private let portionOptions = FoodLogViewModel.PortionSize.allCases
    private let moodOptions = FoodLogViewModel.Mood.allCases
    private let categoryOptions = FoodLogViewModel.MealCategory.allCases
    
    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Details") {
                    TextField("What did you eat?", text: $viewModel.itemName)
                        .textInputAutocapitalization(.sentences)
                        .focused($isItemNameFocused)
                    
                    HStack(spacing: 12) {
                        Picker("", selection: $viewModel.mealTime) {
                            ForEach(mealTimeOptions) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: viewModel.mealTime) { oldValue, newValue in
                            if let adjusted = Calendar.current.date(bySettingHour: hour(for: newValue), minute: 0, second: 0, of: mealDate) {
                                mealDate = adjusted
                            }
                        }
                        DatePicker("", selection: $mealDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .onChange(of: mealDate) { oldValue, newValue in
                                viewModel.adjustMealTime(basedOn: newValue)
                            }
                    }
                    
                    if app.foodLoggingLevel == .beginner || app.foodLoggingLevel == .intermediate || app.foodLoggingLevel == .advanced {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Portion size")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Picker("Portion size", selection: $viewModel.portionSize) {
                                ForEach(portionOptions) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How was the meal?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Picker("How was the meal?", selection: $viewModel.mood) {
                                ForEach(moodOptions) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    
                    if app.foodLoggingLevel != .beginner {
                        TextField("Calories (kcal)", text: $viewModel.calories)
                            .keyboardType(.numberPad)
                        TextField("Protein (g)", text: $viewModel.protein)
                            .keyboardType(.decimalPad)
                        TextField("Fat (g)", text: $viewModel.fat)
                            .keyboardType(.decimalPad)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal focus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Picker("Meal focus", selection: $viewModel.mealCategory) {
                                ForEach(categoryOptions) { category in
                                    Text(category.rawValue).tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                    
                    if app.foodLoggingLevel == .advanced {
                        DisclosureGroup("Advanced tracking") {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Hunger–Fullness Continuum")
                                        .font(.subheadline)
                                    Slider(value: $viewModel.hungerFullness, in: 0...10, step: 1) {
                                        Text("Hunger")
                                    }
                                    .tint(.accentColor)
                                    Text("Current level: \(Int(viewModel.hungerFullness))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                TextField("Hydration notes", text: $viewModel.hydration)
                                TextField("Digestive feedback", text: $viewModel.digestionFeedback)
                                TextField("Energy changes", text: $viewModel.energyChanges)
                                TextField("Mind–body connection", text: $viewModel.mindBodyConnection)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                
                Section {
                    Button {
                        logMeal()
                    } label: {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Log Food", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canLogEntry || isSubmitting)
                }
            }
            .navigationTitle("Add Food Log Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel.adjustMealTime(basedOn: mealDate)
            }
            .task {
                // Focus the first field and show keyboard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isItemNameFocused = true
                }
            }
            .alert("Something went wrong", isPresented: alertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "Please try again later.")
            }
        }
    }
    
    private func hour(for option: FoodLogViewModel.MealTime) -> Int {
        switch option {
        case .morning: return 8
        case .afternoon: return 13
        case .evening: return 19
        }
    }
    
    private func logMeal() {
        guard viewModel.canLogEntry else { return }
        isSubmitting = true
        let request = viewModel.request(for: app.foodLoggingLevel, date: mealDate)
        Task { @MainActor in
            do {
                _ = try await app.addFoodLogItem(request)
                dismiss()
            } catch {
                alertMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

