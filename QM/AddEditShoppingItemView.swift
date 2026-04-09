import SwiftUI
import SwiftData

struct AddEditShoppingItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var item: ShoppingItem? = nil

    @State private var name = ""
    @State private var notes = ""
    @State private var status: ShoppingStatus = .needed

    private var isEditing: Bool { item != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item") {
                    TextField("Name", text: $name)
                    TextField("Notes (optional)", text: $notes)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ShoppingStatus.allCases) { s in
                            Label(s.label, systemImage: s.icon).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
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
        notes = item.notes
        status = item.status
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let item {
            item.name = trimmed
            item.notes = notes
            item.status = status
        } else {
            modelContext.insert(ShoppingItem(name: trimmed, notes: notes, status: status))
        }
        dismiss()
    }
}
