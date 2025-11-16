import SwiftUI

enum AddItemType: Identifiable, Hashable {
    case shoppingItem
    case pantryItem
    case foodLogItem
    case customMetric
    
    var id: String {
        switch self {
        case .shoppingItem: return "shopping"
        case .pantryItem: return "pantry"
        case .foodLogItem: return "foodLog"
        case .customMetric: return "customMetric"
        }
    }
    
    var title: String {
        switch self {
        case .shoppingItem: return "+ Shopping item"
        case .pantryItem: return "+ Pantry item"
        case .foodLogItem: return "+ Food Log item"
        case .customMetric: return "+ Custom metric"
        }
    }
    
    var icon: String {
        switch self {
        case .shoppingItem: return "cart"
        case .pantryItem: return "archivebox"
        case .foodLogItem: return "fork.knife"
        case .customMetric: return "chart.bar"
        }
    }
}

struct AddItemPopup: View {
    @Binding var isPresented: Bool
    let onSelect: (AddItemType) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach([AddItemType.shoppingItem, .pantryItem, .foodLogItem, .customMetric]) { itemType in
                Button {
                    onSelect(itemType)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: itemType.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                        
                        Text(itemType.title)
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                
                if itemType.id != "customMetric" {
                    Divider()
                        .padding(.leading, 64)
                }
            }
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
    }
}

