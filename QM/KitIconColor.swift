import SwiftUI

enum KitIconColor: String, CaseIterable, Identifiable {
    case teal   = "teal"
    case red    = "red"
    case blue   = "blue"
    case orange = "orange"
    case purple = "purple"
    case green  = "green"
    case pink   = "pink"
    case indigo = "indigo"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .teal:   .teal
        case .red:    .red
        case .blue:   .blue
        case .orange: .orange
        case .purple: .purple
        case .green:  .green
        case .pink:   .pink
        case .indigo: .indigo
        }
    }
}
