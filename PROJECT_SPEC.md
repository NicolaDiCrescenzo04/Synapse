# PROJECT SYNAPSE - Technical Specification & Vision

## 1. Visione del Prodotto
Synapse è un'applicazione nativa per macOS dedicata all'apprendimento universitario.
Unisce la creazione di mappe concettuali (Mind Map), la lettura di PDF e il ripasso spaziato (SRS) in un'unica interfaccia fluida.

**Obiettivo UX:** "Apple Native Feel". L'app deve sembrare un'estensione del sistema operativo: veloce, pulita, minimalista (stile Freeform/Apple Notes). Niente interfacce web, niente lag.

## 2. Core Features (In ordine di sviluppo)

### FASE 1: La Mappa (Il Grafo) - PRIORITARIA
- **Canvas Infinito:** Pan e zoom fluido (60fps+).
- **Nodi:** Creazione rapida. Nodi semplici contenenti testo, immagini o equazioni in latex.
- **Connessioni:** I nodi sono collegati da frecce (Bézier curves).
- **Etichette sulle frecce:** È fondamentale poter scrivere SULLA freccia per definire la relazione (es. A --[causa]--> B).
- **Non-Gerarchica:** Struttura a grafo, non ad albero. I nodi possono collegarsi ciclicamente.

### FASE 2: Integrazione PDF (Futura)
- Visualizzazione PDF laterale.
- Drag & Drop dal PDF alla Canvas per creare nodi linkati.

### FASE 3: Sistema FSRS (Futuro)
- Algoritmo di ripasso spaziato integrato (usare quello della piattaforma Open Source Anki).
- I nodi diventano flashcard.

## 3. Stack Tecnologico (Vincolante)
- **Linguaggio:** Swift 6.
- **UI Framework:** SwiftUI.
- **Architettura:** MVVM (Model-View-ViewModel).
- **Data Persistence:** SwiftData (Schema V1).
- **Grafica Canvas:** SwiftUI `Canvas` API o `Path` (per iniziare), fallback su Metal solo se le performance crollano.
- **Target:** macOS 14+ (Sonoma/Sequoia).

## 4. Design System & Estetica
- **Tema:** Dark Mode / Light Mode automatico.
- **Stile:** Minimalista. Sfondo pulito, nodi con bordi arrotondati, ombre leggere.
- **Colori:** Palette pastello per i nodi, colori di sistema per l'interfaccia.

## 5. Regole per l'AI Developer
- Non usare librerie di terze parti se esiste una soluzione nativa Apple.
- Scrivi codice pulito, modulare e commentato in Italiano.
- Prima di implementare una funzione complessa, descrivi brevemente l'approccio logico.
- Usa `@Model` di SwiftData per la persistenza fin da subito.