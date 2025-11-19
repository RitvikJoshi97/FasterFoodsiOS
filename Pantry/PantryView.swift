import SwiftUI

struct PantryView: View {
    @EnvironmentObject private var app: AppState
    @State private var newItemName: String = ""
    @State private var newQuantity: String = ""
    @State private var newUnit: String = "pieces"
    @State private var expiryText: String = ""
    @State private var isLoading: Bool = false
    @State private var didLoadOnce: Bool = false
    @State private var didLoadRecommendations: Bool = false
    @State private var isAddingItem: Bool = false
    @State private var togglingIds: Set<String> = []
    @State private var deletingIds: Set<String> = []
    @State private var isCheckingAll: Bool = false
    @State private var alertMessage: String?
    @State private var usingRecommendationId: String?
    @State private var dismissingRecommendationId: String?
    @State private var selectedRecommendation: ShoppingRecommendation?
    @State private var showReceiptSheet: Bool = false
    @FocusState private var focusedField: Field?
    @State private var recommendationsError: String?
    @State private var showFullSuggestionList: Bool = false
    @State private var suggestionExpansionTask: Task<Void, Never>?

    private enum Field: Hashable { case name, quantity, unit, expiry }

    private let suggestions = [
        "Flour", "Sugar", "Salt", "Olive Oil", "Canned Tomatoes",
        "Beans", "Lentils", "Spices", "Coffee", "Tea"
    ]

    private let defaultUnits: [String: String] = [
        "Flour": "lbs", "Sugar": "lbs", "Salt": "lbs", "Olive Oil": "bottles",
        "Canned Tomatoes": "cans", "Beans": "cans", "Lentils": "lbs", "Spices": "oz",
        "Coffee": "lbs", "Tea": "bags"
    ]

    private let commonUnits = [
        "pieces", "lbs", "kg", "oz", "g", "pints", "liters", "cups", "tbsp", "tsp",
        "loaves", "containers", "bottles", "cans", "bags", "boxes"
    ]

    private let collapsedSuggestionChipLimit = 4
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

    private var alertBinding: Binding<Bool> {
        Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
    }

    private let isoFormatterFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private let isoFormatterBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }

    private var shouldShowDetailFields: Bool {
        let hasItemName = !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasItemName || focusedField != nil
    }

    private var collapsedSuggestionChips: [String] {
        Array(suggestions.prefix(collapsedSuggestionChipLimit))
    }

    private var additionalSuggestionChips: [String] {
        Array(suggestions.dropFirst(collapsedSuggestionChips.count))
    }

    private var collapsedRecommendationChips: [ShoppingRecommendation] {
        Array(app.pantryRecommendations.prefix(max(0, collapsedSuggestionChipLimit - collapsedSuggestionChips.count)))
    }

    private var additionalRecommendationChips: [ShoppingRecommendation] {
        Array(app.pantryRecommendations.dropFirst(collapsedRecommendationChips.count))
    }

    private var suggestionRevealTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
        )
    }

    var body: some View {
        NavigationStack {
            pantryContent
                .navigationTitle("Pantry")
        }
        .task { await loadPantryIfNeeded() }
        .task { await loadPantryRecommendationsIfNeeded() }
        .refreshable {
            await loadPantry(force: true)
            await loadPantryRecommendations(force: true)
        }
        .alert("Something went wrong", isPresented: alertBinding) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage ?? "Please try again later.")
        }
        .sheet(isPresented: $showReceiptSheet) {
            VStack(spacing: 16) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.accentColor)
                Text("Receipt scanning coming soon")
                    .font(.headline)
                Text("You'll be able to add pantry items from photos and receipts right here.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Got it") { showReceiptSheet = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .presentationDetents([.fraction(0.35)])
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private var pantryContent: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Button {
                        focusedField = nil
                        showReceiptSheet = true
                    } label: {
                        Label("Add Receipt", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor.opacity(0.12))
                    .foregroundStyle(Color.accentColor)

                    HStack(spacing: 8) {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.secondary.opacity(0.4))
                        Text("or")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                    .frame(maxWidth: .infinity, minHeight: 16)

                    VStack(spacing: 12) {
                        TextField("Item name", text: $newItemName)
                            .focused($focusedField, equals: .name)
                        if shouldShowDetailFields {
                            VStack(spacing: 12) {
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
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    Button {
                        Task { await addItem() }
                    } label: {
                        if isAddingItem {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Label("Add Item", systemImage: "plus")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canAddItem || isAddingItem)
                }
                .padding(.vertical, 4)
                .animation(.easeInOut(duration: 0.2), value: shouldShowDetailFields)
                .onChange(of: shouldShowDetailFields) { isVisible in
                    guard !isVisible else { return }
                    if focusedField != .name {
                        focusedField = nil
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Suggestions")
                        .font(.headline)
                        .animation(.none, value: showFullSuggestionList)
                    ChipFlow(horizontalSpacing: 8, verticalSpacing: 8) {
                        ForEach(collapsedSuggestionChips, id: \.self) { suggestion in
                            suggestionChip(title: suggestion) {
                                applySuggestion(suggestion)
                            }
                        }
                        .transaction { $0.animation = nil }

                        if showFullSuggestionList {
                            ForEach(additionalSuggestionChips, id: \.self) { suggestion in
                                suggestionChip(title: suggestion) {
                                    applySuggestion(suggestion)
                                }
                                .transition(suggestionRevealTransition)
                            }
                        }

                        ForEach(collapsedRecommendationChips) { recommendation in
                            aiSuggestionChip(recommendation)
                        }
                        .transaction { $0.animation = nil }

                        if showFullSuggestionList {
                            ForEach(additionalRecommendationChips) { recommendation in
                                aiSuggestionChip(recommendation)
                                    .transition(suggestionRevealTransition)
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: showFullSuggestionList)
                    if let recommendationsError,
                       !recommendationsError.isEmpty {
                        Text(recommendationsError)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .onAppear { scheduleSuggestionExpansionIfNeeded() }
            .onDisappear { resetSuggestionExpansion() }

            Section {
                let uncheckedCount = app.pantryItems.filter { !$0.checked }.count
                HStack {
                    (Text("Your Pantry (")
                     + Text("\(uncheckedCount)")
                     + Text("/\(app.pantryItems.count))"))
                    Spacer()
                    if !app.pantryItems.isEmpty {
                        Button {
                            Task { await checkAll() }
                        } label: {
                            if isCheckingAll {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Text("Check All")
                            }
                        }
                        .disabled(isCheckingAll || uncheckedCount == 0)
                    }
                }
                .font(.headline)
                .padding(.vertical, 4)

                if isLoading {
                    ProgressView("Loading pantry items…")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else if app.pantryItems.isEmpty {
                    Text("No items yet. Add your first item above!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(sortedPantryItems()) { item in
                        pantryRow(item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .interactiveKeyboardDismiss()
    }

    private func sortedPantryItems() -> [PantryItem] {
        app.pantryItems.sorted { (lhs: PantryItem, rhs: PantryItem) -> Bool in
            if lhs.checked != rhs.checked {
                return !lhs.checked
            }
            if lhs.checked {
                let lhsDate = lhs.addedOn ?? ""
                let rhsDate = rhs.addedOn ?? ""
                return lhsDate > rhsDate
            }
            let lhsAdded = lhs.addedOn ?? ""
            let rhsAdded = rhs.addedOn ?? ""
            return lhsAdded > rhsAdded
        }
    }

    private func pantryRow(_ item: PantryItem) -> some View {
        let isToggling = togglingIds.contains(item.id)
        let isDeleting = deletingIds.contains(item.id)
        return HStack(alignment: .top, spacing: 12) {
            Button {
                Task { await toggle(item) }
            } label: {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.checked ? Color.green : Color.accentColor)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.headline)
                    .strikethrough(item.checked)
                if let expiry = item.expiryDate,
                   let date = parseDate(expiry) {
                    HStack(spacing: 8) {
                        if isExpired(date) {
                            Text("Expired")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.red.opacity(0.15)))
                                .foregroundStyle(.red)
                        } else if isExpiringSoon(date) {
                            Text("Expiring soon")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.orange.opacity(0.15)))
                                .foregroundStyle(.orange)
                        }
                    }
                }
                HStack(spacing: 12) {
                    if let quantity = item.quantity, !quantity.isEmpty {
                        Text("Quantity: \(quantity) \(item.unit ?? "")")
                    }
                    if let expiry = item.expiryDate,
                       let date = parseDate(expiry) {
                        Text("Expires: \(dateFormatter.string(from: date))")
                            .foregroundStyle(.secondary)
                    }
                    if let added = item.addedOn,
                       let date = parseDate(added) {
                        Text("Added: \(dateFormatter.string(from: date))")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
            }
            Spacer()
            if isDeleting {
                ProgressView().scaleEffect(0.7)
            } else {
                Button(role: .destructive) {
                    Task { await delete(item) }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .disabled(isToggling)
            }
        }
        .padding(.vertical, 6)
        .opacity(isDeleting ? 0.4 : 1)
    }

    private var canAddItem: Bool {
        !newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                .background(Capsule().fill(Color.accentColor.opacity(0.18)))
        }
        .buttonStyle(.plain)
    }

    private func applySuggestion(_ suggestion: String) {
        newItemName = suggestion
        let fallbackUnit = commonUnits.first ?? "pieces"
        let resolvedUnit = defaultUnits[suggestion] ?? (newUnit.isEmpty ? fallbackUnit : newUnit)
        newUnit = resolvedUnit
        if newQuantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            newQuantity = "1"
        }
        focusedField = .quantity
    }

    private func loadPantryIfNeeded() async {
        guard !didLoadOnce else { return }
        didLoadOnce = true
        await loadPantry(force: false)
    }

    private func loadPantry(force: Bool) async {
        if isLoading && !force { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await app.loadPantryItems()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func loadPantryRecommendationsIfNeeded() async {
        guard !didLoadRecommendations else { return }
        await loadPantryRecommendations(force: false)
    }

    private func loadPantryRecommendations(force: Bool) async {
        if didLoadRecommendations && !force { return }
        do {
            try await app.loadPantryRecommendations()
            recommendationsError = nil
            didLoadRecommendations = true
        } catch {
            recommendationsError = error.localizedDescription
        }
    }

    private func scheduleSuggestionExpansionIfNeeded() {
        guard !showFullSuggestionList else { return }
        suggestionExpansionTask?.cancel()
        suggestionExpansionTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut) {
                    showFullSuggestionList = true
                }
            }
        }
    }

    private func resetSuggestionExpansion() {
        suggestionExpansionTask?.cancel()
        suggestionExpansionTask = nil
        if showFullSuggestionList {
            withAnimation(.easeInOut(duration: 0.2)) {
                showFullSuggestionList = false
            }
        }
    }

    private func parseDate(_ value: String) -> Date? {
        if let date = isoFormatterFractional.date(from: value) {
            return date
        }
        return isoFormatterBasic.date(from: value)
    }

    private func isExpired(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: Date())
    }

    private func isExpiringSoon(_ date: Date) -> Bool {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        guard let days = Calendar.current.dateComponents([.day], from: startOfToday, to: date).day else { return false }
        return days >= 0 && days <= 7
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
            newItemName = ""
            newQuantity = ""
            newUnit = commonUnits.first ?? "pieces"
            expiryText = ""
            focusedField = .name
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func toggle(_ item: PantryItem) async {
        if togglingIds.contains(item.id) { return }
        togglingIds.insert(item.id)
        defer { togglingIds.remove(item.id) }
        do {
            try await app.togglePantryItem(id: item.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func delete(_ item: PantryItem) async {
        if deletingIds.contains(item.id) { return }
        deletingIds.insert(item.id)
        defer { deletingIds.remove(item.id) }
        do {
            try await app.deletePantryItem(id: item.id)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func checkAll() async {
        if isCheckingAll { return }
        isCheckingAll = true
        defer { isCheckingAll = false }
        await app.checkAllPantryItems()
    }

    private func useRecommendation(_ recommendation: ShoppingRecommendation) async {
        if usingRecommendationId == recommendation.id { return }
        usingRecommendationId = recommendation.id
        applySuggestion(recommendation.title)
        defer { usingRecommendationId = nil }
        try? await app.sendPantryRecommendationFeedback(id: recommendation.id, action: .accepted)
    }

    private func dismissRecommendation(_ recommendation: ShoppingRecommendation) async {
        if dismissingRecommendationId == recommendation.id { return }
        dismissingRecommendationId = recommendation.id
        defer { dismissingRecommendationId = nil }
        try? await app.sendPantryRecommendationFeedback(id: recommendation.id, action: .dismissed)
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
