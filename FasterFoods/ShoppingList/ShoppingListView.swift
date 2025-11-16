import SwiftUI

struct ShoppingListView: View {
    @EnvironmentObject private var app: AppState
    @State private var newListName: String = ""
    @State private var selectedListId: String = ""
    @State private var newItemName: String = ""
    @State private var newItemQuantity: String = ""
    @State private var newItemUnit: String = ""
    @State private var isLoading: Bool = false
    @State private var didLoadOnce: Bool = false
    @State private var isCreatingList: Bool = false
    @State private var isAddingItem: Bool = false
    @State private var togglingItemIds: Set<String> = []
    @State private var deletingItemIds: Set<String> = []
    @State private var deletingListIds: Set<String> = []
    @State private var alertMessage: String?
    @State private var showNewListField: Bool = false
    @State private var isLoadingRecommendations: Bool = false
    @State private var didLoadRecommendations: Bool = false
    @State private var recommendationsError: String?
    @State private var dismissingRecommendationId: String?
    @State private var usingRecommendationId: String?
    @State private var selectedRecommendation: ShoppingRecommendation?
    @FocusState private var focusedField: Field?

    private let commonSuggestions = [
        "Milk", "Eggs", "Bread", "Chicken", "Tomatoes",
        "Onions", "Rice", "Pasta", "Cheese", "Yogurt"
    ]

    private let defaultUnits: [String: String] = [
        "Milk": "pints",
        "Eggs": "pieces",
        "Bread": "loaves",
        "Chicken": "lbs",
        "Tomatoes": "lbs",
        "Onions": "lbs",
        "Rice": "lbs",
        "Pasta": "lbs",
        "Cheese": "lbs",
        "Yogurt": "containers"
    ]

    private let commonUnits = [
        "pieces", "lbs", "kg", "oz", "g", "pints", "liters", "cups", "tbsp", "tsp",
        "loaves", "containers", "bottles", "cans", "bags", "boxes"
    ]

    private let newListSentinel = "__new_list__"

    private enum Field: Hashable {
        case itemName
        case quantity
        case unit
        case newListName
    }

    private enum ValidationError: LocalizedError {
        case emptyListName
        case missingList

        var errorDescription: String? {
            switch self {
            case .emptyListName:
                return "Please provide a name for the new list before adding an item."
            case .missingList:
                return "Choose a list or create one before adding items."
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )
    }

    private var unitSelection: Binding<String> {
        Binding {
            let trimmed = newItemUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? (commonUnits.first ?? "") : trimmed
        } set: { newValue in
            newItemUnit = newValue
        }
    }

    var body: some View {
        NavigationStack {
            shoppingContent
                .navigationTitle("Shopping List")
        }
        .task { await loadListsIfNeeded() }
        .task { await loadRecommendationsIfNeeded() }
        .refreshable {
            await loadLists(force: true)
            await loadRecommendations(force: true)
        }
        .onChange(of: selectedListId) { oldValue, newValue in
            if newValue == newListSentinel {
                withAnimation { showNewListField = true }
                focusedField = .newListName
            } else {
                if showNewListField {
                    withAnimation { showNewListField = false }
                }
                if focusedField == .newListName {
                    focusedField = nil
                }
                newListName = ""
            }
        }
        .onChange(of: app.shoppingLists.map(\.id)) { oldIds, newIds in
            guard let firstId = newIds.first else {
                selectedListId = ""
                return
            }
            if selectedListId.isEmpty || !newIds.contains(selectedListId) {
                selectedListId = firstId
            }
        }
        .alert("Something went wrong", isPresented: alertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "Please try again later.")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await loadLists(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh lists")
                }
            }
        }
        .sheet(item: $selectedRecommendation) { recommendation in
            RecommendationDetailSheet(
                recommendation: recommendation,
                isUsing: usingRecommendationId == recommendation.id,
                isDismissing: dismissingRecommendationId == recommendation.id,
                onUse: {
                    Task {
                        await useRecommendation(recommendation)
                        selectedRecommendation = nil
                    }
                },
                onDismiss: {
                    Task {
                        await dismissRecommendation(recommendation)
                        selectedRecommendation = nil
                    }
                }
            )
            .withDetents()
        }
    }

    @ViewBuilder
    private var shoppingContent: some View {
        if isLoading && app.shoppingLists.isEmpty {
            loadingState
        } else {
            listsView
        }
    }

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading your shopping lists…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listsView: some View {
        List {
            quickAddSection
            recommendationsSection
            ForEach(app.shoppingLists) { list in
                shoppingSection(for: list)
            }
        }
        .listStyle(.insetGrouped)
        .interactiveKeyboardDismiss()
    }

    @ViewBuilder
    private var quickAddSection: some View {
        Section("Quick Add") {
            VStack(spacing: 12) {
                TextField("Item name", text: $newItemName)
                    .focused($focusedField, equals: .itemName)

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

                HStack {
                    Text("List")
                    Spacer()
                    if app.shoppingLists.isEmpty {
                        Text("Default")
                            .foregroundStyle(.blue)
                    } else {
                        Picker("List", selection: $selectedListId) {
                            ForEach(app.shoppingLists) { list in
                                Text(list.name).tag(list.id)
                            }
                            Label("Add new list", systemImage: "plus")
                                .tag(newListSentinel)
                        }
                        .pickerStyle(.menu)
                    }
                }

                if showNewListField {
                    HStack {
                        TextField("New list name", text: $newListName)
                            .focused($focusedField, equals: .newListName)
                        Button("Cancel") {
                            withAnimation {
                                showNewListField = false
                            }
                            newListName = ""
                            if let first = app.shoppingLists.first?.id {
                                selectedListId = first
                            } else {
                                selectedListId = newListSentinel
                            }
                            focusedField = nil
                        }
                        .buttonStyle(.bordered)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Button {
                    Task { await addItem() }
                } label: {
                    if isAddingItem {
                        ProgressView()
                    } else {
                        Label("Add Item", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canAddItem || isAddingItem)
            }
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Suggestions")
                        .font(.headline)
                    Spacer()
                    if isLoadingRecommendations {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            Task { await loadRecommendations(force: true) }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .accessibilityLabel("Refresh suggestions")
                    }
                }

                ChipFlow(horizontalSpacing: 8, verticalSpacing: 8) {
                    ForEach(commonSuggestions, id: \.self) { suggestion in
                        suggestionChip(title: suggestion) {
                            applySuggestion(suggestion)
                        }
                    }
                    ForEach(app.shoppingRecommendations) { recommendation in
                        aiSuggestionChip(recommendation)
                    }
                }

                if let recommendationsError {
                    Text(recommendationsError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func suggestionChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.secondary.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func aiSuggestionChip(_ recommendation: ShoppingRecommendation) -> some View {
        Button {
            selectedRecommendation = recommendation
        } label: {
            Text(recommendation.title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(Color.accentColor)
                .background(
                    Capsule().fill(Color.accentColor.opacity(0.18))
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func shoppingSection(for list: ShoppingList) -> some View {
        let items = sortedItems(for: list)
        Section(header: listHeader(for: list)) {
            if items.isEmpty {
                Text("No items yet. Add one above?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    shoppingItemRow(list: list, item: item)
                }
                .onDelete { indexSet in
                    Task { await deleteItems(at: indexSet, in: list, items: items) }
                }
            }
        }
    }

    private var canAddItem: Bool {
        let hasItem = !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if showNewListField || selectedListId == newListSentinel {
            return hasItem && !newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // Allow adding items if no lists exist (will auto-create "Default" list)
        if app.shoppingLists.isEmpty {
            return hasItem
        }
        return hasItem && !selectedListId.isEmpty
    }

    private func listHeader(for list: ShoppingList) -> some View {
        HStack {
            Text(list.name)
            Spacer()
            if deletingListIds.contains(list.id) {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(role: .destructive) {
                    Task { await deleteList(list) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(list.name)")
            }
        }
    }

    private func shoppingItemRow(list: ShoppingList, item: ShoppingItem) -> some View {
        let isToggling = togglingItemIds.contains(item.id)
        let isDeleting = deletingItemIds.contains(item.id)
        return HStack(alignment: .center, spacing: 12) {
            Button {
                Task { await toggle(list: list, item: item) }
            } label: {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.checked ? .green : nil)
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(item.checked)
                if let details = itemDetails(item) {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isDeleting {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(role: .destructive) {
                    Task { await deleteItem(list: list, item: item) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .disabled(isToggling)
                .accessibilityLabel("Remove \(item.name)")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .opacity(isDeleting ? 0.4 : 1)
    }

    private func applySuggestion(_ suggestion: String) {
        newItemName = suggestion
        if newItemQuantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newItemQuantity = "1"
        }
        let fallbackUnit = commonUnits.first ?? newItemUnit
        newItemUnit = defaultUnits[suggestion] ?? fallbackUnit
        if selectedListId.isEmpty, let fallback = app.shoppingLists.first?.id {
            selectedListId = fallback
        }
        if showNewListField || selectedListId == newListSentinel {
            focusedField = .newListName
        } else {
            focusedField = .quantity
        }
    }

    private func itemDetails(_ item: ShoppingItem) -> String? {
        let parts: [String] = [
            item.quantity,
            item.unit
        ].compactMap { value in
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " • ")
    }

    private func sortedItems(for list: ShoppingList) -> [ShoppingItem] {
        list.items.sorted { lhs, rhs in
            if lhs.checked != rhs.checked {
                return !lhs.checked
            }
            if !lhs.checked {
                return (lhs.addedAt ?? 0) < (rhs.addedAt ?? 0)
            }
            let lhsTimestamp = lhs.checkedAt ?? lhs.addedAt ?? 0
            let rhsTimestamp = rhs.checkedAt ?? rhs.addedAt ?? 0
            return lhsTimestamp < rhsTimestamp
        }
    }

    @MainActor
    private func loadListsIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await loadLists(force: false)
    }

    @MainActor
    private func loadLists(force: Bool) async {
        if isLoading && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await app.loadShoppingLists()
            if selectedListId.isEmpty, let firstId = app.shoppingLists.first?.id {
                selectedListId = firstId
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadRecommendationsIfNeeded() async {
        guard !didLoadRecommendations else { return }
        await loadRecommendations(force: false)
    }

    @MainActor
    private func loadRecommendations(force: Bool) async {
        if isLoadingRecommendations && !force { return }
        isLoadingRecommendations = true
        recommendationsError = nil
        defer {
            isLoadingRecommendations = false
            didLoadRecommendations = true
        }
        do {
            try await app.loadShoppingRecommendations()
        } catch {
            recommendationsError = error.localizedDescription
        }
    }

    @MainActor
    private func dismissRecommendation(_ recommendation: ShoppingRecommendation) async {
        if dismissingRecommendationId == recommendation.id { return }
        dismissingRecommendationId = recommendation.id
        recommendationsError = nil
        defer { dismissingRecommendationId = nil }
        do {
            try await app.sendShoppingRecommendationFeedback(id: recommendation.id, action: .dismissed)
        } catch {
            recommendationsError = error.localizedDescription
        }
    }

    @MainActor
    private func useRecommendation(_ recommendation: ShoppingRecommendation) async {
        if usingRecommendationId == recommendation.id { return }
        usingRecommendationId = recommendation.id
        recommendationsError = nil
        applySuggestion(recommendation.title)
        defer { usingRecommendationId = nil }
        do {
            try await app.sendShoppingRecommendationFeedback(id: recommendation.id, action: .accepted)
        } catch {
            recommendationsError = error.localizedDescription
        }
    }

    @MainActor
    private func submitNewList() async {
        let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if isCreatingList { return }
        isCreatingList = true
        defer { isCreatingList = false }
        do {
            let list = try await app.createShoppingList(name: trimmed)
            selectedListId = list.id
            newListName = ""
            if showNewListField {
                withAnimation { showNewListField = false }
            }
            focusedField = nil
        } catch {
            alertMessage = error.localizedDescription
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
            
            // If no lists exist, automatically create "Default" list
            if app.shoppingLists.isEmpty {
                let list = try await app.createShoppingList(name: "Default")
                targetListId = list.id
                selectedListId = list.id
            } else if showNewListField {
                let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { throw ValidationError.emptyListName }
                let list = try await app.createShoppingList(name: trimmed)
                targetListId = list.id
                selectedListId = list.id
                newListName = ""
                withAnimation { showNewListField = false }
                focusedField = nil
            } else if targetListId.isEmpty, let fallback = app.shoppingLists.first?.id {
                targetListId = fallback
                selectedListId = fallback
            }

            if targetListId == newListSentinel {
                throw ValidationError.missingList
            }

            guard !targetListId.isEmpty else { throw ValidationError.missingList }

            try await app.addShoppingItem(
                to: targetListId,
                name: newItemName,
                quantity: newItemQuantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newItemQuantity,
                unit: newItemUnit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : newItemUnit,
                listLabel: nil
            )
            newItemName = ""
            newItemQuantity = ""
            newItemUnit = ""
            focusedField = nil
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func toggle(list: ShoppingList, item: ShoppingItem) async {
        if togglingItemIds.contains(item.id) { return }
        togglingItemIds.insert(item.id)
        defer { togglingItemIds.remove(item.id) }
        do {
            try await app.toggleShoppingItem(listId: list.id, itemId: item.id, checked: !item.checked)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteItem(list: ShoppingList, item: ShoppingItem) async {
        if deletingItemIds.contains(item.id) { return }
        deletingItemIds.insert(item.id)
        defer { deletingItemIds.remove(item.id) }
        do {
            try await app.deleteShoppingItem(listId: list.id, itemId: item.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteItems(at offsets: IndexSet, in list: ShoppingList, items: [ShoppingItem]) async {
        for index in offsets {
            guard items.indices.contains(index) else { continue }
            let item = items[index]
            await deleteItem(list: list, item: item)
        }
    }

    @MainActor
    private func deleteList(_ list: ShoppingList) async {
        if deletingListIds.contains(list.id) { return }
        deletingListIds.insert(list.id)
        defer { deletingListIds.remove(list.id) }
        do {
            try await app.deleteShoppingList(id: list.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
