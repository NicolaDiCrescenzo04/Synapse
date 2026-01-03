//
//  CanvasView.swift
//  Synapse
//
//  Vista principale della canvas infinita per la mappa concettuale.
//  Supporta pan, zoom, e interazioni con nodi e connessioni.
//
//  SHORTCUT TASTIERA:
//  - TAB: Crea nodo connesso (a destra del selezionato)
//  - ENTER: Crea nodo fratello (sotto il selezionato)
//  - DELETE/BACKSPACE: Elimina selezione
//  - ESCAPE: Deseleziona tutto
//

import SwiftUI
import SwiftData

/// Canvas infinita per la visualizzazione e manipolazione della mappa concettuale.
/// Supporta:
/// - Doppio tap per creare nuovi nodi
/// - Drag per spostare i nodi
/// - Shift+Drag per creare connessioni
/// - TAB per creare nodi connessi
/// - ENTER per creare nodi fratelli
/// - Delete/Backspace per eliminare selezione
/// - Pan e zoom per navigare la canvas
struct CanvasView: View {
    
    // MARK: - Environment
    
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Stato
    
    /// ViewModel per la gestione della mappa
    @State private var viewModel: MapViewModel?
    
    /// Offset corrente della canvas (per pan)
    @State private var canvasOffset: CGSize = .zero
    
    /// Offset temporaneo durante il drag della canvas
    @State private var dragOffset: CGSize = .zero
    
    /// Scala temporanea per il gesto di ingrandimento
    @State private var lastGestureScale: CGFloat = 1.0
    
    /// Focus della canvas (per intercettare la tastiera)
    @FocusState private var isCanvasFocused: Bool
    
    // MARK: - Costanti
    
    /// Dimensioni della canvas virtuale
    private let canvasSize: CGFloat = 10000
    
    /// Centro della canvas
    private var canvasCenter: CGPoint {
        CGPoint(x: canvasSize / 2, y: canvasSize / 2)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Sfondo della canvas
                canvasBackground
                
                // Area scrollabile con contenuto
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    canvasContent
                        .scaleEffect(viewModel?.zoomScale ?? 1.0, anchor: .center)
                        .frame(
                            width: canvasSize * (viewModel?.zoomScale ?? 1.0),
                            height: canvasSize * (viewModel?.zoomScale ?? 1.0)
                        )
                }
                .scrollPosition(id: .constant(Optional<Int>.none))
                .defaultScrollAnchor(.center)
            }
            .focusable()
            .focused($isCanvasFocused)
            .onAppear {
                initializeViewModel()
                // Auto-focus sulla canvas all'avvio
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isCanvasFocused = true
                }
            }
            // MARK: - Keyboard Handling
            
            // DELETE / BACKSPACE: Elimina selezione
            .onKeyPress(.delete) {
                return handleDelete()
            }
            .onKeyPress(.deleteForward) {
                return handleDelete()
            }
            // Fallback per macOS: onDeleteCommand (più robusto)
            .onDeleteCommand {
                handleDeleteCommand()
            }
            
            // TAB: Crea nodo connesso a destra
            .onKeyPress(.tab) {
                return handleTab()
            }
            
            // ENTER / RETURN: Crea nodo fratello sotto
            .onKeyPress(.return) {
                return handleReturn(geometry: geometry)
            }
            
            // ESCAPE: Deseleziona tutto
            .onKeyPress(.escape) {
                viewModel?.deselectAll()
                isCanvasFocused = true
                return .handled
            }
        }
        .gesture(magnificationGesture)
        .overlay(zoomHUD, alignment: .bottomLeading)
    }
    
    // MARK: - Sottoviste
    
    /// Sfondo della canvas con colore di sistema
    private var canvasBackground: some View {
        Color(.windowBackgroundColor)
            .ignoresSafeArea()
    }
    
    /// Contenuto della canvas (nodi e connessioni)
    private var canvasContent: some View {
        ZStack {
            // Layer interattivo di background - PRIORITÀ PIÙ BASSA
            // Questo layer riceve i tap SOLO se nessun altro elemento li intercetta
            backgroundInteractionLayer
            
            // Layer connessioni (le connessioni intercettano click solo sulla curva)
            connectionsLayer
            
            // Layer linea temporanea (rubber banding durante Shift+Drag)
            temporaryLinkLayer
            
            // Layer nodi (sopra tutto)
            nodesLayer
        }
    }
    
    /// Layer di background per interazioni (crea nodo, deseleziona)
    private var backgroundInteractionLayer: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { location in
                createNode(at: location)
            }
            .onTapGesture(count: 1) {
                // Single tap deseleziona tutto e riprende il focus
                viewModel?.deselectAll()
                isCanvasFocused = true
            }
    }
    
    /// Layer delle connessioni
    private var connectionsLayer: some View {
        Group {
            if let vm = viewModel {
                ForEach(vm.connections, id: \.id) { connection in
                    ConnectionView(connection: connection, viewModel: vm)
                }
            }
        }
    }
    
    /// Layer della linea temporanea durante il linking
    private var temporaryLinkLayer: some View {
        Group {
            if let vm = viewModel, vm.isLinking, let source = vm.tempLinkSource {
                TemporaryConnectionLine(
                    from: source.position,
                    to: vm.tempDragPoint
                )
                .allowsHitTesting(false) // Non intercetta click
            }
        }
    }
    
    /// Layer dei nodi
    private var nodesLayer: some View {
        Group {
            if let vm = viewModel {
                ForEach(vm.nodes, id: \.id) { node in
                    NodeView(node: node, viewModel: vm)
                }
            }
        }
    }
    
    // MARK: - Inizializzazione
    
    /// Inizializza il ViewModel con il ModelContext
    private func initializeViewModel() {
        if viewModel == nil {
            viewModel = MapViewModel(modelContext: modelContext)
        }
    }
    
    // MARK: - Azioni
    
    /// Crea un nuovo nodo alla posizione specificata
    private func createNode(at location: CGPoint) {
        guard let vm = viewModel else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            let node = vm.addNode(at: location)
            // L'editing viene attivato con delay dentro addNode per permettere
            // alla View di renderizzare prima di attivare il focus
            let nodeID = node.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                vm.nodeToEditID = nodeID
            }
        }
    }
    
    // MARK: - Keyboard Handlers
    
    /// Gestisce la pressione del tasto Delete/Backspace
    /// - Returns: .handled se l'evento è stato gestito, .ignored se deve essere passato ad altri
    private func handleDelete() -> KeyPress.Result {
        guard let vm = viewModel else { return .ignored }
        
        // Non intercettare se siamo in editing mode (nodo o connessione)
        if vm.isEditingNode || vm.isEditingConnection {
            return .ignored
        }
        
        // Non intercettare se non c'è selezione
        guard vm.selectedNodeID != nil || vm.selectedConnectionID != nil else {
            return .ignored
        }
        
        withAnimation(.easeOut(duration: 0.2)) {
            _ = vm.deleteSelection()
        }
        
        return .handled
    }
    
    /// Fallback per onDeleteCommand (macOS)
    private func handleDeleteCommand() {
        guard let vm = viewModel else { return }
        
        withAnimation(.easeOut(duration: 0.2)) {
            _ = vm.deleteSelection()
        }
    }
    
    /// Gestisce la pressione del tasto TAB
    /// Crea un nodo connesso a destra del nodo selezionato
    /// - Returns: .handled se c'è un nodo selezionato e non siamo in editing, .ignored altrimenti
    private func handleTab() -> KeyPress.Result {
        guard let vm = viewModel else { return .ignored }
        
        // Non intercettare se siamo in editing mode
        if vm.isEditingNode || vm.isEditingConnection {
            return .ignored
        }
        
        // TAB funziona solo se c'è un nodo selezionato
        guard vm.selectedNodeID != nil else {
            return .ignored
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            _ = vm.createConnectedNode()
        }
        
        return .handled
    }
    
    /// Gestisce la pressione del tasto ENTER/RETURN
    /// - Nodo selezionato (non in editing): Crea nodo fratello sotto
    /// - Nessuna selezione: Crea nodo al centro
    /// - In editing: Non fare nulla (lascia che la TextField gestisca)
    /// - Returns: .handled se creiamo un nodo, .ignored se siamo in editing
    private func handleReturn(geometry: GeometryProxy) -> KeyPress.Result {
        guard let vm = viewModel else { return .ignored }
        
        // IMPORTANTE: Non intercettare se siamo in editing mode
        // Lascia che .onSubmit della TextField gestisca l'evento
        if vm.isEditingNode || vm.isEditingConnection {
            return .ignored
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if vm.selectedNodeID != nil {
                // Crea nodo fratello sotto il selezionato
                _ = vm.createSiblingNode()
            } else {
                // Nessuna selezione: crea al centro della canvas
                let centerPoint = CGPoint(
                    x: canvasSize / 2,
                    y: canvasSize / 2
                )
                _ = vm.createNodeAtCenter(centerPoint)
            }
        }
        
        return .handled
    }
    
    // MARK: - Zoom Gestures & HUD
    
    /// Gestore del pinch-to-zoom
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard let vm = viewModel else { return }
                
                // Calcola il delta rispetto all'ultimo valore del gesto
                let delta = value / lastGestureScale
                lastGestureScale = value
                
                // Applica il delta allo zoom corrente
                let newScale = vm.zoomScale * delta
                vm.zoomScale = min(max(newScale, MapViewModel.minZoom), MapViewModel.maxZoom)
            }
            .onEnded { _ in
                // Reset del valore del gesto per il prossimo pinch
                lastGestureScale = 1.0
            }
    }
    
    /// HUD per controllare lo zoom
    private var zoomHUD: some View {
        HStack(spacing: 12) {
            Button(action: { updateZoom(delta: -0.1) }) {
                Image(systemName: "minus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("-", modifiers: [.command]) // Cmd -
            
            Text("\(Int((viewModel?.zoomScale ?? 1.0) * 100))%")
                .monospacedDigit()
                .frame(minWidth: 40)
            
            Button(action: { updateZoom(delta: 0.1) }) {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("+", modifiers: [.command]) // Cmd +
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()
    }
    
    /// Aggiorna lo zoom tramite pulsanti
    private func updateZoom(delta: CGFloat) {
        guard let vm = viewModel else { return }
        let newScale = vm.zoomScale + delta
        withAnimation(.spring(response: 0.3)) {
            vm.zoomScale = min(max(newScale, MapViewModel.minZoom), MapViewModel.maxZoom)
        }
    }
}

// MARK: - Linea Temporanea per Linking

/// Vista per la linea temporanea durante la creazione di una connessione.
/// Mostra una linea tratteggiata dal nodo sorgente al punto del mouse.
struct TemporaryConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    
    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            Color.accentColor.opacity(0.6),
            style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                dash: [8, 4]
            )
        )
        // Freccia temporanea
        arrowHead
    }
    
    /// Freccia alla fine della linea temporanea
    private var arrowHead: some View {
        Path { path in
            let angle = atan2(to.y - from.y, to.x - from.x)
            let arrowSize: CGFloat = 10
            
            let arrowPoint1 = CGPoint(
                x: to.x - arrowSize * cos(angle - .pi / 6),
                y: to.y - arrowSize * sin(angle - .pi / 6)
            )
            
            let arrowPoint2 = CGPoint(
                x: to.x - arrowSize * cos(angle + .pi / 6),
                y: to.y - arrowSize * sin(angle + .pi / 6)
            )
            
            path.move(to: to)
            path.addLine(to: arrowPoint1)
            path.addLine(to: arrowPoint2)
            path.closeSubpath()
        }
        .fill(Color.accentColor.opacity(0.6))
    }
}

// MARK: - Preview

#Preview {
    CanvasView()
        .modelContainer(for: [SynapseNode.self, SynapseConnection.self], inMemory: true)
}




