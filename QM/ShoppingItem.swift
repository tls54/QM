import Foundation
import SwiftData
import SwiftUI

@Model
final class ShoppingItem {
    var name: String
    var notes: String
    var statusRaw: String
    var source: String
    var createdAt: Date

    init(name: String, notes: String = "", status: ShoppingStatus = .needed, source: ShoppingSource = .user) {
        self.name = name
        self.notes = notes
        self.statusRaw = status.rawValue
        self.source = source.rawValue
        self.createdAt = Date()
    }

    var status: ShoppingStatus {
        get { ShoppingStatus(rawValue: statusRaw) ?? .needed }
        set { statusRaw = newValue.rawValue }
    }
}

enum ShoppingStatus: String, CaseIterable, Identifiable {
    case needed   = "needed"
    case ordered  = "ordered"
    case acquired = "acquired"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .needed:   "Needed"
        case .ordered:  "Ordered"
        case .acquired: "Acquired"
        }
    }

    var icon: String {
        switch self {
        case .needed:   "circle"
        case .ordered:  "arrow.clockwise.circle.fill"
        case .acquired: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .needed:   .primary
        case .ordered:  .orange
        case .acquired: .green
        }
    }
}

enum ShoppingSource: String {
    case user = "user"
    case llm  = "llm"
}
