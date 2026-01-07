//
//  GroupingToolbar.swift
//  Synapse
//
//  Toolbar fluttuante per il raggruppamento di nodi.
//  Appare quando 2 o più nodi sono selezionati.
//  Offre due opzioni: "Testo" (label node) e "Collega" (anchor + linking).
//

import SwiftUI

/// Toolbar fluttuante che mostra le opzioni di raggruppamento.
/// Appare vicino alla selezione quando 2+ nodi sono selezionati.
struct GroupingToolbar: View {
    
    /// Azione chiamata quando l'utente clicca "Testo" (Raggruppa con Label Node)
    let onGroupWithText: () -> Void
    
    /// Azione chiamata quando l'utente clicca "Collega" (Raggruppa e avvia linking)
    let onGroupWithLink: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Opzione A: Raggruppa con Testo (Label Node editabile)
            Button(action: onGroupWithText) {
                VStack(spacing: 4) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 18, weight: .medium))
                    Text("Testo")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(width: 60, height: 50)
            }
            .buttonStyle(.bordered)
            .tint(.accentColor)
            
            // Separatore visivo
            Divider()
                .frame(height: 40)
            
            // Opzione B: Raggruppa e Collega (Anchor Node + auto-linking)
            Button(action: onGroupWithLink) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 18, weight: .medium))
                    Text("Collega")
                        .font(.system(size: 11, weight: .medium))
                }
                .frame(width: 60, height: 50)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        GroupingToolbar(
            onGroupWithText: { print("Testo!") },
            onGroupWithLink: { print("Collega!") }
        )
    }
    .frame(width: 400, height: 200)
}

