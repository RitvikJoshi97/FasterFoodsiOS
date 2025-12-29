import SwiftUI

struct AddShoppingItemSheet: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var toastService: ToastService
    @Environment(\.dismiss) private var dismiss
    @State private var newItemName: String = ""
    @State private var newItemQuantity: String = ""
    @State private var newItemUnit: String = ""
    @State private var selectedListId: String = ""
    @State private var newListName: String = ""
    @State private var isLoading: Bool = false
    @State private var isAddingItem: Bool = false
    @State private var showNewListField: Bool = false
    @State private var alertMessage: String?
    @State private var isScannerPresented = false
    @FocusState private var focusedField: Field?

    private let commonUnits = [
        "pieces", "lbs", "kg", "oz", "g", "pints", "liters", "cups", "tbsp", "tsp",
        "loaves", "containers", "bottles", "cans", "bags", "boxes",
    ]

    private let newListSentinel = "__new_list__"

    private enum Field: Hashable {
        case itemName, quantity, unit, newListName
    }

    private var unitSelection: Binding<String> {
        Binding {
            let trimmed = newItemUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? (commonUnits.first ?? "") : trimmed
        } set: { newValue in
            newItemUnit = newValue
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }

    private var canAddItem: Bool {
        let hasItem = !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if showNewListField || selectedListId == newListSentinel {
            return hasItem && !newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if app.shoppingLists.isEmpty {
            return hasItem
        }
        return hasItem && !selectedListId.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    HStack(spacing: 8) {
                        TextField("Item name", text: $newItemName)
                            .focused($focusedField, equals: .itemName)

                        Button {
                            isScannerPresented = true
                        } label: {
                            Image(systemName: "barcode.viewfinder")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Scan item")
                    }

                    HStack {
                        TextField("Quantity", text: $newItemQuantity)
                            .keyboardType(.numbersAndPunctuation)
                            .focused($focusedField, equals: .quantity)
                        Picker("Unit", selection: unitSelection) {
                            ForEach(commonUnits, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("List") {
                    if app.shoppingLists.isEmpty {
                        Text("Default")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("List", selection: $selectedListId) {
                            ForEach(app.shoppingLists) { list in
                                Text(list.name).tag(list.id)
                            }
                            Label("Add new list", systemImage: "plus")
                                .tag(newListSentinel)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedListId) { oldValue, newValue in
                            if newValue == newListSentinel {
                                withAnimation { showNewListField = true }
                                focusedField = .newListName
                            } else {
                                if showNewListField {
                                    withAnimation { showNewListField = false }
                                }
                                newListName = ""
                            }
                        }
                    }

                    if showNewListField {
                        TextField("New list name", text: $newListName)
                            .focused($focusedField, equals: .newListName)
                    }
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
                    .disabled(!canAddItem || isAddingItem)
                }
            }
            .navigationTitle("Add Shopping Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if app.shoppingLists.isEmpty {
                    try? await app.loadShoppingLists()
                }
                if selectedListId.isEmpty, let firstId = app.shoppingLists.first?.id {
                    selectedListId = firstId
                }
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
            .sheet(isPresented: $isScannerPresented) {
                ScannerView { scannedProduct in
                    applyScan(scannedProduct)
                }
            }
        }
    }

    @MainActor
    private func addItem() async {
        guard canAddItem else { return }
        if isAddingItem { return }
        isAddingItem = true
        defer { isAddingItem = false }
        do {
            var targetListId = selectedListId

            if app.shoppingLists.isEmpty {
                let list = try await app.createShoppingList(name: "Default")
                targetListId = list.id
                selectedListId = list.id
            } else if showNewListField {
                let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let list = try await app.createShoppingList(name: trimmed)
                targetListId = list.id
                selectedListId = list.id
                newListName = ""
                withAnimation { showNewListField = false }
            } else if targetListId.isEmpty, let fallback = app.shoppingLists.first?.id {
                targetListId = fallback
                selectedListId = fallback
            }

            guard !targetListId.isEmpty && targetListId != newListSentinel else { return }

            try await app.addShoppingItem(
                to: targetListId,
                name: newItemName,
                quantity: newItemQuantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : newItemQuantity,
                unit: newItemUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? nil : newItemUnit,
                listLabel: nil
            )
            toastService.show("Shopping item added")
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
            toastService.show("Could not add shopping item.", style: .error)
        }
    }

    private func applyScan(_ product: ScannedProductInfo) {
        newItemName = product.name
        if let quantity = preferredQuantity(for: product) {
            newItemQuantity = formatQuantity(quantity)
        }
        if let unit = preferredUnit(for: product) {
            newItemUnit = unit
        }
    }

    private func preferredQuantity(for product: ScannedProductInfo) -> Double? {
        if let quantity = product.productQuantity, quantity > 0 {
            return quantity
        }
        if let quantity = product.servingQuantity, quantity > 0 {
            return quantity
        }
        return nil
    }

    private func preferredUnit(for product: ScannedProductInfo) -> String? {
        let unit = product.productQuantityUnit ?? product.servingQuantityUnit
        let trimmed = unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func formatQuantity(_ value: Double) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.0001 {
            return String(Int(rounded))
        }
        return String(format: "%.2f", value)
    }
}
