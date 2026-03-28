import Foundation
import SwiftData
import SwiftUI

@Model
final class KitItem {
    var name: String
    var category: String
    var quantity: Int
    var expiryDate: Date?
    var notes: String

    init(name: String, category: ItemCategory, quantity: Int = 1, expiryDate: Date? = nil, notes: String = "") {
        self.name = name
        self.category = category.rawValue
        self.quantity = quantity
        self.expiryDate = expiryDate
        self.notes = notes
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

    var stockStatus: StockStatus {
        if quantity == 0 { return .outOfStock }
        let threshold = UserDefaults.standard.integer(forKey: "lowStockThreshold")
        return (threshold > 0 && quantity <= threshold) ? .low : .ok
    }
}

enum StockStatus {
    case ok, low, outOfStock

    var label: String {
        switch self {
        case .ok: ""
        case .low: "Low stock"
        case .outOfStock: "Out of stock"
        }
    }

    var color: Color {
        switch self {
        case .ok: .secondary
        case .low: .orange
        case .outOfStock: .red
        }
    }
}

enum ExpiryStatus: Equatable, Comparable {
    case noExpiry, ok, expiringSoon, expired

    private var priority: Int {
        switch self {
        case .noExpiry: 0
        case .ok: 1
        case .expiringSoon: 2
        case .expired: 3
        }
    }

    static func < (lhs: ExpiryStatus, rhs: ExpiryStatus) -> Bool {
        lhs.priority < rhs.priority
    }

    var color: Color {
        switch self {
        case .noExpiry, .ok: .secondary
        case .expiringSoon: .orange
        case .expired: .red
        }
    }

    var icon: String {
        switch self {
        case .noExpiry: ""
        case .ok: "checkmark.circle"
        case .expiringSoon: "exclamationmark.triangle.fill"
        case .expired: "xmark.circle.fill"
        }
    }
}
