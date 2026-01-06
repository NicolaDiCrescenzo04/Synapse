//
//  MapViewModel.swift
//  Synapse
//
//  ViewModel per la gestione della canvas e delle operazioni sui nodi/connessioni.
//  Usa @Observable per l'integrazione con SwiftUI.
//

import Foundation
import SwiftUI
import SwiftData

/// ViewModel principale per la gestione della mappa concettuale.
/// Espone nodi e connessioni e fornisce metodi per la manipolazione.
@Observable
class MapViewModel {
    
    // MARK: - Proprietà Observable
    
    /// Tutti i nodi presenti nella mappa
    var nodes: [SynapseNode] = []
    
    /// Tutte le connessioni tra i nodi
    var connections: [SynapseConnection] = []
    
    // MARK: - Stato Selezione
    
    /// ID del nodo attualmente selezionato
    var selectedNodeID: UUID?
    
    /// ID della connessione attualmente selezionata
    var selectedConnectionID: UUID?
    
    /// ID del nodo che deve entrare in modalità editing
    /// Usato per comunicare a NodeView quando attivare la TextField
    var nodeToEditID: UUID?
    
    /// Nodo selezionato (computed per retrocompatibilità)
    var selectedNode: SynapseNode? {
        guard let id = selectedNodeID else { return nil }
        return nodes.first { $0.id == id }
    }
    
    /// Connessione selezionata (computed)
    var selectedConnection: SynapseConnection? {
        guard let id = selectedConnectionID else { return nil }
        return connections.first { $0.id == id }
    }
    
    /// Indica se un nodo è attualmente in modalità editing (TextField attiva)
    var isEditingNode: Bool = false
    
    /// Contatore che viene incrementato quando si applica uno stile al testo.
    /// Usato per forzare un refresh della vista quando i dati del nodo cambiano.
    var styleVersion: Int = 0
    
    /// Indica se una connessione è attualmente in modalità editing
    var isEditingConnection: Bool {
        editingConnectionID != nil || focusedConnectionID != nil
    }
    
    /// Riferimento debole alla NSTextView attualmente attiva (se in editing).
    /// Permette alla toolbar di comunicare direttamente con l'editor.
    weak var activeTextView: NSTextView?
    
    // MARK: - Stato Zoom
    
    /// Livello di zoom attuale della canvas (1.0 = 100%)
    var zoomScale: CGFloat = 1.0
    
    /// Livello minimo di zoom (10%)
    static let minZoom: CGFloat = 0.1
    
    /// Livello massimo di zoom (500%)
    static let maxZoom: CGFloat = 5.0
    
    // MARK: - Stato Navigazione (Custom Pan)
    
    /// Offset corrente della telecamera (Pan)
    var panOffset: CGPoint = .zero
    
    /// Posizione corrente del cursore del mouse (per Zoom to Cursor)
    var currentCursorPosition: CGPoint?
    
    // MARK: - Stato Linking (Shift+Drag)
    
    /// Indica se l'utente sta creando una connessione
    var isLinking: Bool = false
    
    /// Nodo di origine durante la creazione della connessione
    var tempLinkSource: SynapseNode?
    
    /// Posizione corrente del mouse durante il drag di linking
    var tempDragPoint: CGPoint = .zero
    
    /// Range della parola sorgente durante word-level linking (opzionale)
    /// Supporta parole multiple per Cmd+Click selection
    /// Se nil o vuoto, il linking parte dal nodo intero
    var tempLinkWordRanges: [NSRange]?
    
    /// Rettangolo della parola sorgente in coordinate locali del nodo (opzionale)
    var tempLinkWordRect: CGRect?
    
    /// ID della connessione che deve ricevere il focus per l'editing dell'etichetta
    /// Usato sia dopo la creazione che per editing successivo
    var focusedConnectionID: UUID?
    
    /// ID della connessione attualmente in modalità editing
    /// La TextField rimane visibile finché questo ID corrisponde
    var editingConnectionID: UUID?
    
    // MARK: - Costanti per Hit Testing e Dimensioni Nodo
    
    /// Raggio entro cui un punto viene considerato "sopra" un nodo
    private let nodeHitRadius: CGFloat = 60
    
    /// Larghezza di default del nodo (per clipping bordi - usa dimensione dinamica)
    static var nodeWidth: CGFloat { CGFloat(SynapseNode.defaultWidth) }
    
    /// Altezza di default del nodo (per clipping bordi - usa dimensione dinamica)
    static var nodeHeight: CGFloat { CGFloat(SynapseNode.defaultHeight) }
    
    /// Offset orizzontale per nuovo nodo connesso (TAB)
    private let connectedNodeOffsetX: CGFloat = 200
    
    /// Offset verticale per nuovo nodo fratello (ENTER)
    private let siblingNodeOffsetY: CGFloat = 100
    
    // MARK: - Dipendenze
    
    /// Contesto SwiftData per la persistenza
    private var modelContext: ModelContext
    
    // MARK: - Inizializzatore
    
    /// Crea un nuovo MapViewModel con il contesto SwiftData specificato.
    /// - Parameter modelContext: Il contesto per le operazioni di persistenza
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchData()
    }
    
    // MARK: - Data Fetching
    
    /// Carica tutti i nodi e le connessioni dal database.
    func fetchData() {
        do {
            // Fetch dei nodi
            let nodeDescriptor = FetchDescriptor<SynapseNode>()
            nodes = try modelContext.fetch(nodeDescriptor)
            
            // Fetch delle connessioni
            let connectionDescriptor = FetchDescriptor<SynapseConnection>()
            connections = try modelContext.fetch(connectionDescriptor)
        } catch {
            print("Errore nel caricamento dati: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Hit Testing
    
    /// Cerca un nodo alla posizione specificata.
    /// Usa una logica di distanza basata sul raggio del nodo.
    /// - Parameter point: La posizione da testare
    /// - Returns: Il nodo trovato, o nil se nessun nodo è alla posizione
    func findNode(at point: CGPoint) -> SynapseNode? {
        for node in nodes {
            let distance = hypot(point.x - node.position.x, point.y - node.position.y)
            if distance <= nodeHitRadius {
                return node
            }
        }
        return nil
    }
    
    // MARK: - Selezione
    
    /// Seleziona un nodo per l'editing.
    /// Deseleziona automaticamente qualsiasi connessione.
    /// - Parameter node: Il nodo da selezionare (nil per deselezionare)
    func selectNode(_ node: SynapseNode?) {
        selectedNodeID = node?.id
        selectedConnectionID = nil
        focusedConnectionID = nil
    }
    
    /// Seleziona una connessione.
    /// Deseleziona automaticamente qualsiasi nodo.
    /// - Parameter connection: La connessione da selezionare
    func selectConnection(_ connection: SynapseConnection?) {
        selectedConnectionID = connection?.id
        selectedNodeID = nil
    }
    
    /// Deseleziona tutto (nodi e connessioni).
    func deselectAll() {
        selectedNodeID = nil
        selectedConnectionID = nil
        focusedConnectionID = nil
        nodeToEditID = nil
    }
    
    /// Deseleziona il nodo corrente (retrocompatibilità).
    func deselectNode() {
        selectedNodeID = nil
    }
    
    /// Elimina l'elemento attualmente selezionato (nodo o connessione).
    /// Chiamato quando l'utente preme Delete/Backspace.
    /// - Returns: true se è stato eliminato qualcosa
    @discardableResult
    func deleteSelection() -> Bool {
        // Prima prova a eliminare la connessione selezionata
        if let connectionID = selectedConnectionID,
           let connection = connections.first(where: { $0.id == connectionID }) {
            deleteConnection(connection)
            selectedConnectionID = nil
            return true
        }
        
        // Poi prova a eliminare il nodo selezionato
        if let nodeID = selectedNodeID,
           let node = nodes.first(where: { $0.id == nodeID }) {
            deleteNode(node)
            return true
        }
        
        return false
    }
    
    /// Pulisce il flag di editing del nodo.
    func clearNodeEditingFlag() {
        nodeToEditID = nil
    }
    
    // MARK: - Linking (Shift+Drag)
    
    /// Inizia il processo di linking da un nodo sorgente.
    /// Chiamato quando l'utente inizia un Shift+Drag su un nodo.
    /// - Parameters:
    ///   - source: Il nodo di partenza
    ///   - wordRanges: Array opzionale di range delle parole (per multi-word linking)
    ///   - wordRect: Rettangolo opzionale della prima parola in coordinate locali del nodo
    func startLinking(from source: SynapseNode, wordRanges: [NSRange]? = nil, wordRect: CGRect? = nil) {
        isLinking = true
        tempLinkSource = source
        tempLinkWordRanges = wordRanges
        tempLinkWordRect = wordRect
        
        // Punto di partenza: centro della parola o centro del nodo
        if let wordRect = wordRect {
            // Converti wordRect da coordinate locali del nodo a coordinate world
            // Il nodo è posizionato con .position come centro, quindi:
            // topLeft del nodo = position - size/2
            let worldPoint = CGPoint(
                x: source.position.x - source.size.width/2 + wordRect.midX,
                y: source.position.y - source.size.height/2 + wordRect.midY
            )
            tempDragPoint = worldPoint
        } else {
            tempDragPoint = source.position
        }
        focusedConnectionID = nil
    }
    
    /// Convenience per singolo range (retrocompatibilità)
    func startLinking(from source: SynapseNode, wordRange: NSRange?, wordRect: CGRect? = nil) {
        if let range = wordRange {
            startLinking(from: source, wordRanges: [range], wordRect: wordRect)
        } else {
            startLinking(from: source, wordRanges: nil, wordRect: wordRect)
        }
    }
    
    /// Aggiorna la posizione del punto di drag durante il linking.
    /// Chiamato in tempo reale durante il gesture.
    /// - Parameter point: La nuova posizione del mouse
    func updateLinkingDrag(to point: CGPoint) {
        tempDragPoint = point
    }
    
    /// Termina il processo di linking.
    /// Se c'è un nodo valido sotto il punto di rilascio, crea la connessione.
    /// - Parameter endPoint: La posizione finale del mouse
    /// - Returns: La connessione creata, o nil se il linking è fallito
    @discardableResult
    func endLinking(at endPoint: CGPoint) -> SynapseConnection? {
        // Salva i word ranges prima del defer che li resetta
        let wordRanges = tempLinkWordRanges
        
        defer {
            // Reset dello stato di linking
            isLinking = false
            tempLinkSource = nil
            tempDragPoint = .zero
            tempLinkWordRanges = nil
            tempLinkWordRect = nil
        }
        
        guard let source = tempLinkSource else {
            return nil
        }
        
        // Cerca un nodo target alla posizione di rilascio
        guard let target = findNode(at: endPoint) else {
            print("Nessun nodo trovato alla posizione di rilascio")
            return nil
        }
        
        // Crea la connessione (passa i range delle parole se presenti)
        if let connection = createConnection(from: source, to: target, label: "", fromRanges: wordRanges) {
            // Imposta il focus sulla nuova connessione per editing immediato
            focusedConnectionID = connection.id
            return connection
        }
        
        return nil
    }
    
    /// Annulla il processo di linking corrente.
    func cancelLinking() {
        isLinking = false
        tempLinkSource = nil
        tempDragPoint = .zero
        tempLinkWordRanges = nil
        tempLinkWordRect = nil
    }
    
    /// Rimuove il focus dalla connessione corrente.
    func clearConnectionFocus() {
        focusedConnectionID = nil
        editingConnectionID = nil
    }
    
    /// Inizia l'editing dell'etichetta di una connessione esistente.
    /// Chiamato quando l'utente fa doppio click su una connessione.
    /// - Parameter connection: La connessione da editare
    func startEditingConnection(_ connection: SynapseConnection) {
        // Deseleziona eventuali nodi
        selectedNodeID = nil
        nodeToEditID = nil
        
        // Seleziona e attiva editing sulla connessione
        selectedConnectionID = connection.id
        editingConnectionID = connection.id
        focusedConnectionID = connection.id
    }
    
    /// Termina l'editing dell'etichetta di una connessione.
    func stopEditingConnection() {
        editingConnectionID = nil
        focusedConnectionID = nil
    }
    
    // MARK: - Operazioni sui Nodi
    
    /// Crea un nuovo nodo alla posizione specificata.
    /// - Parameter point: La posizione CGPoint dove creare il nodo
    /// - Returns: Il nodo appena creato
    @discardableResult
    func addNode(at point: CGPoint) -> SynapseNode {
        let node = SynapseNode(text: "", at: point)
        modelContext.insert(node)
        nodes.append(node)
        
        // Seleziona automaticamente il nuovo nodo
        selectNode(node)
        
        // Imposta il flag per attivare l'editing
        // (permette alla UI di renderizzare il nodo prima di attivare il focus)
        let nodeID = node.id
        // EDUCATIONAL: Usiamo [weak self] per evitare un retain cycle.
        // Senza [weak self], la closure cattura 'self' in modo forte, creando un ciclo
        // di riferimento se la closure sopravvive alla view (es. se l'utente chiude
        // la view prima che il blocco async venga eseguito).
        // FIX: Delay di 100ms per permettere a SwiftUI di renderizzare il nuovo nodo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.nodeToEditID = nodeID
        }
        
        return node
    }
    
    /// Crea un nuovo nodo CONNESSO al nodo selezionato (tasto TAB).
    /// Il nuovo nodo viene posizionato a destra del nodo selezionato.
    /// Crea automaticamente una connessione e attiva l'editing.
    /// - Returns: Il nuovo nodo creato, o nil se nessun nodo è selezionato
    @discardableResult
    func createConnectedNode() -> SynapseNode? {
        guard let sourceNode = selectedNode else {
            print("Nessun nodo selezionato per creare un nodo connesso")
            return nil
        }
        
        // Calcola la posizione del nuovo nodo (a destra del source)
        let newPosition = CGPoint(
            x: sourceNode.position.x + connectedNodeOffsetX,
            y: sourceNode.position.y
        )
        
        // Crea il nuovo nodo
        let newNode = SynapseNode(text: "", at: newPosition)
        modelContext.insert(newNode)
        nodes.append(newNode)
        
        // Crea la connessione dal source al nuovo nodo
        let _ = createConnection(from: sourceNode, to: newNode, label: "")
        
        // Seleziona il nuovo nodo
        selectNode(newNode)
        
        // Imposta il flag per attivare l'editing
        // (permette alla UI di renderizzare il nodo prima di attivare il focus)
        let nodeID = newNode.id
        // EDUCATIONAL: [weak self] previene memory leak se il ViewModel viene deallocato
        // prima che il blocco async venga eseguito sul main thread.
        // FIX: Delay di 100ms per permettere a SwiftUI di renderizzare il nuovo nodo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.nodeToEditID = nodeID
        }
        
        return newNode
    }
    
    /// Crea un nuovo nodo FRATELLO vicino al nodo selezionato (tasto ENTER).
    /// Se il nodo selezionato ha un genitore, il nuovo nodo viene collegato allo stesso genitore.
    /// Altrimenti viene creato isolato.
    /// La posizione viene calcolata per evitare sovrapposizioni.
    /// - Returns: Il nuovo nodo creato, o nil se nessun nodo è selezionato
    @discardableResult
    func createSiblingNode() -> SynapseNode? {
        guard let sourceNode = selectedNode else {
            print("Nessun nodo selezionato per creare un nodo fratello")
            return nil
        }
        
        // 1. Identifica il genitore comune (il nodo che punta al sourceNode)
        // Se ci sono più connessioni in entrata, prendiamo la prima come "genitore principale"
        let parentNode = sourceNode.incomingConnections.first?.source
        
        // 2. Calcola posizione evitando sovrapposizioni
        // Partiamo dalla posizione sotto il sourceNode
        let startX = sourceNode.position.x
        var checkY = sourceNode.position.y + siblingNodeOffsetY
        
        // Usiamo un raggio di collisione basato sulle dimensioni tipiche del nodo
        // (Height 70, spaziatura 100 -> raggio 40-50 è sicuro, usiamo 80 per margine largo)
        let avoidanceRadius: CGFloat = 80.0
        
        // Funzione locale per verificare collisioni
        func positionIsOccupied(_ point: CGPoint) -> Bool {
            for node in nodes {
                // Ignoriamo noi stessi (non ancora creati) e il sourceNode
                if node.id == sourceNode.id { continue }
                
                let dist = hypot(point.x - node.position.x, point.y - node.position.y)
                if dist < avoidanceRadius {
                    return true
                }
            }
            return false
        }
        
        // Cerca slot libero scorrendo verso il basso
        var attempts = 0
        while positionIsOccupied(CGPoint(x: startX, y: checkY)) && attempts < 50 {
            checkY += siblingNodeOffsetY
            attempts += 1
        }
        
        let newPosition = CGPoint(x: startX, y: checkY)
        
        // 3. Crea il nuovo nodo
        let newNode = SynapseNode(text: "", at: newPosition)
        modelContext.insert(newNode)
        nodes.append(newNode)
        
        // 4. Se esiste un genitore, crea la connessione (così diventano fratelli visuali E logici)
        if let parent = parentNode {
            _ = createConnection(from: parent, to: newNode, label: "")
        }
        
        // 5. Seleziona il nuovo nodo e attiva editing
        selectNode(newNode)
        
        let nodeID = newNode.id
        // EDUCATIONAL: [weak self] è necessario nelle closure asincrone per evitare retain cycles.
        // FIX: Delay di 100ms per permettere a SwiftUI di renderizzare il nuovo nodo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.nodeToEditID = nodeID
        }
        
        return newNode
    }
    
    /// Crea un nuovo nodo al centro della canvas (tasto ENTER senza selezione).
    /// - Parameter centerPoint: Il punto centrale della vista
    /// - Returns: Il nuovo nodo creato
    @discardableResult
    func createNodeAtCenter(_ centerPoint: CGPoint) -> SynapseNode {
        let newNode = SynapseNode(text: "", at: centerPoint)
        modelContext.insert(newNode)
        nodes.append(newNode)
        
        // Seleziona il nuovo nodo
        selectNode(newNode)
        
        // Imposta il flag per attivare l'editing
        let nodeID = newNode.id
        // EDUCATIONAL: Sempre usare [weak self] in closures asincrone all'interno di classi.
        // FIX: Delay di 100ms per permettere a SwiftUI di renderizzare il nuovo nodo
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.nodeToEditID = nodeID
        }
        
        return newNode
    }
    
    /// Aggiorna la posizione di un nodo durante il drag.
    /// Chiamato in tempo reale durante il gesture.
    /// - Parameters:
    ///   - node: Il nodo da spostare
    ///   - newPoint: La nuova posizione
    func updateNodePosition(_ node: SynapseNode, to newPoint: CGPoint) {
        node.position = newPoint
        // SwiftData persiste automaticamente grazie all'autosave
    }
    
    /// Aggiorna il testo di un nodo.
    /// - Parameters:
    ///   - node: Il nodo da modificare
    ///   - newText: Il nuovo testo
    func updateNodeText(_ node: SynapseNode, newText: String) {
        node.text = newText
    }
    
    /// Aggiorna il testo ricco di un nodo (e la versione plain text).
    /// - Parameters:
    ///   - node: Il nodo da modificare
    ///   - richTextData: I dati RTF/Attributed String
    ///   - plainText: La versione semplice del testo (per search/preview)
    func updateNodeRichText(_ node: SynapseNode, richTextData: Data?, plainText: String) {
        node.richTextData = richTextData
        node.text = plainText
    }
    
    /// Elimina un nodo e tutte le sue connessioni (cascade).
    /// - Parameter node: Il nodo da eliminare
    func deleteNode(_ node: SynapseNode) {
        // Rimuovi dalla lista locale
        nodes.removeAll { $0.id == node.id }
        
        // Rimuovi le connessioni dalla lista locale
        // (verranno eliminate dal cascade, ma aggiorniamo la UI)
        connections.removeAll { $0.source?.id == node.id || $0.target?.id == node.id }
        
        // Elimina dal database (cascade elimina le connessioni)
        modelContext.delete(node)
        
        // Deseleziona se era selezionato
        if selectedNodeID == node.id {
            selectedNodeID = nil
        }
    }
    
    // MARK: - Operazioni sulle Connessioni
    
    /// Crea una nuova connessione tra due nodi.
    /// - Parameters:
    ///   - source: Nodo di partenza
    ///   - target: Nodo di destinazione
    ///   - label: Etichetta della connessione (default: stringa vuota)
    ///   - fromRanges: Array opzionale di range del testo sorgente per word-level linking
    /// - Returns: La connessione appena creata, o nil se source == target
    @discardableResult
    func createConnection(from source: SynapseNode, to target: SynapseNode, label: String = "", fromRanges: [NSRange]? = nil) -> SynapseConnection? {
        // Previeni connessioni auto-referenziali
        guard source.id != target.id else {
            print("Impossibile creare una connessione da un nodo a se stesso")
            return nil
        }
        
        // Verifica che non esista già una connessione IDENTICA
        // Una connessione è duplicata solo se ha: stesso source + target + stesso fromRanges
        // Link da parole diverse verso lo stesso target sono PERMESSI (parallel links)
        let existingConnection = connections.first { conn in
            guard conn.source?.id == source.id && conn.target?.id == target.id else {
                return false
            }
            
            // Se entrambi sono node-level (no ranges)
            if conn.fromRanges == nil && fromRanges == nil {
                return true  // Duplicato node-level
            }
            
            // Confronta i range per word-level connections
            if let existingRanges = conn.fromRanges, let newRanges = fromRanges {
                // Considera duplicato solo se i range sono identici (stesso set)
                let existingSet = Set(existingRanges)
                let newSet = Set(newRanges)
                return existingSet == newSet
            }
            
            // Un node-level e un word-level non sono duplicati
            return false
        }
        
        if existingConnection != nil {
            print("Connessione identica già esistente")
            return nil
        }
        
        let connection = SynapseConnection(source: source, target: target, label: label, fromRanges: fromRanges)
        modelContext.insert(connection)
        connections.append(connection)
        
        return connection
    }
    
    /// Convenience per singolo range (retrocompatibilità)
    @discardableResult
    func createConnection(from source: SynapseNode, to target: SynapseNode, label: String = "", fromRange: NSRange?) -> SynapseConnection? {
        if let range = fromRange {
            return createConnection(from: source, to: target, label: label, fromRanges: [range])
        } else {
            return createConnection(from: source, to: target, label: label, fromRanges: nil)
        }
    }
    
    /// Aggiorna l'etichetta di una connessione.
    /// - Parameters:
    ///   - connection: La connessione da modificare
    ///   - newLabel: La nuova etichetta
    func updateConnectionLabel(_ connection: SynapseConnection, newLabel: String) {
        connection.label = newLabel
    }
    
    /// Elimina una connessione.
    /// - Parameter connection: La connessione da eliminare
    func deleteConnection(_ connection: SynapseConnection) {
        connections.removeAll { $0.id == connection.id }
        modelContext.delete(connection)
    }
    
    // MARK: - Logica Zoom & Pan Avanzata
    
    /// Sensibilità dello zoom (0.0 - 1.0).
    /// Valori bassi (es. 0.1-0.2) rendono lo zoom più lento. 1.0 è il massimo.
    static let zoomSensitivity: CGFloat = 1.0
    
    // MARK: - Logica Zoom & Pan Avanzata
    
    /// Processa lo zoom mantenendo fissa la posizione sotto il cursore (Zoom to Cursor).
    /// - Parameters:
    ///   - delta: Il fattore di scala del gesto (es. 1.01 per ingrandire leggermente)
    ///   - anchor: Il punto nello spazio SCHERMO attorno al quale zoomare (tipicamente mouse position)
    func processZoom(delta: CGFloat, anchor: CGPoint) {
        // 1. Applica damping al delta per uno zoom più "pesante" e controllabile
        let dampedDelta = 1.0 + (delta - 1.0) * MapViewModel.zoomSensitivity
        
        // 2. Calcola il nuovo fattore di zoom
        let newZoom = zoomScale * dampedDelta
        
        // 3. Clampa il valore tra min e max
        let clampedZoom = min(max(newZoom, MapViewModel.minZoom), MapViewModel.maxZoom)
        
        // 4. Se lo zoom non è cambiato (limiti o delta minimo), esci
        guard abs(clampedZoom - zoomScale) > 0.0001 else { return }
        
        // 5. MATEMATICA "ZOOM TO CURSOR":
        // Vogliamo che il punto 'anchor' (schermo) rimanga ancorato allo stesso punto del 'mondo'.
        // Formula Trasformazione: Screen = (World * Zoom) + Pan
        // Da cui: World = (Screen - Pan) / Zoom
        
        // Calcoliamo dove si trova l'anchor nel mondo prima dello zoom
        let worldAnchor = CGPoint(
            x: (anchor.x - panOffset.x) / zoomScale,
            y: (anchor.y - panOffset.y) / zoomScale
        )
        
        // Calcoliamo il nuovo PanOffset per mantenere il worldAnchor nello stesso ScreenAnchor
        // Pan_new = ScreenAnchor - (WorldAnchor * Zoom_new)
        let newPanOffset = CGPoint(
            x: anchor.x - (worldAnchor.x * clampedZoom),
            y: anchor.y - (worldAnchor.y * clampedZoom)
        )
        
        // 6. Applica i cambiamenti
        zoomScale = clampedZoom
        panOffset = newPanOffset
    }
    
    /// Effettua il pan della canvas usando delta separati (utile per TrackpadReader).
    /// - Parameters:
    ///   - deltaX: Spostamento orizzontale
    ///   - deltaY: Spostamento verticale
    func pan(deltaX: CGFloat, deltaY: CGFloat) {
        panOffset.x += deltaX
        panOffset.y += deltaY
    }
    
    /// Effettua il pan della canvas.
    /// - Parameter delta: Il vettore di spostamento in coordinate schermo
    func pan(delta: CGPoint) {
        panOffset.x += delta.x
        panOffset.y += delta.y
    }
    
    // MARK: - Text Styling
    
    /// Applica il grassetto:
    /// - Se in editing (isEditingNode): alla selezione corrente tramite activeTextView
    /// - Se nodo selezionato ma NON in editing: a tutto il testo del nodo
    func applyBoldToSelectedNode() {
        // CONTEXT CHECK: Solo se siamo effettivamente in modalità editing
        if isEditingNode, let textView = activeTextView, let formattable = textView as? FormattableTextView {
            formattable.toggleBold(nil)
            return
        }
        // Fallback: applica a tutto il nodo
        guard let node = selectedNode else { return }
        applyFontTrait(.boldFontMask, to: node)
    }
    
    /// Applica il corsivo:
    /// - Se in editing (isEditingNode): alla selezione corrente tramite activeTextView
    /// - Se nodo selezionato ma NON in editing: a tutto il testo del nodo
    func applyItalicToSelectedNode() {
        // CONTEXT CHECK: Solo se siamo effettivamente in modalità editing
        if isEditingNode, let textView = activeTextView, let formattable = textView as? FormattableTextView {
            formattable.toggleItalic(nil)
            return
        }
        // Fallback: applica a tutto il nodo
        guard let node = selectedNode else { return }
        applyFontTrait(.italicFontMask, to: node)
    }
    
    /// Applica/rimuove il colore Rosso (Toggle):
    /// - Se in editing (isEditingNode): toggle rosso/default sulla selezione corrente
    /// - Se nodo selezionato ma NON in editing: toggle rosso/default su tutto il testo
    func applyRedColorToSelectedNode() {
        // CONTEXT CHECK: Solo se siamo effettivamente in modalità editing
        if isEditingNode, let textView = activeTextView, let formattable = textView as? FormattableTextView {
            formattable.toggleRedColor()
            return
        }
        // Fallback: applica a tutto il nodo
        guard let node = selectedNode else { return }
        toggleRedColorOnNode(node)
    }
    
    /// Applica la sottolineatura:
    /// - Se in editing (isEditingNode): alla selezione corrente tramite activeTextView
    /// - Se nodo selezionato ma NON in editing: a tutto il testo del nodo
    func applyUnderlineToSelectedNode() {
        // CONTEXT CHECK: Solo se siamo effettivamente in modalità editing
        if isEditingNode, let textView = activeTextView, let formattable = textView as? FormattableTextView {
            formattable.underline(nil)
            return
        }
        // Fallback: applica a tutto il nodo
        guard let node = selectedNode else { return }
        toggleUnderline(on: node)
    }
    
    /// Applica o rimuove un tratto font (bold/italic) a tutto il testo di un nodo.
    /// Se tutto il testo ha già il tratto, lo rimuove (toggle).
    private func applyFontTrait(_ trait: NSFontTraitMask, to node: SynapseNode) {
        // Ottieni l'NSAttributedString dal nodo
        let attributedString: NSMutableAttributedString
        
        if let data = node.richTextData,
           let existing = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
            attributedString = NSMutableAttributedString(attributedString: existing)
        } else if !node.text.isEmpty {
            // Se non c'è rich text, crea un attributed string dal testo plain
            attributedString = NSMutableAttributedString(string: node.text, attributes: [
                .font: NSFont.systemFont(ofSize: 14)
            ])
        } else {
            return
        }
        
        guard attributedString.length > 0 else { return }
        
        let fullRange = NSRange(location: 0, length: attributedString.length)
        let fontManager = NSFontManager.shared
        
        // Determina se tutto il testo ha già questo tratto
        var allHaveTrait = true
        attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, _, stop in
            if let font = value as? NSFont {
                if !fontManager.traits(of: font).contains(trait) {
                    allHaveTrait = false
                    stop.pointee = true
                }
            } else {
                allHaveTrait = false
                stop.pointee = true
            }
        }
        
        // Applica o rimuove il tratto
        attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, attrRange, _ in
            let currentFont = (value as? NSFont) ?? NSFont.systemFont(ofSize: 14)
            let newFont: NSFont
            
            if allHaveTrait {
                // Rimuovi tratto
                newFont = fontManager.convert(currentFont, toNotHaveTrait: trait)
            } else {
                // Aggiungi tratto
                newFont = fontManager.convert(currentFont, toHaveTrait: trait)
            }
            
            attributedString.addAttribute(.font, value: newFont, range: attrRange)
        }
        
        // Salva i dati modificati nel nodo
        saveAttributedString(attributedString, to: node)
    }
    
    /// Attiva/disattiva la sottolineatura su tutto il testo di un nodo.
    private func toggleUnderline(on node: SynapseNode) {
        // Ottieni l'NSAttributedString dal nodo
        let attributedString: NSMutableAttributedString
        
        if let data = node.richTextData,
           let existing = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
            attributedString = NSMutableAttributedString(attributedString: existing)
        } else if !node.text.isEmpty {
            attributedString = NSMutableAttributedString(string: node.text, attributes: [
                .font: NSFont.systemFont(ofSize: 14)
            ])
        } else {
            return
        }
        
        guard attributedString.length > 0 else { return }
        
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        // Verifica se tutto il testo ha già underline
        var hasUnderline = false
        attributedString.enumerateAttribute(.underlineStyle, in: fullRange, options: []) { value, _, _ in
            if let style = value as? Int, style != NSUnderlineStyle([]).rawValue {
                hasUnderline = true
            }
        }
        
        // Toggle underline
        let newStyle: Int = hasUnderline ? NSUnderlineStyle([]).rawValue : NSUnderlineStyle.single.rawValue
        attributedString.addAttribute(.underlineStyle, value: newStyle, range: fullRange)
        
        // Salva i dati modificati nel nodo
        saveAttributedString(attributedString, to: node)
    }
    
    /// Toggle del colore rosso su tutto il testo di un nodo.
    /// Se tutto il testo è rosso, lo riporta al colore di default.
    /// Se tutto o parte del testo non è rosso, lo rende tutto rosso.
    private func toggleRedColorOnNode(_ node: SynapseNode) {
        // Ottieni l'NSAttributedString dal nodo
        let attributedString: NSMutableAttributedString
        
        if let data = node.richTextData,
           let existing = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
            attributedString = NSMutableAttributedString(attributedString: existing)
        } else if !node.text.isEmpty {
            attributedString = NSMutableAttributedString(string: node.text, attributes: [
                .font: NSFont.systemFont(ofSize: 14)
            ])
        } else {
            return
        }
        
        guard attributedString.length > 0 else { return }
        
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        // Verifica se tutto il testo è già rosso
        var isAllRed = true
        attributedString.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, _, stop in
            if let color = value as? NSColor {
                // Usa confronto RGB approssimativo
                if let rgb = color.usingColorSpace(.deviceRGB),
                   let redRGB = NSColor.red.usingColorSpace(.deviceRGB) {
                    let rDiff = abs(rgb.redComponent - redRGB.redComponent)
                    let gDiff = abs(rgb.greenComponent - redRGB.greenComponent)
                    let bDiff = abs(rgb.blueComponent - redRGB.blueComponent)
                    if rDiff > 0.1 || gDiff > 0.1 || bDiff > 0.1 {
                        isAllRed = false
                        stop.pointee = true
                    }
                } else {
                    isAllRed = false
                    stop.pointee = true
                }
            } else {
                // Nessun colore = default, non è rosso
                isAllRed = false
                stop.pointee = true
            }
        }
        
        // Toggle: se tutto rosso -> default, altrimenti -> rosso
        let newColor: NSColor = isAllRed ? .labelColor : .red
        attributedString.addAttribute(.foregroundColor, value: newColor, range: fullRange)
        
        // Salva i dati modificati nel nodo
        saveAttributedString(attributedString, to: node)
    }
    
    /// Salva un NSAttributedString nel nodo come richTextData.
    private func saveAttributedString(_ attributedString: NSAttributedString, to node: SynapseNode) {
        do {
            let data = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]
            )
            node.richTextData = data
            node.text = attributedString.string
            
            // Forza un refresh della UI incrementando il contatore di versione
            styleVersion += 1
        } catch {
            print("Errore salvataggio rich text: \(error)")
        }
    }
}



