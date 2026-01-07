//
//  GroupBraceView.swift
//  Synapse
//
//  Vista che renderizza un gruppo completo: parentesi graffa + linea al label node.
//  Calcola dinamicamente la geometria basandosi sulle posizioni correnti dei nodi membri.
//

import SwiftUI

/// Vista che renderizza un gruppo visivo di nodi.
/// Mostra la parentesi graffa e una linea di connessione al label node.
struct GroupBraceView: View {
    
    /// Il gruppo da renderizzare
    let group: SynapseGroup
    
    /// ViewModel per accedere ai nodi
    @Bindable var viewModel: MapViewModel
    
    /// Colore della parentesi
    var braceColor: Color = Color.secondary.opacity(0.6)
    
    /// Spessore della parentesi
    var lineWidth: CGFloat = 1.5
    
    /// Offset della parentesi dal bounding box
    private let braceOffset: CGFloat = 8
    
    /// Offset della punta della parentesi
    private let tipOffset: CGFloat = 20
    
    var body: some View {
        // Calcola dinamicamente la geometria basandosi sulle posizioni correnti
        if let boundingBox = viewModel.computeBoundingBox(for: group),
           let labelNode = viewModel.labelNode(for: group) {
            
            // Calcola i punti della parentesi
            let braceGeometry = computeBraceGeometry(
                boundingBox: boundingBox,
                orientation: group.orientation
            )
            
            ZStack {
                // 1. Disegna la parentesi graffa
                BraceShape(
                    startPoint: braceGeometry.startPoint,
                    endPoint: braceGeometry.endPoint,
                    tipPoint: braceGeometry.tipPoint,
                    orientation: group.orientation
                )
                .stroke(braceColor, lineWidth: lineWidth)
                
                // 2. Disegna la linea dalla punta della parentesi al label node
                connectionLine(
                    from: braceGeometry.tipPoint,
                    to: labelNode.position
                )
            }
            .allowsHitTesting(false) // La parentesi non intercetta i click
        }
    }
    
    /// Struttura per i punti geometrici della parentesi
    private struct BraceGeometry {
        let startPoint: CGPoint
        let endPoint: CGPoint
        let tipPoint: CGPoint
    }
    
    /// Calcola i punti della parentesi basandosi sul bounding box e l'orientamento.
    private func computeBraceGeometry(
        boundingBox: CGRect,
        orientation: GroupOrientation
    ) -> BraceGeometry {
        switch orientation {
        case .vertical:
            // Parentesi verticale } sul lato destro
            let x = boundingBox.maxX + braceOffset
            return BraceGeometry(
                startPoint: CGPoint(x: x, y: boundingBox.minY),
                endPoint: CGPoint(x: x, y: boundingBox.maxY),
                tipPoint: CGPoint(x: x + tipOffset, y: boundingBox.midY)
            )
            
        case .horizontal:
            // Parentesi orizzontale ︸ sul lato inferiore
            let y = boundingBox.maxY + braceOffset
            return BraceGeometry(
                startPoint: CGPoint(x: boundingBox.minX, y: y),
                endPoint: CGPoint(x: boundingBox.maxX, y: y),
                tipPoint: CGPoint(x: boundingBox.midX, y: y + tipOffset)
            )
        }
    }
    
    /// Disegna una linea sottile dalla punta della parentesi al centro del label node.
    @ViewBuilder
    private func connectionLine(from: CGPoint, to: CGPoint) -> some View {
        // Calcola il punto di ancoraggio sul bordo del label node
        let targetPoint = calculateLabelAnchorPoint(
            labelCenter: to,
            bracePoint: from
        )
        
        Path { path in
            path.move(to: from)
            path.addLine(to: targetPoint)
        }
        .stroke(
            braceColor,
            style: StrokeStyle(lineWidth: lineWidth * 0.8, lineCap: .round)
        )
    }
    
    /// Calcola il punto di ancoraggio sul bordo del label node.
    /// La linea si connette al bordo del nodo, non al centro.
    private func calculateLabelAnchorPoint(
        labelCenter: CGPoint,
        bracePoint: CGPoint
    ) -> CGPoint {
        // Calcola la direzione dalla parentesi al label
        let dx = labelCenter.x - bracePoint.x
        let dy = labelCenter.y - bracePoint.y
        let distance = hypot(dx, dy)
        
        guard distance > 0 else { return labelCenter }
        
        // Dimensioni del label node (usiamo le dimensioni di default)
        let nodeHalfWidth = SynapseNode.defaultWidth / 2
        let nodeHalfHeight = SynapseNode.defaultHeight / 2
        
        // Calcola il punto sul bordo del nodo nella direzione della parentesi
        // Usiamo un approccio semplificato: proiettiamo sulla direzione
        let scale = min(
            nodeHalfWidth / max(abs(dx), 0.001),
            nodeHalfHeight / max(abs(dy), 0.001)
        )
        
        let clampedScale = min(scale * distance, distance) / distance
        
        return CGPoint(
            x: labelCenter.x - dx * clampedScale * 0.9,
            y: labelCenter.y - dy * clampedScale * 0.9
        )
    }
}

// MARK: - Preview

#Preview {
    // Preview placeholder - requires MapViewModel setup
    Text("GroupBraceView Preview")
        .frame(width: 400, height: 300)
}
