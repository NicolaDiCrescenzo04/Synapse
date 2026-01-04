//
//  TextFormattingToolbar.swift
//  Synapse
//
//  Barra degli strumenti flottante per la formattazione del testo.
//  Invia azioni al First Responder (che sarà la NSTextView attiva).
//  IMPORTANTE: Usa NSButton con refusesFirstResponder per non rubare il focus.
//

import SwiftUI
import AppKit

// Protocollo per definire i selettori custom della nostra FormattableTextView
@objc protocol FormattableTextActions {
    func toggleBold(_ sender: Any?)
    func toggleItalic(_ sender: Any?)
    func underline(_ sender: Any?)
}

struct TextFormattingToolbar: View {
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            // Bold
            NonFocusableButton(iconName: "bold", help: "Grassetto (⌘B)") {
                NSApp.sendAction(#selector(FormattableTextActions.toggleBold(_:)), to: nil, from: nil)
            }
            
            // Italic
            NonFocusableButton(iconName: "italic", help: "Corsivo (⌘I)") {
                NSApp.sendAction(#selector(FormattableTextActions.toggleItalic(_:)), to: nil, from: nil)
            }
            
            // Underline
            NonFocusableButton(iconName: "underline", help: "Sottolineato (⌘U)") {
                NSApp.sendAction(#selector(FormattableTextActions.underline(_:)), to: nil, from: nil)
            }
            
            Divider()
                .frame(height: 16)
            
            // Font Panel - per cambiare dimensione e famiglia font
            NonFocusableButton(iconName: "textformat.size", help: "Dimensione Font") {
                openFontPanel()
            }
            
            // Color Panel - per cambiare colore testo
            NonFocusableButton(iconName: "paintpalette.fill", help: "Colore Testo") {
                openColorPanel()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor).opacity(0.95))
        .cornerRadius(8)
        .shadow(radius: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
    }
    
    // MARK: - Azioni Pannelli
    
    /// Apre il pannello Font di sistema
    private func openFontPanel() {
        let fontPanel = NSFontPanel.shared
        fontPanel.orderFront(nil)
    }
    
    /// Apre il pannello Colore di sistema
    private func openColorPanel() {
        let colorPanel = NSColorPanel.shared
        colorPanel.mode = .wheel
        colorPanel.showsAlpha = true
        colorPanel.isContinuous = true
        
        // Imposta l'azione per inviare il colore selezionato al first responder
        colorPanel.setTarget(nil)
        colorPanel.setAction(NSSelectorFromString("changeColor:"))
        
        colorPanel.orderFront(nil)
    }
}

// MARK: - Non-Focusable Button

/// Wrapper NSViewRepresentable che crea un pulsante che non ruba il focus dalla NSTextView.
/// Questo è fondamentale per permettere la formattazione del testo senza uscire dall'edit mode.
struct NonFocusableButton: NSViewRepresentable {
    let iconName: String
    let help: String
    let action: () -> Void
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        
        // Configurazione immagine SF Symbol
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: help) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
        }
        
        // Stile del pulsante
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.toolTip = help
        
        // CRUCIALE: Non accettare il first responder per non rubare il focus
        button.refusesFirstResponder = true
        
        // Imposta target e action
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))
        
        // Dimensioni
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        return button
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {
        // Aggiorna l'immagine se necessario
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: help) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            nsView.image = image.withSymbolConfiguration(config)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }
    
    class Coordinator: NSObject {
        let action: () -> Void
        
        init(action: @escaping () -> Void) {
            self.action = action
        }
        
        @objc func buttonClicked(_ sender: Any?) {
            action()
        }
    }
}
