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
    
    /// Callback per applicare il colore rosso
    var onRed: () -> Void
    
    /// Callback per inserire delimitatori LaTeX
    var onLatex: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            // Bold - Usa NonFocusableButton per non rubare focus dalla NSTextView
            NonFocusableButton(iconName: "bold", help: "Grassetto", action: onBold)
            
            // Italic
            NonFocusableButton(iconName: "italic", help: "Corsivo", action: onItalic)
            
            // Underline
            NonFocusableButton(iconName: "underline", help: "Sottolineato", action: onUnderline)
            
            Divider()
                .frame(height: 16)
            
            // Red Color - Toggle rosso/nero
            NonFocusableButton(iconName: "paintbrush.fill", help: "Rosso (Toggle)", tintColor: .systemRed, action: onRed)
            
            Divider()
                .frame(height: 16)
            
            // LaTeX - Inserisce delimitatori $$
            NonFocusableButton(iconName: "sum", help: "LaTeX ($$)", action: onLatex)
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
    var color: Color = .primary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
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
    var tintColor: NSColor? = nil
    let action: () -> Void
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        
        // Configurazione immagine SF Symbol
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: help) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            var finalImage = image.withSymbolConfiguration(config) ?? image
            
            // Applica tintColor se specificato
            if let color = tintColor {
                finalImage = finalImage.tinted(with: color)
            }
            
            button.image = finalImage
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
            var finalImage = image.withSymbolConfiguration(config) ?? image
            
            // Applica tintColor se specificato
            if let color = tintColor {
                finalImage = finalImage.tinted(with: color)
            }
            
            nsView.image = finalImage
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

// MARK: - NSImage Tinting Extension

extension NSImage {
    /// Crea una copia dell'immagine con il colore specificato come tinta.
    /// Usato per colorare le icone SF Symbol.
    func tinted(with color: NSColor) -> NSImage {
        let image = self.copy() as! NSImage
        image.lockFocus()
        color.set()
        let imageRect = NSRect(origin: .zero, size: image.size)
        imageRect.fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}
