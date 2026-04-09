//
//  QMApp.swift
//  QM
//
//  Created by Theo Smith on 22/03/2026.
//

import SwiftUI
import SwiftData

@main
struct QMApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Kit.self, KitItem.self, Conversation.self, PersistedMessage.self, KitBundle.self, BundleItem.self])

        // Local-only config. To enable iCloud sync:
        //   1. Register bundle ID and iCloud container in Apple Developer portal
        //   2. Add iCloud capability + CloudKit in Xcode → Signing & Capabilities
        //      (container ID: iCloud.com.atmosphere.QM)
        //   3. Update bundle ID to com.atmosphere.QM in project settings
        //   4. Replace the line below with:
        //      let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        //   Existing local data will upload to iCloud automatically on first launch.
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
