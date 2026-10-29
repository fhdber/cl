# Clipline

Clipboard- und Screenshot-Verlauf für macOS, gebaut nach dem Vorbild von [Supaste](https://www.supaste.com/).
Native SwiftUI und AppKit, die Daten bleiben lokal. Keine Abhängigkeiten.

**Copy once. Reuse anytime.**

## Funktionen

| | |
|---|---|
| **Notch-Shelf** | Ein schwarzes Panel hängt oben aus der Notch. Es wächst aus der Notch, wenn die Maus kurz in der Mitte der Menüleiste (an der Notch) verweilt, und zieht sich wieder zurück, wenn sie sie verlässt. Alternativ mit `⌥⌘V`. Die Karten sind nach Tagen gruppiert. |
| **Mini-Shelf** | Kompakte Variante (460 × 126 pt) mit Suche, drei kleinen Buttons und einer Kartenreihe. Kategorien, Typen und Apps stecken im Filter-Menü. Auf Bildschirmen unter 1600 pt (z. B. MacBook Pro 14") automatisch aktiv. Per Button oder in den Einstellungen umschaltbar. |
| **Nook** (Tab 2) | Widgets in der Notch: Medien für Musik und Spotify (Cover, Titel, Fortschritt, Steuerung), Kalender mit Blättern zwischen Tagen oder wahlweise Kurzbefehle, und ein Spiegel (Kamera nur auf Klick, aus beim Schließen). |
| **Ablage** (Tab 3) | Dateien zur Notch ziehen öffnet das Shelf direkt auf der Ablage. Die Dateien bleiben dort, bis du sie wieder herausziehst. Mit AirDrop-Kachel zum Senden. |
| **Live-Aktivität** | Läuft Musik, legt sich ein schmales schwarzes Band um die Notch, links das Cover, rechts ein Equalizer. Ein Klick öffnet den Nook. |
| **Claude** | `⌃⌘C` nimmt den markierten Text (oder den letzten Clip) und öffnet das Claude-Fenster: Verbessern, Kürzen, Zusammenfassen, Stichpunkte, Professionell, Locker, Übersetzen, Erklären – für Bilder Beschreiben, Text herausholen, Alt-Text, Design-Feedback. Oder frei fragen. Antwort live, dann Einfügen (`⌘↩`), Kopieren oder als Clip sichern. Auch per Rechtsklick auf jeden Clip. |
| **Diktat** | `⌃⌥D` halten und sprechen, loslassen – der Text erscheint, wo dein Cursor steht. Erkennung auf dem Mac, Claude entfernt Füllwörter und setzt Satzzeichen. An der Notch läuft ein Pegel mit. |
| **Aufnehmen** | Bereich `⌃⌥⌘4`, Fenster `⌃⌥⌘5`, Bildschirm `⌃⌥⌘3`, Text erkennen `⌃⌥⌘T`. Danach unten links eine Karte: Kopieren, Sichern, Bearbeiten, Anheften, Text, Claude – oder direkt in eine App ziehen. |
| **Bearbeiten** | Pfeil, Rahmen, Kreis, Linie, Text, Marker, Verpixeln, Zähler. Dazu ein Hintergrund mit Verlauf, Rand und Schatten für schöne Screenshots. |
| **Anheften** | Ein Bild schwebt über allem, verschiebbar. Doppelklick oder Esc schließt. |
| **Datei-Aktionen** | In der Ablage: Dateien auf eine Kachel ziehen oder Kachel antippen – AirDrop, ZIP, Verkleinern, In JPG, Claude, eigene Ordner (⌥ = verschieben) und eine App. |
| **Quick Paste** | `⌃⌘V` öffnet an der Maus ein kompaktes Raster mit drei Spalten. Mit `↩` wird direkt eingefügt. |
| **Bibliothek** | `⌃⌘L` öffnet ein großes Fenster mit Raster und einer Detail-Seitenleiste (Quelle, Link, Maße, erkannter Text). |
| **Letzte 10 Clips** | `⌃⌘0` … `⌃⌘9` fügt systemweit sofort ein. Jede Karte zeigt ihr Kürzel als Badge. |
| **Vorschau** | Auge oder Leertaste: großes Panel unter dem Shelf mit Infos. Für Farben gibt es HEX, RGB, CMYK und HSL. |
| **Kategorien** | Farbige Pills mit Zähler. Clips per Rechtsklick zuordnen. Sie fallen nie aus dem Verlauf. |
| **Finden nach App & Typ** | Runde Filter-Buttons für Favoriten, Typ und App. Die Suche findet auch Text in Bildern. |
| **Screenshot-OCR** | Text in Bildern und Screenshots wird auf dem Gerät erkannt. Der Shelf-Button liest einen Bildschirmbereich aus und kopiert den Text. |
| **Pipette** | Nimmt eine Farbe vom Bildschirm auf und kopiert sie als HEX. |
| **Link-Vorschau** | Kopierte Links bekommen Vorschaubild und Seitentitel. |
| **Multi-Clip Copy** | Mit `⇧←/→` oder `⌘`-Klick mehrere Clips wählen und als einen Block einfügen. |
| **Privat** | Inhalte, die Passwort-Manager als vertraulich markieren, werden ignoriert. Dazu kommen eine Blockliste für Apps und eine Pause. |

### Tastatur in Shelf, Quick Paste und Bibliothek

| Taste | Aktion |
|---|---|
| `←` `→` (`↑` `↓` im Raster) | Clip wählen, mit `⇧` mehrere |
| `↩` / Doppelklick | Einfügen |
| `Leertaste` | Vorschau ein/aus (Shelf) |
| `⌘C` | Nur kopieren |
| `⌘P` | Favorit |
| `⌘⌫` | Löschen |
| `Tab` | Nächste Kategorie |
| `⌘1` `⌘2` `⌘3` | Shelf-Tabs Clips · Nook · Ablage |
| `Esc` | Vorschau schließen, Suche leeren, Panel schließen |

## Bauen & starten

Voraussetzungen: macOS 14 (Sonoma) oder neuer und die Command Line Tools (`xcode-select --install`). Xcode ist nicht nötig, weil der Code bewusst ohne SwiftUI-Makros (`@State`, `@FocusState`) auskommt.

```bash
./scripts/build-app.sh --install   # baut Clipline.app, kopiert nach /Applications, startet
```

Alternativ in Xcode: `Package.swift` öffnen und mit ⌘R starten.

Beim ersten Start fragt macOS nach **Bedienungshilfen**. Das braucht Clipline, um `⌘V` für dich zu drücken.
Ohne diesen Zugriff landet der Clip trotzdem in der Zwischenablage, und du fügst ihn selbst ein.

> Beim ersten Build legt das Skript ein lokales Signatur-Zertifikat („Clipline Local Signing“) im Schlüsselbund an
> (einmal Passwort eingeben). Damit bleibt die Signatur über alle Builds gleich, und macOS fragt Bedienungshilfen,
> Kalender, Kamera und Musiksteuerung nur einmal ab.

## Aufbau

```
Sources/Clipline/
├── App/        main, AppDelegate (Menüleiste, Kürzel, Verdrahtung), Prefs
├── Model/      ClipItem, ClipStore (JSON + PNGs), ContentClassifier
├── Services/   PasteboardMonitor, ScreenshotWatcher, TextRecognizer (OCR), HotKey, Paster, NotchHover
├── UI/         Shelf, Quick Paste, Bibliothek, Karten, Einstellungen, Toast
├── Nook/       Medien, Kalender, Kurzbefehle, Spiegel, Ablage, Live-Aktivität
├── Claude/     API-Client (Messages API, Streaming), Schlüsselbund, Claude-Fenster
├── Dictation/  Spracherkennung, Bereinigung mit Claude, Notch-Anzeige
├── Capture/    Aufnahme, Schnellzugriff-Karte, Anheften, Editor
└── Actions/    Datei-Aktionen (ZIP, Verkleinern, Umwandeln, Ziele)
```

### Claude-Anbindung

Clipline spricht direkt mit der Messages API (`api.anthropic.com/v1/messages`, Version `2026-10-21`), mit Streaming.
Standardmodell ist **Claude Opus 5.5**; in den Einstellungen wählbar sind Sonnet 5.5 und Haiku 5.5, fürs Diktat separat.
Bei Opus und Sonnet ist der serverseitige Fallback (`fallbacks: "default"`) aktiv, falls eine Anfrage abgelehnt wird.
Der API-Schlüssel liegt im Schlüsselbund. Kosten entstehen pro Anfrage über dein Anthropic-Konto.

Die Daten liegen in `~/Library/Application Support/Clipline/` (`library.json` plus `images/`).

## Noch nicht drin (für v2)

- **iCloud-Sync** (CloudKit, braucht einen Apple-Developer-Account)
- **Inline Shortcuts**, also Textbausteine per Kürzel (braucht Input-Monitoring)
- **Clip Reminders** (Erinnerung per `UNUserNotificationCenter`)
- Bulk Copy (Sammelablage mit Zähler an der Notch)
- **Apple Intelligence** zum Umschreiben und Zusammenfassen (Writing Tools API)
- Frei belegbarer Hotkey
- Medien aus Browsern und anderen Playern (macOS 15.4+ sperrt die systemweite Medien-Schnittstelle für Dritt-Apps)
- Ersatz für die Lautstärke- und Helligkeitsanzeige (HUD)
