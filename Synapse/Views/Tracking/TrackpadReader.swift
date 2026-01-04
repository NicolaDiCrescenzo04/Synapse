//
//  TrackpadReader.swift
//  Synapse
//
//  Componente dedicato per intercettare gli eventi scrollWheel del Trackpad.
//  Agisce come un Container View che avvolge il contenuto SwiftUI.
//  Gli eventi di scroll che non vengono gestiti dal contenuto (es. ScrollView)
//  risalgono ("bubble up") fino a questo container, che li intercetta per il panning.
//

import SwiftUI
import AppKit

/// Una View wrapper che intercetta gli eventi di scroll del trackpad.
struct TrackpadReader<Content: View>: NSViewRepresentable {
    
    /// Il contenuto SwiftUI da visualizzare all'interno
    let content: Content
    
    /// Callback per comunicare i delta dello scroll (X, Y)
    var onScroll: (CGFloat, CGFloat) -> Void
    
    init(_ onScroll: @escaping (CGFloat, CGFloat) -> Void, @ViewBuilder content: () -> Content) {
        self.onScroll = onScroll
        self.content = content()
    }
    
    func makeNSView(context: Context) -> TrackpadContainerView<Content> {
        let view = TrackpadContainerView(rootView: content)
        view.onScroll = onScroll
        return view
    }
    
    func updateNSView(_ nsView: TrackpadContainerView<Content>, context: Context) {
        nsView.rootView = content
        nsView.onScroll = onScroll
    }
    
    /// NSView container che ospita il contenuto SwiftUI e intercetta scrollWheel
    class TrackpadContainerView<T: View>: NSHostingView<T> {
        
        var onScroll: ((CGFloat, CGFloat) -> Void)?
        
        override func scrollWheel(with event: NSEvent) {
            // Estraiamo i delta precisi per lo scrolling
            // -1.5 offre un feeling "Natural" e veloce
            // 1.5 inverte la direzione se la precedente era al contrario
            let sensitivity: CGFloat = 1.5
            
            // Verifica che l'evento sia effettivamente uno scroll
            if event.phase == .began || event.phase == .changed || event.momentumPhase == .began || event.momentumPhase == .changed || (event.scrollingDeltaX != 0 || event.scrollingDeltaY != 0) {
                
                if event.scrollingDeltaX != 0 || event.scrollingDeltaY != 0 {
                    onScroll?(event.scrollingDeltaX * sensitivity, event.scrollingDeltaY * sensitivity)
                }
            } else {
                super.scrollWheel(with: event)
            }
        }
        
        // Importante: Assicuriamo che la view accetti il first responder per gestire eventi
        override var acceptsFirstResponder: Bool { true }
    }
}
