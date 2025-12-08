import SwiftUI

struct AddWorkoutsView: View {
    @ObservedObject var viewModel: WorkoutsViewModel
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    HStack(spacing: 8) {
                        Picker("", selection: $viewModel.selectedActivityID) {
                            ForEach(viewModel.activities) { activity in
                                Text(activity.name).tag(activity.id)
                            }
                        }
                        .pickerStyle(.menu)

                        if let categories = viewModel.selectedActivity?.categories {
                            Picker("", selection: $viewModel.selectedCategoryID) {
                                ForEach(categories) { category in
                                    Text(category.name).tag(category.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .disabled(categories.isEmpty)
                        }
                    }
                }

                Section("Details") {
                    HStack(spacing: 12) {
                        TextField("Duration (min)", text: $viewModel.duration)
                            .keyboardType(.decimalPad)
                            .focused($isFieldFocused)
                        TextField("Calories", text: $viewModel.calories)
                            .keyboardType(.decimalPad)
                            .focused($isFieldFocused)
                    }

                    DatePicker(
                        "Time",
                        selection: $viewModel.workoutDate,
                        displayedComponents: [.hourAndMinute]
                    )

                    DatePicker(
                        "Date", selection: $viewModel.workoutDate, displayedComponents: [.date])
                }

                if let parameters = viewModel.selectedCategory?.parameters, !parameters.isEmpty {
                    Section("Activity Parameters") {
                        ForEach(parameters) { parameter in
                            ParameterInput(
                                parameter: parameter,
                                value: viewModel.binding(for: parameter),
                                focusBinding: $isFieldFocused
                            )
                        }
                    }
                }

                Section {
                    Button {
                        onSubmit()
                    } label: {
                        Label("Save Workout", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.makeWorkoutItem() == nil)
                }
            }
            .navigationTitle("Log Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSubmit)
                        .disabled(viewModel.makeWorkoutItem() == nil)
                }
            }
        }
    }
}

private struct ParameterInput: View {
    let parameter: WorkoutParameterDefinition
    let value: Binding<String>
    let focusBinding: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(parameter.name)
                    .font(.subheadline)
                if parameter.required {
                    Text("Required")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            switch parameter.kind {
            case .number(let unit):
                parameterTextField(unit: unit)
                    .keyboardType(.decimalPad)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            case .text(let unit):
                parameterTextField(unit: unit)
            case .options(let options):
                Picker(parameter.name, selection: value) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private func parameterTextField(unit: String) -> some View {
        TextField(parameter.placeholder, text: value)
            .textFieldStyle(.roundedBorder)
            .focused(focusBinding)
            .overlay(alignment: .trailing) {
                if !unit.isEmpty {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 8)
                }
            }
    }
}
