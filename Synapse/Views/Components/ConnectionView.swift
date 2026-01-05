//
//  ConnectionView.swift
//  Synapse
//
//  Componente per disegnare le connessioni (frecce) tra nodi.
//  Design "Lavagna Infinita": le etichette galleggiano senza box,
//  le frecce arrivano vicinissime al testo.
//
//  GHOST UI:
//  - Riposo: etichetta come testo fluttuante senza sfondo
//  - Hover/Editing: sfondo semi-trasparente + bordo
//
//  INTERAZIONI:
//  - Tap singolo: Seleziona la connessione
//  - Doppio tap: Attiva editing etichetta
//  - Tasto destro: Context menu (Modifica, Elimina)
//

import SwiftUI

/// Vista per una singola connessione tra due nodi.
/// Disegna una curva Bézier con freccia e etichetta galleggiante.
struct ConnectionView: View {
    
    // MARK: - Proprietà
    
    /// La connessione da visualizzare
    let connection: SynapseConnection
    
    /// ViewModel per le operazioni e il focus
    var viewModel: MapViewModel
    
    // MARK: - Stato Locale
    
    /// Testo locale per binding con TextField
    @State private var localLabel: String = ""
    
    /// Indica se la TextField è in focus
    @FocusState private var isLabelFocused: Bool
    
    /// Indica se il mouse è sopra l'etichetta
    @State private var isLabelHovered: Bool = false
    
    // MARK: - Costanti Design (Ghost UI)
    
    private let lineWidth: CGFloat = 2
    private let hitTestWidth: CGFloat = 20
    /// Freccia più piccola per essere più vicina al testo
    private let arrowSize: CGFloat = 9
    private let labelPadding: CGFloat = 3
    
    // MARK: - Computed Properties
    
    private var shouldBeFocused: Bool {
        viewModel.focusedConnectionID == connection.id
    }
    
    private var isEditing: Bool {
        viewModel.editingConnectionID == connection.id
    }
    
    private var isSelected: Bool {
        viewModel.selectedConnectionID == connection.id
    }
    
    /// Mostra l'etichetta se c'è testo, siamo in editing, o abbiamo il focus
    private var shouldShowLabel: Bool {
        !localLabel.isEmpty || isEditing || shouldBeFocused
    }
    
    /// Determina se mostrare lo sfondo dell'etichetta (Ghost UI)
    private var shouldShowLabelBackground: Bool {
        isLabelHovered || isEditing || shouldBeFocused || isSelected
    }
    
    private var lineColor: Color {
        isSelected ? Color.accentColor : Color.secondary
    }
    
    // MARK: - Body
    
    var body: some View {
        if let sourceNode = connection.source,
           let targetNode = connection.target {
            
            // Calcola il punto sorgente (parola o centro nodo)
            let sourcePoint = calculateSourcePoint(for: sourceNode)
            let sourceSize = getEffectiveSourceSize(for: sourceNode)
            let targetCenter = targetNode.position
            
            // Edge-clipping: frecce partono dal bordo dei nodi/parole
            let clippedPoints = calculateClippedPoints(
                from: sourcePoint, sourceSize: sourceSize,
                to: targetCenter, targetSize: targetNode.size
            )
            
            let startPoint = connection.isWordAnchored ? sourcePoint : clippedPoints.start
            let endPoint = clippedPoints.end
            
            let controlPoints = calculateControlPoints(from: startPoint, to: endPoint)
            let curvePath = bezierPath(from: startPoint, to: endPoint, control1: controlPoints.0, control2: controlPoints.1)
            let labelPosition = bezierMidpoint(from: startPoint, to: endPoint, control1: controlPoints.0, control2: controlPoints.1)
            
            Group {
                // Sottolineatura della parola se ancorata
                if connection.isWordAnchored, let range = connection.fromTextRange, let wordRect = calculateWordRect(for: range, in: sourceNode) {
                    let underlineY = sourceNode.position.y - sourceNode.size.height/2 + wordRect.maxY
                    let underlineXStart = sourceNode.position.x - sourceNode.size.width/2 + wordRect.minX
                    let underlineXEnd = sourceNode.position.x - sourceNode.size.width/2 + wordRect.maxX
                    
                    Path { path in
                        path.move(to: CGPoint(x: underlineXStart, y: underlineY))
                        path.addLine(to: CGPoint(x: underlineXEnd, y: underlineY))
                    }
                    .stroke(lineColor, lineWidth: 1.5)
                }
                
                // Linea curva Bézier - VISIBILE
                curvePath
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .allowsHitTesting(false)
                
                // Area cliccabile invisibile
                curvePath
                    .stroke(Color.clear, style: StrokeStyle(lineWidth: hitTestWidth, lineCap: .round))
                    .contentShape(curvePath.strokedPath(StrokeStyle(lineWidth: hitTestWidth, lineCap: .round)))
                    .onTapGesture(count: 2) {
                        viewModel.startEditingConnection(connection)
                    }
                    .onTapGesture(count: 1) {
                        viewModel.selectConnection(connection)
                    }
                    .contextMenu {
                        connectionContextMenu
                    }
                
                // Freccia sulla destinazione
                arrowHead(at: endPoint, control: controlPoints.1)
                    .fill(lineColor)
                    .allowsHitTesting(false)
                
                // Etichetta galleggiante (Ghost UI: senza box di default)
                if shouldShowLabel {
                    connectionLabelView
                        .position(labelPosition)
                }
            }
            .onAppear {
                localLabel = connection.label
            }
            .onChange(of: shouldBeFocused) { _, newValue in
                if newValue {
                    isLabelFocused = true
                }
            }
            .onChange(of: isLabelFocused) { _, newValue in
                if !newValue && (shouldBeFocused || isEditing) {
                    viewModel.stopEditingConnection()
                }
            }
        }
    }
    
    // MARK: - Context Menu
    
    @ViewBuilder
    private var connectionContextMenu: some View {
        Button {
            viewModel.startEditingConnection(connection)
        } label: {
            Label("Modifica etichetta", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive) {
            viewModel.deleteConnection(connection)
        } label: {
            Label("Elimina connessione", systemImage: "trash")
        }
    }
    
    // MARK: - Cardinal Point Anchoring
    
    /// Calcola i punti di ancoraggio ai centri dei lati (N/S/E/W)
    /// invece dell'intersezione angolare. Le frecce si ancorano sempre
    /// al centro del lato più vicino, dando l'illusione che puntino alla parola.
    private func calculateClippedPoints(from source: CGPoint, sourceSize: CGSize, to target: CGPoint, targetSize: CGSize) -> (start: CGPoint, end: CGPoint) {
        let dx = target.x - source.x
        let dy = target.y - source.y
        
        let sourceHalfW = sourceSize.width / 2
        let sourceHalfH = sourceSize.height / 2
        let targetHalfW = targetSize.width / 2
        let targetHalfH = targetSize.height / 2
        
        var startPoint: CGPoint
        var endPoint: CGPoint
        
        // Determina l'asse dominante
        if abs(dx) > abs(dy) {
            // Relazione ORIZZONTALE
            if dx > 0 {
                // Target a DESTRA del source
                startPoint = CGPoint(x: source.x + sourceHalfW, y: source.y) // Centro Destro
                endPoint = CGPoint(x: target.x - targetHalfW, y: target.y)   // Centro Sinistro
            } else {
                // Target a SINISTRA del source
                startPoint = CGPoint(x: source.x - sourceHalfW, y: source.y) // Centro Sinistro
                endPoint = CGPoint(x: target.x + targetHalfW, y: target.y)   // Centro Destro
            }
        } else {
            // Relazione VERTICALE
            if dy > 0 {
                // Target SOTTO il source
                startPoint = CGPoint(x: source.x, y: source.y + sourceHalfH) // Centro Basso
                endPoint = CGPoint(x: target.x, y: target.y - targetHalfH)   // Centro Alto
            } else {
                // Target SOPRA il source
                startPoint = CGPoint(x: source.x, y: source.y - sourceHalfH) // Centro Alto
                endPoint = CGPoint(x: target.x, y: target.y + targetHalfH)   // Centro Basso
            }
        }
        
        return (startPoint, endPoint)
    }
    
    // MARK: - Word-Level Connection Helpers
    
    /// Calcola il punto sorgente della connessione
    /// Se la connessione è ancorata a una parola, calcola la posizione della parola
    private func calculateSourcePoint(for node: SynapseNode) -> CGPoint {
        guard connection.isWordAnchored,
              let range = connection.fromTextRange else {
            return node.position
        }
        
        // Calcola la posizione della parola partendo dal testo del nodo
        if let wordRect = calculateWordRect(for: range, in: node) {
            // Converti da coordinate locali del nodo a coordinate world
            // La freccia parte dal BORDO INFERIORE CENTRALE (per la sottolineatura)
            return CGPoint(
                x: node.position.x - node.size.width/2 + wordRect.midX,
                y: node.position.y - node.size.height/2 + wordRect.maxY
            )
        }
        
        // Fallback al centro del nodo
        return node.position
    }
    
    /// Restituisce la dimensione effettiva della sorgente per il clipping
    /// Per word-anchored connections, restituisce la dimensione della parola
    private func getEffectiveSourceSize(for node: SynapseNode) -> CGSize {
        guard connection.isWordAnchored,
              let range = connection.fromTextRange,
              let wordRect = calculateWordRect(for: range, in: node) else {
            return node.size
        }
        
        // Per word-anchored connections, usa la dimensione della parola
        return wordRect.size
    }
    
    /// Calcola il rettangolo di una parola data dal range nel testo del nodo
    /// Include safety check per range invalidi (quando il testo è stato modificato)
    /// - Returns: Il CGRect della parola in coordinate locali del nodo, o nil se non calcolabile
    private func calculateWordRect(for range: NSRange, in node: SynapseNode) -> CGRect? {
        // SAFETY CHECK: Verifica che il range sia valido per il testo corrente
        let textLength = (node.text as NSString).length
        guard range.location >= 0,
              range.length > 0,
              range.location + range.length <= textLength else {
            // Range invalido - il testo è stato modificato dopo la creazione della connessione
            return nil
        }
        
        // Crea un layout temporaneo per calcolare la posizione della parola
        let text: NSAttributedString
        if let richData = node.richTextData,
           let attributedString = try? NSAttributedString(
               data: richData,
               options: [.documentType: NSAttributedString.DocumentType.rtfd],
               documentAttributes: nil
           ) {
            text = attributedString
        } else {
            text = NSAttributedString(string: node.text, attributes: [
                .font: NSFont.systemFont(ofSize: 14) // Allinea con RichTextEditor default
            ])
        }
        
        // Safety check aggiuntivo
        guard range.location + range.length <= text.length else {
            return nil
        }
        
        let layoutManager = NSLayoutManager()
        // Larghezza disponibile per il testo (Node Width - Padding Orizzontale)
        // horizontalPadding = 4, quindi total = 8
        let availableWidth = max(1, node.width - 8)
        let textContainer = NSTextContainer(size: CGSize(
            width: availableWidth,
            height: CGFloat.greatestFiniteMagnitude
        ))
        // Assicuriamoci che widthTracksTextView sia false qui perché stiamo definendo una larghezza fissa
        textContainer.widthTracksTextView = false
        
        let textStorage = NSTextStorage(attributedString: text)
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        // Forza il layout per calcoli corretti
        layoutManager.ensureLayout(for: textContainer)
        
        // ---------------------------------------------------------
        // CORREZIONE CENTERING VERTICALE (Mirroring FormattableTextView logic)
        // ---------------------------------------------------------
        
        // Calcola altezza usata dal testo
        let usedRect = layoutManager.usedRect(for: textContainer)
        let contentHeight = usedRect.height
        
        // Calcola altezza disponibile nel nodo (Node Height - Padding Verticale)
        // verticalPadding = 2, quindi total = 4
        let availableHeight = node.height - 4
        
        // Calcola offset Y per centering
        var yOffset: CGFloat = 0
        if contentHeight < availableHeight && contentHeight > 0 {
            yOffset = floor((availableHeight - contentHeight) / 2.0)
        }
        
        // ---------------------------------------------------------
        
        // Calcola il rettangolo del range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Mappa in coordinate del Nodo:
        // X = rect.x + horizontalPadding (4)
        // Y = rect.y + verticalPadding (2) + yOffset (Centering)
        return CGRect(
            x: rect.origin.x + 4,
            y: rect.origin.y + 2 + yOffset,
            width: rect.width,
            height: rect.height
        )
    }
    
    // MARK: - Curva Bézier
    
    private func bezierPath(from start: CGPoint, to end: CGPoint, control1: CGPoint, control2: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }
    }
    
    private func calculateControlPoints(from source: CGPoint, to target: CGPoint) -> (CGPoint, CGPoint) {
        let dx = target.x - source.x
        let dy = target.y - source.y
        let distance = hypot(dx, dy)
        
        let controlOffset = min(max(distance * 0.4, 40), 120)
        
        if abs(dx) > abs(dy) {
            return (
                CGPoint(x: source.x + controlOffset * (dx > 0 ? 1 : -1), y: source.y),
                CGPoint(x: target.x - controlOffset * (dx > 0 ? 1 : -1), y: target.y)
            )
        } else {
            return (
                CGPoint(x: source.x, y: source.y + controlOffset * (dy > 0 ? 1 : -1)),
                CGPoint(x: target.x, y: target.y - controlOffset * (dy > 0 ? 1 : -1))
            )
        }
    }
    
    private func bezierMidpoint(from start: CGPoint, to end: CGPoint, control1: CGPoint, control2: CGPoint) -> CGPoint {
        let t: CGFloat = 0.5
        let mt = 1 - t
        
        let x = mt * mt * mt * start.x +
                3 * mt * mt * t * control1.x +
                3 * mt * t * t * control2.x +
                t * t * t * end.x
        
        let y = mt * mt * mt * start.y +
                3 * mt * mt * t * control1.y +
                3 * mt * t * t * control2.y +
                t * t * t * end.y
        
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Freccia (Arrowhead)
    
    private func arrowHead(at point: CGPoint, control: CGPoint) -> Path {
        Path { path in
            let angle = atan2(point.y - control.y, point.x - control.x)
            
            let arrowPoint1 = CGPoint(
                x: point.x - arrowSize * cos(angle - .pi / 7),
                y: point.y - arrowSize * sin(angle - .pi / 7)
            )
            
            let arrowPoint2 = CGPoint(
                x: point.x - arrowSize * cos(angle + .pi / 7),
                y: point.y - arrowSize * sin(angle + .pi / 7)
            )
            
            path.move(to: point)
            path.addLine(to: arrowPoint1)
            path.addLine(to: arrowPoint2)
            path.closeSubpath()
        }
    }
    
    /// Etichetta con sfondo "maschera" e dimensione auto-fit
    /// Usa il trucco ZStack: Text invisibile sotto per determinare la larghezza
    private var connectionLabelView: some View {
        ZStack {
            // Text invisibile che determina la larghezza naturale
            Text(localLabel.isEmpty ? "etichetta..." : localLabel)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .opacity(0)
            
            // TextField sovrapposta che si adatta alla dimensione del Text
            TextField("etichetta...", text: $localLabel)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .focused($isLabelFocused)
        }
        .fixedSize(horizontal: true, vertical: true)
        // SEMPRE: sfondo pieno che "maschera" la linea sotto
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        // Bordo solo su hover/editing/focus
        .overlay(
            Group {
                if shouldShowLabelBackground {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(labelBorderColor, lineWidth: 1)
                }
            }
        )
        .onHover { hovering in
            isLabelHovered = hovering
        }
        .onSubmit {
            viewModel.updateConnectionLabel(connection, newLabel: localLabel)
            isLabelFocused = false
            viewModel.stopEditingConnection()
        }
        .onChange(of: localLabel) { _, newValue in
            viewModel.updateConnectionLabel(connection, newLabel: newValue)
        }
    }
    
    /// Colore del bordo dell'etichetta
    private var labelBorderColor: Color {
        if isSelected || isEditing || shouldBeFocused {
            return Color.accentColor
        }
        return Color(.separatorColor).opacity(0.5)
    }
}
