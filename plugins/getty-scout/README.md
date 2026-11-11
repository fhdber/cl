# getty-scout

Findet die besten Stockmotive auf Getty Images und iStock.

**Ablauf:** Briefing schärfen → Bildidee in einem Satz → 4–6 Such-Winkel mit
präzisem Getty-Vokabular und Filtern → Such-Links bzw. Kontaktbogen →
kuratierte Shortlist (Bewertungsraster, 12 Punkte) → Lizenz-Check.

**Aufrufen:** "Finde ein Getty-Motiv für …", "Bildrecherche für …",
"Stockfoto für die Website von …" oder `/getty-scout`.

## Optional: Getty API

Ohne API-Key liefert der Skill klickbare Such-Links (Getty + iStock). Mit Key
holt er Treffer direkt und baut einen HTML-Kontaktbogen inkl. "Ähnliche Bilder".

Lege im Arbeitsordner eine `.env` an:

```
GETTY_API_KEY=...
GETTY_API_SECRET=...   # optional
```

Key beantragen: https://developers.gettyimages.com

Voraussetzung für das Skript: Node.js 18+.
