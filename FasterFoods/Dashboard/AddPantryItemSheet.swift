import SwiftUI

struct AddPantryItemSheet: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var newItemName: String = ""
    @State private var newQuantity: String = ""
    @State private var newUnit: String = "pieces"
    @State private var expiryText: String = ""
    @State private var isAddingItem: Bool = false
    @State private var alertMessage: String?
    @FocusState private var focusedField: Field?
    
    private enum Field: Hashable { case name, quantity, unit, expiry }
    
    private let commonUnits = [
        "pieces", "lbs", "kg", "oz", "g", "pints", "liters", "cups", "tbsp", "tsp",
        "loaves", "containers", "bottles", "cans", "bags", "boxes"
    ]
    
    private var unitTagBinding: Binding<String> {
        Binding {
            newUnit.isEmpty ? commonUnits.first ?? "pieces" : newUnit
        } set: { newUnit = $0.isEmpty ? (commonUnits.first ?? "pieces") : $0 }
    }
    
    private let inputDateFormatters: [DateFormatter] = {
        let iso = DateFormatter()
        iso.dateFormat = "yyyy-MM-dd"
        iso.timeZone = TimeZone(secondsFromGMT: 0)
        let alt = DateFormatter()
        alt.dateFormat = "dd/MM/yyyy"
        alt.timeZone = TimeZone(secondsFromGMT: 0)
        return [iso, alt]
    }()
    
    private let isoFormatterBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
    
    private var alertBinding: Binding<Bool> {
        Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
    }
    
    private var canAddItem: Bool {
        !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Item name", text: $newItemName)
                        .focused($focusedField, equals: .name)
                    
                    HStack {
                        TextField("Quantity", text: $newQuantity)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($focusedField, equals: .quantity)
                        Picker("Unit", selection: unitTagBinding) {
                            ForEach(commonUnits, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    TextField("Expiry date (optional)", text: $expiryText)
                        .focused($focusedField, equals: .expiry)
                }
                
                Section {
                    Button {
                        HapticSoundPlayer.shared.playPrimaryTap()
                        Task { await addItem() }
                    } label: {
                        if isAddingItem {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Add Item", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddItem || isAddingItem)
                }
            }
            .navigationTitle("Add Pantry Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                // Focus the first field and show keyboard
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .name
                }
            }
            .alert("Something went wrong", isPresented: alertBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "Please try again later.")
            }
        }
    }
    
    private func addItem() async {
        guard canAddItem else { return }
        if isAddingItem { return }
        isAddingItem = true
        defer { isAddingItem = false }
        do {
            try await app.addPantryItem(
                name: newItemName,
                quantity: newQuantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newQuantity,
                unit: newUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newUnit,
                expiryDate: normalizedExpiryString()
            )
            await MainActor.run {
                dismiss()
            }
        } catch {
            await MainActor.run {
                alertMessage = error.localizedDescription
            }
        }
    }
    
    private func normalizedExpiryString() -> String? {
        let trimmed = expiryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in inputDateFormatters {
            if let date = formatter.date(from: trimmed) {
                return isoFormatterBasic.string(from: date)
            }
        }
        return trimmed
    }
}
