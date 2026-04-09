import SwiftUI
import SwiftData

struct BundleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let bundle: KitBundle

    @State private var showingEditBundle = false
    @State private var showingAddItem = false
    @State private var editingItem: BundleItem?

    private var sortedKits: [Kit] {
        bundle.kits.sorted { $0.name < $1.name }
    }

    private var sortedItems: [BundleItem] {
        bundle.items.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            Section {
                if bundle.kits.isEmpty {
                    Text("No kits — long-press any kit to add it to this bundle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedKits) { kit in
                        NavigationLink(destination: KitDetailView(kit: kit)) {
                            KitRowView(kit: kit)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                bundle.kits.removeAll { $0.persistentModelID == kit.persistentModelID }
                            } label: {
                                Label("Remove", systemImage: "minus.circle")
                            }
                            .tint(.orange)
                        }
                    }
                }
            } header: {
                Text("Kits (\(bundle.kits.count))")
            }

            Section {
                ForEach(sortedItems) { item in
                    BundleItemRow(item: item)
                        .contentShape(Rectangle())
                        .onTapGesture { editingItem = item }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                modelContext.delete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
                Button("Add Item") { showingAddItem = true }
                    .foregroundStyle(.tint)
            } header: {
                Text("Loose Items (\(bundle.items.count))")
            } footer: {
                if !bundle.notes.isEmpty {
                    Text(bundle.notes)
                }
            }
        }
        .navigationTitle(bundle.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingEditBundle = true } label: {
                    Label("Edit Bundle", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEditBundle) {
            AddEditBundleView(bundle: bundle)
        }
        .sheet(isPresented: $showingAddItem) {
            AddEditBundleItemView(bundle: bundle)
        }
        .sheet(item: $editingItem) { item in
            AddEditBundleItemView(bundle: bundle, item: item)
        }
    }
}

private struct BundleItemRow: View {
    let item: BundleItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                HStack(spacing: 6) {
                    Text(item.itemCategory.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let size = item.size, !size.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            if item.expiryStatus == .expired || item.expiryStatus == .expiringSoon {
                Image(systemName: item.expiryStatus.icon)
                    .foregroundStyle(item.expiryStatus.color)
                    .font(.caption)
            }
            Text("\(item.quantity)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
