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
        let schema = Schema([Kit.self, KitItem.self, Conversation.self, PersistedMessage.self])
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
