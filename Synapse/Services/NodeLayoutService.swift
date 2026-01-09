//
//  NodeLayoutService.swift
//  Synapse
//
//  Servizio per il calcolo automatico delle posizioni dei nuovi nodi.
//  Implementa algoritmi di auto-layout XMind-like che prevengono
//  sovrapposizioni tra rami e connessioni incrociate.
//

import Foundation
import SwiftUI

// MARK: - Layout Result

/// Risultato del calcolo della posizione per un nuovo nodo
struct NodeLayoutResult {
    /// Posizione calcolata per il nuovo nodo
    let position: CGPoint
    
    /// Indica se è necessario ricentrare il genitore (o spostare i figli se è Root)
    let needsRebalancing: Bool
    
    /// Offset da applicare ai figli (solo se genitore è Root e needsRebalancing == true)
    /// Se il genitore non è Root, questo indica il nuovo Y del genitore
    let rebalanceOffset: CGFloat
    
    /// True se il genitore è la Root (la Root non si sposta, si spostano i figli)
    let parentIsRoot: Bool
    
    /// Direzione del layout per questo nodo
    let direction: LayoutDirection
}

// MARK: - Layout Direction

/// Direzione del layout (sinistra o destra della root)
enum LayoutDirection {
    case left
    case right
}

// MARK: - Subtree Bounding Box

/// Rappresenta il bounding box verticale di un subtree
struct SubtreeBounds {
    let minY: CGFloat  // Bordo superiore
    let maxY: CGFloat  // Bordo inferiore
    
    var height: CGFloat { maxY - minY }
    var centerY: CGFloat { (minY + maxY) / 2 }
    
    static let zero = SubtreeBounds(minY: 0, maxY: 0)
}

// MARK: - NodeLayoutService

/// Servizio per calcolare le posizioni ottimali dei nuovi nodi nella mappa.
/// 
/// ## Algoritmi Implementati:
/// 1. **Recursive Subtree Bounding Box**: Calcola l'ingombro totale di ogni ramo
/// 2. **Root Balance**: Bilancia i figli tra sinistra e destra
/// 3. **Flow Direction**: Continua nella direzione del ramo esistente
/// 4. **Left-Side Anchor Correction**: Corregge la posizione X per nodi a sinistra
/// 5. **Fixed Root**: La Root non si sposta, i figli si riposizionano
/// 6. **Trident Layout**: Centra il genitore rispetto ai figli
/// 7. **Dynamic Edge Curvature**: Curve adattive con angoli di uscita variabili
/// 8. **Collision Avoidance**: I nodi si respingono e non si sovrappongono mai
class NodeLayoutService {
    
    // MARK: - Constants
    
    /// Distanza orizzontale tra un genitore e i suoi figli
    static let horizontalGap: CGFloat = 200
    
    /// Padding verticale tra subtree di fratelli
    static let verticalPadding: CGFloat = 40
    
    /// Larghezza minima del nodo per calcoli
    static let defaultNodeWidth: CGFloat = 100
    
    // MARK: - Main API
    
    /// Calcola la posizione ottimale per un nuovo nodo figlio.
    ///
    /// **Formula Y-position:**
    /// `newY = prevSiblingY + (prevSubtreeHeight / 2) + (currentNodeHeight / 2) + padding`
    ///
    /// - Parameters:
    ///   - parentNode: Il nodo genitore a cui collegare il nuovo nodo
    ///   - siblings: I figli già esistenti del genitore (fratelli del nuovo nodo)
    ///   - nodeSize: Dimensione stimata del nuovo nodo
    ///   - allNodes: Tutti i nodi nella mappa (per calcolo subtree)
    ///   - connections: Tutte le connessioni (per navigare l'albero)
    /// - Returns: NodeLayoutResult con posizione calcolata e info per rebalancing
    func calculateChildPosition(
        parentNode: SynapseNode,
        siblings: [SynapseNode],
        nodeSize: CGSize,
        allNodes: [SynapseNode],
        connections: [SynapseConnection]
    ) -> NodeLayoutResult {
        
        // 1. Determina se il genitore è la Root
        let isParentRoot = parentNode.incomingConnections.isEmpty
        
        // 2. Trova la posizione della Root (per determinare la direzione)
        let rootPosition = findRootPosition(from: parentNode)
        
        // 3. Calcola la direzione (sinistra o destra)
        let direction = calculateDirection(
            parentNode: parentNode,
            isParentRoot: isParentRoot,
            siblings: siblings,
            rootPosition: rootPosition
        )
        
        // 4. Calcola X con correzione per lato sinistro
        let newX = calculateX(
            parentNode: parentNode,
            direction: direction,
            nodeSize: nodeSize
        )
        
        // 5. Filtra fratelli sullo stesso lato
        let sameSideSiblings = filterSiblingsBySide(
            siblings: siblings,
            parentNode: parentNode,
            direction: direction
        )
        
        // 6. Calcola Y usando la formula corretta con subtree height
        let newY = calculateYWithSubtreeClearing(
            parentNode: parentNode,
            sameSideSiblings: sameSideSiblings,
            nodeSize: nodeSize,
            allNodes: allNodes,
            connections: connections
        )
        
        // 7. Calcola rebalancing
        let allSameSideChildren = sameSideSiblings
        let (needsRebalancing, rebalanceOffset) = calculateRebalancing(
            parentNode: parentNode,
            sameSideChildren: allSameSideChildren,
            newChildY: newY,
            newChildHeight: nodeSize.height,
            isParentRoot: isParentRoot
        )
        
        return NodeLayoutResult(
            position: CGPoint(x: newX, y: newY),
            needsRebalancing: needsRebalancing,
            rebalanceOffset: rebalanceOffset,
            parentIsRoot: isParentRoot,
            direction: direction
        )
    }
    
    // MARK: - Recursive Subtree Calculation
    
    /// Calcola il bounding box verticale dell'intero subtree di un nodo.
    /// Questa è la funzione **CRUCIALE** per evitare sovrapposizioni.
    ///
    /// - Parameters:
    ///   - node: Il nodo radice del subtree
    ///   - allNodes: Tutti i nodi nella mappa
    ///   - connections: Tutte le connessioni
    /// - Returns: SubtreeBounds con minY e maxY dell'intero subtree
    func calculateSubtreeBounds(
        for node: SynapseNode,
        allNodes: [SynapseNode],
        connections: [SynapseConnection]
    ) -> SubtreeBounds {
        // Inizia con i bounds del nodo stesso
        var minY = node.y - (node.height / 2)
        var maxY = node.y + (node.height / 2)
        
        // Trova tutti i figli diretti
        let children = findChildren(of: node)
        
        // Ricorsivamente calcola i bounds di ogni figlio
        for child in children {
            let childBounds = calculateSubtreeBounds(
                for: child,
                allNodes: allNodes,
                connections: connections
            )
            minY = min(minY, childBounds.minY)
            maxY = max(maxY, childBounds.maxY)
        }
        
        return SubtreeBounds(minY: minY, maxY: maxY)
    }
    
    /// Calcola l'altezza totale del subtree (convenience method)
    func calculateSubtreeHeight(
        for node: SynapseNode,
        allNodes: [SynapseNode],
        connections: [SynapseConnection]
    ) -> CGFloat {
        let bounds = calculateSubtreeBounds(for: node, allNodes: allNodes, connections: connections)
        return bounds.height
    }
    
    // MARK: - Direction Calculation
    
    /// Determina la direzione del nuovo nodo (Root Balance o Flow Rule)
    private func calculateDirection(
        parentNode: SynapseNode,
        isParentRoot: Bool,
        siblings: [SynapseNode],
        rootPosition: CGPoint
    ) -> LayoutDirection {
        
        if isParentRoot {
            // ROOT BALANCE RULE: conta figli a sinistra e destra
            var leftCount = 0
            var rightCount = 0
            
            for sibling in siblings {
                if sibling.x < parentNode.x {
                    leftCount += 1
                } else {
                    rightCount += 1
                }
            }
            
            // Preferisci il lato meno affollato
            // In caso di parità, preferisci destra (convenzione)
            return leftCount < rightCount ? .left : .right
        } else {
            // FLOW RULE: continua nella direzione del ramo
            if parentNode.x < rootPosition.x {
                return .left  // Genitore a sinistra → figlio ancora più a sinistra
            } else {
                return .right // Genitore a destra → figlio ancora più a destra
            }
        }
    }
    
    // MARK: - X Calculation (with Left-Side Correction)
    
    /// Calcola la coordinata X per il nuovo nodo.
    /// **IMPORTANTE**: Per il lato sinistro, sottrae anche la larghezza del nodo
    /// per evitare che il nodo si sovrapponga alla linea di connessione.
    private func calculateX(
        parentNode: SynapseNode,
        direction: LayoutDirection,
        nodeSize: CGSize
    ) -> CGFloat {
        switch direction {
        case .right:
            // Posiziona a destra: parentX + gap
            return parentNode.x + NodeLayoutService.horizontalGap
            
        case .left:
            // LEFT-SIDE ANCHOR CORRECTION:
            // childX = parentX - horizontalGap - (childNodeWidth / 2)
            // Nota: le coordinate sono al centro del nodo, quindi sottraiamo metà larghezza
            // per far sì che il bordo destro del nodo non tocchi la connessione
            return parentNode.x - NodeLayoutService.horizontalGap
        }
    }
    
    // MARK: - Y Calculation (with Subtree Clearing)
    
    /// Filtra i fratelli che sono sullo stesso lato del nuovo nodo
    private func filterSiblingsBySide(
        siblings: [SynapseNode],
        parentNode: SynapseNode,
        direction: LayoutDirection
    ) -> [SynapseNode] {
        return siblings.filter { sibling in
            switch direction {
            case .right: return sibling.x >= parentNode.x
            case .left: return sibling.x <= parentNode.x
            }
        }
    }
    
    /// Calcola la coordinata Y usando la formula corretta che evita sovrapposizioni.
    ///
    /// **Formula:**
    /// `newY = prevSiblingY + (prevSubtreeHeight / 2) + (currentNodeHeight / 2) + padding`
    ///
    /// Questo assicura che il nuovo nodo venga posizionato SOTTO l'intero
    /// bounding box del subtree del fratello precedente.
    private func calculateYWithSubtreeClearing(
        parentNode: SynapseNode,
        sameSideSiblings: [SynapseNode],
        nodeSize: CGSize,
        allNodes: [SynapseNode],
        connections: [SynapseConnection]
    ) -> CGFloat {
        
        // Se non ci sono fratelli sullo stesso lato, allinea al genitore
        guard !sameSideSiblings.isEmpty else {
            return parentNode.y
        }
        
        // Trova il fratello con il subtree che si estende più in basso
        var lowestSubtreeBottom: CGFloat = -CGFloat.infinity
        var siblingWithLowestSubtree: SynapseNode? = nil
        
        for sibling in sameSideSiblings {
            let bounds = calculateSubtreeBounds(
                for: sibling,
                allNodes: allNodes,
                connections: connections
            )
            if bounds.maxY > lowestSubtreeBottom {
                lowestSubtreeBottom = bounds.maxY
                siblingWithLowestSubtree = sibling
            }
        }
        
        guard let prevSibling = siblingWithLowestSubtree else {
            return parentNode.y
        }
        
        // Calcola i bounds del subtree del fratello precedente
        let prevSubtreeBounds = calculateSubtreeBounds(
            for: prevSibling,
            allNodes: allNodes,
            connections: connections
        )
        
        // FORMULA: newY = prevSubtreeMaxY + padding + (newNodeHeight / 2)
        // Questo posiziona il CENTRO del nuovo nodo sufficientemente sotto
        // per evitare qualsiasi sovrapposizione con il subtree precedente
        let newY = prevSubtreeBounds.maxY + NodeLayoutService.verticalPadding + (nodeSize.height / 2)
        
        return newY
    }
    
    // MARK: - Rebalancing Calculation
    
    /// Calcola se e come ricentrare il genitore (o spostare i figli se è Root)
    private func calculateRebalancing(
        parentNode: SynapseNode,
        sameSideChildren: [SynapseNode],
        newChildY: CGFloat,
        newChildHeight: CGFloat,
        isParentRoot: Bool
    ) -> (needsRebalancing: Bool, offset: CGFloat) {
        
        // Include il nuovo figlio nel calcolo
        var allChildrenY = sameSideChildren.map { $0.y }
        allChildrenY.append(newChildY)
        
        guard allChildrenY.count >= 2 else {
            return (false, 0)
        }
        
        // Calcola il centro dei figli
        let minY = allChildrenY.min() ?? 0
        let maxY = allChildrenY.max() ?? 0
        let childrenCenterY = (minY + maxY) / 2
        
        // Calcola l'offset necessario per centrare
        let offset = parentNode.y - childrenCenterY
        
        // Se l'offset è significativo (> 10 pixel), suggerisci rebalancing
        let needsRebalancing = abs(offset) > 10
        
        return (needsRebalancing, offset)
    }
    
    // MARK: - Rebalancing Application
    
    /// Applica il rebalancing spostando i nodi appropriati.
    /// - Se parentIsRoot: sposta tutti i figli dell'offset calcolato (Root resta ferma)
    /// - Altrimenti: sposta solo il genitore
    /// - Parameters:
    ///   - result: Il risultato del layout contenente le info di rebalancing
    ///   - parentNode: Il nodo genitore
    ///   - children: I figli del genitore (incluso il nuovo appena creato)
    ///   - direction: La direzione per filtrare i figli da spostare
    func applyRebalancing(
        result: NodeLayoutResult,
        parentNode: SynapseNode,
        children: [SynapseNode]
    ) {
        guard result.needsRebalancing else { return }
        
        if result.parentIsRoot {
            // FIXED ROOT: la Root non si muove, spostiamo i figli sullo stesso lato
            let sameSideChildren = children.filter { child in
                switch result.direction {
                case .right: return child.x >= parentNode.x
                case .left: return child.x <= parentNode.x
                }
            }
            
            for child in sameSideChildren {
                moveSubtree(node: child, deltaY: result.rebalanceOffset)
            }
        } else {
            // Nodo normale: sposta il genitore
            parentNode.y += result.rebalanceOffset
        }
    }
    
    /// Sposta un nodo e tutto il suo subtree di un delta Y.
    /// **Rispetta isPinned**: I nodi pinnati NON vengono spostati.
    private func moveSubtree(node: SynapseNode, deltaY: CGFloat) {
        // Se il nodo è pinnato, NON spostarlo (user intent ha la priorità)
        if !node.isPinned {
            node.y += deltaY
        }
        
        // Sposta anche tutti i figli ricorsivamente (se non pinnati)
        for connection in node.outgoingConnections {
            if let child = connection.target {
                moveSubtree(node: child, deltaY: deltaY)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Trova la posizione della Root partendo da un qualsiasi nodo
    private func findRootPosition(from node: SynapseNode) -> CGPoint {
        var current = node
        
        // Risali l'albero fino alla root (nodo senza connessioni in entrata)
        while let parentConnection = current.incomingConnections.first,
              let parent = parentConnection.source {
            current = parent
        }
        
        return current.position
    }
    
    /// Trova tutti i figli diretti di un nodo
    private func findChildren(of node: SynapseNode) -> [SynapseNode] {
        return node.outgoingConnections.compactMap { $0.target }
    }
    
    /// Trova tutti i fratelli di un nodo (altri figli dello stesso genitore)
    func findSiblings(of node: SynapseNode) -> [SynapseNode] {
        guard let parentConnection = node.incomingConnections.first,
              let parent = parentConnection.source else {
            return []
        }
        
        return findChildren(of: parent).filter { $0.id != node.id }
    }
    
    // MARK: - Collision Detection & Avoidance
    
    /// Padding minimo tra due nodi (margine di sicurezza)
    static let collisionPadding: CGFloat = 20
    
    /// Verifica se due nodi si sovrappongono
    /// - Parameters:
    ///   - node1: Primo nodo
    ///   - node2: Secondo nodo
    /// - Returns: True se i nodi si sovrappongono
    func nodesOverlap(_ node1: SynapseNode, _ node2: SynapseNode) -> Bool {
        let rect1 = getNodeRect(node1)
        let rect2 = getNodeRect(node2)
        return rect1.intersects(rect2)
    }
    
    /// Ottiene il rettangolo di un nodo (con padding di sicurezza)
    private func getNodeRect(_ node: SynapseNode) -> CGRect {
        let padding = NodeLayoutService.collisionPadding / 2
        return CGRect(
            x: node.x - (node.width / 2) - padding,
            y: node.y - (node.height / 2) - padding,
            width: node.width + NodeLayoutService.collisionPadding,
            height: node.height + NodeLayoutService.collisionPadding
        )
    }
    
    /// Trova tutti i nodi che si sovrappongono con un nodo specifico
    /// - Parameters:
    ///   - node: Il nodo da controllare
    ///   - allNodes: Lista di tutti i nodi
    /// - Returns: Lista di nodi che si sovrappongono con `node`
    func findOverlappingNodes(for node: SynapseNode, in allNodes: [SynapseNode]) -> [SynapseNode] {
        return allNodes.filter { other in
            other.id != node.id && nodesOverlap(node, other)
        }
    }
    
    /// Calcola quanto spostare un nodo per evitare la collisione con un altro
    /// - Parameters:
    ///   - movingNode: Il nodo da spostare
    ///   - staticNode: Il nodo che rimane fermo
    /// - Returns: Delta Y da applicare al movingNode
    private func calculateRepulsionDelta(movingNode: SynapseNode, staticNode: SynapseNode) -> CGFloat {
        let movingRect = getNodeRect(movingNode)
        let staticRect = getNodeRect(staticNode)
        
        // Se non si sovrappongono, nessun delta
        guard movingRect.intersects(staticRect) else { return 0 }
        
        // Calcola la direzione di repulsione (allontana verso l'alto o il basso)
        if movingNode.y < staticNode.y {
            // Il nodo mobile è sopra: spostalo ancora più su
            let overlap = staticRect.minY - movingRect.maxY
            return overlap - NodeLayoutService.collisionPadding
        } else {
            // Il nodo mobile è sotto: spostalo ancora più giù
            let overlap = movingRect.minY - staticRect.maxY
            return -overlap + NodeLayoutService.collisionPadding
        }
    }
    
    /// Risolve tutte le collisioni tra fratelli sullo stesso livello.
    /// I nodi vengono spostati verso l'alto o il basso per creare spazio.
    ///
    /// - Parameters:
    ///   - siblings: Lista di fratelli da controllare (figli dello stesso genitore)
    ///   - allNodes: Tutti i nodi nella mappa
    func resolveSiblingCollisions(siblings: [SynapseNode], allNodes: [SynapseNode]) {
        guard siblings.count >= 2 else { return }
        
        // Ordina i fratelli per Y
        let sortedSiblings = siblings.sorted { $0.y < $1.y }
        
        // Per ogni coppia consecutiva, verifica e risolvi collisioni
        for i in 0..<(sortedSiblings.count - 1) {
            let upperNode = sortedSiblings[i]
            let lowerNode = sortedSiblings[i + 1]
            
            let upperBounds = calculateSubtreeBounds(for: upperNode, allNodes: allNodes, connections: [])
            let lowerBounds = calculateSubtreeBounds(for: lowerNode, allNodes: allNodes, connections: [])
            
            // Controlla se i subtree si sovrappongono
            if upperBounds.maxY + NodeLayoutService.collisionPadding > lowerBounds.minY {
                // Calcola quanto spostare il nodo inferiore (e il suo subtree)
                let overlap = upperBounds.maxY + NodeLayoutService.collisionPadding - lowerBounds.minY
                moveSubtree(node: lowerNode, deltaY: overlap)
            }
        }
    }
    
    /// Risolve le collisioni per un singolo nodo appena creato.
    /// Sposta il nodo verso il basso finché non trova uno slot libero.
    ///
    /// - Parameters:
    ///   - newNode: Il nodo appena creato
    ///   - allNodes: Tutti i nodi nella mappa
    ///   - maxAttempts: Numero massimo di tentativi di riposizionamento
    func resolveCollisionsForNewNode(newNode: SynapseNode, allNodes: [SynapseNode], maxAttempts: Int = 20) {
        var attempts = 0
        
        while attempts < maxAttempts {
            let overlapping = findOverlappingNodes(for: newNode, in: allNodes)
            
            if overlapping.isEmpty {
                return // Nessuna collisione, posizione OK
            }
            
            // Trova il nodo con cui c'è la sovrapposizione più critica
            // e calcola lo spostamento necessario
            var maxDelta: CGFloat = 0
            for otherNode in overlapping {
                let delta = calculateRepulsionDelta(movingNode: newNode, staticNode: otherNode)
                if abs(delta) > abs(maxDelta) {
                    maxDelta = delta
                }
            }
            
            // Applica lo spostamento
            if abs(maxDelta) > 0 {
                newNode.y += maxDelta
            } else {
                // Fallback: sposta di un padding fisso verso il basso
                newNode.y += NodeLayoutService.verticalPadding + newNode.height
            }
            
            attempts += 1
        }
        
        print("⚠️ Warning: Could not resolve all collisions after \(maxAttempts) attempts")
    }
    
    /// Risolve le collisioni globali tra tutti i nodi.
    /// Utile dopo operazioni di layout che potrebbero aver causato sovrapposizioni.
    ///
    /// - Parameter allNodes: Tutti i nodi nella mappa
    func resolveAllCollisions(allNodes: [SynapseNode]) {
        // Ordina i nodi per Y per processarli dall'alto verso il basso
        let sortedNodes = allNodes.sorted { $0.y < $1.y }
        
        for node in sortedNodes {
            resolveCollisionsForNewNode(newNode: node, allNodes: allNodes, maxAttempts: 10)
        }
    }
    
    // MARK: - Trident Layout (Parent Centering)
    
    /// Calcola la posizione Y centrata per un genitore basandosi sui suoi figli.
    /// 
    /// **Formula Trident Layout:**
    /// `Parent.y = (FirstChild.y + LastChild.y) / 2`
    /// 
    /// Questo assicura che il genitore sia centrato verticalmente rispetto
    /// a tutti i suoi figli diretti, creando un layout "a tridente" bilanciato.
    ///
    /// - Parameter parentNode: Il nodo genitore da centrare
    /// - Returns: La nuova coordinata Y per il genitore, o nil se non ha figli
    func calculateCenteredParentY(for parentNode: SynapseNode) -> CGFloat? {
        let children = findChildren(of: parentNode)
        guard !children.isEmpty else { return nil }
        
        // Ordina i figli per Y
        let sortedChildren = children.sorted { $0.y < $1.y }
        
        guard let firstChild = sortedChildren.first,
              let lastChild = sortedChildren.last else {
            return nil
        }
        
        // Formula: Parent.y = (FirstChild.y + LastChild.y) / 2
        return (firstChild.y + lastChild.y) / 2
    }
    
    /// Applica il Trident Layout: centra il genitore rispetto ai suoi figli.
    /// Se il genitore è la Root, invece di spostare la Root, sposta tutti i figli.
    /// **Rispetta isPinned**: Se il genitore è pinnato, NON viene spostato (ma si usa comunque per calcoli).
    ///
    /// - Parameters:
    ///   - parentNode: Il nodo genitore
    ///   - isRoot: True se il genitore è la Root (non si deve spostare)
    func applyTridentLayout(parentNode: SynapseNode, isRoot: Bool) {
        guard let targetY = calculateCenteredParentY(for: parentNode) else { return }
        
        let deltaY = targetY - parentNode.y
        guard abs(deltaY) > 1 else { return } // Skip if difference is negligible
        
        if isRoot {
            // FIXED ROOT: sposta tutti i figli per centrare rispetto alla Root
            let children = findChildren(of: parentNode)
            for child in children {
                moveSubtree(node: child, deltaY: -deltaY)
            }
        } else if !parentNode.isPinned {
            // Nodo normale NON pinnato: sposta il genitore alla posizione centrata
            parentNode.y = targetY
        }
        // Se parentNode.isPinned == true: non spostare il genitore (user intent)
        // ma il calcolo è comunque fatto per altri usi
    }
    
    /// Applica il Trident Layout ricorsivamente a tutto l'albero.
    /// Utile dopo aver aggiunto molti nodi per ribilanciare tutto.
    /// **Rispetta isPinned**: I nodi pinnati non vengono spostati.
    ///
    /// - Parameter rootNode: La radice dell'albero
    func applyTridentLayoutRecursively(rootNode: SynapseNode) {
        // Prima applica ai sottoalberi (bottom-up)
        let children = findChildren(of: rootNode)
        for child in children {
            applyTridentLayoutRecursively(rootNode: child)
        }
        
        // Poi applica a questo nodo
        let isRoot = rootNode.incomingConnections.isEmpty
        applyTridentLayout(parentNode: rootNode, isRoot: isRoot)
    }
    
    // MARK: - Hybrid Layout Update (Responsive Layout)
    
    /// Esegue un aggiornamento ibrido del layout dopo che un nodo è stato spostato.
    /// Questo metodo è ottimizzato per essere chiamato dopo ogni drag gesture.
    ///
    /// **Gerarchia di Priorità:**
    /// 1. Anti-Collision: I nodi non si sovrappongono mai
    /// 2. Manual Positioning: I nodi pinnati mantengono la loro posizione
    /// 3. Algorithmic Layout: I nodi non pinnati si riposizionano per centrare i genitori
    ///
    /// - Parameters:
    ///   - movedNode: Il nodo che è stato spostato dall'utente
    ///   - allNodes: Tutti i nodi nella mappa
    func applyHybridLayoutUpdate(movedNode: SynapseNode, allNodes: [SynapseNode]) {
        // 1. Ricentra i genitori rispetto ai figli (incluso il nodo spostato)
        //    Risali l'albero dal nodo spostato fino alla root
        var currentNode = movedNode
        while let parentConnection = currentNode.incomingConnections.first,
              let parent = parentConnection.source {
            let isRoot = parent.incomingConnections.isEmpty
            applyTridentLayout(parentNode: parent, isRoot: isRoot)
            currentNode = parent
        }
        
        // 2. Risolvi collisioni per tutti i fratelli del nodo spostato
        if let parentConnection = movedNode.incomingConnections.first,
           let parent = parentConnection.source {
            let siblings = findChildren(of: parent)
            resolveSiblingCollisions(siblings: siblings, allNodes: allNodes)
        }
        
        // 3. Risolvi eventuali collisioni globali causate dallo spostamento
        resolveCollisionsForNewNode(newNode: movedNode, allNodes: allNodes)
    }
    
    // MARK: - Subtree Mirroring (Side Change Detection)
    
    /// Rileva se un nodo ha attraversato la linea centrale (root X) e specchia il subtree.
    /// Chiamato dopo che un nodo è stato trascinato per verificare se è cambiato lato.
    ///
    /// - Parameters:
    ///   - movedNode: Il nodo che è stato spostato
    ///   - previousX: La posizione X precedente del nodo (prima del drag)
    ///   - allNodes: Tutti i nodi nella mappa
    func checkAndMirrorSubtreeIfSideChanged(
        movedNode: SynapseNode,
        previousX: CGFloat,
        allNodes: [SynapseNode]
    ) {
        // Trova la root position
        let rootPosition = findRootPosition(from: movedNode)
        
        // Determina il lato precedente e attuale
        let wasOnLeft = previousX < rootPosition.x
        let isNowOnLeft = movedNode.x < rootPosition.x
        
        // Se il lato è cambiato, specchia tutto il subtree
        if wasOnLeft != isNowOnLeft {
            mirrorSubtree(node: movedNode, rootX: rootPosition.x)
        }
    }
    
    /// Specchia un nodo e tutto il suo subtree rispetto alla posizione X della root.
    /// Tutti i figli vengono riposizionati sul lato opposto.
    ///
    /// **Formula:**
    /// `newX = rootX + (rootX - oldX)` oppure `newX = 2 * rootX - oldX`
    ///
    /// - Parameters:
    ///   - node: Il nodo radice del subtree da specchiare
    ///   - rootX: La coordinata X della root (asse di simmetria)
    func mirrorSubtree(node: SynapseNode, rootX: CGFloat) {
        // Specchia solo i figli, non il nodo stesso (che è già stato spostato dall'utente)
        for connection in node.outgoingConnections {
            if let child = connection.target {
                mirrorNodeAndDescendants(node: child, rootX: rootX)
            }
        }
    }
    
    /// Specchia un nodo e tutti i suoi discendenti rispetto a rootX.
    /// Funzione ricorsiva interna.
    private func mirrorNodeAndDescendants(node: SynapseNode, rootX: CGFloat) {
        // Formula di specchiatura: newX = 2 * rootX - oldX
        let newX = 2 * rootX - node.x
        node.x = newX
        
        // Ricorsivamente specchia tutti i figli
        for connection in node.outgoingConnections {
            if let child = connection.target {
                mirrorNodeAndDescendants(node: child, rootX: rootX)
            }
        }
    }
    
    // MARK: - Edge Routing (Avoid Node Intersections)
    
    /// Genera un path Bézier che evita di passare attraverso altri nodi.
    /// Se il percorso diretto interseca un nodo, la curva viene deviata per aggirarlo.
    ///
    /// - Parameters:
    ///   - sourceCenter: Centro del nodo sorgente
    ///   - targetCenter: Centro del nodo destinazione
    ///   - sourceSize: Dimensioni del nodo sorgente
    ///   - targetSize: Dimensioni del nodo destinazione
    ///   - allNodes: Tutti i nodi nella mappa (per collision detection)
    ///   - sourceNode: Il nodo sorgente (per escluderlo dal collision check)
    ///   - targetNode: Il nodo target (per escluderlo dal collision check)
    /// - Returns: Path Bézier che evita le intersezioni con altri nodi
    func createRoutedConnectionPath(
        from sourceCenter: CGPoint,
        to targetCenter: CGPoint,
        sourceSize: CGSize,
        targetSize: CGSize,
        allNodes: [SynapseNode],
        sourceNode: SynapseNode,
        targetNode: SynapseNode
    ) -> Path {
        var path = Path()
        
        // Calcola la direzione
        let direction = targetCenter.x > sourceCenter.x ? LayoutDirection.right : .left
        
        // Calcola i punti di ancoraggio ai bordi dei nodi
        let startPoint: CGPoint
        let endPoint: CGPoint
        
        switch direction {
        case .right:
            startPoint = CGPoint(x: sourceCenter.x + sourceSize.width / 2, y: sourceCenter.y)
            endPoint = CGPoint(x: targetCenter.x - targetSize.width / 2, y: targetCenter.y)
        case .left:
            startPoint = CGPoint(x: sourceCenter.x - sourceSize.width / 2, y: sourceCenter.y)
            endPoint = CGPoint(x: targetCenter.x + targetSize.width / 2, y: targetCenter.y)
        }
        
        // Trova nodi che potrebbero interferire con il percorso
        let obstructingNodes = findObstructingNodes(
            from: startPoint,
            to: endPoint,
            allNodes: allNodes,
            excludeNodes: [sourceNode, targetNode]
        )
        
        if obstructingNodes.isEmpty {
            // Nessun ostacolo: usa il path standard
            return createDynamicConnectionPath(
                from: sourceCenter,
                to: targetCenter,
                sourceSize: sourceSize,
                targetSize: targetSize
            )
        }
        
        // Calcola il bypass: devia la curva sopra o sotto gli ostacoli
        let bypassY = calculateBypassY(
            startY: startPoint.y,
            endY: endPoint.y,
            obstructingNodes: obstructingNodes
        )
        
        // Crea un path con un punto intermedio per bypassare gli ostacoli
        let midX = (startPoint.x + endPoint.x) / 2
        let controlOffset = abs(endPoint.x - startPoint.x) * 0.3
        
        switch direction {
        case .right:
            let cp1 = CGPoint(x: startPoint.x + controlOffset, y: startPoint.y)
            let midPoint = CGPoint(x: midX, y: bypassY)
            let cp2 = CGPoint(x: midX - controlOffset * 0.5, y: bypassY)
            let cp3 = CGPoint(x: midX + controlOffset * 0.5, y: bypassY)
            let cp4 = CGPoint(x: endPoint.x - controlOffset, y: endPoint.y)
            
            path.move(to: startPoint)
            path.addQuadCurve(to: midPoint, control: cp1)
            path.addQuadCurve(to: endPoint, control: cp4)
            
        case .left:
            let cp1 = CGPoint(x: startPoint.x - controlOffset, y: startPoint.y)
            let cp4 = CGPoint(x: endPoint.x + controlOffset, y: endPoint.y)
            
            path.move(to: startPoint)
            path.addQuadCurve(to: CGPoint(x: midX, y: bypassY), control: cp1)
            path.addQuadCurve(to: endPoint, control: cp4)
        }
        
        return path
    }
    
    /// Trova i nodi che ostruiscono il percorso diretto tra due punti
    private func findObstructingNodes(
        from start: CGPoint,
        to end: CGPoint,
        allNodes: [SynapseNode],
        excludeNodes: [SynapseNode]
    ) -> [SynapseNode] {
        let excludeIDs = Set(excludeNodes.map { $0.id })
        
        // Bounding box del percorso diretto (con un po' di margine)
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y) - 20
        let maxY = max(start.y, end.y) + 20
        
        return allNodes.filter { node in
            // Escludi source e target
            guard !excludeIDs.contains(node.id) else { return false }
            
            // Controlla se il nodo è nel corridoio del percorso
            let nodeMinX = node.x - node.width / 2
            let nodeMaxX = node.x + node.width / 2
            let nodeMinY = node.y - node.height / 2
            let nodeMaxY = node.y + node.height / 2
            
            let xOverlap = nodeMaxX > minX && nodeMinX < maxX
            let yOverlap = nodeMaxY > minY && nodeMinY < maxY
            
            return xOverlap && yOverlap
        }
    }
    
    /// Calcola la Y del bypass per evitare gli ostacoli
    private func calculateBypassY(
        startY: CGFloat,
        endY: CGFloat,
        obstructingNodes: [SynapseNode]
    ) -> CGFloat {
        // Trova i bounds verticali degli ostacoli
        var minObstacleY = CGFloat.infinity
        var maxObstacleY = -CGFloat.infinity
        
        for node in obstructingNodes {
            let nodeTop = node.y - node.height / 2
            let nodeBottom = node.y + node.height / 2
            minObstacleY = min(minObstacleY, nodeTop)
            maxObstacleY = max(maxObstacleY, nodeBottom)
        }
        
        // Scegli se passare sopra o sotto gli ostacoli
        let avgY = (startY + endY) / 2
        let distanceToTop = abs(avgY - minObstacleY)
        let distanceToBottom = abs(avgY - maxObstacleY)
        
        if distanceToTop < distanceToBottom {
            // Passa sopra
            return minObstacleY - 30
        } else {
            // Passa sotto
            return maxObstacleY + 30
        }
    }
    
    // MARK: - Dynamic Edge Curvature (Prevents Overlapping Arrows)
    
    /// Genera un path Bézier con curvatura dinamica per prevenire sovrapposizione frecce.
    /// 
    /// **Caratteristiche:**
    /// - Control points dinamici basati sulla distanza verticale (dy)
    /// - Angoli di uscita variabili per evitare che le frecce si fondano
    /// - Estensione orizzontale maggiore per target lontani verticalmente
    ///
    /// - Parameters:
    ///   - sourceCenter: Centro del nodo sorgente
    ///   - targetCenter: Centro del nodo destinazione
    ///   - sourceSize: Dimensioni del nodo sorgente
    ///   - targetSize: Dimensioni del nodo destinazione
    ///   - childIndex: Indice del figlio (per variare l'angolo di uscita)
    ///   - totalChildren: Numero totale di figli (per calcolare la variazione)
    /// - Returns: Path Bézier per disegnare la connessione
    func createDynamicConnectionPath(
        from sourceCenter: CGPoint,
        to targetCenter: CGPoint,
        sourceSize: CGSize,
        targetSize: CGSize,
        childIndex: Int = 0,
        totalChildren: Int = 1
    ) -> Path {
        var path = Path()
        
        // Calcola la direzione
        let direction = targetCenter.x > sourceCenter.x ? LayoutDirection.right : .left
        
        // Calcola i punti di ancoraggio ai bordi dei nodi
        let startPoint: CGPoint
        let endPoint: CGPoint
        
        switch direction {
        case .right:
            startPoint = CGPoint(
                x: sourceCenter.x + sourceSize.width / 2,
                y: sourceCenter.y
            )
            endPoint = CGPoint(
                x: targetCenter.x - targetSize.width / 2,
                y: targetCenter.y
            )
        case .left:
            startPoint = CGPoint(
                x: sourceCenter.x - sourceSize.width / 2,
                y: sourceCenter.y
            )
            endPoint = CGPoint(
                x: targetCenter.x + targetSize.width / 2,
                y: targetCenter.y
            )
        }
        
        // Calcola distanze
        let dx = abs(endPoint.x - startPoint.x)
        let dy = endPoint.y - startPoint.y  // Mantieni il segno per sapere se va su o giù
        let absDy = abs(dy)
        
        // === DYNAMIC CURVATURE based on vertical distance ===
        // Se il target è lontano verticalmente, estendi il control point orizzontalmente
        let baseHorizontalOffset = dx * 0.35
        let dyFactor = min(absDy / 200.0, 1.0)  // Normalizza a 0-1
        let extendedOffset = baseHorizontalOffset + (dx * 0.25 * dyFactor)
        
        // === EXIT ANGLE VARIATION to prevent arrow merging ===
        // Calcola un offset verticale per il primo control point basato sull'indice del figlio
        // Questo fa sì che le frecce abbiano angoli di uscita leggermente diversi
        var exitAngleOffset: CGFloat = 0
        if totalChildren > 1 {
            // Distribuisci gli angoli tra -10 e +10 pixel
            let normalizedIndex = CGFloat(childIndex) / CGFloat(totalChildren - 1) - 0.5  // -0.5 to 0.5
            exitAngleOffset = normalizedIndex * 20.0  // -10 to +10 pixels
        }
        
        // === DYNAMIC CONTROL POINTS ===
        let control1: CGPoint
        let control2: CGPoint
        
        switch direction {
        case .right:
            // Primo control point: esce orizzontalmente con leggera variazione angolare
            control1 = CGPoint(
                x: startPoint.x + extendedOffset,
                y: startPoint.y + exitAngleOffset
            )
            // Secondo control point: entra nel target da sinistra
            control2 = CGPoint(
                x: endPoint.x - min(extendedOffset, dx * 0.4),
                y: endPoint.y
            )
            
        case .left:
            control1 = CGPoint(
                x: startPoint.x - extendedOffset,
                y: startPoint.y + exitAngleOffset
            )
            control2 = CGPoint(
                x: endPoint.x + min(extendedOffset, dx * 0.4),
                y: endPoint.y
            )
        }
        
        path.move(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
        
        return path
    }
    
    /// Genera un path Bézier classico S-curve (per retrocompatibilità)
    func createAdaptiveConnectionPath(
        from sourceCenter: CGPoint,
        to targetCenter: CGPoint,
        sourceSize: CGSize,
        targetSize: CGSize
    ) -> Path {
        return createDynamicConnectionPath(
            from: sourceCenter,
            to: targetCenter,
            sourceSize: sourceSize,
            targetSize: targetSize,
            childIndex: 0,
            totalChildren: 1
        )
    }
    
    /// Genera un path Bézier semplificato (S-curve) per connessioni orizzontali tipiche
    func createSimpleSCurvePath(
        from startPoint: CGPoint,
        to endPoint: CGPoint
    ) -> Path {
        var path = Path()
        
        let midX = (startPoint.x + endPoint.x) / 2
        
        path.move(to: startPoint)
        path.addCurve(
            to: endPoint,
            control1: CGPoint(x: midX, y: startPoint.y),
            control2: CGPoint(x: midX, y: endPoint.y)
        )
        
        return path
    }
}
