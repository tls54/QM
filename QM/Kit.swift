import Foundation
import SwiftData
import SwiftUI

@Model
final class Kit {
    var name: String
    var isStore: Bool
    var kitCategory: String = ""
    var kitIcon: String = "cross.case.fill"
    var kitIconColor: String = KitIconColor.teal.rawValue
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var items: [KitItem] = []

    init(name: String, isStore: Bool = false, kitCategory: String = "", kitIcon: String = "cross.case.fill", kitIconColor: KitIconColor = .teal) {
        self.name = name
        self.isStore = isStore
        self.kitCategory = kitCategory
        self.kitIcon = kitIcon
        self.kitIconColor = kitIconColor.rawValue
        self.createdAt = Date()
    }

    var iconColor: Color {
        KitIconColor(rawValue: kitIconColor)?.color ?? .teal
    }

    var sortedItems: [KitItem] {
        items.sorted { $0.name < $1.name }
    }

    var expiredCount: Int {
        items.filter { $0.expiryStatus == .expired }.count
    }

    var expiringSoonCount: Int {
        items.filter { $0.expiryStatus == .expiringSoon }.count
    }
}
