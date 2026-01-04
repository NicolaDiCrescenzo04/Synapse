//
//  NodeView.swift
//  Synapse
//
//  Componente UI per un singolo nodo nella canvas.
//  Mostra un rettangolo con bordi arrotondati e TextField per il testo.
//  Supporta Shift+Drag per creare connessioni tra nodi.
//
//  MODALITÀ:
//  - View Mode (default): Tap singolo seleziona, mostra Text statico
//  - Edit Mode: Doppio click attiva editing, mostra TextField
//
//  RIDIMENSIONAMENTO:
//  - Maniglia nell'angolo in basso a destra
//  - Drag per ridimensionare, con limiti minimi
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Vista per un singolo nodo della mappa concettuale.
/// Supporta:
/// - Click singolo: Seleziona il nodo (View Mode)
/// - Doppio click: Attiva editing testo (Edit Mode)
/// - Drag: Sposta il nodo
/// - Shift+Drag: Crea connessione
/// - Maniglia angolo: Ridimensiona nodo
struct NodeView: View {
    
    // MARK: - Proprietà
    
    /// Il nodo da visualizzare
    let node: SynapseNode
    
    /// ViewModel per le operazioni
    var viewModel: MapViewModel
    
    /// Indica se questo nodo è selezionato
    var isSelected: Bool {
        viewModel.selectedNodeID == node.id
    }
    
    /// Indica se questo nodo è la sorgente di un linking in corso
    var isLinkingSource: Bool {
        viewModel.isLinking && viewModel.tempLinkSource?.id == node.id
    }
    
    /// Indica se un linking è in corso e questo nodo è un potenziale target
    var isPotentialTarget: Bool {
        viewModel.isLinking && viewModel.tempLinkSource?.id != node.id
    }
    
    // MARK: - Stato Locale
    
    /// Testo locale per binding
    @State private var localText: String = ""
    
    /// Dati rich text locali
    @State private var localRichTextData: Data?
    
    /// Indica se siamo in modalità editing (doppio click)
    @State private var isEditing: Bool = false
    
    /// Focus per la TextField (non più usato con RichTextEditor, ma mantenuto per compatibilità logica se serve)
    @FocusState private var isTextFieldFocused: Bool
    
    /// Posizione iniziale per il calcolo del drag
    @State private var dragStartPosition: CGPoint = .zero
    
    /// Dimensioni durante il resize
    @State private var resizeStartSize: CGSize = .zero
    
    // MARK: - Costanti Design
    
    private let cornerRadius: CGFloat = 12
    private let shadowRadius: CGFloat = 4
    private let resizeHandleSize: CGFloat = 16
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Sfondo del nodo
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(nodeBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(borderColor, lineWidth: borderWidth)
                )
                .shadow(
                    color: shadowColor,
                    radius: isSelected ? shadowRadius * 2 : shadowRadius,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
            
            // Contenuto
            if isEditing {
                // EDIT MODE: RichTextEditor
                RichTextEditor(
                    data: $localRichTextData,
                    plainText: $localText,
                    isEditable: true,
                    onCommit: {
                        finishEditing()
                    }
                )
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            } else {
                // VIEW MODE
                if let imageData = node.imageData, let nsImage = NSImage(data: imageData) {
                    // MODO IMMAGINE
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                        .allowsHitTesting(false)
                } else if isLatex(localText) {
                    // MODO LATEX
                    LatexView(latex: extractLatex(from: localText))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                } else {
                    // MODO TESTO (Rich o Plain)
                    if localRichTextData != nil && !localText.isEmpty {
                        // Se c'è rich text, usiamo l'editor in modalità read-only per rendering fedele
                        RichTextEditor(
                            data: $localRichTextData,
                            plainText: $localText,
                            isEditable: false
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .allowsHitTesting(false)
                    } else {
                        // Fallback Text semplice (più leggero)
                        Text(localText.isEmpty ? "Nuovo nodo..." : localText)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(localText.isEmpty ? .secondary : .primary)
                            .lineLimit(nil)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .allowsHitTesting(false)
                    }
                }
            }
            
            // Maniglia di ridimensionamento (solo se selezionato)
            if isSelected && !isEditing {
                resizeHandle
            }
        }
        .overlay(alignment: .top) {
            if isEditing {
                TextFormattingToolbar()
                    .offset(y: -45) // Posiziona sopra il nodo
                    .transition(.opacity)
            }
        }
        .frame(
            width: max(SynapseNode.minWidth, node.width),
            height: max(SynapseNode.minHeight, node.height)
        )
        .position(node.position)
        .applyIf(!isEditing) { view in
            view.gesture(combinedGesture)
        }
        // Doppio click: Priorità alta per essere riconosciuto prima del singolo
        .highPriorityGesture(
            TapGesture(count: 2)
                .onEnded {
                    handleDoubleTap()
                }
        )
        // Click singolo: Usa simultaneousGesture per rispondere immediatamente
        .simultaneousGesture(
            TapGesture(count: 1)
                .onEnded {
                    handleSingleTap()
                }
        )
        .contextMenu {
            nodeContextMenu
        }
        .onAppear {
            localText = node.text
            localRichTextData = node.richTextData
        }
        // Sincronizza stato editing con ViewModel
        .onChange(of: isEditing) { _, newValue in
            viewModel.isEditingNode = newValue
        }
        // Quando il nodo viene deselezionato, esci da edit mode
        .onChange(of: isSelected) { _, newValue in
            if !newValue {
                finishEditing()
            }
        }
        // Quando il ViewModel segnala che questo nodo deve entrare in editing
        // (es. dopo TAB o ENTER che crea un nuovo nodo)
        .onChange(of: viewModel.nodeToEditID) { _, newValue in
            if newValue == node.id {
                startEditing()
            }
        }
    }
    
    // MARK: - Resize Handle
    
    /// Maniglia per ridimensionare il nodo
    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary)
            .frame(width: resizeHandleSize, height: resizeHandleSize)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.controlBackgroundColor))
                    .shadow(radius: 1)
            )
            .offset(x: -4, y: -4)
            .gesture(resizeGesture)
    }
    
    /// Gesture per il ridimensionamento
    private var resizeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeStartSize == .zero {
                    resizeStartSize = node.size
                }
                
                let newWidth = resizeStartSize.width + value.translation.width
                let newHeight = resizeStartSize.height + value.translation.height
                
                node.size = CGSize(
                    width: max(SynapseNode.minWidth, newWidth),
                    height: max(SynapseNode.minHeight, newHeight)
                )
            }
            .onEnded { _ in
                resizeStartSize = .zero
            }
    }
    
    // MARK: - Gestione Click
    
    /// Gestisce il click singolo: seleziona il nodo (view mode)
    private func handleSingleTap() {
        // Se stavamo editando, finisci l'editing
        if isEditing {
            finishEditing()
            return
        }
        
        // Seleziona il nodo
        viewModel.selectNode(node)
    }
    
    /// Gestisce il doppio click: entra in edit mode
    private func handleDoubleTap() {
        // Prima seleziona il nodo
        viewModel.selectNode(node)
        startEditing()
    }
    
    /// Entra in modalità editing
    private func startEditing() {
        isEditing = true
        viewModel.isEditingNode = true
        
        // FIX: Delay per evitare che il flag venga pulito prima che NodeView lo osservi
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak viewModel] in
            viewModel?.clearNodeEditingFlag()
        }
    }
    
    /// Esce dalla modalità editing
    private func finishEditing() {
        guard isEditing else { return }
        
        isEditing = false
        viewModel.isEditingNode = false
        // Salviamo sia il rich text che il plain text
        viewModel.updateNodeRichText(node, richTextData: localRichTextData, plainText: localText)
    }
    
    // MARK: - Context Menu
    
    /// Menu contestuale per il nodo (tasto destro)
    @ViewBuilder
    private var nodeContextMenu: some View {
        Button(role: .destructive) {
            viewModel.deleteNode(node)
        } label: {
            Label("Elimina", systemImage: "trash")
        }
        
        Divider()
        
        Button("Modifica testo") {
            handleDoubleTap()
        }
        
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
    
    // MARK: - Gesture Combinata
    
    /// Gesture che distingue tra Move (normale) e Link (Shift premuto)
    private var combinedGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }
    
    /// Gestisce l'inizio/aggiornamento del drag
    private func handleDragChanged(_ value: DragGesture.Value) {
        // Se stiamo editando, ignora il drag
        if isEditing { return }
        
        // Controlla se Shift è premuto usando NSEvent
        let shiftPressed = NSEvent.modifierFlags.contains(.shift)
        
        if shiftPressed {
            // MODO LINK: Shift è premuto
            if !viewModel.isLinking {
                // Inizia il linking
                viewModel.startLinking(from: node)
            }
            // Aggiorna la posizione del punto di drag
            viewModel.updateLinkingDrag(to: value.location)
        } else {
            // MODO MOVE: Sposta il nodo
            // Se stavamo facendo linking, annulla
            if viewModel.isLinking {
                viewModel.cancelLinking()
            }
            viewModel.updateNodePosition(node, to: value.location)
        }
    }
    
    /// Gestisce la fine del drag
    private func handleDragEnded(_ value: DragGesture.Value) {
        if viewModel.isLinking {
            // Termina il linking e crea la connessione se valido
            viewModel.endLinking(at: value.location)
        }
        // Se era un drag normale, la posizione è già aggiornata
    }
    
    // MARK: - Computed Colors
    
    /// Colore di sfondo del nodo
    private var nodeBackgroundColor: Color {
        if isLinkingSource {
            // Evidenzia il nodo sorgente durante il linking
            return Color.accentColor.opacity(0.2)
        }
        if isPotentialTarget {
            // Evidenzia i potenziali target durante il linking
            return Color.green.opacity(0.1)
        }
        if let hex = node.hexColor, !hex.isEmpty {
            return Color(hex: hex) ?? Color(.controlBackgroundColor)
        }
        return Color(.controlBackgroundColor)
    }
    
    /// Colore del bordo (evidenziato se selezionato o durante linking)
    private var borderColor: Color {
        if isLinkingSource {
            return Color.accentColor
        }
        if isPotentialTarget {
            return Color.green
        }
        if isSelected {
            return Color.accentColor
        }
        return Color(.separatorColor)
    }
    
    /// Larghezza del bordo
    private var borderWidth: CGFloat {
        if isSelected {
            return 3
        }
        if isLinkingSource || isPotentialTarget {
            return 2.5
        }
        return 1
    }
    
    /// Colore dell'ombra
    private var shadowColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.3)
        }
        return Color.black.opacity(0.15)
    }
    
    // MARK: - Helpers
    
    /// Rileva se il testo è una formula Latex (racchiuso tra $$ )
    private func isLatex(_ text: String) -> Bool {
        return text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("$$") &&
               text.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("$$")
    }
    
    /// Estrae il contenuto Latex rimuovendo i delimitatori
    /// EDUCATIONAL: La versione precedente usava removeFirst(2)/removeLast(2) che causa crash
    /// se la stringa ha meno di 4 caratteri. Questa versione usa dropFirst/dropLast che sono sicuri
    /// e restituiscono una Substring vuota invece di crashare.
    private func extractLatex(from text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // SAFETY: Verifichiamo che la stringa abbia almeno 4 caratteri ($$ all'inizio e alla fine)
        guard clean.count >= 4 else { return clean }
        // dropFirst/dropLast sono sicuri: non crashano mai, restituiscono Substring vuota se necessario
        return String(clean.dropFirst(2).dropLast(2))
    }
    
    /// Apre il pannello di selezione immagine
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
                        // Aggiorna il nodo con l'immagine
                        node.imageData = data
                        // Adatta dimensioni nodo se necessario (semplice resize)
                        if node.width < 200 { node.width = 200 }
                        if node.height < 200 { node.height = 200 }
                    }
                } catch {
                    print("Errore caricamento immagine: \(error)")
                }
            }
        }
    }
}

// MARK: - Color Extension per Hex

extension Color {
    /// Inizializza un Color da una stringa esadecimale.
    /// Supporta formati: "#RGB", "#RRGGBB", "RGB", "RRGGBB"
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let length = hexSanitized.count
        
        switch length {
        case 3: // RGB (12-bit)
            let r = Double((rgb & 0xF00) >> 8) / 15.0
            let g = Double((rgb & 0x0F0) >> 4) / 15.0
            let b = Double(rgb & 0x00F) / 15.0
            self.init(red: r, green: g, blue: b)
            
        case 6: // RRGGBB (24-bit)
            let r = Double((rgb & 0xFF0000) >> 16) / 255.0
            let g = Double((rgb & 0x00FF00) >> 8) / 255.0
            let b = Double(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b)
            
        default:
            return nil
        }
    }
}

// MARK: - View Extension per Modificatori Condizionali

extension View {
    /// Applica una trasformazione alla view solo se la condizione è vera.
    /// Permette di applicare gesture e altri modificatori in modo condizionale.
    /// - Parameters:
    ///   - condition: La condizione da valutare
    ///   - transform: La trasformazione da applicare se la condizione è vera
    /// - Returns: La view trasformata o originale
    @ViewBuilder
    func applyIf<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
