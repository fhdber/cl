# CONTRABEATZ Shop: Anleitung

Eigenes Shopify-Theme (Online Store 2.0), gebaut für Drum Kits, One Shots, Loops, MIDI und Presets.

## Prinzip

**Jeder Produkttyp hat eine Form.** Drum Kit = 16-Step-Raster, One Shot = Punkt, Loop = Kreis,
MIDI = Piano-Roll, Phrase = Welle, Preset = Regler, Suite = Schichten, Session = Überlagerung.
Die Form taucht im Platzhalter-Cover, im Kategorie-Index auf der Startseite und in der Navigation auf.
Meta-Infos (Katalognummer, Typ, BPM, Key, Samples) laufen in Mono wie auf einem Plattenlabel.

## Was im Shop schon angelegt ist

| Bereich | Stand |
|---|---|
| Theme | `CONTRABEATZ v1` (unveröffentlicht). `CONTRABEATZ Entwurf` kann gelöscht werden. |
| Produkte | 9 Platzhalter (Tag `platzhalter`), je Typ eins plus Free Pack, alle Metafelder gefüllt |
| Metafelder | Katalognummer, Demo (Audio), Previews (Audio), Inhalt, Dateigröße, plus BPM, Key, Genre, Format, DAW, Sample Count |
| Seiten | Lizenz (`/pages/lizenz`), FAQ (`/pages/faq`), Kontakt mit Formular |
| Menüs | Hauptmenü, Fußzeile (inkl. Rechtstexte), `shop-menu` für die Filter-Chips |
| Audio | `CB_Platzhalter_Demo.mp3` in Inhalte → Dateien (synthetischer Loop, ersetzen) |

## Deine Schritte

### 1. Theme ansehen und veröffentlichen
Onlineshop → Themes → `CONTRABEATZ v1` → Vorschau. Wenn alles passt: Veröffentlichen.
Im Theme-Editor sind alle Texte, Farben, Cover-Farben, Schriften und Sections änderbar.

### 2. Pro Kit: Produkt anlegen oder Platzhalter überschreiben
- **Titel, Preis, Beschreibung** (2–4 ruhige Sätze, kein Hype)
- **Produkttyp** muss exakt einer dieser Werte sein, sonst landet das Kit in keiner Kollektion:
  `Drum Kit` · `One Shot Kit` · `Loop Kit` · `MIDI Kit` · `Phrase Kit` · `Preset Bank` · `Suite` · `Session`
- **Free-Kits:** Preis 0 und Tag `free`
- **Versand:** „Physisches Produkt“ deaktivieren

### 3. Cover / Packshot
Einfach ein Bild als Produktmedium hochladen. Es ersetzt das Platzhalter-Cover automatisch.
- Format **1:1**, mind. **2000 × 2000 px**, JPG oder WebP
- Ohne Bild bleibt das typografische Cover stehen. Das ist bewusst gewollt und kann dauerhaft so bleiben.
- Vorlage für eigene Cover im gleichen System: `docs/cover-template.svg` (3000 × 3000 px, Raster und Textpositionen wie im Shop)

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
sections/    hero, featured-collection, type-index, split, facts, rich-text, faq,
             main-product, related-products, main-collection, main-cart, cart-drawer, …
snippets/    cover (Fallback-Cover), glyph (Typ-Formen), product-card, play-button, player, …
assets/      base.css, theme.js (Player, Warenkorb-Leiste, Varianten; ohne Framework)
templates/   JSON-Templates; page.license, page.faq, page.contact für die Seiten
```

Lizenzstufen (z. B. Basic / Extended) als Produktvarianten anlegen. Die Produktseite zeigt sie automatisch als Auswahl.
