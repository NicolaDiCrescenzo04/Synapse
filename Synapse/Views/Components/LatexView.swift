//
//  LatexView.swift
//  Synapse
//
//  Componente per renderizzare formule matematiche Latex.
//  Usa WKWebView per caricare una stringa HTML che include MathJax.
//  È una soluzione leggera che non richiede dipendenze esterne pesanti.
//

import SwiftUI
import WebKit

struct LatexView: NSViewRepresentable {
    
    let latex: String
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground") // Sfondo trasparente
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let html = generateHTML(from: latex)
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private func generateHTML(from latex: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <script src="https://polyfill.io/v3/polyfill.min.js?features=es6"></script>
            <script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>
            <style>
                body {
                    background-color: transparent;
                    color: black; /* Adatta al tema se necessario */
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    overflow: hidden;
                }
            </style>
        </head>
        <body>
            $$ \(latex) $$
        </body>
        </html>
        """
    }
}
