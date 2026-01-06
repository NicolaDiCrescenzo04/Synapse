//
//  NodeView.swift
//  Synapse
//
//  Componente UI per un singolo nodo nella canvas.
//  Design "Lavagna Infinita": il nodo appare come testo fluttuante,
//  le decorazioni (sfondo, bordo) appaiono SOLO su interazione.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Hover Target Enum

/// Enum per tracciare cosa sta puntando il mouse (per feedback visivo pre-drag)
enum HoverTarget: Equatable {
    case none
    case node
    case word(rect: CGRect, range: NSRange)
    
    static func == (lhs: HoverTarget, rhs: HoverTarget) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none), (.node, .node):
            return true
        case let (.word(r1, rng1), .word(r2, rng2)):
            return r1 == r2 && rng1 == rng2
        default:
            return false
        }
    }
}

struct NodeView: View {
    
    // MARK: - Proprietà
    
    let node: SynapseNode
    var viewModel: MapViewModel
    
    var isSelected: Bool {
        viewModel.selectedNodeID == node.id
    }
    
    var isLinkingSource: Bool {
        viewModel.isLinking && viewModel.tempLinkSource?.id == node.id
    }
    
    var isPotentialTarget: Bool {
        viewModel.isLinking && viewModel.tempLinkSource?.id != node.id
    }
    
    // MARK: - Stato Locale
    
    @State private var localText: String = ""
    @State private var localRichTextData: Data?
    @State private var isEditing: Bool = false
    @State private var isHovered: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var dragStartPosition: CGPoint = .zero
    
    /// Riferimento alla NSTextView per word hit testing durante il linking
    @State private var textViewRef: NSTextView?
    
    /// Stato corrente dell'hover per feedback visivo pre-drag
    @State private var hoverTarget: HoverTarget = .none
    
    // MARK: - Costanti Design
    
    private let cornerRadius: CGFloat = 6
    private let horizontalPadding: CGFloat = 4
    private let verticalPadding: CGFloat = 2
    
    // MARK: - Ghost UI Computed
    
    private var shouldShowBackground: Bool {
        isHovered || isSelected || isLinkingSource || isPotentialTarget || isEditing
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Sfondo (GHOST: solo su interazione)
            if shouldShowBackground {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(nodeBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: borderWidth)
                    )
            }
            
            // Contenuto
            if isEditing {
                // EDIT MODE
                RichTextEditor(
                    data: $localRichTextData,
                    plainText: $localText,
                    isEditable: true,
                    onCommit: { finishEditing() },
                    onResolveEditor: { textView in
                        viewModel.activeTextView = textView
                    }
                )
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            } else {
                // VIEW MODE
                if let imageData = node.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                        .allowsHitTesting(false)
                } else if isLatex(localText) {
                    LatexView(latex: extractLatex(from: localText))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                } else if localRichTextData != nil && !localText.isEmpty {
                    RichTextEditor(
                        data: $localRichTextData,
                        plainText: $localText,
                        isEditable: false,
                        onResolveEditor: { textView in
                            textViewRef = textView
                        }
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    // Permetti hit testing per word-level linking
                    .allowsHitTesting(false)
                } else {
                    RichTextEditor(
                        data: .constant(nil),
                        plainText: .constant(localText.isEmpty ? "..." : localText),
                        isEditable: false,
                        onResolveEditor: { textView in
                            textViewRef = textView
                        }
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .opacity(localText.isEmpty ? 0.5 : 1.0)
                    .allowsHitTesting(false)
                }
            }
            
            // UX "Hover Ghost" Halo: Feedback visivo sul target del link
            // Appare su hover (prima del click), non solo durante il drag
            if case .word(let rect, _) = hoverTarget, !isEditing {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: rect.width + 6, height: rect.height + 4)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }
        }
        .frame(
            width: max(SynapseNode.minWidth, node.width),
            height: max(SynapseNode.minHeight, node.height)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                hoverTarget = .none
            }
        }
        .onContinuousHover { phase in
            guard !isEditing else {
                hoverTarget = .none
                return
            }
            switch phase {
            case .active(let location):
                updateHoverTarget(at: location)
            case .ended:
                hoverTarget = .none
            @unknown default:
                hoverTarget = .none
            }
        }
        .position(node.position)
        .applyIf(!isEditing) { view in
            view.gesture(combinedGesture)
        }
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded { handleDoubleTap() }
        )
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded { handleSingleTap() }
        )
        .contextMenu { nodeContextMenu }
        .onAppear {
            localText = node.text
            localRichTextData = node.richTextData
        }
        .onChange(of: isEditing) { _, newValue in
            viewModel.isEditingNode = newValue
        }
        .onChange(of: isSelected) { _, newValue in
            if !newValue { finishEditing() }
        }
        .onChange(of: viewModel.nodeToEditID) { _, newValue in
            if newValue == node.id { startEditing() }
        }
        // Sincronizza lo stato locale quando il nodo viene modificato dal ViewModel
        .onChange(of: node.richTextData) { _, newValue in
            localRichTextData = newValue
        }
        .onChange(of: node.text) { _, newValue in
            localText = newValue
        }
        // Forza refresh quando viene applicato uno stile
        .onChange(of: viewModel.styleVersion) { _, _ in
            // Risincronizza i dati dal nodo quando viene applicato uno stile
            if isSelected {
                localRichTextData = node.richTextData
                localText = node.text
            }
        }
    }
    
    // MARK: - Gestione Click
    
    private func handleSingleTap() {
        if isEditing {
            finishEditing()
            return
        }
        viewModel.selectNode(node)
    }
    
    private func handleDoubleTap() {
        viewModel.selectNode(node)
        startEditing()
    }
    
    private func startEditing() {
        isEditing = true
        viewModel.isEditingNode = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak viewModel] in
            viewModel?.clearNodeEditingFlag()
        }
    }
    
    private func finishEditing() {
        guard isEditing else { return }
        isEditing = false
        viewModel.isEditingNode = false
        // IMPORTANTE: Resetta activeTextView per permettere alla toolbar di funzionare in node-mode
        viewModel.activeTextView = nil
        viewModel.updateNodeRichText(node, richTextData: localRichTextData, plainText: localText)
        
        // Auto-resize: adatta la larghezza al testo
        autoResizeToFitText()
    }
    
    /// Calcola la larghezza necessaria per il testo e aggiorna node.width
    private func autoResizeToFitText() {
        let text = localText.isEmpty ? "..." : localText
        let font = NSFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        let textSize = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes
        )
        
        // Larghezza = testo + padding (8 per lato = 16 totale) + margine extra
        let requiredWidth = ceil(textSize.width) + (horizontalPadding * 2) + 16
        node.width = max(SynapseNode.minWidth, requiredWidth)
    }
    
    // MARK: - Gesture Combinata
    
    private var combinedGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if isEditing { return }
                let shiftPressed = NSEvent.modifierFlags.contains(.shift)
                if shiftPressed {
                    if !viewModel.isLinking {
                        // "What you see is what you link": usa lo stato hoverTarget corrente
                        // invece di ricalcolare da zero (l'utente ha già visto l'halo)
                        switch hoverTarget {
                        case .word(let rect, let range):
                            viewModel.startLinking(from: node, wordRange: range, wordRect: rect)
                        case .node, .none:
                            viewModel.startLinking(from: node)
                        }
                    }
                    viewModel.updateLinkingDrag(to: value.location)
                } else {
                    if viewModel.isLinking {
                        viewModel.cancelLinking()
                    }
                    viewModel.updateNodePosition(node, to: value.location)
                }
            }
            .onEnded { value in
                if viewModel.isLinking {
                    viewModel.endLinking(at: value.location)
                }
            }
    }
    
    /// Converte un punto da coordinate del NodeView a coordinate della textView
    /// Tiene conto dei padding applicati alla textView
    private func convertToTextViewCoordinates(_ point: CGPoint) -> CGPoint {
        // La textView è inset di horizontalPadding (4) e verticalPadding (2) rispetto al NodeView
        // Detection: sottrarre padding converte da Node Space a Text Space
        return CGPoint(
            x: point.x - horizontalPadding,
            y: point.y - verticalPadding
        )
    }
    
    /// Aggiorna lo stato hoverTarget in base alla posizione del mouse
    private func updateHoverTarget(at point: CGPoint) {
        guard let textView = textViewRef as? FormattableTextView else {
            print("[DEBUG] updateHoverTarget: textViewRef is nil, falling back to .node")
            hoverTarget = .node
            return
        }
        
        // Converti da Node Space a Text Space (sottraendo padding)
        let textPoint = convertToTextViewCoordinates(point)
        print("[DEBUG] updateHoverTarget: point=\(point), textPoint=\(textPoint)")
        
        if let wordHit = textView.findWord(at: textPoint) {
            // Trovata parola: converti il rettangolo da Text Space a Node Space (aggiungendo padding)
            let adjustedRect = CGRect(
                x: wordHit.rect.origin.x + horizontalPadding,
                y: wordHit.rect.origin.y + verticalPadding,
                width: wordHit.rect.width,
                height: wordHit.rect.height
            )
            print("[DEBUG] Found word '\(wordHit.word)' at rect=\(adjustedRect)")
            hoverTarget = .word(rect: adjustedRect, range: wordHit.range)
        } else {
            print("[DEBUG] No word found at textPoint=\(textPoint)")
            hoverTarget = .node
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var nodeContextMenu: some View {
        Button(role: .destructive) {
            viewModel.deleteNode(node)
        } label: {
            Label("Elimina", systemImage: "trash")
        }
        
        Divider()
        
        Button("Modifica testo") { handleDoubleTap() }
        
        Divider()
        
        Menu("Colore") {
            Button("Default") { node.hexColor = nil }
            Button("Rosso") { node.hexColor = "#FFCDD2" }
            Button("Verde") { node.hexColor = "#C8E6C9" }
            Button("Blu") { node.hexColor = "#BBDEFB" }
            Button("Giallo") { node.hexColor = "#FFF9C4" }
            Button("Viola") { node.hexColor = "#E1BEE7" }
            Button("Arancione") { node.hexColor = "#FFE0B2" }
        }
        
        Divider()
        
        Button {
            selectImage()
        } label: {
            Label("Aggiungi Immagine", systemImage: "photo")
        }
    }
    
    // MARK: - Computed Colors
    
    private var nodeBackgroundColor: Color {
        if isLinkingSource {
            return Color.accentColor.opacity(0.15)
        }
        if isPotentialTarget {
            return Color.green.opacity(0.1)
        }
        if isEditing {
            return Color(.textBackgroundColor)
        }
        if let hex = node.hexColor, !hex.isEmpty {
            return (Color(hex: hex) ?? Color(.windowBackgroundColor)).opacity(0.7)
        }
        return Color(.windowBackgroundColor).opacity(0.6)
    }
    
    private var borderColor: Color {
        if isLinkingSource { return Color.accentColor }
        if isPotentialTarget { return Color.green }
        if isSelected { return Color.accentColor }
        return Color(.separatorColor).opacity(0.5)
    }
    
    private var borderWidth: CGFloat {
        if isSelected { return 2 }
        if isLinkingSource || isPotentialTarget { return 2 }
        return 1
    }
    
    // MARK: - Helpers
    
    private func isLatex(_ text: String) -> Bool {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.hasPrefix("$$") && clean.hasSuffix("$$")
    }
    
    private func extractLatex(from text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 4 else { return clean }
        return String(clean.dropFirst(2).dropLast(2))
    }
    
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                do {
                    let data = try Data(contentsOf: url)
                    DispatchQueue.main.async {
                        node.imageData = data
                    }
                } catch {
                    print("Errore caricamento immagine: \(error)")
                }
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        switch length {
        case 3:
            let r = Double((rgb & 0xF00) >> 8) / 15.0
            let g = Double((rgb & 0x0F0) >> 4) / 15.0
            let b = Double(rgb & 0x00F) / 15.0
            self.init(red: r, green: g, blue: b)
        case 6:
            let r = Double((rgb & 0xFF0000) >> 16) / 255.0
            let g = Double((rgb & 0x00FF00) >> 8) / 255.0
            let b = Double(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b)
        default:
            return nil
        }
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
