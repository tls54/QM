import SwiftUI
import SwiftData

struct KitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let kit: Kit
    @State private var showingAddItem = false
    @State private var showingEditKit = false
    @State private var editingItem: KitItem?
    @State private var filterExpiring = false

    private var itemsByCategory: [(ItemCategory, [KitItem])] {
        let source = filterExpiring
            ? kit.sortedItems.filter { $0.expiryStatus == .expired || $0.expiryStatus == .expiringSoon }
            : kit.sortedItems
        let grouped = Dictionary(grouping: source, by: { $0.itemCategory })
        return ItemCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        List {
            if kit.items.isEmpty {
                ContentUnavailableView(
                    "No Items",
                    systemImage: "cross.case",
                    description: Text("Tap + to add items to this kit.")
                )
            } else {
                ForEach(itemsByCategory, id: \.0) { category, items in
                    Section {
                        ForEach(items) { item in
                            KitItemRowView(item: item, onAdjust: { delta in
                                item.quantity = max(0, item.quantity + delta)
                                try? modelContext.save()
                            })
                            .contentShape(Rectangle())
                            .onTapGesture { editingItem = item }
                        }
                        .onDelete { offsets in
                            deleteItems(from: items, offsets: offsets)
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
        }
        .navigationTitle(kit.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { filterExpiring.toggle() }) {
                        Image(systemName: filterExpiring ? "clock.fill" : "clock")
                            .foregroundStyle(filterExpiring ? .orange : .primary)
                    }
                    Button(action: { showingEditKit = true }) {
                        Image(systemName: "pencil")
                    }
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditKit) {
            AddEditKitView(kit: kit)
        }
        .sheet(isPresented: $showingAddItem) {
            AddEditItemView(kit: kit)
        }
        .sheet(item: $editingItem) { item in
            AddEditItemView(kit: kit, item: item)
        }
    }

    private func deleteItems(from items: [KitItem], offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
        try? modelContext.save()
    }
}

private struct KitItemRowView: View {
    let item: KitItem
    let onAdjust: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.body)

                if let expiry = item.expiryDate {
                    Text(expiryLabel(for: expiry, status: item.expiryStatus))
                        .font(.caption)
                        .foregroundStyle(item.expiryStatus.color)
                }

                if let size = item.size, !size.isEmpty {
                    Text(size)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Button {
                    onAdjust(-1)
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(item.quantity > 0 ? .secondary : Color.secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(item.quantity == 0)

                if item.stockStatus != .ok {
                    Text(item.stockStatus.label)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.stockStatus.color, in: Capsule())
                } else {
                    Text("×\(item.quantity)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 28, alignment: .center)
                }

                Button {
                    onAdjust(1)
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                if item.expiryStatus == .expiringSoon || item.expiryStatus == .expired {
                    Image(systemName: item.expiryStatus.icon)
                        .foregroundStyle(item.expiryStatus.color)
                }
            }
        }
        .padding(.vertical, 3)
    }

    private func expiryLabel(for date: Date, status: ExpiryStatus) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        switch status {
        case .expired:
            let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
            return days == 1 ? "Expired yesterday" : "Expired \(days) days ago"
        case .expiringSoon:
            let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            if days == 0 { return "Expires today" }
            if days == 1 { return "Expires tomorrow" }
            return "Expires \(formatter.string(from: date))"
        default:
            return "Expires \(formatter.string(from: date))"
        }
    }
}
