//
//  SynapseConnection.swift
//  Synapse
//
//  Modello SwiftData per le connessioni (frecce) tra nodi.
//  Ogni connessione ha un'etichetta che descrive la relazione.
//

import Foundation
import SwiftData

/// Rappresenta una connessione direzionale tra due nodi.
/// La connessione può avere un'etichetta che descrive la relazione
/// (es. "causa", "implica", "dipende da").
@Model
final class SynapseConnection {
    
    // MARK: - Proprietà Base
    
    /// Identificatore unico della connessione
    var id: UUID
    
    /// Testo dell'etichetta sulla freccia.
    /// Descrive la natura della relazione tra i due nodi.
    var label: String
    
    // MARK: - Relazioni
    
    /// Nodo di partenza della connessione.
    /// La relazione inversa è gestita da SynapseNode.outgoingConnections
    var source: SynapseNode?
    
    /// Nodo di destinazione della connessione.
    /// La relazione inversa è gestita da SynapseNode.incomingConnections
    var target: SynapseNode?
    
    // MARK: - Inizializzatore
    
    /// Crea una nuova connessione tra due nodi.
    /// - Parameters:
    ///   - source: Nodo di partenza
    ///   - target: Nodo di destinazione
    ///   - label: Etichetta che descrive la relazione (default: stringa vuota)
    init(source: SynapseNode, target: SynapseNode, label: String = "") {
        self.id = UUID()
        self.source = source
        self.target = target
        self.label = label
    }
}
