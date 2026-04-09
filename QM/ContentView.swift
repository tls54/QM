//
//  ContentView.swift
//  QM
//
//  Created by Theo Smith on 22/03/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appearancePreference")   private var appearancePreference = "system"
    @AppStorage("medicalFeaturesEnabled") private var medicalFeaturesEnabled = false

    private var preferredColorScheme: ColorScheme? {
        switch appearancePreference {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil
        }
    }

    var body: some View {
        TabView {
            Tab("Kits", systemImage: "cross.case") {
                KitListView()
            }
            Tab("Assistant", systemImage: "bubble.left.and.bubble.right") {
                AssistantView()
            }
            Tab("Shopping", systemImage: "checklist") {
                ShoppingListView()
            }
            if medicalFeaturesEnabled {
                Tab("Guide", systemImage: "book.closed") {
                    ReferenceView()
                }
            }
            Tab("Inventory", systemImage: "list.clipboard") {
                InventoryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .preferredColorScheme(preferredColorScheme)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Kit.self, KitItem.self], inMemory: true)
}
