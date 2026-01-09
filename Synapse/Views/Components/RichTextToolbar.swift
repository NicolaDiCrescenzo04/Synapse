//
//  RichTextToolbar.swift
//  Synapse
//
//  Toolbar SwiftUI per la formattazione del testo arricchito.
//  Fornisce controlli per stili, colori, allineamento e indentazione.
//

import SwiftUI
import AppKit

/// Toolbar per la formattazione del testo nel RichTextEditor
struct RichTextToolbar: View {
    
    // MARK: - Dipendenze
    
    /// Riferimento debole alla textView per applicare le formattazioni
    weak var textView: FormattableTextView?
    
    // MARK: - State
    
    @State private var fontSize: CGFloat = 14
    @State private var selectedTextColor: FormattableTextView.TextColorPalette = .black
    @State private var selectedHighlight: FormattableTextView.HighlightColorPalette = .none
    
    // MARK: - Body
    
    var body: some View {
        HStack(spacing: 8) {
            // Font Size
            fontSizeControls
            
            Divider()
                .frame(height: 20)
            
            // Style Buttons
            styleButtons
            
            Divider()
                .frame(height: 20)
            
            // Color Pickers
            colorPickers
            
            Divider()
                .frame(height: 20)
            
            // Alignment
            alignmentButtons
            
            Divider()
                .frame(height: 20)
            
            // Indent
            indentButtons
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
    
    // MARK: - Font Size Controls
    
    @ViewBuilder
    private var fontSizeControls: some View {
        HStack(spacing: 4) {
            Text("Dim:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button {
                fontSize = max(8, fontSize - 2)
                textView?.setFontSize(fontSize)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            
            Text("\(Int(fontSize))")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .frame(width: 24)
            
            Button {
                fontSize = min(72, fontSize + 2)
                textView?.setFontSize(fontSize)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Style Buttons
    
    @ViewBuilder
    private var styleButtons: some View {
        HStack(spacing: 4) {
            // Bold
            Button {
                textView?.toggleBold(nil)
            } label: {
                Text("B")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Grassetto (⌘B)")
            
            // Italic
            Button {
                textView?.toggleItalic(nil)
            } label: {
                Text("I")
                    .font(.system(size: 14, weight: .regular).italic())
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Corsivo (⌘I)")
            
            // Underline
            Button {
                textView?.underline(nil)
            } label: {
                Text("U")
                    .font(.system(size: 14, weight: .regular))
                    .underline()
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Sottolineato (⌘U)")
            
            // Strikethrough
            Button {
                textView?.toggleStrikethrough()
            } label: {
                Text("S")
                    .font(.system(size: 14, weight: .regular))
                    .strikethrough()
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Barrato")
        }
    }
    
    // MARK: - Color Pickers
    
    @ViewBuilder
    private var colorPickers: some View {
        HStack(spacing: 8) {
            // Text Color Menu
            Menu {
                ForEach(FormattableTextView.TextColorPalette.allCases, id: \.self) { paletteColor in
                    Button {
                        selectedTextColor = paletteColor
                        textView?.applyTextColorFromPalette(paletteColor)
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color(nsColor: paletteColor.color))
                                .frame(width: 12, height: 12)
                            Text(paletteColor.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "textformat")
                        .font(.system(size: 12))
                    Circle()
                        .fill(Color(nsColor: selectedTextColor.color))
                        .frame(width: 10, height: 10)
                }
                .frame(width: 40, height: 26)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .help("Colore Testo")
            
            // Highlight Color Menu
            Menu {
                ForEach(FormattableTextView.HighlightColorPalette.allCases, id: \.self) { paletteColor in
                    Button {
                        selectedHighlight = paletteColor
                        textView?.applyHighlightFromPalette(paletteColor)
                    } label: {
                        HStack {
                            if let color = paletteColor.color {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(nsColor: color))
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 10))
                            }
                            Text(paletteColor.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "highlighter")
                        .font(.system(size: 12))
                    if let hlColor = selectedHighlight.color {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(nsColor: hlColor))
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 40, height: 26)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
            .menuStyle(.borderlessButton)
            .help("Evidenziatore")
        }
    }
    
    // MARK: - Alignment Buttons
    
    @ViewBuilder
    private var alignmentButtons: some View {
        HStack(spacing: 2) {
            Button {
                textView?.setTextAlignment(.left)
            } label: {
                Image(systemName: "text.alignleft")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Allinea a Sinistra")
            
            Button {
                textView?.setTextAlignment(.center)
            } label: {
                Image(systemName: "text.aligncenter")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Centra")
            
            Button {
                textView?.setTextAlignment(.right)
            } label: {
                Image(systemName: "text.alignright")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Allinea a Destra")
        }
    }
    
    // MARK: - Indent Buttons
    
    @ViewBuilder
    private var indentButtons: some View {
        HStack(spacing: 2) {
            Button {
                textView?.decreaseIndent()
            } label: {
                Image(systemName: "decrease.indent")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Riduci Rientro")
            
            Button {
                textView?.increaseIndent()
            } label: {
                Image(systemName: "increase.indent")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
            .help("Aumenta Rientro")
        }
    }
}

#Preview {
    RichTextToolbar(textView: nil)
        .frame(width: 600)
}
