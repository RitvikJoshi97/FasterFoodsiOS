import SwiftUI

struct AddFoodLogItemSheet: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var toastService: ToastService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FoodLogViewModel()
    @State private var mealDate = Date()
    @State private var isSubmitting = false
    @State private var alertMessage: String?
    private enum FocusedField: Hashable {
        case itemName
        case ingredientQuantity(Int)
    }

    @FocusState private var focusedField: FocusedField?
    @State private var ingredientEntries: [IngredientEntry] = [IngredientEntry()]
    @State private var isScannerPresented = false
    @State private var scannerTargetIndex: Int?
    @State private var mealScanInfo: ScannedProductInfo?
    @State private var manualMacros = MacroTotals()
    @State private var isUpdatingMacros = false
    @State private var friendSearch = ""
    @State private var selectedFriends = Set<String>()
    @State private var revealedFriend: String?
    @State private var isAddFriendPresented = false

    private let mealTimeOptions = FoodLogViewModel.MealTime.allCases
    private let portionOptions = FoodLogViewModel.PortionSize.allCases
    private let moodOptions = FoodLogViewModel.Mood.allCases
    private let categoryOptions = FoodLogViewModel.MealCategory.allCases
    private let friendOptions = ["Shreshtha", "Steven", "Kartik", "Chitra"]
    private let commonUnits = [
        "g", "pieces", "lbs", "kg", "oz", "ml", "l", "pints", "liters", "cups", "tbsp", "tsp",
        "loaves", "containers", "bottles", "cans", "bags", "boxes",
    ]

    private struct IngredientEntry: Identifiable {
        let id = UUID()
        var name = ""
        var quantity = ""
        var unit = ""
        var scanInfo: ScannedProductInfo?
        var appliedRecommendedMacros: MacroTotals?
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

    private var splitCount: Double {
        Double(max(selectedFriends.count + 1, 1))
    }

    private var filteredFriends: [String] {
        let trimmed = friendSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return friendOptions.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal Details") {
                    HStack(spacing: 8) {
                        TextField("What did you eat?", text: $viewModel.itemName)
                            .textInputAutocapitalization(.sentences)
                            .focused($focusedField, equals: .itemName)

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
                        HStack {
                            Text("Calories (kcal)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", text: $viewModel.calories)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 80)
                                .onChange(of: viewModel.calories) { _, newValue in
                                    updateManualMacro(newValue, field: .calories)
                                }
                        }
                        HStack {
                            Text("Carbohydrates (g)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", text: $viewModel.carbohydrates)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 80)
                                .onChange(of: viewModel.carbohydrates) { _, newValue in
                                    updateManualMacro(newValue, field: .carbohydrates)
                                }
                        }
                        HStack {
                            Text("Protein (g)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", text: $viewModel.protein)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 80)
                                .onChange(of: viewModel.protein) { _, newValue in
                                    updateManualMacro(newValue, field: .protein)
                                }
                        }
                        HStack {
                            Text("Fat (g)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", text: $viewModel.fat)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 80)
                                .onChange(of: viewModel.fat) { _, newValue in
                                    updateManualMacro(newValue, field: .fat)
                                }
                        }

                        HStack {
                            Text("Meal focus")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Picker("", selection: $viewModel.mealCategory) {
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
                                    let hadApplied =
                                        ingredientEntries[index].appliedRecommendedMacros != nil
                                    ingredientEntries[index].appliedRecommendedMacros = nil
                                    if trimmed.isEmpty {
                                        ingredientEntries[index].scanInfo = nil
                                        recalculateMacros()
                                    } else if hadApplied {
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
                                        .focused(
                                            $focusedField,
                                            equals: .ingredientQuantity(index)
                                        )
                                        .onChange(
                                            of: ingredientEntries[index].quantity
                                        ) { _, _ in
                                            if ingredientEntries[index].appliedRecommendedMacros
                                                != nil
                                            {
                                                ingredientEntries[index].appliedRecommendedMacros =
                                                    nil
                                            }
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
                                    if let totals = ingredientScannedMacros(
                                        for: ingredientEntries[index]
                                    ) {
                                        HStack(spacing: 12) {
                                            if totals.calories > 0 {
                                                Text(
                                                    "Calories: \(formatMacroValue(totals.calories, decimals: 0))"
                                                )
                                                .font(.caption)
                                            }
                                            if totals.carbohydrates > 0 {
                                                Text(
                                                    "C: \(formatMacroValue(totals.carbohydrates, decimals: 1))"
                                                )
                                                .font(.caption)
                                            }
                                            if totals.protein > 0 {
                                                Text(
                                                    "P: \(formatMacroValue(totals.protein, decimals: 1))"
                                                )
                                                .font(.caption)
                                            }
                                            if totals.fat > 0 {
                                                Text(
                                                    "F: \(formatMacroValue(totals.fat, decimals: 1))"
                                                )
                                                .font(.caption)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if let appliedTotals =
                                        ingredientEntries[index].appliedRecommendedMacros
                                    {
                                        HStack(spacing: 12) {
                                            if appliedTotals.calories > 0 {
                                                Text(
                                                    "Calories: \(formatMacroValue(appliedTotals.calories, decimals: 0))"
                                                )
                                                .font(.caption)
                                            }
                                            if appliedTotals.carbohydrates > 0 {
                                                Text(
                                                    "C: \(formatMacroValue(appliedTotals.carbohydrates, decimals: 1))"
                                                )
                                                .font(.caption)
                                            }
                                            if appliedTotals.protein > 0 {
                                                Text(
                                                    "P: \(formatMacroValue(appliedTotals.protein, decimals: 1))"
                                                )
                                                .font(.caption)
                                            }
                                            if appliedTotals.fat > 0 {
                                                Text(
                                                    "F: \(formatMacroValue(appliedTotals.fat, decimals: 1))"
                                                )
                                                .font(.caption)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    } else if let suggestedTotals = ingredientSuggestedMacros(
                                        for: ingredientEntries[index]
                                    ) {
                                        HStack(spacing: 12) {
                                            HStack(spacing: 12) {
                                                if suggestedTotals.calories > 0 {
                                                    Text(
                                                        "Calories: \(formatMacroValue(suggestedTotals.calories, decimals: 0))"
                                                    )
                                                    .font(.caption)
                                                }
                                                if suggestedTotals.carbohydrates > 0 {
                                                    Text(
                                                        "C: \(formatMacroValue(suggestedTotals.carbohydrates, decimals: 1))"
                                                    )
                                                    .font(.caption)
                                                }
                                                if suggestedTotals.protein > 0 {
                                                    Text(
                                                        "P: \(formatMacroValue(suggestedTotals.protein, decimals: 1))"
                                                    )
                                                    .font(.caption)
                                                }
                                                if suggestedTotals.fat > 0 {
                                                    Text(
                                                        "F: \(formatMacroValue(suggestedTotals.fat, decimals: 1))"
                                                    )
                                                    .font(.caption)
                                                }
                                            }
                                            Spacer()
                                            Button("Use") {
                                                applySuggestedMacros(suggestedTotals, index: index)
                                            }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.accentColor)
                                            .clipShape(Capsule())
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    Divider()
                                }
                            }
                        }
                        .listRowSeparator(.hidden)
                    }
                }

                Section("Split with") {
                    if !selectedFriends.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedFriends.sorted(), id: \.self) { friend in
                                    HStack(spacing: 6) {
                                        Text(friend)
                                            .font(.footnote)
                                        if revealedFriend == friend {
                                            Button {
                                                selectedFriends.remove(friend)
                                                revealedFriend = nil
                                                recalculateMacros()
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption2)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.15))
                                    .clipShape(Capsule())
                                    .contentShape(Capsule())
                                    .onTapGesture {
                                        revealedFriend = (revealedFriend == friend) ? nil : friend
                                    }
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Search friend", text: $friendSearch)
                        Button {
                            isAddFriendPresented = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add friend")
                    }

                    if friendSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EmptyView()
                    } else if filteredFriends.isEmpty {
                        Text("No matches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredFriends, id: \.self) { friend in
                            Button {
                                if selectedFriends.contains(friend) {
                                    selectedFriends.remove(friend)
                                } else {
                                    selectedFriends.insert(friend)
                                }
                                recalculateMacros()
                            } label: {
                                HStack {
                                    Text(friend)
                                    Spacer()
                                    if selectedFriends.contains(friend) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
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
                    focusedField = .itemName
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
            .sheet(isPresented: $isAddFriendPresented) {
                AddFriendSheet()
                    .presentationDetents([.medium, .large])
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
            return trimmed.isEmpty ? "g" : trimmed
        } set: { newValue in
            ingredientEntries[index].unit = newValue
            ingredientEntries[index].appliedRecommendedMacros = nil
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
        DispatchQueue.main.async {
            focusedField = .ingredientQuantity(index)
        }
    }

    private func applyMealScan(_ product: ScannedProductInfo) {
        viewModel.itemName = product.name
        mealScanInfo = product
        recalculateMacros()
    }

    private func updateManualMacro(_ newValue: String, field: MacroField) {
        guard !isUpdatingMacros else { return }
        let scannedTotals = scannedMacroTotals()
        let entered = parseDouble(newValue) * splitCount
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
        preserveTrailingDecimalInput(newValue, field: field)
    }

    private func recalculateMacros() {
        applyMacroTotals(scannedMacroTotals())
    }

    private func applyMacroTotals(_ scannedTotals: MacroTotals) {
        var totals = manualMacros
        totals.add(scannedTotals)
        let split = splitCount
        totals.calories /= split
        totals.carbohydrates /= split
        totals.protein /= split
        totals.fat /= split
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
            if let appliedTotals = entry.appliedRecommendedMacros {
                totals.add(appliedTotals)
                continue
            }
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

    private func ingredientSuggestedMacros(for entry: IngredientEntry) -> MacroTotals? {
        guard entry.appliedRecommendedMacros == nil else { return nil }
        let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let quantityValue = parseDouble(entry.quantity)
        guard quantityValue > 0 else { return nil }
        if ingredientScannedMacros(for: entry) != nil { return nil }
        let unit = entry.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUnit: String
        if unit.isEmpty {
            if let info = entry.scanInfo, let preferred = preferredUnit(for: info) {
                resolvedUnit = preferred
            } else {
                resolvedUnit = "g"
            }
        } else {
            resolvedUnit = unit
        }
        guard let grams = quantityInGrams(quantityValue, unit: resolvedUnit) else { return nil }
        return dummySuggestedMacros(for: grams)
    }

    private func ingredientScannedMacros(for entry: IngredientEntry) -> MacroTotals? {
        guard let info = entry.scanInfo, let nutriments = info.nutriments else { return nil }
        let quantityValue = parseDouble(entry.quantity)
        guard quantityValue > 0 else { return nil }
        let unit = entry.unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedUnit = unit.isEmpty ? preferredUnit(for: info) : unit
        guard let grams = quantityInGrams(quantityValue, unit: resolvedUnit) else { return nil }
        let totals = macros(from: nutriments, grams: grams)
        guard
            totals.calories > 0 || totals.protein > 0 || totals.fat > 0 || totals.carbohydrates > 0
        else {
            return nil
        }
        return totals
    }

    private func dummySuggestedMacros(for grams: Double) -> MacroTotals? {
        guard grams > 0 else { return nil }
        let per100g = MacroTotals(
            calories: 261,
            protein: 3,
            fat: 15,
            carbohydrates: 27
        )
        let multiplier = grams / 100.0
        let totals = MacroTotals(
            calories: per100g.calories * multiplier,
            protein: per100g.protein * multiplier,
            fat: per100g.fat * multiplier,
            carbohydrates: per100g.carbohydrates * multiplier
        )
        guard
            totals.calories > 0 || totals.protein > 0 || totals.fat > 0 || totals.carbohydrates > 0
        else {
            return nil
        }
        return totals
    }

    private func applySuggestedMacros(_ totals: MacroTotals, index: Int) {
        ingredientEntries[index].appliedRecommendedMacros = totals
        recalculateMacros()
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
        var formatted = String(format: "%.\(decimals)f", value)
        if decimals > 0, formatted.contains(".") {
            formatted = formatted.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            formatted = formatted.hasSuffix(".") ? String(formatted.dropLast()) : formatted
        }
        return formatted
    }

    private func preserveTrailingDecimalInput(_ rawValue: String, field: MacroField) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(".") else { return }
        isUpdatingMacros = true
        switch field {
        case .calories:
            viewModel.calories = trimmed
        case .protein:
            viewModel.protein = trimmed
        case .fat:
            viewModel.fat = trimmed
        case .carbohydrates:
            viewModel.carbohydrates = trimmed
        }
        isUpdatingMacros = false
    }

    private func formatQuantityValue(_ value: Double) -> String {
        guard value > 0 else { return "" }
        if value == floor(value) {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    private func parseDouble(_ text: String?) -> Double {
        guard let raw = text, !raw.isEmpty else { return 0 }
        let allowedCharacters = CharacterSet(charactersIn: "0123456789.")
        let filtered = raw.unicodeScalars.filter { allowedCharacters.contains($0) }
        return Double(String(filtered)) ?? 0
    }

    private func ingredientRequests() -> [FoodLogIngredientCreateRequest] {
        ingredientEntries.compactMap { entry in
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let quantity = entry.quantity.trimmingCharacters(in: .whitespacesAndNewlines)
            let quantityValue = parseDouble(quantity)
            let adjustedQuantity: String?
            if quantity.isEmpty {
                adjustedQuantity = nil
            } else if quantityValue > 0, splitCount > 1 {
                adjustedQuantity = formatQuantityValue(quantityValue / splitCount)
            } else {
                adjustedQuantity = quantity
            }
            let unit = entry.unit.trimmingCharacters(in: .whitespacesAndNewlines)
            let barcodeString =
                entry.scanInfo?.barcode.trimmingCharacters(in: .whitespacesAndNewlines)
            let barcode = barcodeString.flatMap { Int64($0) }
            return FoodLogIngredientCreateRequest(
                barcode: barcode,
                itemName: name,
                quantity: adjustedQuantity,
                unit: unit.isEmpty ? nil : unit
            )
        }
    }

    private func logMeal() {
        guard viewModel.canLogEntry else { return }
        isSubmitting = true
        let request = viewModel.request(for: app.foodLoggingLevel, date: mealDate)
        Task { @MainActor in
            do {
                let item = try await app.addFoodLogItem(request)
                let ingredients = ingredientRequests()
                var ingredientsFailed = false
                if !ingredients.isEmpty {
                    do {
                        try await app.addFoodLogItemIngredients(
                            itemId: item.id, ingredients: ingredients)
                    } catch {
                        ingredientsFailed = true
                    }
                }
                if ingredientsFailed {
                    toastService.show(
                        "Saved meal, but ingredients did not save.", style: .error)
                } else {
                    toastService.show("Food log saved")
                }
                dismiss()
            } catch {
                alertMessage = error.localizedDescription
                toastService.show("Could not save food log.", style: .error)
            }
            isSubmitting = false
        }
    }
}
