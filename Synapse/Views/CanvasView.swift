//
//  CanvasView.swift
//  Synapse
//
//  Vista principale della canvas infinita per la mappa concettuale.
//  Versione RIFATTORIZZATA: Navigazione manuale (Pan & Zoom) senza ScrollView.
//

import SwiftUI
import SwiftData

struct CanvasView: View {
    
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Stato
    @State private var viewModel: MapViewModel?
    @FocusState private var isCanvasFocused: Bool
    
    // Gesture State temporanei per fluidità
    @State private var dragOffset: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1.0
    
    // Stato per rubber band selection
    @State private var isSelecting: Bool = false
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { geometry in
            // 1. TRACKPAD WRAPPER (Top Level)
            // Avvolge tutto il contenuto per intercettare gli eventi scrollWheel del trackpad
            TrackpadReader { dx, dy in
                viewModel?.pan(deltaX: dx, deltaY: dy)
            } content: {
                ZStack {
                    // 2. GESTURE HANDLER LAYER (Fondo)
                    // Questo layer cattura drag (panning con click) e tap.
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 5)
                                .onChanged { value in
                                    guard let vm = viewModel else { return }
                                    
                                    // Converti in coordinate world
                                    let worldStart = screenToWorld(value.startLocation, vm: vm)
                                    let worldCurrent = screenToWorld(value.location, vm: vm)
                                    
                                    if !isSelecting {
                                        // Inizia selezione rubber band
                                        isSelecting = true
                                        let additive = NSEvent.modifierFlags.contains(.shift)
                                        vm.startSelection(at: worldStart, additive: additive)
                                    }
                                    
                                    vm.updateSelection(to: worldCurrent)
                                }
                                .onEnded { value in
                                    viewModel?.endSelection()
                                    isSelecting = false
                                }
                        )
                        // DOUBLE TAP: Crea nodo
                        .onTapGesture(count: 2) { location in
                            if let vm = viewModel {
                                let worldLocation = screenToWorld(location, vm: vm)
                                createNode(at: worldLocation)
                            }
                        }
                        // SINGLE TAP: Deseleziona e Focus Canvas
                        .onTapGesture(count: 1) {
                            viewModel?.deselectAll()
                            isCanvasFocused = true // Recupera focus per permettere Delete
                        }
                    
                    // 3. WORLD CONTENT (Mondo Virtuale)
                    Group {
                        ZStack(alignment: .topLeading) {
                            groupsLayer          // Gruppi (parentesi graffe) - sotto tutto
                            connectionsLayer
                            temporaryLinkLayer
                            rubberBandLayer
                            nodesLayer
                        }
                    }
                    .scaleEffect(viewModel?.zoomScale ?? 1.0, anchor: .topLeading)
                    .offset(x: (viewModel?.panOffset.x ?? 0) + dragOffset.width,
                            y: (viewModel?.panOffset.y ?? 0) + dragOffset.height)
                }
                .focusable() // Rende la view capace di ricevere eventi tastiera
                .focusEffectDisabled(true) // Nasconde il riquadro di focus (anello blu)
                .focused($isCanvasFocused)
                // GESTURE ZOOM (Pinch)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            guard let vm = viewModel else { return }
                            let delta = value / lastMagnification
                            lastMagnification = value
                            
                            let anchor = vm.currentCursorPosition ?? CGPoint(x: geometry.size.width/2, y: geometry.size.height/2)
                            vm.processZoom(delta: delta, anchor: anchor)
                        }
                        .onEnded { _ in
                            lastMagnification = 1.0
                        }
                )
                // TRACKING MOUSE
                .onContinuousHover { phase in
                    guard let vm = viewModel else { return }
                    switch phase {
                    case .active(let location):
                        vm.currentCursorPosition = location
                    case .ended:
                        vm.currentCursorPosition = nil
                    }
                }
                .onAppear {
                    initializeViewModel()
                    centerInitialMappa(geometry: geometry)
                    // EDUCATIONAL: In SwiftUI struct views, non c'è rischio di retain cycle con @State/@FocusState
                    // perché le struct non creano cicli di riferimento. Tuttavia, il delay async è comunque sicuro.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                         isCanvasFocused = true
                    }
                }
                // KEYBOARD
                .onKeyPress(.delete) { handleDelete() }
                .onKeyPress(.deleteForward) { handleDelete() }
                .onDeleteCommand { handleDeleteCommand() }
                .onKeyPress(.tab) { handleTab() }
                .onKeyPress(.return) { handleReturn(geometry: geometry) }
                // Undo/Redo: Cmd+Z / Cmd+Shift+Z
                .onKeyPress(keys: [.init("z")]) { keyPress in
                    guard keyPress.modifiers.contains(.command) else { return .ignored }
                    guard let vm = viewModel else { return .ignored }
                    // Non eseguire undo/redo se stiamo editando testo (NSTextView gestisce il suo undo)
                    if vm.isEditingNode || vm.isEditingConnection { return .ignored }
                    
                    if keyPress.modifiers.contains(.shift) {
                        // Cmd+Shift+Z = Redo
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.redo()
                        }
                    } else {
                        // Cmd+Z = Undo
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.undo()
                        }
                    }
                    return .handled
                }
                .onKeyPress(.escape) {
                    viewModel?.deselectAll()
                    isCanvasFocused = true
                    return .handled
                }
                // Quando si esce dall'editing di un nodo, ripristina il focus sulla canvas
                // Usando un delay minimo per permettere a SwiftUI di completare il ciclo di rendering
                .onChange(of: viewModel?.isEditingNode) { oldValue, newValue in
                    if oldValue == true && newValue == false {
                        // FIX: Delay per permettere a SwiftUI di completare la transizione
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isCanvasFocused = true
                        }
                    }
                }
            }
        }
        .overlay(zoomHUD, alignment: .bottomLeading)
        // Toolbar di formattazione - appare quando un nodo è selezionato (non in editing)
        .overlay(alignment: .top) {
            if let vm = viewModel,
               !vm.selectedNodeIDs.isEmpty {
                TextFormattingToolbar(
                    onBold: { vm.applyBoldToSelectedNode() },
                    onItalic: { vm.applyItalicToSelectedNode() },
                    onUnderline: { vm.applyUnderlineToSelectedNode() },
                    onRed: { vm.applyRedColorToSelectedNode() },
                    onLatex: { vm.insertLatexDelimiters() }
                )
                .padding(.top, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: vm.selectedNodeID)
            }
        }
        // Toolbar di raggruppamento - appare quando 2+ nodi sono selezionati
        .overlay(alignment: .bottom) {
            if let vm = viewModel,
               vm.selectedNodeIDs.count >= 2,
               !vm.isEditingNode {
                GroupingToolbar(
                    onGroupWithText: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            _ = vm.createGroup()
                        }
                    },
                    onGroupWithLink: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            _ = vm.createGroupWithLink()
                        }
                    }
                )
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.2), value: vm.selectedNodeIDs.count)
            }
        }
        .background(Color(NSColor.windowBackgroundColor)) // Sfondo app
    }
    
    // MARK: - Helper Coordinate
    
    /// Converte Screen -> World
    private func screenToWorld(_ point: CGPoint, vm: MapViewModel) -> CGPoint {
        // Inverse Transformation: World = (Screen - Pan) / Zoom
        let panX = vm.panOffset.x + dragOffset.width
        let panY = vm.panOffset.y + dragOffset.height
        
        return CGPoint(
            x: (point.x - panX) / vm.zoomScale,
            y: (point.y - panY) / vm.zoomScale
        )
    }
    
    // MARK: - Subviews Generators
    
    /// Layer per le parentesi graffe dei gruppi (renderizzato sotto le connessioni)
    private var groupsLayer: some View {
        Group {
            if let vm = viewModel {
                ForEach(vm.groups, id: \.id) { group in
                    GroupBraceView(group: group, viewModel: vm)
                }
            }
        }
    }
    
    private var connectionsLayer: some View {
        Group {
            if let vm = viewModel {
                ForEach(vm.connections, id: \.id) { connection in
                    ConnectionView(connection: connection, viewModel: vm)
                }
            }
        }
    }
    
    private var temporaryLinkLayer: some View {
        Group {
            if let vm = viewModel, vm.isLinking, let source = vm.tempLinkSource {
                TemporaryConnectionLine(
                    from: calculateTempLinkStartPoint(source: source, wordRect: vm.tempLinkWordRect),
                    to: vm.tempDragPoint
                )
                .allowsHitTesting(false)
            }
        }
    }
    
    /// Rettangolo di selezione rubber band (azzurro semi-trasparente)
    private var rubberBandLayer: some View {
        Group {
            if let vm = viewModel, let rect = vm.selectionRect {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.15))
                    .overlay(
                        Rectangle()
                            .stroke(Color.accentColor, lineWidth: 1)
                    )
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .allowsHitTesting(false)
            }
        }
    }
    
    /// Calcola il punto di partenza per la linea temporanea durante il linking
    /// - Parameters:
    ///   - source: Nodo sorgente
    ///   - wordRect: Rettangolo della parola (opzionale, per word-level linking)
    /// - Returns: Punto di partenza in coordinate world
    private func calculateTempLinkStartPoint(source: SynapseNode, wordRect: CGRect?) -> CGPoint {
        if let wordRect = wordRect {
            // Word-level: centro BASE della parola in coordinate world (per matchare sottolineatura)
            return CGPoint(
                x: source.position.x - source.size.width/2 + wordRect.midX,
                y: source.position.y - source.size.height/2 + wordRect.maxY
            )
        } else {
            // Node-level: centro del nodo
            return source.position
        }
    }
    
    private var nodesLayer: some View {
        Group {
            if let vm = viewModel {
                ForEach(vm.nodes, id: \.id) { node in
                    NodeView(node: node, viewModel: vm)
                }
            }
        }
    }
    
    // MARK: - Initialization & Helpers
    
    private func initializeViewModel() {
        if viewModel == nil {
            viewModel = MapViewModel(modelContext: modelContext)
        }
    }
    
    private func centerInitialMappa(geometry: GeometryProxy) {
        guard let vm = viewModel, vm.panOffset == .zero else { return }
        // Centriamo su (5000, 5000) - legacy coordination
        let legacyCenter = CGPoint(x: 5000, y: 5000)
        vm.panOffset = CGPoint(
            x: geometry.size.width / 2 - legacyCenter.x,
            y: geometry.size.height / 2 - legacyCenter.y
        )
    }
    
    private func createNode(at location: CGPoint) {
        guard let vm = viewModel else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            _ = vm.addNode(at: location)
        }
    }
    
    // MARK: - Keyboard Handlers
    
    private func handleDelete() -> KeyPress.Result {
        guard let vm = viewModel else { return .ignored }
        if vm.isEditingNode || vm.isEditingConnection { return .ignored }
        guard vm.selectedNodeID != nil || vm.selectedConnectionID != nil else { return .ignored }
        withAnimation(.easeOut(duration: 0.2)) { _ = vm.deleteSelection() }
        return .handled
    }
    
    private func handleDeleteCommand() {
        guard let vm = viewModel else { return }
        withAnimation(.easeOut(duration: 0.2)) { _ = vm.deleteSelection() }
    }
    
    private func handleTab() -> KeyPress.Result {
        guard let vm = viewModel else { return .ignored }
        if vm.isEditingNode || vm.isEditingConnection { return .ignored }
        guard vm.selectedNodeID != nil else { return .ignored }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { _ = vm.createConnectedNode() }
        return .handled
    }
    
    private func handleReturn(geometry: GeometryProxy) -> KeyPress.Result {
        guard let vm = viewModel else { return .ignored }
        if vm.isEditingNode || vm.isEditingConnection { return .ignored }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if vm.selectedNodeID != nil {
                _ = vm.createSiblingNode()
            } else {
                let worldCenter = screenToWorld(CGPoint(x: geometry.size.width/2, y: geometry.size.height/2), vm: vm)
                _ = vm.createNodeAtCenter(worldCenter)
            }
        }
        return .handled
    }
    
    // MARK: - Zoom HUD
    
    private var zoomHUD: some View {
        HStack(spacing: 12) {
            Button(action: { updateZoom(delta: 0.9) }) {
                Image(systemName: "minus").frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("-", modifiers: [.command])
            
            Text("\(Int((viewModel?.zoomScale ?? 1.0) * 100))%")
                .monospacedDigit()
                .frame(minWidth: 40)
            
            Button(action: { updateZoom(delta: 1.1) }) {
                Image(systemName: "plus").frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("+", modifiers: [.command])
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()
    }
    
    private func updateZoom(delta: CGFloat) {
        guard let vm = viewModel else { return }
        // Pulsanti zoomano verso il centro dello schermo
        // NOTA: Qui delta è un moltiplicatore (es. 1.1 per +10%)
        // Ma vogliamo che funzioni con la nostra logica processZoom che accetta delta relativo.
        // Simuliamo un evento magnification
        vm.processZoom(delta: delta, anchor: CGPoint(x: 400, y: 300)) // Fallback approssimativo o reale center
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




