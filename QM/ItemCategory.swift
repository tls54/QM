enum ItemCategory: String, CaseIterable, Identifiable, Hashable {
    // First aid
    case woundCare       = "Wound Care"
    case medications     = "Medications"
    case airwayAndBreathing = "Airway & Breathing"
    case immobilisation  = "Immobilisation"
    // General / tools
    case toolsAndEquipment = "Tools & Equipment"
    // Outdoor
    case navigation      = "Navigation"
    case shelter         = "Shelter"
    case cookingAndWater = "Cooking & Water"
    case lighting        = "Lighting"
    case communication   = "Communication"
    // Catch-all
    case other           = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .woundCare:          "bandage.fill"
        case .medications:        "pills.fill"
        case .airwayAndBreathing: "lungs.fill"
        case .immobilisation:     "figure.walk.motion"
        case .toolsAndEquipment:  "wrench.and.screwdriver.fill"
        case .navigation:         "map.fill"
        case .shelter:            "tent.fill"
        case .cookingAndWater:    "flame.fill"
        case .lighting:           "flashlight.on.fill"
        case .communication:      "antenna.radiowaves.left.and.right"
        case .other:              "archivebox.fill"
        }
    }
}
