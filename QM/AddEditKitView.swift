import SwiftUI
import SwiftData

struct AddEditKitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var kit: Kit? = nil
    @State private var name = ""
    @State private var kitCategory = ""
    @State private var kitIcon = "cross.case.fill"
    @State private var iconColor: KitIconColor = .teal
    @State private var showingIconPicker = false

    private var isEditing: Bool { kit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Kit Name", text: $name)
                    TextField("Type (e.g. Medical, Equipment)", text: $kitCategory)
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
            }
            .navigationTitle(isEditing ? "Edit Kit" : "New Kit")
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
            .onAppear { loadKit() }
        }
    }

    private func loadKit() {
        guard let kit else { return }
        name = kit.name
        kitCategory = kit.kitCategory
        kitIcon = kit.kitIcon
        iconColor = KitIconColor(rawValue: kit.kitIconColor) ?? .teal
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let kit {
            kit.name = trimmed
            kit.kitCategory = kitCategory
            kit.kitIcon = kitIcon
            kit.kitIconColor = iconColor.rawValue
        } else {
            modelContext.insert(Kit(
                name: trimmed,
                kitCategory: kitCategory,
                kitIcon: kitIcon,
                kitIconColor: iconColor
            ))
        }
        dismiss()
    }
}
