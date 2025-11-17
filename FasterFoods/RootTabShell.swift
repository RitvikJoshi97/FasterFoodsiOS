import SwiftUI
import UIKit

enum TabIdentifier: Hashable {
    case dashboard
    case calendar
    case shopping
    case pantry
}

struct RootTabShell: View {
    @EnvironmentObject private var app: AppState
    @State private var selectedTab: TabIdentifier = .dashboard
    @State private var showingAddSheet = false
    @State private var activeAddDestination: AddItemType?

    init() {
        if #available(iOS 16.0, *) {
            UITabBar.appearance().isHidden = true
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(TabIdentifier.dashboard)
                CalendarView()
                    .tag(TabIdentifier.calendar)
                ShoppingListView()
                    .tag(TabIdentifier.shopping)
                PantryView()
                    .tag(TabIdentifier.pantry)
            }
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selection: $selectedTab) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                    showingAddSheet = true
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingAddSheet) {
            AddActionPickerSheet { selection in
                presentAddDestination(selection)
            }
            .presentationDetents([.fraction(0.35), .medium])
            .presentationDragIndicator(.visible)
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
        .glassNavigationBarStyle()
    }
}

private extension RootTabShell {
    func presentAddDestination(_ itemType: AddItemType) {
        let showDestination = {
            activeAddDestination = itemType
        }

        if showingAddSheet {
            showingAddSheet = false
            let springDismissDelay = 0.32
            DispatchQueue.main.asyncAfter(deadline: .now() + springDismissDelay) {
                showDestination()
            }
        } else {
            showDestination()
        }
    }
}

private struct AddActionPickerSheet: View {
    let onSelect: (AddItemType) -> Void

    private let options: [AddItemType] = [
        .shoppingItem, .pantryItem, .foodLogItem, .customMetric
    ]

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 80, height: 5)
                .padding(.top, 8)

            Text("Add something new")
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 14) {
                ForEach(options) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: option.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .frame(width: 46, height: 46)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white.opacity(0.45), lineWidth: 0.5)
                                        )
                                        .shadow(color: .black.opacity(0.25), radius: 8, y: 6)
                                )

                            Text(option.title)
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                                )
                                .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.3),
                    Color.white.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}
