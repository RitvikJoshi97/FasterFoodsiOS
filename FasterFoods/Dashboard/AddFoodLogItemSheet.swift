import SwiftUI

struct AddFoodLogItemSheet: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var toastService: ToastService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodLogViewModel()
    @State private var mealDate = Date()
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    @FocusState private var isItemNameFocused: Bool
    @State private var ingredientEntries: [IngredientEntry] = [IngredientEntry()]
    @State private var isScannerPresented = false
    @State private var scannerTargetIndex: Int?

    private let mealTimeOptions = FoodLogViewModel.MealTime.allCases
    private let portionOptions = FoodLogViewModel.PortionSize.allCases
    private let moodOptions = FoodLogViewModel.Mood.allCases
    private let categoryOptions = FoodLogViewModel.MealCategory.allCases
    private let commonUnits = [
        "pieces", "lbs", "kg", "oz", "g", "pints", "liters", "cups", "tbsp", "tsp",
        "loaves", "containers", "bottles", "cans", "bags", "boxes",
    ]

    private struct IngredientEntry: Identifiable {
        let id = UUID()
        var name = ""
        var quantity = ""
        var unit = ""
    }

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
                    HStack(spacing: 8) {
                        TextField("What did you eat?", text: $viewModel.itemName)
                            .textInputAutocapitalization(.sentences)
                            .focused($isItemNameFocused)

                        Button {
                            scannerTargetIndex = nil
                            isScannerPresented = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Scan food")
                    }

                    HStack(spacing: 12) {
                        Picker("", selection: $viewModel.mealTime) {
                            ForEach(mealTimeOptions) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: viewModel.mealTime) { oldValue, newValue in
                            if let adjusted = Calendar.current.date(
                                bySettingHour: hour(for: newValue), minute: 0, second: 0,
                                of: mealDate)
                            {
                                mealDate = adjusted
                            }
                        }
                        DatePicker(
                            "", selection: $mealDate, displayedComponents: [.date, .hourAndMinute]
                        )
                        .labelsHidden()
                        .onChange(of: mealDate) { oldValue, newValue in
                            viewModel.adjustMealTime(basedOn: newValue)
                        }
                    }

                    if app.foodLoggingLevel == .beginner || app.foodLoggingLevel == .intermediate
                        || app.foodLoggingLevel == .advanced
                    {
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
                                TextField(
                                    "Mind–body connection", text: $viewModel.mindBodyConnection)
                            }
                            .padding(.top, 8)
                        }
                    }
                }

                Section("Ingredients") {
                    ForEach(ingredientEntries.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                TextField(
                                    "What did your meal contain?",
                                    text: $ingredientEntries[index].name
                                )
                                .onChange(of: ingredientEntries[index].name) { _, newValue in
                                    let trimmed = newValue.trimmingCharacters(
                                        in: .whitespacesAndNewlines)
                                    let isLast = index == ingredientEntries.count - 1
                                    if isLast && !trimmed.isEmpty {
                                        ingredientEntries.append(IngredientEntry())
                                    }
                                }

                                Button {
                                    scannerTargetIndex = index
                                    isScannerPresented = true
                                } label: {
                                    Image(systemName: "barcode.viewfinder")
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Scan ingredient")
                            }

                            if !ingredientEntries[index].name
                                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            {
                                VStack(spacing: 4) {
                                    HStack {
                                        TextField(
                                            "Quantity",
                                            text: $ingredientEntries[index].quantity
                                        )
                                        .keyboardType(.numbersAndPunctuation)
                                        Picker(
                                            "Unit",
                                            selection: unitSelection(for: index)
                                        ) {
                                            ForEach(commonUnits, id: \.self) { option in
                                                Text(option).tag(option)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    Divider()
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }

                Section {
                    Button {
                        HapticSoundPlayer.shared.playPrimaryTap()
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticSoundPlayer.shared.playPrimaryTap()
                        logMeal()
                    }
                    .disabled(!viewModel.canLogEntry || isSubmitting)
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
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "Please try again later.")
            }
            .sheet(
                isPresented: $isScannerPresented,
                onDismiss: {
                    scannerTargetIndex = nil
                }
            ) {
                ScannerView { scannedValue in
                    if let index = scannerTargetIndex, ingredientEntries.indices.contains(index) {
                        ingredientEntries[index].name = scannedValue
                    } else {
                        viewModel.itemName = scannedValue
                    }
                }
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

    private func unitSelection(for index: Int) -> Binding<String> {
        Binding {
            let trimmed = ingredientEntries[index]
                .unit
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? (commonUnits.first ?? "") : trimmed
        } set: { newValue in
            ingredientEntries[index].unit = newValue
        }
    }

    private func logMeal() {
        guard viewModel.canLogEntry else { return }
        isSubmitting = true
        let request = viewModel.request(for: app.foodLoggingLevel, date: mealDate)
        Task { @MainActor in
            do {
                _ = try await app.addFoodLogItem(request)
                toastService.show("Food log saved")
                dismiss()
            } catch {
                alertMessage = error.localizedDescription
                toastService.show("Could not save food log.", style: .error)
            }
            isSubmitting = false
        }
    }
}
