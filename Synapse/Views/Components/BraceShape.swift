//
//  BraceShape.swift
//  Synapse
//
//  Forma della parentesi per i gruppi di nodi.
//  Stile "Square Bracket" con linee ortogonali a 90°.
//

import SwiftUI

/// Forma della parentesi quadra che abbraccia un gruppo di nodi.
/// Utilizza linee ortogonali (addLine) per un aspetto tecnico e pulito.
/// Forma a "forchetta" con angoli a 90°.
struct BraceShape: Shape {
    
    /// Punto di inizio della parentesi (estremo superiore/sinistro)
    let startPoint: CGPoint
    
    /// Punto di fine della parentesi (estremo inferiore/destro)
    let endPoint: CGPoint
    
    /// Punto della punta dove converge la parentesi
    let tipPoint: CGPoint
    
    /// Orientamento della parentesi
    let orientation: GroupOrientation
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        switch orientation {
        case .vertical:
            drawVerticalBrace(path: &path)
        case .horizontal:
            drawHorizontalBrace(path: &path)
        }
        
        return path
    }
    
    /// Disegna una parentesi quadra verticale: ⊐ (sul lato destro)
    /// Linee ortogonali: |_ che convergono alla punta _|
    private func drawVerticalBrace(path: inout Path) {
        // Calcola il punto intermedio X (a metà tra la linea e la punta)
        let midX = (startPoint.x + tipPoint.x) / 2
        let midY = (startPoint.y + endPoint.y) / 2
        
        // Parte superiore: startPoint → angolo → punta
        path.move(to: startPoint)
        // Linea orizzontale verso destra
        path.addLine(to: CGPoint(x: midX, y: startPoint.y))
        // Linea verticale verso il centro
        path.addLine(to: CGPoint(x: midX, y: midY))
        // Linea orizzontale verso la punta
        path.addLine(to: tipPoint)
        
        // Parte inferiore: punta → angolo → endPoint (nuova sub-path)
        path.move(to: tipPoint)
        // Linea orizzontale indietro
        path.addLine(to: CGPoint(x: midX, y: midY))
        // Linea verticale verso il basso
        path.addLine(to: CGPoint(x: midX, y: endPoint.y))
        // Linea orizzontale verso startPoint.x
        path.addLine(to: endPoint)
    }
    
    /// Disegna una parentesi quadra orizzontale: ⊥ (sul lato inferiore)
    /// Linee ortogonali: ⌐ che convergono alla punta ⌐
    private func drawHorizontalBrace(path: inout Path) {
        // Calcola il punto intermedio Y (a metà tra la linea e la punta)
        let midY = (startPoint.y + tipPoint.y) / 2
        let midX = (startPoint.x + endPoint.x) / 2
        
        // Parte sinistra: startPoint → angolo → punta
        path.move(to: startPoint)
        // Linea verticale verso il basso
        path.addLine(to: CGPoint(x: startPoint.x, y: midY))
        // Linea orizzontale verso il centro
        path.addLine(to: CGPoint(x: midX, y: midY))
        // Linea verticale verso la punta
        path.addLine(to: tipPoint)
        
        // Parte destra: punta → angolo → endPoint (nuova sub-path)
        path.move(to: tipPoint)
        // Linea verticale indietro
        path.addLine(to: CGPoint(x: midX, y: midY))
        // Linea orizzontale verso destra
        path.addLine(to: CGPoint(x: endPoint.x, y: midY))
        // Linea verticale verso startPoint.y
        path.addLine(to: endPoint)
    }
}

// MARK: - Preview

#Preview("Vertical Brace") {
    Canvas { context, size in
        let startPoint = CGPoint(x: 50, y: 50)
        let endPoint = CGPoint(x: 50, y: 250)
        let tipPoint = CGPoint(x: 100, y: 150)
        
        let brace = BraceShape(
            startPoint: startPoint,
            endPoint: endPoint,
            tipPoint: tipPoint,
            orientation: .vertical
        )
        
        context.stroke(
            brace.path(in: CGRect(origin: .zero, size: size)),
            with: .color(.accentColor),
            lineWidth: 2
        )
    }
    .frame(width: 200, height: 300)
    .background(Color.gray.opacity(0.1))
}

#Preview("Horizontal Brace") {
    Canvas { context, size in
        let startPoint = CGPoint(x: 50, y: 50)
        let endPoint = CGPoint(x: 250, y: 50)
        let tipPoint = CGPoint(x: 150, y: 100)
        
        let brace = BraceShape(
            startPoint: startPoint,
            endPoint: endPoint,
            tipPoint: tipPoint,
            orientation: .horizontal
        )
        
        context.stroke(
            brace.path(in: CGRect(origin: .zero, size: size)),
            with: .color(.accentColor),
            lineWidth: 2
        )
    }
    .frame(width: 300, height: 200)
    .background(Color.gray.opacity(0.1))
}
