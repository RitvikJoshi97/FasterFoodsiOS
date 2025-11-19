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
    @State private var showingAddMenu = false
    @State private var activeAddDestination: AddItemType?
    @State private var addButtonFrame: CGRect = .zero
    @State private var addMenuSize: CGSize = .zero

    init() {
        if #available(iOS 16.0, *) {
            UITabBar.appearance().isHidden = true
        }
    }

    var body: some View {
        ZStack {
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

            addMenuOverlay
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(
                selection: $selectedTab,
                isAddMenuPresented: showingAddMenu,
                onAddOpen: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        showingAddMenu = true
                    }
                },
                onAddClose: {
                    dismissAddMenu()
                }
            )
            .onPreferenceChange(AddButtonFramePreferenceKey.self) { frame in
                addButtonFrame = frame
            }
        }
        .toolbar(.hidden, for: .tabBar)
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
    @ViewBuilder
    var addMenuOverlay: some View {
        if showingAddMenu, addButtonFrame != .zero {
            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .transition(.opacity)
                    .onTapGesture { dismissAddMenu() }

                AddActionPopup(onSelect: presentAddDestination)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: AddMenuSizePreferenceKey.self, value: geo.size)
                        }
                    )
                    .position(addMenuPosition(for: addMenuSize == .zero ? CGSize(width: 220, height: 220) : addMenuSize))
                    .transition(.scale(scale: 0.9, anchor: .bottomTrailing).combined(with: .opacity))
            }
            .onPreferenceChange(AddMenuSizePreferenceKey.self) { addMenuSize = $0 }
            .zIndex(1)
        }
    }

    func dismissAddMenu() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            showingAddMenu = false
        }
    }

    func presentAddDestination(_ itemType: AddItemType) {
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

    func addMenuPosition(for menuSize: CGSize) -> CGPoint {
        let trailingAlignment = addButtonFrame.maxX - (menuSize.width / 2)
        let buttonHeight = addButtonFrame.height == 0 ? 56 : addButtonFrame.height
        let verticalSpacing = buttonHeight + 24
        let targetY = addButtonFrame.minY - verticalSpacing - (menuSize.height / 2)
        let safeY = max(targetY, menuSize.height / 2 + 12)
        return CGPoint(x: trailingAlignment, y: safeY)
    }
}

private struct AddActionPopup: View {
    let onSelect: (AddItemType) -> Void

    private let options: [AddItemType] = [
        .shoppingItem, .pantryItem, .foodLogItem, .customMetric
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button {
                    HapticSoundPlayer.shared.playSelectionTap()
                    onSelect(option)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: option.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(.ultraThinMaterial))

                        Text(option.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: 6)
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 8)
                    .padding(.trailing, 4)
                }
                .buttonStyle(.plain)

                if index < options.count - 1 {
                    Divider()
                        .padding(.horizontal, 10)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(width: 212, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
        )
        .accessibilityElement(children: .contain)
    }
}

struct AddButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct AddMenuSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
