import SwiftUI
import SwiftData

struct InventoryView: View {
    @Query private var allItems: [KitItem]

    private struct AggregateItem: Identifiable {
        let name: String
        let category: ItemCategory
        let totalQuantity: Int
        let worstExpiryStatus: ExpiryStatus
        var id: String { "\(name.lowercased())|\(category.rawValue)" }
    }

    private var aggregates: [AggregateItem] {
        let grouped = Dictionary(grouping: allItems) {
            "\($0.name.lowercased())|\($0.category)"
        }
        return grouped.values.map { items in
            AggregateItem(
                name: items[0].name,
                category: items[0].itemCategory,
                totalQuantity: items.reduce(0) { $0 + $1.quantity },
                worstExpiryStatus: items.map(\.expiryStatus).max() ?? .noExpiry
            )
        }
        .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    private var byCategory: [(ItemCategory, [AggregateItem])] {
        let grouped = Dictionary(grouping: aggregates, by: \.category)
        return ItemCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if aggregates.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "list.clipboard",
                        description: Text("Add items to your kits to see them here.")
                    )
                } else {
                    ForEach(byCategory, id: \.0) { category, items in
                        Section(category.rawValue) {
                            ForEach(items) { item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name)
                                    }
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Text("×\(item.totalQuantity)")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                        if item.worstExpiryStatus != .noExpiry && item.worstExpiryStatus != .ok {
                                            Image(systemName: item.worstExpiryStatus.icon)
                                                .foregroundStyle(item.worstExpiryStatus.color)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
        }
    }
}

#Preview {
    InventoryView()
        .modelContainer(for: [Kit.self, KitItem.self], inMemory: true)
}
