import SwiftUI

struct AddCustomMetricSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = CustomMetricsViewModel()
    @State private var alertMessage: String?
    @FocusState private var isNameFocused: Bool
    
    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Metric Details") {
                    TextField("Metric name (e.g., Weight)", text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                        .focused($isNameFocused)
                    
                    HStack(spacing: 12) {
                        TextField("Value", text: $viewModel.value)
                            .keyboardType(.decimalPad)
                        TextField("Unit (e.g., lbs)", text: $viewModel.unit)
                    }
                    
                    DatePicker("Date", selection: $viewModel.date, displayedComponents: .date)
                }
                
                Section {
                    Button {
                        addMetric()
                    } label: {
                        Label("Add metric", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.makeMetric() == nil)
                }
            }
            .navigationTitle("Add Custom Metric")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Focus the first field and show keyboard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFocused = true
                }
            }
            .alert("Something went wrong", isPresented: alertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "Please try again later.")
            }
        }
    }
    
    private func addMetric() {
        guard let metric = viewModel.makeMetric() else { return }
        Task {
            do {
                try await app.addCustomMetric(metric)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = error.localizedDescription
                }
            }
        }
    }
}

