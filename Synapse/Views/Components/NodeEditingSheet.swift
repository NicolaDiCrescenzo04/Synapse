//
//  NodeEditingSheet.swift
//  Synapse
//
//  Sheet modale per l'editing del testo arricchito di un nodo.
//  Contiene la RichTextToolbar e il RichTextEditor.
//

import SwiftUI
import AppKit
import SwiftData

/// Sheet modale per l'editing del contenuto di un nodo
struct NodeEditingSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Proprietà
    
    /// Il nodo da editare
    let node: SynapseNode
    
    /// ViewModel per salvare le modifiche
    var viewModel: MapViewModel
    
    // MARK: - State
    
    /// Dati rich text locali (copia di lavoro)
    @State private var localRichTextData: Data?
    
    /// Testo plain locale (copia di lavoro)
    @State private var localPlainText: String = ""
    
    /// Riferimento alla textView per la toolbar
    @State private var textViewRef: FormattableTextView?
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header con titolo
            headerView
            
            Divider()
            
            // Toolbar formattazione
            RichTextToolbar(textView: textViewRef)
            
            Divider()
            
            // Editor area
            editorArea
            
            Divider()
            
            // Footer con azioni
            footerView
        }
        .frame(width: 550, height: 450)
        .onAppear {
            loadData()
        }
    }
    
    // MARK: - Header View
    
    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("Modifica Nodo")
                .font(.headline)
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Editor Area
    
    @ViewBuilder
    private var editorArea: some View {
        RichTextEditor(
            data: $localRichTextData,
            plainText: $localPlainText,
            isEditable: true,
            explicitWidth: 500,
            shouldWrapText: true,
            onResolveEditor: { textView in
                textViewRef = textView as? FormattableTextView
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - Footer View
    
    @ViewBuilder
    private var footerView: some View {
        HStack {
            // Annulla
            Button("Annulla") {
                dismiss()
            }
            .keyboardShortcut(.escape, modifiers: [])
            
            Spacer()
            
            // Suggerimento LaTeX
            Button {
                textViewRef?.insertLatexDelimiters()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "function")
                    Text("LaTeX")
                }
            }
            .buttonStyle(.bordered)
            .help("Inserisci formula LaTeX (racchiusa tra $$)")
            
            // Salva
            Button("Salva") {
                saveAndDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Data Management
    
    /// Carica i dati dal nodo
    private func loadData() {
        localRichTextData = node.richTextData
        localPlainText = node.text
    }
    
    /// Salva le modifiche e chiude lo sheet
    private func saveAndDismiss() {
        viewModel.updateNodeRichText(node, richTextData: localRichTextData, plainText: localPlainText)
        
        // Incrementa styleVersion per forzare refresh della vista
        viewModel.styleVersion += 1
        
        dismiss()
    }
}

#Preview {
    // Preview con nodo dummy
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: SynapseNode.self, configurations: config)
    let node = SynapseNode(text: "Esempio di testo", at: CGPoint(x: 100, y: 100))
    
    return NodeEditingSheet(
        node: node,
        viewModel: MapViewModel(modelContext: container.mainContext)
    )
}
