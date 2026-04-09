import SwiftUI
import SwiftData

struct AddEditBundleItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let bundle: KitBundle
    var item: BundleItem? = nil

    @State private var name = ""
    @State private var category: ItemCategory = .other
    @State private var quantity = 1
    @State private var hasExpiry = false
    @State private var expiryDate = Date()
    @State private var notes = ""
    @State private var trackStock = true
    @State private var size = ""

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(ItemCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    TextField("Size (optional)", text: $size)
                }

                Section("Stock") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 0...9999)
                    Toggle("Track stock level", isOn: $trackStock)
                }

                Section("Expiry") {
                    Toggle("Has expiry date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Item" : "New Item")
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
        hasExpiry = item.expiryDate != nil
        expiryDate = item.expiryDate ?? Date()
        notes = item.notes
        trackStock = item.trackStock
        size = item.size ?? ""
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let expiry: Date? = hasExpiry ? expiryDate : nil
        let sizeValue: String? = size.trimmingCharacters(in: .whitespaces).isEmpty ? nil : size.trimmingCharacters(in: .whitespaces)

        if let item {
            item.name = trimmed
            item.category = category.rawValue
            item.quantity = quantity
            item.expiryDate = expiry
            item.notes = notes
            item.trackStock = trackStock
            item.size = sizeValue
        } else {
            let newItem = BundleItem(
                name: trimmed,
                category: category,
                quantity: quantity,
                expiryDate: expiry,
                notes: notes,
                trackStock: trackStock,
                size: sizeValue
            )
            modelContext.insert(newItem)
            bundle.items.append(newItem)
        }
        dismiss()
    }
}
