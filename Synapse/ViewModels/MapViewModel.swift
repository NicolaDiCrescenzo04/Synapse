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
    
    /// Indica se una connessione è attualmente in modalità editing
    var isEditingConnection: Bool {
        editingConnectionID != nil || focusedConnectionID != nil
    }
    
    // MARK: - Stato Zoom
    
    /// Livello di zoom attuale della canvas (1.0 = 100%)
    var zoomScale: CGFloat = 1.0
    
    /// Livello minimo di zoom (10%)
    static let minZoom: CGFloat = 0.1
    
    /// Livello massimo di zoom (500%)
    static let maxZoom: CGFloat = 5.0
    
    // MARK: - Stato Linking (Shift+Drag)
    
    /// Indica se l'utente sta creando una connessione
    var isLinking: Bool = false
    
    /// Nodo di origine durante la creazione della connessione
    var tempLinkSource: SynapseNode?
    
    /// Posizione corrente del mouse durante il drag di linking
    var tempDragPoint: CGPoint = .zero
    
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
    /// - Parameter source: Il nodo di partenza
    func startLinking(from source: SynapseNode) {
        isLinking = true
        tempLinkSource = source
        tempDragPoint = source.position
        focusedConnectionID = nil
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
        defer {
            // Reset dello stato di linking
            isLinking = false
            tempLinkSource = nil
            tempDragPoint = .zero
        }
        
        guard let source = tempLinkSource else {
            return nil
        }
        
        // Cerca un nodo target alla posizione di rilascio
        guard let target = findNode(at: endPoint) else {
            print("Nessun nodo trovato alla posizione di rilascio")
            return nil
        }
        
        // Crea la connessione
        if let connection = createConnection(from: source, to: target, label: "") {
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
        
        // Seleziona automaticamente il nuovo nodo per editing
        selectNode(node)
        
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
        
        // Imposta il flag per attivare l'editing con delay
        // (permette alla UI di renderizzare il nodo prima di attivare il focus)
        let nodeID = newNode.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.nodeToEditID = nodeID
        }
        
        return newNode
    }
    
    /// Crea un nuovo nodo FRATELLO vicino al nodo selezionato (tasto ENTER).
    /// Il nuovo nodo viene posizionato sotto il nodo selezionato, senza connessione.
    /// Attiva automaticamente l'editing del testo.
    /// - Returns: Il nuovo nodo creato, o nil se nessun nodo è selezionato
    @discardableResult
    func createSiblingNode() -> SynapseNode? {
        guard let sourceNode = selectedNode else {
            print("Nessun nodo selezionato per creare un nodo fratello")
            return nil
        }
        
        // Calcola la posizione del nuovo nodo (sotto il source)
        let newPosition = CGPoint(
            x: sourceNode.position.x,
            y: sourceNode.position.y + siblingNodeOffsetY
        )
        
        // Crea il nuovo nodo
        let newNode = SynapseNode(text: "", at: newPosition)
        modelContext.insert(newNode)
        nodes.append(newNode)
        
        // Seleziona il nuovo nodo (senza creare connessione)
        selectNode(newNode)
        
        // Imposta il flag per attivare l'editing con delay
        let nodeID = newNode.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.nodeToEditID = nodeID
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
        
        // Imposta il flag per attivare l'editing con delay
        let nodeID = newNode.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.nodeToEditID = nodeID
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
    /// - Returns: La connessione appena creata, o nil se source == target
    @discardableResult
    func createConnection(from source: SynapseNode, to target: SynapseNode, label: String = "") -> SynapseConnection? {
        // Previeni connessioni auto-referenziali
        guard source.id != target.id else {
            print("Impossibile creare una connessione da un nodo a se stesso")
            return nil
        }
        
        // Verifica che non esista già una connessione identica
        let existingConnection = connections.first { 
            $0.source?.id == source.id && $0.target?.id == target.id 
        }
        
        if existingConnection != nil {
            print("Connessione già esistente tra questi nodi")
            return nil
        }
        
        let connection = SynapseConnection(source: source, target: target, label: label)
        modelContext.insert(connection)
        connections.append(connection)
        
        return connection
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
}



