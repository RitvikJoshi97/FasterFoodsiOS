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
    @State private var mealScanInfo: ScannedProductInfo?
    @State private var manualMacros = MacroTotals()
    @State private var isUpdatingMacros = false

    private let mealTimeOptions = FoodLogViewModel.MealTime.allCases
    private let portionOptions = FoodLogViewModel.PortionSize.allCases
    private let moodOptions = FoodLogViewModel.Mood.allCases
    private let categoryOptions = FoodLogViewModel.MealCategory.allCases
    private let commonUnits = [
        "pieces", "lbs", "kg", "oz", "g", "ml", "l", "pints", "liters", "cups", "tbsp", "tsp",
        "loaves", "containers", "bottles", "cans", "bags", "boxes",
    ]

    private struct IngredientEntry: Identifiable {
        let id = UUID()
        var name = ""
        var quantity = ""
        var unit = ""
        var scanInfo: ScannedProductInfo?
    }

    private struct MacroTotals: Equatable {
        var calories: Double = 0
        var protein: Double = 0
        var fat: Double = 0
        var carbohydrates: Double = 0

        mutating func add(_ other: MacroTotals) {
            calories += other.calories
            protein += other.protein
            fat += other.fat
            carbohydrates += other.carbohydrates
        }
    }

    private enum MacroField {
        case calories
        case protein
        case fat
        case carbohydrates
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
                            .onChange(of: viewModel.calories) { _, newValue in
                                updateManualMacro(newValue, field: .calories)
                            }
                        TextField("Carbohydrates (g)", text: $viewModel.carbohydrates)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.carbohydrates) { _, newValue in
                                updateManualMacro(newValue, field: .carbohydrates)
                            }
                        TextField("Protein (g)", text: $viewModel.protein)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.protein) { _, newValue in
                                updateManualMacro(newValue, field: .protein)
                            }
                        TextField("Fat (g)", text: $viewModel.fat)
                            .keyboardType(.decimalPad)
                            .onChange(of: viewModel.fat) { _, newValue in
                                updateManualMacro(newValue, field: .fat)
                            }

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
                                    if trimmed.isEmpty {
                                        ingredientEntries[index].scanInfo = nil
                                        recalculateMacros()
                                    }
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
                                        .onChange(
                                            of: ingredientEntries[index].quantity
                                        ) { _, _ in
                                            recalculateMacros()
                                        }
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
                manualMacros = MacroTotals(
                    calories: parseDouble(viewModel.calories),
                    protein: parseDouble(viewModel.protein),
                    fat: parseDouble(viewModel.fat),
                    carbohydrates: parseDouble(viewModel.carbohydrates)
                )
                recalculateMacros()
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
                ScannerView { scannedProduct in
                    if let index = scannerTargetIndex, ingredientEntries.indices.contains(index) {
                        applyIngredientScan(scannedProduct, index: index)
                    } else {
                        applyMealScan(scannedProduct)
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
            recalculateMacros()
        }
    }

    private func applyIngredientScan(_ product: ScannedProductInfo, index: Int) {
        ingredientEntries[index].name = product.name
        ingredientEntries[index].scanInfo = product
        if let unit = preferredUnit(for: product) {
            ingredientEntries[index].unit = unit
        }
        recalculateMacros()
    }

    private func applyMealScan(_ product: ScannedProductInfo) {
        viewModel.itemName = product.name
        mealScanInfo = product
        recalculateMacros()
    }

    private func updateManualMacro(_ newValue: String, field: MacroField) {
        guard !isUpdatingMacros else { return }
        let scannedTotals = scannedMacroTotals()
        let entered = parseDouble(newValue)
        switch field {
        case .calories:
            manualMacros.calories = max(entered - scannedTotals.calories, 0)
        case .protein:
            manualMacros.protein = max(entered - scannedTotals.protein, 0)
        case .fat:
            manualMacros.fat = max(entered - scannedTotals.fat, 0)
        case .carbohydrates:
            manualMacros.carbohydrates = max(entered - scannedTotals.carbohydrates, 0)
        }
        applyMacroTotals(scannedTotals)
    }

    private func recalculateMacros() {
        applyMacroTotals(scannedMacroTotals())
    }

    private func applyMacroTotals(_ scannedTotals: MacroTotals) {
        var totals = manualMacros
        totals.add(scannedTotals)
        isUpdatingMacros = true
        viewModel.calories = formatMacroValue(totals.calories, decimals: 0)
        viewModel.carbohydrates = formatMacroValue(totals.carbohydrates, decimals: 1)
        viewModel.protein = formatMacroValue(totals.protein, decimals: 1)
        viewModel.fat = formatMacroValue(totals.fat, decimals: 1)
        isUpdatingMacros = false
    }

    private func scannedMacroTotals() -> MacroTotals {
        var totals = MacroTotals()

        if let mealScanInfo, let nutriments = mealScanInfo.nutriments {
            if let quantity = servingQuantityInGrams(for: mealScanInfo) {
                totals.add(macros(from: nutriments, grams: quantity))
            }
        }

        for entry in ingredientEntries {
            guard let info = entry.scanInfo, let nutriments = info.nutriments else { continue }
            let quantityValue = parseDouble(entry.quantity)
            guard quantityValue > 0 else { continue }
            let unit = entry.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedUnit = unit.isEmpty ? preferredUnit(for: info) : unit
            guard let grams = quantityInGrams(quantityValue, unit: resolvedUnit) else {
                continue
            }
            totals.add(macros(from: nutriments, grams: grams))
        }

        return totals
    }

    private func servingQuantityInGrams(for product: ScannedProductInfo) -> Double? {
        guard let quantity = product.servingQuantity else { return nil }
        return quantityInGrams(quantity, unit: product.servingQuantityUnit)
    }

    private func macros(from nutriments: ScannedNutriments, grams: Double) -> MacroTotals {
        let multiplier = grams / 100.0
        var totals = MacroTotals()
        if let protein = nutriments.proteins100g {
            totals.protein = protein * multiplier
        }
        if let fat = nutriments.fat100g {
            totals.fat = fat * multiplier
        }
        if let carbs = nutriments.carbohydrates100g {
            totals.carbohydrates = carbs * multiplier
        }
        if let energy = energyKilocalories(from: nutriments) {
            totals.calories = energy * multiplier
        }
        return totals
    }

    private func energyKilocalories(from nutriments: ScannedNutriments) -> Double? {
        guard let energy = nutriments.energyValue ?? nutriments.energy100g else { return nil }
        guard let unit = nutriments.energyUnit?.trimmingCharacters(in: .whitespacesAndNewlines),
            !unit.isEmpty
        else {
            return energy
        }

        switch unit.lowercased() {
        case "kj":
            return energy / 4.184
        case "kcal":
            return energy
        default:
            return energy
        }
    }

    private func quantityInGrams(_ quantity: Double, unit: String?) -> Double? {
        guard let unit = unit?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            !unit.isEmpty
        else {
            return nil
        }

        switch unit {
        case "g":
            return quantity
        case "kg":
            return quantity * 1000
        case "lb", "lbs":
            return quantity * 453.592
        case "oz":
            return quantity * 28.3495
        case "ml":
            return quantity
        case "l", "liter", "liters":
            return quantity * 1000
        default:
            return nil
        }
    }

    private func preferredUnit(for product: ScannedProductInfo) -> String? {
        let unit = product.productQuantityUnit ?? product.servingQuantityUnit
        let trimmed = unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func formatMacroValue(_ value: Double, decimals: Int) -> String {
        guard value > 0 else { return "" }
        return String(format: "%.\(decimals)f", value)
    }

    private func parseDouble(_ text: String?) -> Double {
        guard let raw = text, !raw.isEmpty else { return 0 }
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let filtered = raw.unicodeScalars.filter { allowedCharacters.contains($0) }
        return Double(String(filtered)) ?? 0
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
