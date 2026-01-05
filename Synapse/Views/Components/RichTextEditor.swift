//
//  RichTextEditor.swift
//  Synapse
//
//  Componente SwiftUI che wrappa NSTextView per editing di testo arricchito.
//  Gestisce la conversione tra NSAttributedString e Data per la persistenza.
//

import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    
    // MARK: - Bindings
    
    /// Binding ai dati del testo ricco (RTF/Archived Data)
    @Binding var data: Data?
    
    /// Binding alla versione plain text (per sync e fallback)
    @Binding var plainText: String
    
    // MARK: - Configurazione
    
    /// Se true, permette l'editing. Se false, è sola lettura (selezionabile).
    var isEditable: Bool = true
    
    /// Callback quando l'editing termina (perdita focus)
    var onCommit: (() -> Void)?
    
    // MARK: - NSViewRepresentable
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        
        // Usa la sottoclasse custom per il centering verticale e formattazione
        let textView = FormattableTextView()
        textView.delegate = context.coordinator
        
        // Configurazione visuale
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsImageEditing = false
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.usesInspectorBar = false
        textView.usesFontPanel = true
        textView.usesRuler = false
        
        // Font e allineamento di default
        textView.font = .systemFont(ofSize: 14)
        textView.alignment = .center 
        
        // Configurazione container
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 0)
        
        // Imposta il contenuto iniziale
        if let data = data {
            if let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attributedString)
            }
        } else {
            textView.string = plainText
            textView.font = .systemFont(ofSize: 14)
            textView.alignment = .center
        }
        
        // Configura i typing attributes con allineamento centrato
        textView.setupCenteredTypingAttributes()
        
        textView.autoresizingMask = [.width, .height]
        scrollView.documentView = textView
        
        // Auto-focus se è in modalità editing
        // EDUCATIONAL: Usiamo [weak textView] perché la textView potrebbe essere
        // deallocata prima che il blocco async venga eseguito (es. se la view viene
        // rimossa dalla gerarchia). Con weak, il blocco semplicemente non fa nulla.
        if isEditable {
            DispatchQueue.main.async { [weak textView] in
                textView?.window?.makeFirstResponder(textView)
            }
        }
        
        return scrollView
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Aggiorna editabilità
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        
        // Ricarica il contenuto se i dati sono cambiati
        // Compara i dati attuali con quelli nella textView
        let currentData = data
        let textViewData: Data?
        if let storage = textView.textStorage, storage.length > 0 {
            textViewData = try? storage.data(from: NSRange(location: 0, length: storage.length),
                                              documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
        } else {
            textViewData = nil
        }
        
        // Se i dati sono diversi, aggiorna il contenuto
        if currentData != textViewData {
            if let data = currentData,
               let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
                textView.textStorage?.setAttributedString(attributedString)
            } else if !plainText.isEmpty && textView.string != plainText {
                textView.string = plainText
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            
            // 1. Aggiorna Plain Text
            parent.plainText = textView.string
            
            // 2. Aggiorna Rich Data
            if let textStorage = textView.textStorage {
                let range = NSRange(location: 0, length: textStorage.length)
                do {
                    let data = try textStorage.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
                    parent.data = data
                } catch {
                    print("Errore salvataggio rich text: \(error)")
                }
            }
        }
        
        func textDidEndEditing(_ notification: Notification) {
            parent.onCommit?()
        }
    }
}

// MARK: - Custom TextView con Formattazione e Vertical Centering

/// TextView custom che supporta formattazione del testo (bold, italic, underline, colore, dimensione font)
/// e centra verticalmente il contenuto.
/// Gestisce anche Enter (conferma) vs Shift+Enter (a capo).
class FormattableTextView: NSTextView {
    
    // MARK: - Setup Iniziale
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCenteredTypingAttributes()
    }
    
    /// Configura i typingAttributes di default con allineamento centrato
    func setupCenteredTypingAttributes() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        var attrs = typingAttributes
        attrs[.paragraphStyle] = paragraphStyle
        if attrs[.font] == nil {
            attrs[.font] = NSFont.systemFont(ofSize: 14)
        }
        typingAttributes = attrs
    }
    
    // MARK: - Gestione Tastiera
    
    /// Override di keyDown per gestire Enter e Shift+Enter
    /// - Enter solo: Esce dall'edit mode (conferma)
    /// - Shift+Enter: Inserisce un a capo
    override func keyDown(with event: NSEvent) {
        // Controlla se è stato premuto Enter (keyCode 36) o Return (keyCode 76 sul numpad)
        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.contains(.shift) {
                // Shift+Enter: Inserisce un a capo normale
                insertNewline(nil)
            } else {
                // Enter solo: Conferma e esci dall'editing
                // FIX: Semplicemente rilascia il first responder, questo triggera textDidEndEditing -> onCommit
                window?.makeFirstResponder(nil)
            }
            return
        }
        
        // Per tutti gli altri tasti, comportamento normale
        super.keyDown(with: event)
    }
    
    // MARK: - Mantenimento Allineamento Centrato
    
    /// Assicura che tutto il testo abbia l'allineamento centrato
    private func ensureCenteredAlignment() {
        guard let storage = textStorage, storage.length > 0 else { return }
        
        let fullRange = NSRange(location: 0, length: storage.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        // Applica l'allineamento centrato a tutto il testo
        storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
    }
    
    // MARK: - Layout Verticale
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        // Forza il centering quando la view viene aggiunta alla gerarchia
        DispatchQueue.main.async { [weak self] in
            self?.layoutManager?.ensureLayout(for: self?.textContainer ?? NSTextContainer())
            self?.centerVertically()
        }
    }
    
    override func layout() {
        super.layout()
        centerVertically()
    }
    
    /// Dopo ogni modifica al testo, ricalcola il centering
    override func didChangeText() {
        super.didChangeText()
        ensureCenteredAlignment()
        
        // Forza il ricalcolo del layout e centering verticale
        layoutManager?.ensureLayout(for: textContainer ?? NSTextContainer())
        centerVertically()
    }
    
    private func centerVertically() {
        guard let container = textContainer, let layoutManager = layoutManager else { return }
        
        // Forza il calcolo del layout prima di ottenere l'altezza del contenuto
        layoutManager.ensureLayout(for: container)
        
        let height = self.bounds.height
        let contentHeight = layoutManager.usedRect(for: container).height
        
        if contentHeight < height && contentHeight > 0 {
            let topInset = (height - contentHeight) / 2.0
            textContainerInset = NSSize(width: 0, height: max(0, floor(topInset)))
        } else {
            textContainerInset = NSSize(width: 0, height: 0)
        }
    }
    
    // MARK: - Range di Lavoro
    
    /// Restituisce il range su cui applicare le modifiche:
    /// - Se c'è una selezione valida (lunghezza > 0), usa quella
    /// - Altrimenti, restituisce l'intero range del testo (per applicare stili a tutto il nodo)
    private var effectiveRange: NSRange {
        let range = selectedRange()
        // Se c'è una selezione esplicita, usa quella
        if range.length > 0 {
            return range
        }
        // Altrimenti, restituisci l'intera lunghezza del testo
        return NSRange(location: 0, length: textStorage?.length ?? 0)
    }
    
    // MARK: - Azioni di Formattazione
    
    /// Attiva/disattiva il grassetto sulla selezione o su tutto il testo
    @objc func toggleBold(_ sender: Any?) {
        let range = effectiveRange
        if range.length > 0 {
            applyTraitToSelection(.boldFontMask, inRange: range)
        }
        notifyTextChange()
    }
    
    /// Attiva/disattiva il corsivo sulla selezione o su tutto il testo
    @objc func toggleItalic(_ sender: Any?) {
        let range = effectiveRange
        if range.length > 0 {
            applyTraitToSelection(.italicFontMask, inRange: range)
        }
        notifyTextChange()
    }
    
    /// Attiva/disattiva la sottolineatura sulla selezione o su tutto il testo
    @objc override func underline(_ sender: Any?) {
        let range = effectiveRange
        guard range.length > 0, let storage = textStorage else { return }
        
        // Verifica se il range ha già underline
        var hasUnderline = false
        storage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, _ in
            if let style = value as? Int, style != NSUnderlineStyle([]).rawValue {
                hasUnderline = true
            }
        }
        
        // Toggle underline
        let newStyle: Int = hasUnderline ? NSUnderlineStyle([]).rawValue : NSUnderlineStyle.single.rawValue
        storage.addAttribute(.underlineStyle, value: newStyle, range: range)
        notifyTextChange()
    }

    @objc func setFontSize(_ fontSize: CGFloat) {
        let range = effectiveRange
        guard range.length > 0, let storage = textStorage else { return }
        
        // Cambia dimensione per ogni font nel range
        storage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            if let font = value as? NSFont {
                let newFont = NSFontManager.shared.convert(font, toSize: fontSize)
                storage.addAttribute(.font, value: newFont, range: attrRange)
            } else {
                // Se non c'è font, usa il system font con la nuova dimensione
                storage.addAttribute(.font, value: NSFont.systemFont(ofSize: fontSize), range: attrRange)
            }
        }
        notifyTextChange()
    }
    
    // MARK: - Gestione Font Panel
    
    /// Override di changeFont per supportare NSFontPanel
    override func changeFont(_ sender: Any?) {
        guard let fontManager = sender as? NSFontManager,
              let storage = textStorage else { return }
        
        let range = effectiveRange
        guard range.length > 0 else { return }
        
        // Applica il cambio font al range
        storage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            let currentFont = (value as? NSFont) ?? .systemFont(ofSize: 14)
            let newFont = fontManager.convert(currentFont)
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
        notifyTextChange()
    }
    
    // MARK: - Gestione Color Panel
    
    /// Override di changeColor per supportare NSColorPanel
    override func changeColor(_ sender: Any?) {
        let color = NSColorPanel.shared.color
        let range = effectiveRange
        
        guard range.length > 0, let storage = textStorage else { return }
        storage.addAttribute(.foregroundColor, value: color, range: range)
        notifyTextChange()
    }
    
    // MARK: - Helper Privati
    
    /// Applica o rimuove un tratto font (bold/italic) alla selezione
    private func applyTraitToSelection(_ trait: NSFontTraitMask, inRange range: NSRange) {
        guard let storage = textStorage else { return }
        let fontManager = NSFontManager.shared
        
        // Determina se la selezione ha già questo tratto
        var hasTrait = true
        storage.enumerateAttribute(.font, in: range, options: []) { value, _, stop in
            if let font = value as? NSFont {
                if !fontManager.traits(of: font).contains(trait) {
                    hasTrait = false
                    stop.pointee = true
                }
            } else {
                hasTrait = false
                stop.pointee = true
            }
        }
        
        // Applica o rimuove il tratto
        storage.enumerateAttribute(.font, in: range, options: []) { value, attrRange, _ in
            let currentFont = (value as? NSFont) ?? .systemFont(ofSize: 14)
            let newFont: NSFont
            
            if hasTrait {
                // Rimuovi tratto
                newFont = fontManager.convert(currentFont, toNotHaveTrait: trait)
            } else {
                // Aggiungi tratto
                newFont = fontManager.convert(currentFont, toHaveTrait: trait)
            }
            
            storage.addAttribute(.font, value: newFont, range: attrRange)
        }
    }
    
    /// Notifica che il testo è cambiato (per aggiornare i binding)
    private func notifyTextChange() {
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }
}
