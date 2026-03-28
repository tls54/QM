import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(IconLibrary.categories, id: \.name) { category in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(category.name)
                                .font(.headline)
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(category.icons, id: \.self) { icon in
                                    Button {
                                        selectedIcon = icon
                                        dismiss()
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .frame(width: 48, height: 48)
                                            .background(
                                                selectedIcon == icon
                                                    ? Color.accentColor.opacity(0.2)
                                                    : Color(.secondarySystemGroupedBackground),
                                                in: RoundedRectangle(cornerRadius: 10)
                                            )
                                            .foregroundStyle(selectedIcon == icon ? .accent : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

enum IconLibrary {
    struct Category {
        let name: String
        let icons: [String]
    }

    static let categories: [Category] = [
        Category(name: "Medical", icons: [
            "cross.case.fill", "cross.case", "pills.fill", "stethoscope",
            "heart.fill", "bandage.fill", "syringe.fill", "thermometer",
            "staroflife.fill", "lungs.fill", "waveform.path.ecg",
            "cross.vial.fill"
        ]),
        Category(name: "Outdoor & Camping", icons: [
            "tent.fill", "figure.hiking", "backpack.fill", "mountain.2.fill",
            "sun.max.fill", "moon.stars.fill", "flame.fill", "drop.fill",
            "snowflake", "leaf.fill", "tree.fill", "binoculars.fill",
            "map.fill", "location.north.fill", "flashlight.on.fill",
            "antenna.radiowaves.left.and.right"
        ]),
        Category(name: "Food & Cooking", icons: [
            "fork.knife", "cup.and.saucer.fill", "cart.fill", "basket.fill",
            "refrigerator.fill", "frying.pan.fill", "wineglass.fill",
            "mug.fill"
        ]),
        Category(name: "Tools & Equipment", icons: [
            "wrench.and.screwdriver.fill", "hammer.fill", "screwdriver.fill",
            "gearshape.fill", "bolt.fill", "flashlight.on.fill",
            "antenna.radiowaves.left.and.right", "cable.connector",
            "scissors", "ruler.fill"
        ]),
        Category(name: "Safety & Emergency", icons: [
            "shield.fill", "exclamationmark.triangle.fill", "bell.fill",
            "lock.fill", "eye.fill", "hand.raised.fill",
            "light.beacon.max.fill", "sos", "figure.stand",
            "ear.and.waveform"
        ]),
        Category(name: "General", icons: [
            "bag.fill", "briefcase.fill", "archivebox.fill", "tray.fill",
            "folder.fill", "shippingbox.fill", "suitcase.fill", "tag.fill",
            "star.fill", "flag.fill", "bookmark.fill", "house.fill"
        ])
    ]
}
