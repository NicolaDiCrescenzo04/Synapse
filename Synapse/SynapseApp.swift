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
    /// EDUCATIONAL: Evitiamo fatalError perché causerebbe un crash immediato dell'app.
    /// Invece, usiamo una fallback in-memory che permette all'app di funzionare
    /// (anche se i dati non persistono fino a quando il problema non viene risolto).
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SynapseNode.self,
            SynapseConnection.self,
            SynapseGroup.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // SAFETY: Invece di crashare, usiamo un container in-memory come fallback
            print("⚠️ Errore nella creazione del ModelContainer persistente: \(error)")
            print("   Usando storage in-memory come fallback. I dati NON verranno salvati.")
            
            // Tentiamo con configurazione in-memory
            let inMemoryConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            do {
                return try ModelContainer(for: schema, configurations: [inMemoryConfiguration])
            } catch {
                // Se anche la versione in-memory fallisce, è un errore critico dello schema
                fatalError("Impossibile creare anche il ModelContainer in-memory: \(error)")
            }
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
