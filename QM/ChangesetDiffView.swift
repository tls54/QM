import SwiftUI
import SwiftData

struct ChangesetDiffView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var kits: [Kit]
    @Environment(\.dismiss) private var dismiss

    let changeset: Changeset
    @State private var approvedIDs: Set<UUID>

    init(changeset: Changeset) {
        self.changeset = changeset
        _approvedIDs = State(initialValue: Set(changeset.operations.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(changeset.operations) { op in
                        Button {
                            if approvedIDs.contains(op.id) {
                                approvedIDs.remove(op.id)
                            } else {
                                approvedIDs.insert(op.id)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: approvedIDs.contains(op.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(approvedIDs.contains(op.id) ? Color.accentColor : Color.secondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Image(systemName: op.systemImage)
                                            .foregroundStyle(op.accentColor)
                                            .font(.caption)
                                        Text(op.displayTitle)
                                            .foregroundStyle(.primary)
                                    }
                                    if let detail = op.displayDetail {
                                        Text(detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Tap to toggle individual operations. Only checked items will be applied.")
                }
            }
            .navigationTitle("Proposed Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply (\(approvedIDs.count))") {
                        applyApproved()
                    }
                    .disabled(approvedIDs.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func applyApproved() {
        for op in changeset.operations where approvedIDs.contains(op.id) {
            execute(op)
        }
        dismiss()
    }

    private func execute(_ op: ChangeOperation) {
        switch op.type {
        case "create_item":
            guard let kitName = op.kit_name,
                  let payload = op.item,
                  let kit = kits.first(where: { $0.name == kitName }) else { return }
            let newItem = KitItem(
                name: payload.name,
                category: ItemCategory(rawValue: payload.category) ?? .other,
                quantity: payload.quantity,
                notes: payload.notes ?? ""
            )
            modelContext.insert(newItem)
            kit.items.append(newItem)

        case "delete_item":
            guard let kitName = op.kit_name,
                  let itemName = op.item_name,
                  let kit = kits.first(where: { $0.name == kitName }),
                  let item = kit.items.first(where: { $0.name.lowercased() == itemName.lowercased() }) else { return }
            modelContext.delete(item)

        case "update_quantity":
            guard let kitName = op.kit_name,
                  let itemName = op.item_name,
                  let newQty = op.quantity,
                  let kit = kits.first(where: { $0.name == kitName }),
                  let item = kit.items.first(where: { $0.name.lowercased() == itemName.lowercased() }) else { return }
            item.quantity = newQty

        case "create_kit":
            guard let kitName = op.kit_name else { return }
            let newKit = Kit(name: kitName, kitCategory: op.kit_category ?? "")
            modelContext.insert(newKit)

        default:
            break
        }
    }
}
