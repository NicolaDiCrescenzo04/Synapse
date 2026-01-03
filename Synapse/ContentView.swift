//
//  ContentView.swift
//  Synapse
//
//  Vista principale dell'applicazione.
//  Ospita la CanvasView per la mappa concettuale.
//

import SwiftUI
import SwiftData

/// Vista principale che contiene la canvas della mappa concettuale.
struct ContentView: View {
    
    var body: some View {
        CanvasView()
            .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [SynapseNode.self, SynapseConnection.self], inMemory: true)
}
