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

// MARK: - Resize Edge Enum

/// Enum per identificare quale maniglia di resize è usata
enum ResizeEdge {
    case trailing   // Destra - resize orizzontale
    case bottom     // Basso - resize verticale
    case corner     // Angolo basso-destra - resize libero
}

struct NodeView: View {
    
    // MARK: - Proprietà
    
    let node: SynapseNode
    var viewModel: MapViewModel
    
    var isSelected: Bool {
        viewModel.selectedNodeIDs.contains(node.id)
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
    @State private var lastDragTranslation: CGSize = .zero
    
    /// Riferimento alla NSTextView per word hit testing durante il linking
    @State private var textViewRef: NSTextView?
    
    /// Stato corrente dell'hover per feedback visivo pre-drag
    @State private var hoverTarget: HoverTarget = .none
    
    /// Set di range delle parole selezionate con Cmd+Click per multi-word linking
    @State private var selectedWordRanges: Set<NSRange> = []
    
    // MARK: - Resize State
    
    /// Dimensioni iniziali quando inizia il resize
    @State private var resizeStartSize: CGSize = .zero
    
    /// Flag per tracciare se siamo in modalità resize
    @State private var isResizing: Bool = false
    
    /// Altezza dinamica riportata dal RichTextEditor (per manual wrap mode)
    @State private var reportedContentHeight: CGFloat = 0
    
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
                // FIX: Passa SEMPRE la larghezza del nodo così il testo rimane centrato durante la digitazione
                // Prima passavamo nil per nodi non manuallySized, ma questo causava textContainer infinito
                // e il testo appariva spostato a sinistra durante l'editing
                let editorWidth = node.width - (horizontalPadding * 2) - 8
                RichTextEditor(
                    data: $localRichTextData,
                    plainText: $localText,
                    isEditable: true,
                    explicitWidth: editorWidth,
                    shouldWrapText: node.isManuallySized,
                    onCommit: { finishEditing() },
                    onResolveEditor: { textView in
                        viewModel.activeTextView = textView
                    },
                    onContentHeightChanged: { height in
                        handleContentHeightChange(height)
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
                    SmartLatexView(latex: extractLatex(from: localText))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                } else if localRichTextData != nil && !localText.isEmpty {
                    RichTextEditor(
                        data: $localRichTextData,
                        plainText: $localText,
                        isEditable: false,
                        explicitWidth: node.isManuallySized ? node.width - (horizontalPadding * 2) - 8 : nil,
                        shouldWrapText: node.isManuallySized,
                        onResolveEditor: { textView in
                            textViewRef = textView
                        },
                        onContentHeightChanged: { height in
                            handleContentHeightChange(height)
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
                        explicitWidth: node.isManuallySized ? node.width - (horizontalPadding * 2) - 8 : nil,
                        shouldWrapText: node.isManuallySized,
                        onResolveEditor: { textView in
                            textViewRef = textView
                        },
                        onContentHeightChanged: { height in
                            handleContentHeightChange(height)
                        }
                    )
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .opacity(localText.isEmpty ? 0.5 : 1.0)
                    .allowsHitTesting(false)
                }
            }
            
            // UX: Halo blu PERSISTENTE per parole selezionate con Cmd+Click
            // Queste rimangono evidenziate finché non si deselezione
            if !isEditing {
                ForEach(Array(selectedWordRanges), id: \.self) { range in
                    if let textView = textViewRef as? FormattableTextView,
                       let wordHit = getRectForRange(range, in: textView) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor.opacity(0.6), lineWidth: 1)
                            )
                            .frame(width: wordHit.width + 6, height: wordHit.height + 4)
                            .position(x: wordHit.midX, y: wordHit.midY)
                            .allowsHitTesting(false)
                    }
                }
            }
            
            // UX "Hover Ghost" Halo grigio: Feedback visivo sul target potenziale
            // Appare su hover, ma NON se la parola è già selezionata (evita doppio halo)
            if case .word(let rect, let range) = hoverTarget, !isEditing, !selectedWordRanges.contains(range) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: rect.width + 6, height: rect.height + 4)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }
            
            // MARK: - Resize Handles
            // Maniglie di resize visibili solo quando il nodo è selezionato e non in editing
            if isSelected && !isEditing {
                resizeHandlesOverlay
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
            if !newValue {
                finishEditing()
                // Reset della selezione parole quando il nodo perde focus (standard behavior)
                selectedWordRanges.removeAll()
            }
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
        
        // Cmd+Click: Toggle selezione parola per multi-word linking
        if NSEvent.modifierFlags.contains(.command) {
            if case .word(_, let range) = hoverTarget {
                if selectedWordRanges.contains(range) {
                    selectedWordRanges.remove(range)
                } else {
                    selectedWordRanges.insert(range)
                }
                return  // Non selezionare il nodo, solo toggle della parola
            }
        } else {
            // Tap senza Command: pulisci la selezione (standard Finder behavior)
            selectedWordRanges.removeAll()
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
    /// NOTA: Non fa nulla se il nodo è in modalità manual (isManuallySized = true)
    private func autoResizeToFitText() {
        // In manual mode, la larghezza è fissa - non fare auto-resize
        guard !node.isManuallySized else { return }
        
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
                    // LINKING MODE (Shift+Drag)
                    if !viewModel.isLinking {
                        // Determina se linkare le parole selezionate o la singola parola
                        switch hoverTarget {
                        case .word(let rect, let range):
                            if selectedWordRanges.contains(range) && !selectedWordRanges.isEmpty {
                                // Parti da una parola selezionata -> verifica contiguità
                                let ranges = Array(selectedWordRanges)
                                if isContiguousSelection(ranges) {
                                    // Selezione contigua: linka TUTTE le selezionate
                                    viewModel.startLinking(from: node, wordRanges: ranges, wordRect: rect)
                                    selectedWordRanges.removeAll()
                                }
                                // else: selezione discontinua -> ignora il gesto, non fare nulla
                            } else {
                                // Parti da una parola non selezionata -> linka solo quella
                                viewModel.startLinking(from: node, wordRange: range, wordRect: rect)
                            }
                        case .node, .none:
                            viewModel.startLinking(from: node)
                        }
                    }
                    viewModel.updateLinkingDrag(to: value.location)
                } else {
                    // DRAG MODE (spostamento nodi)
                    if viewModel.isLinking {
                        viewModel.cancelLinking()
                    }
                    
                    // Inizializzazione drag
                    if dragStartPosition == .zero {
                        dragStartPosition = node.position
                        lastDragTranslation = .zero
                        
                        // Se questo nodo non è già selezionato, seleziona SOLO lui
                        if !viewModel.selectedNodeIDs.contains(node.id) {
                            viewModel.selectedNodeIDs = [node.id]
                        }
                    }
                    
                    // Calcola delta incrementale (rispetto all'ultimo frame)
                    let currentDelta = CGSize(
                        width: value.translation.width - lastDragTranslation.width,
                        height: value.translation.height - lastDragTranslation.height
                    )
                    lastDragTranslation = value.translation
                    
                    // Sposta tutti i nodi selezionati
                    viewModel.moveSelectedNodes(delta: currentDelta)
                }
            }
            .onEnded { value in
                if viewModel.isLinking {
                    viewModel.endLinking(at: value.location)
                }
                // Reset stato drag
                dragStartPosition = .zero
                lastDragTranslation = .zero
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
            hoverTarget = .node
            return
        }
        
        // Converti da Node Space a Text Space (sottraendo padding)
        let textPoint = convertToTextViewCoordinates(point)
        
        if let wordHit = textView.findWord(at: textPoint) {
            // Trovata parola: converti il rettangolo da Text Space a Node Space
            let adjustedRect = CGRect(
                x: wordHit.rect.origin.x + horizontalPadding,
                y: wordHit.rect.origin.y + verticalPadding,
                width: wordHit.rect.width,
                height: wordHit.rect.height
            )
            hoverTarget = .word(rect: adjustedRect, range: wordHit.range)
        } else {
            hoverTarget = .node
        }
    }
    
    /// Calcola il rettangolo per un range dato, usando la stessa matematica dell'hover halo
    /// per garantire consistenza visiva perfetta.
    private func getRectForRange(_ range: NSRange, in textView: FormattableTextView) -> CGRect? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }
        
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Aggiungi textContainerInset (stesso calcolo di findWord)
        rect.origin.x += textView.textContainerInset.width
        rect.origin.y += textView.textContainerInset.height
        
        // Converti da Text Space a Node Space (aggiungendo padding - stessa math dell'hover)
        return CGRect(
            x: rect.origin.x + horizontalPadding,
            y: rect.origin.y + verticalPadding,
            width: rect.width,
            height: rect.height
        )
    }
    
    /// Verifica se un set di range forma una selezione contigua.
    /// Restituisce true se tutti i range sono adiacenti (gap ≤ 3 caratteri).
    private func isContiguousSelection(_ ranges: [NSRange]) -> Bool {
        guard ranges.count > 1 else { return true }  // Singolo range è sempre contiguo
        
        // Ordina per posizione nel testo
        let sorted = ranges.sorted { $0.location < $1.location }
        
        for i in 1..<sorted.count {
            let prev = sorted[i - 1]
            let curr = sorted[i]
            
            // Calcola gap tra fine del precedente e inizio del corrente
            let prevEnd = prev.location + prev.length
            let gap = curr.location - prevEnd
            
            // Gap > 3 caratteri = discontinuo
            if gap > 3 {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Resize Handles
    
    /// Overlay con la maniglia di resize (solo angolo basso-destra)
    /// Usa un approccio semplificato con Color.clear + overlay e alignment
    @ViewBuilder
    private var resizeHandlesOverlay: some View {
        let handleSize: CGFloat = 14
        
        Color.clear
            .overlay(alignment: .bottomTrailing) {
                // Maniglia d'angolo - usa .local coordinate space
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: handleSize, height: handleSize)
                    .offset(x: handleSize / 2 - 2, y: handleSize / 2 - 2)
                    .contentShape(Circle().size(width: handleSize + 10, height: handleSize + 10))
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .local)
                            .onChanged { value in
                                if !isResizing {
                                    resizeStartSize = CGSize(width: node.width, height: node.height)
                                    isResizing = true
                                }
                                // Usa translation diretta (più affidabile)
                                let newWidth = resizeStartSize.width + value.translation.width
                                let newHeight = resizeStartSize.height + value.translation.height
                                
                                node.width = max(SynapseNode.minWidth, newWidth)
                                node.height = max(SynapseNode.minHeight, newHeight)
                            }
                            .onEnded { _ in
                                isResizing = false
                                node.isManuallySized = true
                            }
                    )
                    .onHover { hovering in
                        if hovering {
                            NSCursor.crosshair.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
            }
    }
    
    /// Crea una gesture di resize per una specifica edge
    private func resizeGesture(for edge: ResizeEdge) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isResizing {
                    resizeStartSize = CGSize(width: node.width, height: node.height)
                    isResizing = true
                }
                updateNodeSize(for: edge, translation: value.translation)
            }
            .onEnded { _ in
                isResizing = false
                node.isManuallySized = true
            }
    }
    
    /// Aggiorna le dimensioni del nodo in base alla translation del drag
    private func updateNodeSize(for edge: ResizeEdge, translation: CGSize) {
        switch edge {
        case .trailing:
            // Solo larghezza - l'altezza si aggiorna automaticamente via callback
            node.width = max(SynapseNode.minWidth, resizeStartSize.width + translation.width)
        case .bottom:
            // Solo altezza
            node.height = max(SynapseNode.minHeight, resizeStartSize.height + translation.height)
        case .corner:
            // Entrambe le dimensioni
            node.width = max(SynapseNode.minWidth, resizeStartSize.width + translation.width)
            node.height = max(SynapseNode.minHeight, resizeStartSize.height + translation.height)
        }
    }
    
    /// Gestisce i cambiamenti di altezza del contenuto riportati da RichTextEditor
    /// IMPORTANTE: Solo ESPANDE l'altezza quando il contenuto ne richiede di più,
    /// non riduce MAI sotto l'altezza impostata manualmente dall'utente.
    private func handleContentHeightChange(_ contentHeight: CGFloat) {
        // NON modificare l'altezza durante il resize attivo dell'utente
        guard !isResizing else { return }
        
        // Auto-height solo in manual mode
        guard node.isManuallySized else { return }
        
        // Calcola l'altezza richiesta (contenuto + padding)
        let requiredHeight = contentHeight + (verticalPadding * 2) + 8
        
        // SOLO ESPANDERE: aggiorna SOLO se il contenuto richiede PIÙ spazio
        // Non ridurre mai sotto l'altezza attuale (impostata dall'utente)
        let minRequiredHeight = max(SynapseNode.minHeight, requiredHeight)
        
        if minRequiredHeight > node.height {
            // Il contenuto ha bisogno di più spazio - espandi
            node.height = minRequiredHeight
        }
        // Se minRequiredHeight <= node.height, NON fare nulla - mantieni la height manuale
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
        
        // Opzione per resettare le dimensioni manuali
        if node.isManuallySized {
            Divider()
            
            Button {
                node.isManuallySized = false
                autoResizeToFitText()
            } label: {
                Label("Ripristina Dimensione Auto", systemImage: "arrow.counterclockwise")
            }
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
