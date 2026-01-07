//
//  SynapseNode.swift
//  Synapse
//
//  Modello SwiftData per i nodi della mappa concettuale.
//  Ogni nodo ha coordinate persistenti (x, y) e può avere
//  connessioni in entrata e in uscita.
//

import Foundation
import SwiftData
import SwiftUI

/// Rappresenta un nodo nella mappa concettuale.
/// I nodi contengono testo e possono essere collegati tra loro tramite connessioni.
@Model
final class SynapseNode {
    
    // MARK: - Proprietà Base
    
    /// Identificatore unico del nodo
    @Attribute(.unique) var id: UUID
    
    /// Testo contenuto nel nodo
    var text: String
    
    /// Coordinata X sulla canvas (persistente)
    var x: Double
    
    /// Coordinata Y sulla canvas (persistente)
    var y: Double
    
    /// Larghezza del nodo (ridimensionabile)
    /// Default: 140 - necessario per migrazione SwiftData
    var width: Double = 140.0
    
    /// Altezza del nodo (ridimensionabile)
    /// Default: 70 - necessario per migrazione SwiftData
    var height: Double = 70.0
    
    /// Colore del nodo in formato esadecimale (es. "#FF5733")
    /// Opzionale per permettere styling futuro
    /// Colore del nodo in formato esadecimale (es. "#FF5733")
    /// Opzionale per permettere styling futuro
    var hexColor: String?

    /// Dati dell'immagine incorporata (opzionale)
    /// externalStorage suggerisce a SwiftData di salvare il blob su disco
    @Attribute(.externalStorage) var imageData: Data?
    
    /// Dati del testo formattato (RTF/NSAttributedString) per supportare stili misti
    @Attribute(.externalStorage) var richTextData: Data?
    
    /// Indica se il nodo è stato ridimensionato manualmente dall'utente.
    /// Se true, la larghezza è fissa e il testo va a capo (word wrap).
    /// Se false, il nodo auto-si adatta al contenuto (single-line, cresce orizzontalmente).
    var isManuallySized: Bool = false
    
    // MARK: - Costanti
    
    /// Larghezza minima del nodo
    static let minWidth: Double = 60
    
    /// Altezza minima del nodo
    static let minHeight: Double = 28
    
    /// Larghezza di default per nuovi nodi
    static let defaultWidth: Double = 100
    
    /// Altezza di default per nuovi nodi
    static let defaultHeight: Double = 36
    
    // MARK: - Relazioni
    
    /// Connessioni che partono da questo nodo.
    /// deleteRule: .cascade → eliminando il nodo, elimina tutte le frecce in uscita
    @Relationship(deleteRule: .cascade, inverse: \SynapseConnection.source)
    var outgoingConnections: [SynapseConnection] = []
    
    /// Connessioni che arrivano a questo nodo.
    /// deleteRule: .cascade → eliminando il nodo, elimina tutte le frecce in entrata
    @Relationship(deleteRule: .cascade, inverse: \SynapseConnection.target)
    var incomingConnections: [SynapseConnection] = []
    
    // MARK: - Computed Properties
    
    /// Posizione come CGPoint per l'uso in SwiftUI.
    /// Converte automaticamente tra Double (DB) e CGPoint (View).
    var position: CGPoint {
        get { CGPoint(x: x, y: y) }
        set {
            x = newValue.x
            y = newValue.y
        }
    }
    
    /// Dimensioni come CGSize per l'uso in SwiftUI.
    var size: CGSize {
        get { CGSize(width: width, height: height) }
        set {
            width = max(SynapseNode.minWidth, newValue.width)
            height = max(SynapseNode.minHeight, newValue.height)
        }
    }
    
    // MARK: - Inizializzatore
    
    /// Crea un nuovo nodo con testo e posizione specificati.
    /// - Parameters:
    ///   - text: Testo iniziale del nodo (default: stringa vuota)
    ///   - x: Coordinata X sulla canvas
    ///   - y: Coordinata Y sulla canvas
    ///   - width: Larghezza del nodo (default: 140)
    ///   - height: Altezza del nodo (default: 70)
    ///   - hexColor: Colore opzionale in formato esadecimale
    ///   - imageData: Dati immagine opzionali
    ///   - richTextData: Dati rich text opzionali
    init(text: String = "", x: Double, y: Double, width: Double = SynapseNode.defaultWidth, height: Double = SynapseNode.defaultHeight, hexColor: String? = nil, imageData: Data? = nil, richTextData: Data? = nil) {
        self.id = UUID()
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.hexColor = hexColor
        self.imageData = imageData
        self.richTextData = richTextData
    }
    
    /// Crea un nuovo nodo usando un CGPoint per la posizione.
    /// - Parameters:
    ///   - text: Testo iniziale del nodo
    ///   - position: Posizione come CGPoint
    ///   - hexColor: Colore opzionale in formato esadecimale
    convenience init(text: String = "", at position: CGPoint, hexColor: String? = nil, imageData: Data? = nil, richTextData: Data? = nil) {
        self.init(text: text, x: position.x, y: position.y, hexColor: hexColor, imageData: imageData, richTextData: richTextData)
    }
}

