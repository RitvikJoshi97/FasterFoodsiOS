import SwiftUI

enum TabIdentifier: Hashable {
    case dashboard
    case calendar
    case shopping
    case pantry
    case add

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .calendar:
            return "Calendar"
        case .shopping:
            return "Shopping"
        case .pantry:
            return "Pantry"
        case .add:
            return "Add"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:
            return "speedometer"
        case .calendar:
            return "calendar"
        case .shopping:
            return "cart"
        case .pantry:
            return "archivebox"
        case .add:
            return "plus"
        }
    }
}

struct RootTabShell: View {
    @EnvironmentObject private var app: AppState
    @State private var selectedTab: TabIdentifier = .dashboard
    @State private var lastNonAddTab: TabIdentifier = .dashboard
    @State private var showingAddMenu = false
    @State private var activeAddDestination: AddItemType?

    var body: some View {
        ZStack {
            tabScaffold
            addMenuOverlay
        }
        .sheet(item: $activeAddDestination) { itemType in
            Group {
                switch itemType {
                case .shoppingItem:
                    AddShoppingItemSheet()
                case .pantryItem:
                    AddPantryItemSheet()
                case .foodLogItem:
                    AddFoodLogItemSheet()
                case .customMetric:
                    AddCustomMetricSheet()
                }
            }
            .environmentObject(app)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $app.showAssistant) {
            ChatAssistantView(
                title: app.assistantTitle,
                script: app.assistantScript,
                queue: app.assistantMode == .onboarding
                    ? OnboardingMessageQueue()
                    : MockAssistantMessageQueue(),
                bootstrapMessage: app.assistantMode == .onboarding
                    ? AssistantScript.onboardingBootstrapMessage
                    : nil,
                dismissLabel: app.assistantMode == .onboarding ? "Later" : "Close",
                onComplete: {
                    if app.assistantMode == .onboarding {
                        app.markOnboardingComplete()
                    }
                    app.showAssistant = false
                },
                onDismiss: {
                    app.showAssistant = false
                }
            )
            .environmentObject(app)
        }
        .glassNavigationBarStyle()
        .onAppear {
            app.presentOnboardingIfNeeded()
        }
    }
}

extension RootTabShell {
    @ViewBuilder
    private var tabScaffold: some View {
        if #available(iOS 18.0, *) {
            modernTabView
        } else {
            fallbackTabView
        }
    }

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(value: .dashboard) {
                DashboardView()
            } label: {
                Label(TabIdentifier.dashboard.title, systemImage: TabIdentifier.dashboard.icon)
            }

            Tab(value: .calendar) {
                CalendarView()
            } label: {
                Label(TabIdentifier.calendar.title, systemImage: TabIdentifier.calendar.icon)
            }

            Tab(value: .shopping) {
                ShoppingListView()
            } label: {
                Label(TabIdentifier.shopping.title, systemImage: TabIdentifier.shopping.icon)
            }

            Tab(value: .pantry) {
                PantryView()
            } label: {
                Label(TabIdentifier.pantry.title, systemImage: TabIdentifier.pantry.icon)
            }

            Tab(value: .add, role: .search) {
                Color.clear
            } label: {
                Label(TabIdentifier.add.title, systemImage: TabIdentifier.add.icon)
            }
        }
        .tint(.accentColor)
        .onChange(of: selectedTab) { newValue in
            handleTabChange(newValue)
        }
    }

    private var fallbackTabView: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label(TabIdentifier.dashboard.title, systemImage: TabIdentifier.dashboard.icon)
                }
                .tag(TabIdentifier.dashboard)

            CalendarView()
                .tabItem {
                    Label(TabIdentifier.calendar.title, systemImage: TabIdentifier.calendar.icon)
                }
                .tag(TabIdentifier.calendar)

            ShoppingListView()
                .tabItem {
                    Label(TabIdentifier.shopping.title, systemImage: TabIdentifier.shopping.icon)
                }
                .tag(TabIdentifier.shopping)

            PantryView()
                .tabItem {
                    Label(TabIdentifier.pantry.title, systemImage: TabIdentifier.pantry.icon)
                }
                .tag(TabIdentifier.pantry)

            Color.clear
                .tabItem { Label(TabIdentifier.add.title, systemImage: TabIdentifier.add.icon) }
                .tag(TabIdentifier.add)
        }
        .tint(.accentColor)
        .onChange(of: selectedTab) { newValue in
            handleTabChange(newValue)
        }
    }

    @ViewBuilder
    fileprivate var addMenuOverlay: some View {
        if showingAddMenu {
            ZStack {
                Color.black.opacity(0.0001)
                    .ignoresSafeArea()
                    .onTapGesture { dismissAddMenu() }
                    .transition(.opacity)

                GeometryReader { proxy in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            AddActionPopup(onSelect: presentAddDestination)
                                .frame(width: proxy.size.width * 0.5)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 60)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.85), value: showingAddMenu)
            .zIndex(1)
        }
    }

    private func handleTabChange(_ newValue: TabIdentifier) {
        guard newValue == .add else {
            lastNonAddTab = newValue
            return
        }

        HapticSoundPlayer.shared.playPrimaryTap()

        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            showingAddMenu = true
        }

        // Keep the TabView on the previously selected tab.
        selectedTab = lastNonAddTab
    }

    fileprivate func dismissAddMenu() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            showingAddMenu = false
        }
    }

    fileprivate func presentAddDestination(_ itemType: AddItemType) {
        let showDestination = {
            activeAddDestination = itemType
        }

        if showingAddMenu {
            dismissAddMenu()
            let springDismissDelay = 0.32
            DispatchQueue.main.asyncAfter(deadline: .now() + springDismissDelay) {
                showDestination()
            }
        } else {
            showDestination()
        }
    }
}

private struct AddActionPopup: View {
    let onSelect: (AddItemType) -> Void

    private let options: [AddItemType] = [
        .shoppingItem, .pantryItem, .foodLogItem, .customMetric,
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    HapticSoundPlayer.shared.playSelectionTap()
                    onSelect(option)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(option.title)")
                            .font(.headline.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Divider()
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(radius: 2)
        .accessibilityElement(children: .contain)
    }
}
