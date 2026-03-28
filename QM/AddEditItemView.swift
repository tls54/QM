import SwiftUI
import SwiftData

struct AddEditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Kit.createdAt) private var allKits: [Kit]

    let kit: Kit
    var item: KitItem? = nil

    @State private var name = ""
    @State private var category: ItemCategory = .other
    @State private var quantity = 1
    @State private var hasExpiry = false
    @State private var expiryDate = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    @State private var notes = ""
    @State private var targetKit: Kit? = nil

    private var isEditing: Bool { item != nil }
    private var otherKits: [Kit] { allKits.filter { $0.id != kit.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Item Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                }

                Section("Stock") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...999)
                }

                Section("Expiry") {
                    Toggle("Has Expiry Date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expiry Date", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...)
                }

                if isEditing && !otherKits.isEmpty {
                    Section("Move to Kit") {
                        Picker("Move to", selection: $targetKit) {
                            Text("— Stay in \(kit.name) —").tag(Kit?.none)
                            ForEach(otherKits) { k in
                                Label(k.name, systemImage: k.isStore ? "archivebox.fill" : k.kitIcon)
                                    .tag(Kit?.some(k))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelStyle(.titleAndIcon)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadItem() }
        }
    }

    private func loadItem() {
        guard let item else { return }
        name = item.name
        category = item.itemCategory
        quantity = item.quantity
        notes = item.notes
        if let expiry = item.expiryDate {
            hasExpiry = true
            expiryDate = expiry
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let expiry = hasExpiry ? expiryDate : nil

        if let item {
            item.name = trimmed
            item.category = category.rawValue
            item.quantity = quantity
            item.expiryDate = expiry
            item.notes = notes

            if let destination = targetKit {
                kit.items.removeAll { $0.id == item.id }
                destination.items.append(item)
            }
        } else {
            let newItem = KitItem(
                name: trimmed,
                category: category,
                quantity: quantity,
                expiryDate: expiry,
                notes: notes
            )
            kit.items.append(newItem)
        }
        dismiss()
    }
}
