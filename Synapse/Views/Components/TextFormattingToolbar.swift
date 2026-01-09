//
//  TextFormattingToolbar.swift
//  Synapse
//
//  Barra degli strumenti flottante per la formattazione del testo.
//  Versione COMPLETA con tutti i controlli di formattazione rich text.
//

import SwiftUI
import AppKit

// MARK: - Protocollo per FormattableTextView

@objc protocol FormattableTextActions {
    func toggleBold(_ sender: Any?)
    func toggleItalic(_ sender: Any?)
    func underline(_ sender: Any?)
}

// MARK: - TextFormattingToolbar

struct TextFormattingToolbar: View {
    
    // MARK: - Callbacks Base
    
    var onBold: () -> Void
    var onItalic: () -> Void
    var onUnderline: () -> Void
    var onStrikethrough: () -> Void
    var onLatex: () -> Void
    
    // MARK: - Callbacks Colori
    
    var onTextColor: (FormattableTextView.TextColorPalette) -> Void
    var onHighlight: (FormattableTextView.HighlightColorPalette) -> Void
    
    // MARK: - Callbacks Font Size
    
    var onFontSizeIncrease: () -> Void
    var onFontSizeDecrease: () -> Void
    
    // MARK: - State
    
    @State private var selectedTextColor: FormattableTextView.TextColorPalette = .black
    @State private var selectedHighlight: FormattableTextView.HighlightColorPalette = .none
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 4) {
            // Font Size Controls
            fontSizeControls
            
            Divider()
                .frame(height: 16)
            
            // Style Buttons (B, I, U, S) con keyboard shortcuts
            styleButtons
            
            Divider()
                .frame(height: 16)
            
            // Color Menus
            colorMenus
            
            Divider()
                .frame(height: 16)
            
            // LaTeX
            NonFocusableButton(iconName: "sum", help: "LaTeX ($$)", action: onLatex)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor).opacity(0.95))
        .cornerRadius(8)
        .shadow(radius: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separatorColor), lineWidth: 0.5)
        )
        // Keyboard Shortcuts
        .background(keyboardShortcuts)
    }
    
    // MARK: - Keyboard Shortcuts (Hidden Buttons)
    
    @ViewBuilder
    private var keyboardShortcuts: some View {
        // Hidden buttons that capture keyboard shortcuts
        HStack(spacing: 0) {
            Button("Bold") { onBold() }
                .keyboardShortcut("b", modifiers: .command)
                .hidden()
            
            Button("Italic") { onItalic() }
                .keyboardShortcut("i", modifiers: .command)
                .hidden()
            
            Button("Underline") { onUnderline() }
                .keyboardShortcut("u", modifiers: .command)
                .hidden()
        }
        .frame(width: 0, height: 0)
    }
    
    // MARK: - Font Size Controls
    
    @ViewBuilder
    private var fontSizeControls: some View {
        HStack(spacing: 2) {
            NonFocusableButton(iconName: "minus", help: "Riduci Font", action: onFontSizeDecrease)
            
            Text("A")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            
            NonFocusableButton(iconName: "plus", help: "Aumenta Font", action: onFontSizeIncrease)
        }
    }
    
    // MARK: - Style Buttons
    
    @ViewBuilder
    private var styleButtons: some View {
        HStack(spacing: 2) {
            NonFocusableButton(iconName: "bold", help: "Grassetto (⌘B)", action: onBold)
            NonFocusableButton(iconName: "italic", help: "Corsivo (⌘I)", action: onItalic)
            NonFocusableButton(iconName: "underline", help: "Sottolineato (⌘U)", action: onUnderline)
            NonFocusableButton(iconName: "strikethrough", help: "Barrato", action: onStrikethrough)
        }
    }
    
    // MARK: - Color Menus
    
    @ViewBuilder
    private var colorMenus: some View {
        HStack(spacing: 4) {
            // Text Color Menu - Icona palette colori
            Menu {
                ForEach(FormattableTextView.TextColorPalette.allCases, id: \.self) { color in
                    Button {
                        selectedTextColor = color
                        onTextColor(color)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(Color(nsColor: color.color))
                                .font(.system(size: 10))
                            Text(color.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 11))
                    Circle()
                        .fill(Color(nsColor: selectedTextColor.color))
                        .frame(width: 8, height: 8)
                }
                .frame(width: 36, height: 24)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Colore Testo")
            
            // Highlight Color Menu
            Menu {
                ForEach(FormattableTextView.HighlightColorPalette.allCases, id: \.self) { color in
                    Button {
                        selectedHighlight = color
                        onHighlight(color)
                    } label: {
                        HStack(spacing: 8) {
                            if let c = color.color {
                                Image(systemName: "circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(Color(nsColor: c))
                                    .font(.system(size: 10))
                            } else {
                                Image(systemName: "circle.slash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Text(color.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 11))
                    if let hlColor = selectedHighlight.color {
                        Circle()
                            .fill(Color(nsColor: hlColor))
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 36, height: 24)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Evidenziatore")
        }
    }
}

// MARK: - NonFocusableButton

/// NSButton wrapper che non ruba il focus dalla NSTextView durante l'editing.
struct NonFocusableButton: NSViewRepresentable {
    let iconName: String
    let help: String
    var tintColor: NSColor? = nil
    let action: () -> Void
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton()
        
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: help) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            var finalImage = image.withSymbolConfiguration(config) ?? image
            
            if let color = tintColor {
                finalImage = finalImage.tinted(with: color)
            }
            
            button.image = finalImage
        }
        
        button.bezelStyle = .accessoryBarAction
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.toolTip = help
        button.refusesFirstResponder = true
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))
        
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        return button
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: help) {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            var finalImage = image.withSymbolConfiguration(config) ?? image
            
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
