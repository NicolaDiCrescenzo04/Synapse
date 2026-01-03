//
//  SynapseApp.swift
//  Synapse
//
//  Created by Nicola Di Crescenzo on 03/01/26.
//

import SwiftUI
import SwiftData

@main
struct SynapseApp: App {
    
    /// Container condiviso per la persistenza SwiftData.
    /// Include i modelli SynapseNode e SynapseConnection.
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SynapseNode.self,
            SynapseConnection.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Errore nella creazione del ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .modelContainer(sharedModelContainer)
    }
}
