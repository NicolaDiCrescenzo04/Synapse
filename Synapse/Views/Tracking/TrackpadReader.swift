//
//  TrackpadReader.swift
//  Synapse
//
//  Componente dedicato per intercettare gli eventi scrollWheel del Trackpad
//  su macOS, essenziali per il panning a due dita in SwiftUI.
//

import SwiftUI
import AppKit

/// Una rappresentazione SwiftUI di una NSView trasparente che cattura lo scrolling.
struct TrackpadReader: NSViewRepresentable {
    
    /// Callback per comunicare i delta dello scroll (X, Y)
    var onScroll: (CGFloat, CGFloat) -> Void
    
    func makeNSView(context: Context) -> TrackpadView {
        let view = TrackpadView()
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: TrackpadView, context: Context) {
        nsView.onScroll = onScroll
    }
    
    /// NSView sottostante che gestisce gli eventi
    class TrackpadView: NSView {
        
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        
        override var acceptsFirstResponder: Bool { true }
        
        override func scrollWheel(with event: NSEvent) {
            // Estraiamo i delta precisi per lo scrolling inerziale/pixel-based
            // Moltiplichiamo per un fattore negativo per ottenere il "Natural Scrolling"
            // (muovo le dita a sinistra -> il contenuto va a sinistra, quindi la "camera" va a sinistra)
           
            // Fattore di moltiplicazione per la sensibilità e direzione
            // -1.5 offre un feeling "Natural" e veloce
            let sensitivity: CGFloat = -1.5
            
            if event.scrollingDeltaX != 0 || event.scrollingDeltaY != 0 {
                // Notifica il listener
                onScroll?(event.scrollingDeltaX * sensitivity, event.scrollingDeltaY * sensitivity)
            }
        }
    }
}
