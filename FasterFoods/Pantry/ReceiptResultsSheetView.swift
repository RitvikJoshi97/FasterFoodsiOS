import SwiftUI

struct ReceiptResultsSheetView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var toastService: ToastService
    let result: ReceiptScanResult
    @State private var items: [ReceiptScanItem]
    @State private var isEditing = false
    @State private var editingItemID: UUID?
    @State private var editingText = ""
    @State private var isAdding = false

    init(result: ReceiptScanResult) {
        self.result = result
        _items = State(initialValue: result.items)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.store)
                                .font(.headline)
                            Text(receiptDateText())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("Processed \(result.processingDate)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Items") {
                    ForEach(items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(.headline)
                                Text(item.estimatedName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            let actionColor = Color.accentColor
                            Button {
                                print("Delete receipt item: \(item.name)")
                                deleteItem(item)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .tint(actionColor)

                            Button {
                                beginEdit(item)
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .tint(actionColor)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Receipt Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await addItemsToPantry() }
                    } label: {
                        if isAdding {
                            ProgressView()
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(items.isEmpty || isAdding)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .alert("Edit item", isPresented: $isEditing) {
            TextField("Estimated name", text: $editingText)
            Button("Save") { applyEdit() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Update the estimated name.")
        }
    }

    private func receiptDateText() -> String {
        let trimmed = result.dateOnReceipt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Receipt date unavailable" : "Receipt date: \(trimmed)"
    }

    private func beginEdit(_ item: ReceiptScanItem) {
        editingItemID = item.id
        editingText = item.estimatedName
        isEditing = true
    }

    private func applyEdit() {
        guard let editingItemID else { return }
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let index = items.firstIndex(where: { $0.id == editingItemID })
        else {
            isEditing = false
            return
        }
        items[index].estimatedName = trimmed
        isEditing = false
    }

    private func deleteItem(_ item: ReceiptScanItem) {
        items.removeAll { $0.id == item.id }
    }

    private func addItemsToPantry() async {
        guard !items.isEmpty else { return }
        isAdding = true
        defer { isAdding = false }

        var addedCount = 0
        for item in items {
            let trimmed = item.estimatedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            do {
                _ = try await app.addPantryItem(
                    name: trimmed, quantity: nil, unit: nil, expiryDate: nil
                )
                addedCount += 1
            } catch {
                toastService.show("Could not add \(trimmed).", style: .error)
            }
        }

        if addedCount > 0 {
            toastService.show("Added \(addedCount) items")
        }
    }
}
