import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.createdAt) private var items: [ShoppingItem]

    @State private var showingAddItem = false
    @State private var editingItem: ShoppingItem?
    @State private var showingAcquired = false

    private var activeItems: [ShoppingItem] {
        items.filter { $0.status != .acquired }
    }

    private var neededItems: [ShoppingItem] {
        items.filter { $0.status == .needed }
    }

    private var orderedItems: [ShoppingItem] {
        items.filter { $0.status == .ordered }
    }

    private var acquiredItems: [ShoppingItem] {
        items.filter { $0.status == .acquired }
    }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Items",
                        systemImage: "checklist",
                        description: Text("Tap + to add items you need to buy or restock.")
                    )
                } else if activeItems.isEmpty && !showingAcquired {
                    ContentUnavailableView(
                        "All Done",
                        systemImage: "checkmark.circle",
                        description: Text("Everything on your list has been acquired.")
                    )
                } else {
                    List {
                        if !neededItems.isEmpty {
                            Section("Needed") {
                                ForEach(neededItems) { item in
                                    ShoppingItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingItem = item }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                item.status = .ordered
                                            } label: {
                                                Label("Ordered", systemImage: "arrow.clockwise.circle.fill")
                                            }
                                            .tint(.orange)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                item.status = .acquired
                                            } label: {
                                                Label("Acquired", systemImage: "checkmark.circle.fill")
                                            }
                                            .tint(.green)
                                        }
                                }
                            }
                        }

                        if !orderedItems.isEmpty {
                            Section("Ordered") {
                                ForEach(orderedItems) { item in
                                    ShoppingItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingItem = item }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                item.status = .needed
                                            } label: {
                                                Label("Mark Needed", systemImage: "circle")
                                            }
                                            .tint(.blue)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                            Button {
                                                item.status = .acquired
                                            } label: {
                                                Label("Acquired", systemImage: "checkmark.circle.fill")
                                            }
                                            .tint(.green)
                                        }
                                }
                            }
                        }

                        if showingAcquired && !acquiredItems.isEmpty {
                            Section("Acquired") {
                                ForEach(acquiredItems) { item in
                                    ShoppingItemRow(item: item)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingItem = item }
                                        .swipeActions(edge: .leading) {
                                            Button {
                                                item.status = .needed
                                            } label: {
                                                Label("Mark Needed", systemImage: "circle")
                                            }
                                            .tint(.blue)
                                        }
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                modelContext.delete(item)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !acquiredItems.isEmpty {
                        Button {
                            showingAcquired.toggle()
                        } label: {
                            Image(systemName: showingAcquired ? "clock.fill" : "clock")
                                .foregroundStyle(showingAcquired ? Color.accentColor : Color.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddItem = true } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddEditShoppingItemView()
            }
            .sheet(item: $editingItem) { item in
                AddEditShoppingItemView(item: item)
            }
        }
    }
}

private struct ShoppingItemRow: View {
    let item: ShoppingItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.status.icon)
                .foregroundStyle(item.status.color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .strikethrough(item.status == .acquired)
                    .foregroundStyle(item.status == .acquired ? .secondary : .primary)
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if item.source == ShoppingSource.llm.rawValue {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
