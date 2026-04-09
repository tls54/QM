import SwiftUI
import SwiftData

struct AddEditBundleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var bundle: KitBundle? = nil

    @State private var name = ""
    @State private var notes = ""
    @State private var kitIcon = "shippingbox.fill"
    @State private var iconColor: KitIconColor = .teal
    @State private var showingIconPicker = false
    @State private var showingDeleteConfirmation = false

    private var isEditing: Bool { bundle != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Bundle Name", text: $name)
                    TextField("Notes (optional)", text: $notes)
                }

                Section("Icon") {
                    HStack {
                        Image(systemName: kitIcon)
                            .font(.title2)
                            .foregroundStyle(iconColor.color)
                            .frame(width: 36)
                        Text("Choose Icon")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showingIconPicker = true }
                }

                Section("Colour") {
                    HStack(spacing: 14) {
                        ForEach(KitIconColor.allCases) { c in
                            Button {
                                iconColor = c
                            } label: {
                                Circle()
                                    .fill(c.color)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        if iconColor == c {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if isEditing {
                    Section {
                        Button("Delete Bundle", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    } footer: {
                        Text("Kits and items inside the bundle are not deleted.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Bundle" : "New Bundle")
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
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $kitIcon)
            }
            .confirmationDialog(
                "Delete Bundle?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Bundle", role: .destructive) {
                    if let bundle { modelContext.delete(bundle) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The bundle will be deleted. Kits and items inside it are not affected.")
            }
            .onAppear { loadBundle() }
        }
    }

    private func loadBundle() {
        guard let bundle else { return }
        name = bundle.name
        notes = bundle.notes
        kitIcon = bundle.kitIcon
        iconColor = KitIconColor(rawValue: bundle.kitIconColor) ?? .teal
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let bundle {
            bundle.name = trimmed
            bundle.notes = notes
            bundle.kitIcon = kitIcon
            bundle.kitIconColor = iconColor.rawValue
        } else {
            modelContext.insert(KitBundle(
                name: trimmed,
                notes: notes,
                kitIcon: kitIcon,
                kitIconColor: iconColor
            ))
        }
        dismiss()
    }
}
