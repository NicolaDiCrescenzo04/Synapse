//
//  SynapseGroup.swift
//  Synapse
//
//  Modello SwiftData per i gruppi di nodi.
//  Un gruppo rappresenta una parentesi graffa che abbraccia nodi selezionati
//  con un nodo etichetta alla punta.
//

import Foundation
import SwiftData

/// Orientamento della parentesi graffa del gruppo.
enum GroupOrientation: String, Codable {
    case vertical   // Parentesi } sul lato destro
    case horizontal // Parentesi ︸ sul lato inferiore
}

/// Rappresenta un gruppo visivo di nodi con una parentesi graffa.
/// Il gruppo non modifica le relazioni tra nodi, ma crea una visualizzazione
/// che li "abbraccia" con un nodo etichetta alla punta.
@Model
final class SynapseGroup {
    
    // MARK: - Proprietà Base
    
    /// Identificatore unico del gruppo
    @Attribute(.unique) var id: UUID
    
    /// ID del nodo etichetta posizionato alla punta della parentesi
    var labelNodeID: UUID
    
    /// Orientamento della parentesi: "vertical" o "horizontal"
    /// Stored as String for SwiftData compatibility
    var orientationRaw: String
    
    // MARK: - Member Node IDs Storage
    
    /// Dati JSON-encoded per gli UUID dei nodi membri
    /// SwiftData non supporta direttamente Set<UUID>, quindi serializziamo
    @Attribute(.externalStorage) var memberNodeIDsData: Data?
    
    // MARK: - Computed Properties
    
    /// Orientamento della parentesi (computed per type-safety)
    var orientation: GroupOrientation {
        get { GroupOrientation(rawValue: orientationRaw) ?? .vertical }
        set { orientationRaw = newValue.rawValue }
    }
    
    /// Set di UUID dei nodi membri del gruppo
    var memberNodeIDs: Set<UUID> {
        get {
            guard let data = memberNodeIDsData else { return [] }
            guard let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) else {
                return []
            }
            return ids
        }
        set {
            memberNodeIDsData = try? JSONEncoder().encode(newValue)
        }
    }
    
    // MARK: - Inizializzatore
    
    /// Crea un nuovo gruppo con i nodi membri e il label node specificati.
    /// - Parameters:
    ///   - memberNodeIDs: Set di UUID dei nodi da raggruppare
    ///   - labelNodeID: UUID del nodo etichetta alla punta della parentesi
    ///   - orientation: Orientamento della parentesi (default: vertical)
    init(memberNodeIDs: Set<UUID>, labelNodeID: UUID, orientation: GroupOrientation = .vertical) {
        self.id = UUID()
        self.labelNodeID = labelNodeID
        self.orientationRaw = orientation.rawValue
        self.memberNodeIDs = memberNodeIDs
    }
}
