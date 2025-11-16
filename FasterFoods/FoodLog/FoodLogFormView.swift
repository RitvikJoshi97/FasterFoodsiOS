import SwiftUI

struct FoodLogFormView: View {
    @ObservedObject var viewModel: FoodLogViewModel
    let loggingLevel: FoodLoggingLevel
    @Binding var mealDate: Date
    var isSubmitting: Bool
    var onSubmit: () -> Void

    private let mealTimeOptions = FoodLogViewModel.MealTime.allCases
    private let portionOptions = FoodLogViewModel.PortionSize.allCases
    private let moodOptions = FoodLogViewModel.Mood.allCases
    private let categoryOptions = FoodLogViewModel.MealCategory.allCases

    var body: some View {
        VStack(spacing: 16) {
            TextField("What did you eat?", text: $viewModel.itemName)
                .textInputAutocapitalization(.sentences)

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

            if loggingLevel == .beginner || loggingLevel == .intermediate || loggingLevel == .advanced {
                portionSelector
                moodSelector
            }

            if loggingLevel != .beginner {
                macroFields
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

            if loggingLevel == .advanced {
                advancedSection
            }

            Button(action: onSubmit) {
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
        .onAppear {
            viewModel.adjustMealTime(basedOn: mealDate)
        }
    }

    private func hour(for option: FoodLogViewModel.MealTime) -> Int {
        switch option {
        case .morning: return 8
        case .afternoon: return 13
        case .evening: return 19
        }
    }

    private var portionSelector: some View {
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
    }

    private var moodSelector: some View {
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

    private var macroFields: some View {
        VStack(spacing: 10) {
            TextField("Calories (kcal)", text: $viewModel.calories)
                .keyboardType(.numberPad)
            TextField("Protein (g)", text: $viewModel.protein)
                .keyboardType(.decimalPad)
            TextField("Fat (g)", text: $viewModel.fat)
                .keyboardType(.decimalPad)
        }
    }


    private var advancedSection: some View {
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
