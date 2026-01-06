//
//  SynapseConnection.swift
//  Synapse
//
//  Modello SwiftData per le connessioni (frecce) tra nodi.
//  Ogni connessione ha un'etichetta che descrive la relazione.
//

import Foundation
import SwiftData

// MARK: - Codable Range Helper

/// Struct Codable per serializzare NSRange (che non è Codable di default)
struct CodableRange: Codable, Hashable {
    let location: Int
    let length: Int
    
    init(_ range: NSRange) {
        self.location = range.location
        self.length = range.length
    }
    
    var nsRange: NSRange {
        NSRange(location: location, length: length)
    }
}

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
    
    // MARK: - Word-Level Anchoring (Multi-Range Support)
    
    /// Dati JSON-encoded per i range di testo sorgente (supporta parole multiple)
    /// Se nil, la connessione parte dal nodo intero
    var fromRangesData: Data?
    
    /// Computed property per verificare se la connessione è ancorata a parole
    var isWordAnchored: Bool {
        guard let ranges = fromRanges else { return false }
        return !ranges.isEmpty
    }
    
    /// Computed property per ottenere/impostare gli NSRange
    var fromRanges: [NSRange]? {
        get {
            guard let data = fromRangesData else { return nil }
            guard let codableRanges = try? JSONDecoder().decode([CodableRange].self, from: data) else {
                return nil
            }
            return codableRanges.map { $0.nsRange }
        }
        set {
            guard let ranges = newValue, !ranges.isEmpty else {
                fromRangesData = nil
                return
            }
            let codableRanges = ranges.map { CodableRange($0) }
            fromRangesData = try? JSONEncoder().encode(codableRanges)
        }
    }
    
    /// Convenience per ottenere il primo range (retrocompatibilità)
    var fromTextRange: NSRange? {
        fromRanges?.first
    }
    
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
    ///   - fromRanges: Array opzionale di range per word-level linking (supporta parole multiple)
    init(source: SynapseNode, target: SynapseNode, label: String = "", fromRanges: [NSRange]? = nil) {
        self.id = UUID()
        self.source = source
        self.target = target
        self.label = label
        self.fromRanges = fromRanges
    }
    
    /// Convenience initializer per singolo range (retrocompatibilità)
    convenience init(source: SynapseNode, target: SynapseNode, label: String = "", fromRange: NSRange?) {
        if let range = fromRange {
            self.init(source: source, target: target, label: label, fromRanges: [range])
        } else {
            self.init(source: source, target: target, label: label, fromRanges: nil)
        }
    }
}
