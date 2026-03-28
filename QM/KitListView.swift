import SwiftUI
import SwiftData

struct KitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Kit.createdAt) private var kits: [Kit]
    @State private var showingAddKit = false
    @State private var editingKit: Kit?

    private var storeKit: Kit? { kits.first(where: { $0.isStore }) }
    private var regularKits: [Kit] { kits.filter { !$0.isStore } }

    private var kitsByCategory: [(String, [Kit])] {
        let grouped = Dictionary(grouping: regularKits) {
            $0.kitCategory.trimmingCharacters(in: .whitespaces).isEmpty ? "Uncategorised" : $0.kitCategory
        }
        var keys = grouped.keys.filter { $0 != "Uncategorised" }.sorted()
        if grouped["Uncategorised"] != nil { keys.append("Uncategorised") }
        return keys.compactMap { key in
            guard let kits = grouped[key] else { return nil }
            return (key, kits.sorted { $0.name < $1.name })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let store = storeKit {
                    Section("Store") {
                        NavigationLink(destination: KitDetailView(kit: store)) {
                            KitRowView(kit: store)
                        }
                    }
                }

                if regularKits.isEmpty {
                    Section {
                        Text("No kits yet — tap + to add one.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                } else {
                    ForEach(kitsByCategory, id: \.0) { category, kits in
                        Section(category) {
                            ForEach(kits) { kit in
                                NavigationLink(destination: KitDetailView(kit: kit)) {
                                    KitRowView(kit: kit)
                                }
                                .swipeActions(edge: .leading) {
                                    Button { editingKit = kit } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        modelContext.delete(kit)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Kit Manager")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddKit = true }) {
                        Label("Add Kit", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddKit) {
                AddEditKitView()
            }
            .sheet(item: $editingKit) { kit in
                AddEditKitView(kit: kit)
            }
            .task {
                guard !kits.contains(where: { $0.isStore }) else { return }
                modelContext.insert(Kit(name: "Store", isStore: true))
            }
        }
    }
}

private struct KitRowView: View {
    let kit: Kit

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: kit.isStore ? "archivebox.fill" : kit.kitIcon)
                .font(.title2)
                .foregroundStyle(kit.isStore ? Color.secondary : kit.iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(kit.name)
                    .font(.body)

                HStack(spacing: 10) {
                    let total = kit.items.count
                    let outOfStock = kit.items.filter { $0.stockStatus == .outOfStock }.count
                    let lowStock  = kit.items.filter { $0.stockStatus == .low }.count

                    Text("\(total) item\(total == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if outOfStock > 0 {
                        Label("\(outOfStock) out of stock", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if lowStock > 0 {
                        Label("\(lowStock) low", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if kit.expiredCount > 0 {
                        Label("\(kit.expiredCount) expired", systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if kit.expiringSoonCount > 0 {
                        Label("\(kit.expiringSoonCount) expiring", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    KitListView()
        .modelContainer(for: [Kit.self, KitItem.self], inMemory: true)
}
