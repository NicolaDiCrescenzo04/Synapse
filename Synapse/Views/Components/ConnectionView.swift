//
//  ConnectionView.swift
//  Synapse
//
//  Componente per disegnare le connessioni (frecce) tra nodi.
//  Usa Path per curve Bézier fluide con edge-clipping.
//  Supporta auto-focus per editing immediato dell'etichetta.
//
//  INTERAZIONI:
//  - Tap singolo: Seleziona la connessione
//  - Doppio tap: Attiva editing etichetta
//  - Tasto destro: Context menu (Modifica, Elimina)
//

import SwiftUI

/// Vista per una singola connessione tra due nodi.
/// Disegna una curva Bézier con freccia e etichetta editabile.
/// Le linee partono dal bordo del nodo, non dal centro.
/// IMPORTANTE: L'area cliccabile è SOLO la curva, non l'intera View.
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
    
    // MARK: - Costanti Design
    
    private let lineWidth: CGFloat = 2
    private let hitTestWidth: CGFloat = 20 // Area cliccabile più ampia della linea visibile
    private let arrowSize: CGFloat = 12
    private let labelPadding: CGFloat = 4
    
    // MARK: - Computed Properties
    
    /// Indica se questa connessione deve avere il focus (TextField attiva)
    private var shouldBeFocused: Bool {
        viewModel.focusedConnectionID == connection.id
    }
    
    /// Indica se questa connessione è in modalità editing
    private var isEditing: Bool {
        viewModel.editingConnectionID == connection.id
    }
    
    /// Indica se questa connessione è selezionata
    private var isSelected: Bool {
        viewModel.selectedConnectionID == connection.id
    }
    
    /// Determina se mostrare la TextField per l'etichetta
    /// Mostra se: c'è un'etichetta, siamo in editing, o abbiamo il focus
    private var shouldShowLabel: Bool {
        !localLabel.isEmpty || isEditing || shouldBeFocused
    }
    
    /// Colore della linea (cambia se selezionata)
    private var lineColor: Color {
        isSelected ? Color.accentColor : Color.secondary
    }
    
    // MARK: - Body
    
    var body: some View {
        // Verifica che source e target esistano
        if let sourceNode = connection.source,
           let targetNode = connection.target {
            
            let sourceCenter = sourceNode.position
            let targetCenter = targetNode.position
            
            // Calcola i punti di bordo (edge-clipping) usando le dimensioni effettive dei nodi
            let clippedPoints = calculateClippedPoints(
                from: sourceCenter, sourceSize: sourceNode.size,
                to: targetCenter, targetSize: targetNode.size
            )
            
            let startPoint = clippedPoints.start
            let endPoint = clippedPoints.end
            
            // Calcola i punti di controllo per la curva
            let controlPoints = calculateControlPoints(from: startPoint, to: endPoint)
            
            // Crea il path della curva
            let curvePath = bezierPath(from: startPoint, to: endPoint, control1: controlPoints.0, control2: controlPoints.1)
            
            // Calcola il punto medio per l'etichetta
            let labelPosition = bezierMidpoint(from: startPoint, to: endPoint, control1: controlPoints.0, control2: controlPoints.1)
            
            // IMPORTANTE: Usiamo Group senza ZStack per evitare hit testing su aree vuote
            Group {
                // Linea curva Bézier - VISIBILE
                curvePath
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .allowsHitTesting(false) // La linea sottile non intercetta click
                
                // Area cliccabile invisibile - più spessa per facilitare il click
                curvePath
                    .stroke(Color.clear, style: StrokeStyle(lineWidth: hitTestWidth, lineCap: .round))
                    .contentShape(curvePath.strokedPath(StrokeStyle(lineWidth: hitTestWidth, lineCap: .round)))
                    // Doppio tap: Attiva editing etichetta
                    .onTapGesture(count: 2) {
                        viewModel.startEditingConnection(connection)
                    }
                    // Tap singolo: Seleziona
                    .onTapGesture(count: 1) {
                        viewModel.selectConnection(connection)
                    }
                    .contextMenu {
                        connectionContextMenu
                    }
                
                // Freccia sulla destinazione (ruotata sulla tangente)
                arrowHead(at: endPoint, control: controlPoints.1)
                    .fill(lineColor)
                    .allowsHitTesting(false) // La freccia non intercetta click
                
                // Etichetta editabile al centro della curva
                if shouldShowLabel {
                    connectionLabelView
                        .position(labelPosition)
                } else {
                    // Indicatore cliccabile quando non c'è etichetta
                    // Piccolo cerchio che indica che è possibile aggiungere un'etichetta
                    Circle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .position(labelPosition)
                        .onTapGesture(count: 2) {
                            viewModel.startEditingConnection(connection)
                        }
                        .onTapGesture(count: 1) {
                            viewModel.selectConnection(connection)
                        }
                }
            }
            .onAppear {
                localLabel = connection.label
            }
            // Quando il ViewModel segnala che dobbiamo prendere il focus
            .onChange(of: shouldBeFocused) { _, newValue in
                if newValue {
                    isLabelFocused = true
                }
            }
            // Quando perdiamo il focus, termina editing
            .onChange(of: isLabelFocused) { _, newValue in
                if !newValue && (shouldBeFocused || isEditing) {
                    viewModel.stopEditingConnection()
                }
            }
        }
    }
    
    // MARK: - Context Menu
    
    /// Menu contestuale per la connessione
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
    
    // MARK: - Edge Clipping (Matematica Vettoriale)
    
    /// Calcola i punti di inizio e fine "clippati" sui bordi dei nodi.
    /// Le linee partono dal bordo del rettangolo, non dal centro.
    /// - Parameters:
    ///   - source: Centro del nodo sorgente
    ///   - sourceSize: Dimensioni del nodo sorgente
    ///   - target: Centro del nodo target
    ///   - targetSize: Dimensioni del nodo target
    private func calculateClippedPoints(from source: CGPoint, sourceSize: CGSize, to target: CGPoint, targetSize: CGSize) -> (start: CGPoint, end: CGPoint) {
        // Calcola l'angolo tra i due centri
        let angle = atan2(target.y - source.y, target.x - source.x)
        
        // Calcola l'offset per il source (punto di partenza sul bordo)
        let startOffset = calculateEdgeOffset(angle: angle, width: sourceSize.width, height: sourceSize.height)
        let startPoint = CGPoint(
            x: source.x + startOffset.x,
            y: source.y + startOffset.y
        )
        
        // Calcola l'offset per il target (punto di arrivo sul bordo)
        // L'angolo è opposto per il target
        let endOffset = calculateEdgeOffset(angle: angle + .pi, width: targetSize.width, height: targetSize.height)
        let endPoint = CGPoint(
            x: target.x + endOffset.x,
            y: target.y + endOffset.y
        )
        
        return (startPoint, endPoint)
    }
    
    /// Calcola l'offset dal centro al bordo del nodo nella direzione specificata.
    /// Usa la matematica per trovare l'intersezione con il bordo del rettangolo.
    private func calculateEdgeOffset(angle: CGFloat, width: CGFloat, height: CGFloat) -> CGPoint {
        let halfWidth = width / 2
        let halfHeight = height / 2
        
        // Calcola le coordinate normalizzate
        let cos_a = cos(angle)
        let sin_a = sin(angle)
        
        // Trova quale bordo viene intersecato
        // Usa il rapporto tra tangente e aspect ratio
        let aspectRatio = halfWidth / halfHeight
        
        var offsetX: CGFloat
        var offsetY: CGFloat
        
        if abs(cos_a) > abs(sin_a) * aspectRatio {
            // Interseca il bordo verticale (sinistro o destro)
            offsetX = cos_a > 0 ? halfWidth : -halfWidth
            offsetY = halfWidth * tan(angle)
            // Clamp per evitare overflow
            offsetY = max(-halfHeight, min(halfHeight, offsetY))
        } else {
            // Interseca il bordo orizzontale (sopra o sotto)
            offsetY = sin_a > 0 ? halfHeight : -halfHeight
            offsetX = halfHeight / tan(angle)
            // Clamp per evitare overflow
            offsetX = max(-halfWidth, min(halfWidth, offsetX))
        }
        
        return CGPoint(x: offsetX, y: offsetY)
    }
    
    // MARK: - Curva Bézier
    
    /// Crea il path della curva Bézier cubica.
    private func bezierPath(from start: CGPoint, to end: CGPoint, control1: CGPoint, control2: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            path.addCurve(to: end, control1: control1, control2: control2)
        }
    }
    
    /// Calcola i punti di controllo per una curva Bézier a "S" morbida.
    /// I punti di controllo dipendono dalla distanza e dall'angolo tra i nodi.
    private func calculateControlPoints(from source: CGPoint, to target: CGPoint) -> (CGPoint, CGPoint) {
        let dx = target.x - source.x
        let dy = target.y - source.y
        let distance = hypot(dx, dy)
        
        // Offset proporzionale alla distanza (minimo 40, massimo 120)
        let controlOffset = min(max(distance * 0.4, 40), 120)
        
        // Determina la direzione principale
        if abs(dx) > abs(dy) {
            // Movimento principalmente orizzontale → curva esce orizzontalmente
            return (
                CGPoint(x: source.x + controlOffset * (dx > 0 ? 1 : -1), y: source.y),
                CGPoint(x: target.x - controlOffset * (dx > 0 ? 1 : -1), y: target.y)
            )
        } else {
            // Movimento principalmente verticale → curva esce verticalmente
            return (
                CGPoint(x: source.x, y: source.y + controlOffset * (dy > 0 ? 1 : -1)),
                CGPoint(x: target.x, y: target.y - controlOffset * (dy > 0 ? 1 : -1))
            )
        }
    }
    
    /// Calcola il punto medio della curva Bézier (per posizionare l'etichetta).
    private func bezierMidpoint(from start: CGPoint, to end: CGPoint, control1: CGPoint, control2: CGPoint) -> CGPoint {
        // Usa t = 0.5 per il punto medio della curva Bézier cubica
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
    
    /// Crea la forma della freccia alla destinazione.
    /// La freccia è ruotata in base alla tangente della curva nel punto finale.
    private func arrowHead(at point: CGPoint, control: CGPoint) -> Path {
        Path { path in
            // Calcola l'angolo tangente alla curva nel punto finale
            // (direzione dal control point al punto finale)
            let angle = atan2(point.y - control.y, point.x - control.x)
            
            // Calcola i punti della freccia
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
    
    // MARK: - Etichetta Editabile
    
    /// Vista per l'etichetta della connessione con TextField editabile.
    private var connectionLabelView: some View {
        TextField("etichetta...", text: $localLabel)
            .textFieldStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.primary)
            .multilineTextAlignment(.center)
            .frame(minWidth: 60, maxWidth: 120)
            .padding(.horizontal, labelPadding * 2)
            .padding(.vertical, labelPadding)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(labelBackgroundColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(borderColor, lineWidth: isSelected || isEditing || shouldBeFocused ? 1.5 : 0)
            )
            .focused($isLabelFocused)
            .onSubmit {
                viewModel.updateConnectionLabel(connection, newLabel: localLabel)
                isLabelFocused = false
                viewModel.stopEditingConnection()
            }
            .onChange(of: localLabel) { _, newValue in
                viewModel.updateConnectionLabel(connection, newLabel: newValue)
            }
    }
    
    /// Colore di sfondo dell'etichetta
    private var labelBackgroundColor: Color {
        Color(.windowBackgroundColor)
    }
    
    /// Colore del bordo dell'etichetta
    private var borderColor: Color {
        if isSelected || isEditing || shouldBeFocused {
            return Color.accentColor
        }
        return Color.clear
    }
}




