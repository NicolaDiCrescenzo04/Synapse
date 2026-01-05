//
//  TextFormattingToolbar.swift
//  Synapse
//
//  Barra degli strumenti flottante per la formattazione del testo.
//  Usa SwiftUI Button per garantire che i click vengano catturati correttamente.
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
    
    // MARK: - Callbacks
    
    /// Callback per applicare il grassetto
    var onBold: () -> Void
    
    /// Callback per applicare il corsivo
    var onItalic: () -> Void
    
    /// Callback per applicare la sottolineatura
    var onUnderline: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            // Bold
            ToolbarButton(iconName: "bold", help: "Grassetto") {
                onBold()
            }
            
            // Italic
            ToolbarButton(iconName: "italic", help: "Corsivo") {
                onItalic()
            }
            
            // Underline
            ToolbarButton(iconName: "underline", help: "Sottolineato") {
                onUnderline()
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
}

// MARK: - Toolbar Button (SwiftUI Native)

/// Pulsante semplice per la toolbar usando SwiftUI Button nativo.
/// Evita problemi di hit testing con NSButton wrapper.
struct ToolbarButton: View {
    let iconName: String
    let help: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Non-Focusable Button (Legacy - kept for reference)

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
