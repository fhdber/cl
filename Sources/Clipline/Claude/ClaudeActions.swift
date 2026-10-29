import Foundation

/// One-tap tasks offered for a text or image context.
struct ClaudeAction: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let instruction: String

    static let textActions: [ClaudeAction] = [
        ClaudeAction(id: "improve", title: "Verbessern", symbol: "wand.and.stars",
                     instruction: "Korrigiere Rechtschreibung, Grammatik und Zeichensetzung und glätte den Stil. Bedeutung, Ton und Sprache bleiben gleich."),
        ClaudeAction(id: "shorten", title: "Kürzen", symbol: "arrow.down.right.and.arrow.up.left",
                     instruction: "Kürze den Text auf etwa die Hälfte, ohne wichtige Aussagen zu verlieren."),
        ClaudeAction(id: "summarize", title: "Zusammenfassen", symbol: "text.append",
                     instruction: "Fasse den Text in zwei bis vier Sätzen zusammen."),
        ClaudeAction(id: "bullets", title: "Stichpunkte", symbol: "list.bullet",
                     instruction: "Mach aus dem Text eine knappe Stichpunktliste mit „– “ am Zeilenanfang."),
        ClaudeAction(id: "formal", title: "Professionell", symbol: "briefcase",
                     instruction: "Formuliere den Text professionell und klar, für Kunden geeignet."),
        ClaudeAction(id: "casual", title: "Locker", symbol: "face.smiling",
                     instruction: "Formuliere den Text locker und freundlich, wie unter Kollegen."),
        ClaudeAction(id: "english", title: "→ Englisch", symbol: "globe",
                     instruction: "Übersetze den Text ins Englische. Natürlich klingend, nicht wörtlich."),
        ClaudeAction(id: "german", title: "→ Deutsch", symbol: "globe.europe.africa",
                     instruction: "Übersetze den Text ins Deutsche. Natürlich klingend, nicht wörtlich, mit Du-Anrede wenn eine Anrede vorkommt."),
        ClaudeAction(id: "explain", title: "Erklären", symbol: "questionmark.bubble",
                     instruction: "Erkläre kurz und verständlich, was dieser Text oder Code bedeutet oder macht."),
    ]

    static let imageActions: [ClaudeAction] = [
        ClaudeAction(id: "describe", title: "Beschreiben", symbol: "eye",
                     instruction: "Beschreibe knapp, was auf dem Bild zu sehen ist."),
        ClaudeAction(id: "ocr", title: "Text herausholen", symbol: "text.viewfinder",
                     instruction: "Gib den gesamten Text auf dem Bild exakt wieder, mit sinnvollen Zeilenumbrüchen. Nichts hinzufügen."),
        ClaudeAction(id: "alt", title: "Alt-Text", symbol: "accessibility",
                     instruction: "Schreib einen prägnanten Alt-Text (höchstens 125 Zeichen) für dieses Bild."),
        ClaudeAction(id: "feedback", title: "Design-Feedback", symbol: "paintbrush.pointed",
                     instruction: "Gib kurzes, konkretes Design-Feedback zu Hierarchie, Typografie, Farbe und Abständen. Drei bis fünf Punkte."),
    ]

    /// Shared system prompt: results only, no chatter – they are meant to be pasted.
    static let system = """
    Du bist in Clipline eingebaut, eine Zwischenablage-App für macOS. Deine Antworten werden oft direkt \
    in andere Apps eingefügt. Antworte deshalb nur mit dem Ergebnis: keine Einleitung, kein Nachsatz, \
    keine Anführungszeichen um das Ergebnis und kein Markdown, außer der Nutzer verlangt es oder es ist Code. \
    Behalte die Sprache des Eingabetextes bei, außer bei Übersetzungen. Sprich den Nutzer mit Du an.
    """

    static func prompt(instruction: String, text: String?) -> String {
        guard let text, !text.isEmpty else { return instruction }
        return "<aufgabe>\n\(instruction)\n</aufgabe>\n\n<inhalt>\n\(text)\n</inhalt>"
    }
}
