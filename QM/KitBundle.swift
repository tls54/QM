import Foundation
import SwiftData
import SwiftUI

@Model
final class KitBundle {
    var name: String
    var notes: String
    var kitIcon: String
    var kitIconColor: String
    var createdAt: Date

    @Relationship(inverse: \Kit.bundles) var kits: [Kit] = []
    @Relationship(deleteRule: .cascade, inverse: \BundleItem.bundle) var items: [BundleItem] = []

    init(name: String, notes: String = "", kitIcon: String = "shippingbox.fill", kitIconColor: KitIconColor = .teal) {
        self.name = name
        self.notes = notes
        self.kitIcon = kitIcon
        self.kitIconColor = kitIconColor.rawValue
        self.createdAt = Date()
    }

    var iconColor: Color {
        KitIconColor(rawValue: kitIconColor)?.color ?? .teal
    }

    var totalItemCount: Int {
        kits.reduce(0) { $0 + $1.items.count } + items.count
    }
}

@Model
final class BundleItem {
    var name: String
    var category: String
    var quantity: Int
    var expiryDate: Date?
    var notes: String
    var trackStock: Bool
    var size: String?
    var bundle: KitBundle?

    init(name: String, category: ItemCategory, quantity: Int = 1, expiryDate: Date? = nil, notes: String = "", trackStock: Bool = true, size: String? = nil) {
        self.name = name
        self.category = category.rawValue
        self.quantity = quantity
        self.expiryDate = expiryDate
        self.notes = notes
        self.trackStock = trackStock
        self.size = size
    }

    var itemCategory: ItemCategory {
        ItemCategory(rawValue: category) ?? .other
    }

    var expiryStatus: ExpiryStatus {
        guard let expiryDate else { return .noExpiry }
        let now = Date()
        if expiryDate < now { return .expired }
        let days = UserDefaults.standard.integer(forKey: "expiryWarningDays")
        let threshold = Calendar.current.date(byAdding: .day, value: days > 0 ? days : 30, to: now)!
        return expiryDate <= threshold ? .expiringSoon : .ok
    }
}
