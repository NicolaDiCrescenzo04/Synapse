//
//  LatexView.swift
//  Synapse
//
//  Componente per visualizzare formule matematiche LaTeX.
//  NOTA: Per evitare crash del WKWebView, usiamo un approccio semplificato
//  che mostra il testo LaTeX in modo stilizzato. Il rendering completo
//  MathJax verrà implementato in una fase successiva con un'architettura
//  più robusta (es. pre-rendering server-side o cache SVG).
//

import SwiftUI
import WebKit

// MARK: - SmartLatexView

/// Vista che mostra LaTeX in modo stilizzato.
/// Fase 1: Mostra il codice LaTeX formattato (senza rendering MathJax).
/// Fase 2 (futura): Integrazione con rendering MathJax via WebView singleton.
struct SmartLatexView: View {
    
    let latex: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            // Mostra il codice LaTeX con stile matematico
            Text(formatLatexForDisplay(latex))
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(8)
        }
    }
    
    /// Formatta il LaTeX per una visualizzazione leggibile (senza rendering completo).
    /// Sostituisce alcuni comandi comuni con simboli Unicode equivalenti.
    private func formatLatexForDisplay(_ input: String) -> String {
        var result = input
        
        // Sostituisci comandi LaTeX comuni con Unicode
        let replacements: [(String, String)] = [
            // Lettere greche
            ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
            ("\\epsilon", "ε"), ("\\zeta", "ζ"), ("\\eta", "η"), ("\\theta", "θ"),
            ("\\iota", "ι"), ("\\kappa", "κ"), ("\\lambda", "λ"), ("\\mu", "μ"),
            ("\\nu", "ν"), ("\\xi", "ξ"), ("\\pi", "π"), ("\\rho", "ρ"),
            ("\\sigma", "σ"), ("\\tau", "τ"), ("\\upsilon", "υ"), ("\\phi", "φ"),
            ("\\chi", "χ"), ("\\psi", "ψ"), ("\\omega", "ω"),
            ("\\Alpha", "Α"), ("\\Beta", "Β"), ("\\Gamma", "Γ"), ("\\Delta", "Δ"),
            ("\\Theta", "Θ"), ("\\Lambda", "Λ"), ("\\Xi", "Ξ"), ("\\Pi", "Π"),
            ("\\Sigma", "Σ"), ("\\Phi", "Φ"), ("\\Psi", "Ψ"), ("\\Omega", "Ω"),
            
            // Operatori e simboli
            ("\\times", "×"), ("\\div", "÷"), ("\\pm", "±"), ("\\mp", "∓"),
            ("\\cdot", "·"), ("\\circ", "∘"), ("\\ast", "∗"),
            ("\\leq", "≤"), ("\\geq", "≥"), ("\\neq", "≠"),
            ("\\approx", "≈"), ("\\equiv", "≡"), ("\\sim", "∼"),
            ("\\propto", "∝"), ("\\infty", "∞"), ("\\partial", "∂"),
            ("\\nabla", "∇"), ("\\forall", "∀"), ("\\exists", "∃"),
            ("\\in", "∈"), ("\\notin", "∉"), ("\\subset", "⊂"), ("\\supset", "⊃"),
            ("\\cup", "∪"), ("\\cap", "∩"), ("\\emptyset", "∅"),
            ("\\rightarrow", "→"), ("\\leftarrow", "←"), ("\\Rightarrow", "⇒"),
            ("\\Leftarrow", "⇐"), ("\\leftrightarrow", "↔"), ("\\Leftrightarrow", "⇔"),
            ("\\sum", "Σ"), ("\\prod", "Π"), ("\\int", "∫"),
            ("\\sqrt", "√"), ("\\ldots", "…"), ("\\cdots", "⋯"),
            
            // Formattazione semplice
            ("\\left", ""), ("\\right", ""),
            ("\\bigl", ""), ("\\bigr", ""),
            ("\\Big", ""), ("\\big", ""),
            ("{", ""), ("}", ""),
            ("^", "^"), ("_", "_"),
        ]
        
        for (latex, unicode) in replacements {
            result = result.replacingOccurrences(of: latex, with: unicode)
        }
        
        // Gestisci frazioni: \frac{a}{b} -> a/b
        let fracPattern = try? NSRegularExpression(pattern: "\\\\frac\\s*(\\S+)\\s*(\\S+)", options: [])
        if let pattern = fracPattern {
            result = pattern.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(location: 0, length: result.utf16.count),
                withTemplate: "$1/$2"
            )
        }
        
        return result.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Legacy LatexView

/// Vista legacy che mostra LaTeX formattato (senza WebView).
struct LatexView: View {
    let latex: String
    
    var body: some View {
        SmartLatexView(latex: latex)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        SmartLatexView(latex: "\\frac{1}{2}")
        SmartLatexView(latex: "\\alpha + \\beta = \\gamma")
        SmartLatexView(latex: "E = mc^2")
        SmartLatexView(latex: "\\sum_{i=1}^{n} x_i")
        SmartLatexView(latex: "\\int_0^\\infty e^{-x} dx")
    }
    .padding()
    .frame(width: 300, height: 400)
}
