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
    
    /// Larghezza esplicita per il text wrapping (nil = auto-width, single-line)
    var explicitWidth: CGFloat? = nil
    
    /// Se true, il testo va a capo (word wrap); se false, scorre orizzontalmente
    var shouldWrapText: Bool = false
    
    /// Callback quando l'editing termina (perdita focus)
    var onCommit: (() -> Void)?
    
    /// Callback per esporre la NSTextView sottostante al ViewModel.
    /// Indispensabile per permettere alla Toolbar esterna di agire sull'editor attivo.
    var onResolveEditor: ((NSTextView) -> Void)?
    
    /// Callback per notificare cambiamenti di altezza del contenuto (per auto-height in manual mode)
    var onContentHeightChanged: ((CGFloat) -> Void)?
    
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
        
        // Configurazione container basata sulla modalità wrap
        configureTextContainer(textView: textView)
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
        
        // Espone SEMPRE la textView al viewmodel (necessario per word hit testing in hover)
        // EDUCATIONAL: Usiamo [weak textView] perché la textView potrebbe essere
        // deallocata prima che il blocco async venga eseguito (es. se la view viene
        // rimossa dalla gerarchia). Con weak, il blocco semplicemente non fa nulla.
        DispatchQueue.main.async { [weak textView] in
            guard let textView = textView else { return }
            // Espone la textView al viewmodel per word hit testing
            onResolveEditor?(textView)
            // Auto-focus solo se è in modalità editing
            if isEditable {
                textView.window?.makeFirstResponder(textView)
            }
        }
        
        // Report iniziale dell'altezza contenuto
        reportContentHeight(textView: textView)
        
        return scrollView
    }
    
    /// Configura il text container in base alla modalità wrap
    private func configureTextContainer(textView: NSTextView) {
        guard let textContainer = textView.textContainer else { return }
        
        if shouldWrapText, let width = explicitWidth, width > 0 {
            // MANUAL MODE: word-wrap attivo, larghezza fissa
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            
            // FIX: Imposta minSize e maxSize per impedire che la view collassi o scompaia
            textView.minSize = NSSize(width: width, height: 0)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            
            // Forza la larghezza del frame della textView
            var frame = textView.frame
            frame.size.width = width
            textView.frame = frame
        } else if let width = explicitWidth, width > 0 {
            // EDITING MODE (non wrap): larghezza fissa per centering, ma contenuto può eccedere orizzontalmente
            // Questo permette all'allineamento .center di funzionare durante la digitazione
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false  // textView non cresce, il centering funziona
            textView.isVerticallyResizable = false
            
            // Imposta larghezza fissa
            textView.minSize = NSSize(width: width, height: 0)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            
            // Forza la larghezza del frame
            var frame = textView.frame
            frame.size.width = width
            textView.frame = frame
        } else {
            // AUTO MODE (VIEW): singola riga, cresce orizzontalmente
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
            textView.isVerticallyResizable = false
            
            // Reset minSize/maxSize per auto mode
            textView.minSize = NSSize(width: 0, height: 0)
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
    }
    
    /// Calcola e notifica l'altezza del contenuto
    private func reportContentHeight(textView: NSTextView) {
        guard shouldWrapText, let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        
        // Forza il calcolo del layout
        layoutManager.ensureLayout(for: textContainer)
        
        let contentHeight = layoutManager.usedRect(for: textContainer).height
        onContentHeightChanged?(contentHeight)
    }
    
    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }
        
        // Aggiorna editabilità
        if textView.isEditable != isEditable {
            textView.isEditable = isEditable
        }
        
        // Aggiorna configurazione wrap (sempre, perché può cambiare dinamicamente)
        configureTextContainer(textView: textView)
        
        // PROTEZIONE UPDATE LOOP:
        // Se la textView è attualmente il first responder (utente sta editando),
        // NON sovrascrivere il contenuto - causerebbe reset di cursor e selezione.
        // Gli aggiornamenti arrivano già dal Coordinator.textDidChange.
        let isFirstResponder = textView.window?.firstResponder == textView
        if isFirstResponder {
            // Ri-espone la textView al ViewModel per sicurezza
            onResolveEditor?(textView)
            // Report altezza anche durante l'editing (per wrap dinamico)
            reportContentHeight(textView: textView)
            return
        }
        
        // Ricarica il contenuto SOLO se la textView non è in focus
        // IMPORTANTE: Applica sempre l'attributed string per catturare cambi di STILE
        // (non solo cambi di testo plain)
        if let currentData = data,
           let attributedString = try? NSAttributedString(data: currentData, options: [.documentType: NSAttributedString.DocumentType.rtfd], documentAttributes: nil) {
            // Applica l'attributed string (include stili)
            // Il confronto plain text non basta perché gli stili potrebbero cambiare
            textView.textStorage?.setAttributedString(attributedString)
        } else if !plainText.isEmpty && textView.string != plainText {
            textView.string = plainText
        }
        
        // Report altezza contenuto dopo l'aggiornamento
        reportContentHeight(textView: textView)
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
            
            // 3. Report altezza contenuto (per auto-height in manual mode)
            if parent.shouldWrapText, let layoutManager = textView.layoutManager,
               let textContainer = textView.textContainer {
                layoutManager.ensureLayout(for: textContainer)
                let contentHeight = layoutManager.usedRect(for: textContainer).height
                parent.onContentHeightChanged?(contentHeight)
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
    
    // MARK: - Layout Loop Protection
    
    /// Flag per prevenire loop infiniti di layout durante il centering verticale
    private var isUpdatingLayout: Bool = false
    
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
    
    /// Auto-focus quando la view viene aggiunta a una finestra (fix per nuovi nodi)
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window = window else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Centra verticalmente subito all'apertura
            self.centerVertically()
            // Se editabile, diventa first responder
            if self.isEditable {
                window.makeFirstResponder(self)
            }
        }
    }
    
    override func layout() {
        super.layout()
        // Proteggi da loop infiniti di layout
        guard !isUpdatingLayout else { return }
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
    
    /// Centra il testo sia orizzontalmente che verticalmente nella view.
    /// Funziona correttamente sia in modalità auto (singola riga) che manuale (testo a capo).
    /// Usa isUpdatingLayout per prevenire loop infiniti.
    private func centerVertically() {
        // Previeni loop infiniti
        guard !isUpdatingLayout else { return }
        guard let container = textContainer, let layoutManager = layoutManager else { return }
        
        // Attiva la protezione
        isUpdatingLayout = true
        defer { isUpdatingLayout = false }
        
        // Forza il calcolo del layout per assicurarsi che usedRect sia accurato
        // Questo è cruciale per il testo a capo (wrapped text)
        layoutManager.ensureLayout(for: container)
        
        // Ottieni le dimensioni della view e del contenuto
        let viewWidth = self.bounds.width
        let viewHeight = self.bounds.height
        let usedRect = layoutManager.usedRect(for: container)
        let contentWidth = usedRect.width
        let contentHeight = usedRect.height
        
        var newWidthInset: CGFloat = 0
        var newHeightInset: CGFloat = 0
        
        // Centra orizzontalmente se il contenuto è più stretto della view
        if contentWidth < viewWidth && contentWidth > 0 && viewWidth > 0 {
            let leftInset = (viewWidth - contentWidth) / 2.0
            newWidthInset = max(0, floor(leftInset))
        }
        
        // Centra verticalmente se il contenuto è più corto della view
        if contentHeight < viewHeight && contentHeight > 0 && viewHeight > 0 {
            let topInset = (viewHeight - contentHeight) / 2.0
            newHeightInset = max(0, floor(topInset))
        }
        
        let newInset = NSSize(width: newWidthInset, height: newHeightInset)
        
        // Evita update loop: aggiorna solo se c'è una differenza significativa
        if abs(textContainerInset.width - newInset.width) > 0.5 ||
           abs(textContainerInset.height - newInset.height) > 0.5 {
            textContainerInset = newInset
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
    
    /// Toggle del colore rosso per la selezione corrente o per tutto il testo.
    /// Se la selezione è già rossa, la riporta al colore di default (labelColor).
    /// Se la selezione non è rossa, la rende rossa.
    @objc func toggleRedColor() {
        let range = effectiveRange
        guard range.length > 0, let storage = textStorage else { return }
        
        // Verifica se la selezione è già rossa
        var isRed = true
        storage.enumerateAttribute(.foregroundColor, in: range, options: []) { value, _, stop in
            if let color = value as? NSColor {
                // Confronta con rosso (tolleranza per diverse rappresentazioni)
                if !color.isClose(to: .red) {
                    isRed = false
                    stop.pointee = true
                }
            } else {
                // Nessun colore = default (nero) -> non è rosso
                isRed = false
                stop.pointee = true
            }
        }
        
        // Toggle: se rosso -> default, se non rosso -> rosso
        let newColor: NSColor = isRed ? .labelColor : .red
        storage.addAttribute(.foregroundColor, value: newColor, range: range)
        notifyTextChange()
    }
    
    /// Imposta un colore specifico per la selezione corrente o per tutto il testo (legacy)
    /// Nota: rinominato da setTextColor per evitare conflitto con NSText.textColor setter
    @objc func applyColor(_ color: NSColor) {
        let range = effectiveRange
        guard range.length > 0, let storage = textStorage else { return }
        
        storage.addAttribute(.foregroundColor, value: color, range: range)
        notifyTextChange()
    }

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
    
    /// Inserisce i delimitatori LaTeX ($$$$) alla posizione del cursore corrente
    /// e posiziona il cursore tra i delimitatori per permettere la digitazione immediata.
    @objc func insertLatexDelimiters() {
        let insertionPoint = selectedRange().location
        let latex = "$$$$"
        insertText(latex, replacementRange: selectedRange())
        // Posiziona cursore tra i $$ (dopo i primi 2 caratteri)
        setSelectedRange(NSRange(location: insertionPoint + 2, length: 0))
        notifyTextChange()
    }
    
    /// Notifica che il testo è cambiato (per aggiornare i binding)
    private func notifyTextChange() {
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
    }
    
    // MARK: - Word Hit Testing
    
    /// Risultato del word hit testing
    struct WordHitResult {
        let range: NSRange       // Range della parola nel testo
        let rect: CGRect         // Rettangolo della parola in coordinate della textView
        let word: String         // Il testo della parola
    }
    
    /// Trova la parola sotto il punto specificato (in coordinate della textView)
    /// - Parameter point: Punto in coordinate locali della textView
    /// - Returns: WordHitResult se una parola è stata trovata, nil altrimenti
    func findWord(at point: CGPoint) -> WordHitResult? {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer,
              let textStorage = textStorage,
              textStorage.length > 0 else { return nil }
        
        // 1. Trova l'indice del glifo più vicino
        // Sottrai l'inset del container
        let adjustedPoint = CGPoint(
            x: point.x - textContainerInset.width,
            y: point.y - textContainerInset.height
        )
        
        // Verifica che il punto sia all'interno dell'area del testo
        let usedRect = layoutManager.usedRect(for: textContainer)
        guard usedRect.contains(adjustedPoint) else { return nil }
        
        let glyphIndex = layoutManager.glyphIndex(for: adjustedPoint, in: textContainer)
        
        // 2. Converti in indice carattere
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        
        // Verifica che l'indice sia valido
        guard charIndex < textStorage.length else { return nil }
        
        // 3. Espandi alla parola intera
        let string = textStorage.string as NSString
        let wordRange = string.rangeOfWord(at: charIndex)
        
        guard wordRange.length > 0 else { return nil }
        
        // 4. Calcola il rettangolo della parola
        let glyphRange = layoutManager.glyphRange(forCharacterRange: wordRange, actualCharacterRange: nil)
        var wordRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        
        // Aggiungi l'inset del container al rettangolo
        wordRect.origin.x += textContainerInset.width
        wordRect.origin.y += textContainerInset.height
        
        // 5. Estrai il testo della parola
        let word = string.substring(with: wordRange)
        
        return WordHitResult(range: wordRange, rect: wordRect, word: word)
    }
}

// MARK: - NSString Extension for Word Detection

extension NSString {
    /// Trova il range della parola all'indice specificato
    func rangeOfWord(at index: Int) -> NSRange {
        guard index >= 0 && index < length else { return NSRange(location: 0, length: 0) }
        
        let wordBoundaries = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        
        // Trova l'inizio della parola
        var start = index
        while start > 0 {
            let prevIndex = start - 1
            let char = self.character(at: prevIndex)
            if let scalar = Unicode.Scalar(char), wordBoundaries.contains(scalar) {
                break
            }
            start = prevIndex
        }
        
        // Trova la fine della parola
        var end = index
        while end < length {
            let char = self.character(at: end)
            if let scalar = Unicode.Scalar(char), wordBoundaries.contains(scalar) {
                break
            }
            end += 1
        }
        
        return NSRange(location: start, length: end - start)
    }
}

// MARK: - NSColor Extension for Comparison

extension NSColor {
    /// Confronta due colori con tolleranza per le diverse rappresentazioni.
    /// Utile per verificare se un colore è "rosso" anche se ha leggere variazioni.
    func isClose(to other: NSColor, tolerance: CGFloat = 0.1) -> Bool {
        // Converte entrambi i colori nello stesso color space per confronto
        guard let selfRGB = self.usingColorSpace(.deviceRGB),
              let otherRGB = other.usingColorSpace(.deviceRGB) else {
            return false
        }
        
        let rDiff = abs(selfRGB.redComponent - otherRGB.redComponent)
        let gDiff = abs(selfRGB.greenComponent - otherRGB.greenComponent)
        let bDiff = abs(selfRGB.blueComponent - otherRGB.blueComponent)
        
        return rDiff < tolerance && gDiff < tolerance && bDiff < tolerance
    }
}

