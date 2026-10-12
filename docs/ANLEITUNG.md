# CONTRABEATZ Shop: Anleitung

Eigenes Shopify-Theme (Online Store 2.0), gebaut für Drum Kits, One Shots, Loops, MIDI und Presets.

## Gestaltung (v2)

Das Theme folgt Florians Shop-Layout (`docs/layout-referenz-index_35.html`):
Weiß und Ink `#0D0D0D`, Inter, Versalien-Labels mit orangem Punkt (`#D0532A`), Header mit CB-Emblem in der Mitte,
CONTRA-Wortmarke mit gesprühtem „Shop“-Tag als Bühne, schwarze Cover mit Waveform, Format-Kacheln,
Signature-Suite-Feature und die CONTRA-Wortmarke, die im Footer von oben einfährt.

Das Layout ist noch nicht final. Deshalb ist fast alles im Theme-Editor einstellbar:
Farben, Seitenrand, Sektionsabstand, Spaltenabstand, Spaltenzahl, Tag-Position (rechts / über R und A / ohne),
Größe der Wortmarke, Schwarz-Weiß-Cover, Reihenfolge der Sektionen.

Zusätzlich, inspiriert von Balmoral, als frei kombinierbare Sektionen:
- **Editorial-Raster**: randlos, 4 Spalten, große Bildkachel (2 × 2) neben Produktkacheln
- **Produkt-Raster** im Stil „Randlos“: enge Fugen, Titel und Preis erst beim Hover
- **Service-Karten**: Lizenz, Download, Kontakt, Free Pack mit Bild und einer Zeile Text

## Was im Shop schon angelegt ist

| Bereich | Stand |
|---|---|
| Theme | `CONTRABEATZ v2 (Layout Florian)` (unveröffentlicht). `v1 (alt)` und `Entwurf` können gelöscht werden. |
| Produkte | 10 Platzhalter (Tag `platzhalter`), u. a. 808 Cathedral, Vapor One-Shots, Midnight Keys, Signature Suite, Beat „Late Drive“ mit Lizenzstufen |
| Metafelder | Katalognummer, Demo (Audio), Previews (Audio), Inhalt, Dateigröße, plus BPM, Key, Genre, Format, DAW, Sample Count |
| Seiten | Lizenz (`/pages/lizenz`), FAQ (`/pages/faq`), Kontakt mit Formular |
| Menüs | Hauptmenü wie im Layout (Sample Packs, Drum Kits, One Shot Kits, Beats), Fußzeile, `shop-menu` für die Filter auf Kollektionsseiten |
| Audio | `CB_Platzhalter_Demo.mp3` in Inhalte → Dateien (synthetischer Loop, ersetzen) |

## Deine Schritte

### 1. Theme ansehen und veröffentlichen
Onlineshop → Themes → `CONTRABEATZ v2 (Layout Florian)` → Anpassen. Wenn alles passt: Veröffentlichen.
Im Theme-Editor sind alle Texte, Farben, Cover-Farben, Schriften und Sections änderbar.

### 2. Pro Kit: Produkt anlegen oder Platzhalter überschreiben
- **Titel, Preis, Beschreibung** (2–4 ruhige Sätze, kein Hype)
- **Produkttyp** muss exakt einer dieser Werte sein, sonst landet das Kit in keiner Kollektion:
  `Drum Kit` · `One Shot Kit` · `Loop Kit` · `MIDI Kit` · `Phrase Kit` · `Preset Bank` · `Suite` · `Session` · `Beat`
- **Beats:** Lizenzen als Varianten anlegen (Option „Lizenz“: MP3 Lease, WAV Lease, Trackouts). Die Produktseite zeigt sie als Auswahl.
- **Free-Kits:** Preis 0 und Tag `free`
- **Versand:** „Physisches Produkt“ deaktivieren

### 3. Cover / Packshot
Einfach ein Bild als Produktmedium hochladen. Es ersetzt die schwarze Waveform-Fläche automatisch.
- Format **1:1**, mind. **2000 × 2000 px**, JPG oder WebP
- Standard wie im Layout: Cover in Schwarz-Weiß mit Waveform darüber, Farbe beim Hover (Theme-Einstellungen → Produktkarten)
- Ohne Bild bleibt die schwarze Fläche mit Waveform, Katalognummer und Typ stehen

### 4. Audio-Previews
1. Inhalte → Dateien → MP3s hochladen (**256 kbps oder mehr**, gemastert)
2. Im Produkt unten bei Metafelder:
   - **Demo (Audio):** ein Demo-Mix, 30–60 s. Spielt auf Karte, Cover und Produktseite.
   - **Previews (Audio):** 8–15 einzelne Hörproben. Der Dateiname wird zum Titel: `Kick_Dusty_01.mp3` → „Kick Dusty 01“.
     Alternativ den Alt-Text der Datei setzen, der hat Vorrang.
3. **Inhalt:** eine Zeile pro Typ, Zahl zuerst: `24 Kicks`, `18 Snares` … wird zur Zahlenleiste „Was drin ist“.

### 5. Digitale Auslieferung
Shopify liefert ZIPs nicht von allein aus. App installieren: **Digital Downloads** (kostenlos, von Shopify).
Dort pro Produkt die ZIP-Datei anhängen.

### 6. Rechtliches (Deutschland, Pflicht)
- Einstellungen → Richtlinien: **Impressum, AGB, Widerruf, Datenschutz** ausfüllen (die Footer-Links zeigen schon dorthin)
- Widerruf bei digitalen Inhalten: Kunden müssen vor dem Kauf ausdrücklich zustimmen, dass das Widerrufsrecht mit dem Download erlischt.
  Das geht über eine Checkout-Checkbox (z. B. App „Legal Text Checkbox“) oder einen Rechtstext-Dienst wie IT-Recht Kanzlei oder Händlerbund.
- Den Lizenztext unter `/pages/lizenz` einmal juristisch gegenlesen lassen

### 7. Aufräumen vor dem Launch
Produkte mit Tag `platzhalter` löschen oder überschreiben. Die Platzhalter-MP3 aus den Dateien löschen.

## Theme-Struktur

```
layout/      theme.liquid, password.liquid
sections/    contra-hero, featured-collection, format-tiles, feature, editorial-grid, statement,
             service-cards, facts, faq, main-product, related-products, main-collection, cart-drawer, …
snippets/    contra-wordmark (CONTRA + Spray-Tag), cb-emblem, cover, waveform, product-card,
             product-tile, meta-line, play-button, player, …
assets/      base.css, theme.js (Player, Warenkorb, Hero-Intro, Reveal, Footer-Wortmarke; ohne Framework)
templates/   JSON-Templates; page.license, page.faq, page.contact für die Seiten
```

Lizenzstufen (z. B. Basic / Extended) als Produktvarianten anlegen. Die Produktseite zeigt sie automatisch als Auswahl.
