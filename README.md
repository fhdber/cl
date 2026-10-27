# Clipline

Clipboard- und Screenshot-Verlauf für macOS, gebaut nach dem Vorbild von [Supaste](https://www.supaste.com/).
Native SwiftUI und AppKit, die Daten bleiben lokal. Keine Abhängigkeiten.

**Copy once. Reuse anytime.**

## Funktionen

| | |
|---|---|
| **Notch-Shelf** | Ein schwarzes Panel hängt oben aus der Notch. Es wächst aus der Notch, wenn die Maus in die Menüleiste fährt, und zieht sich wieder zurück, wenn sie sie verlässt. Alternativ mit `⌥⌘V`. Die Karten sind nach Tagen gruppiert. |
| **Mini-Shelf** | Kompakte Variante (460 × 126 pt) mit Suche, drei kleinen Buttons und einer Kartenreihe. Kategorien, Typen und Apps stecken im Filter-Menü. Auf Bildschirmen unter 1600 pt (z. B. MacBook Pro 14") automatisch aktiv. Per Button oder in den Einstellungen umschaltbar. |
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
| `Esc` | Vorschau schließen, Suche leeren, Panel schließen |

## Bauen & starten

Voraussetzungen: macOS 14 (Sonoma) oder neuer und die Command Line Tools (`xcode-select --install`). Xcode ist nicht nötig, weil der Code bewusst ohne SwiftUI-Makros (`@State`, `@FocusState`) auskommt.

```bash
./scripts/build-app.sh --install   # baut Clipline.app, kopiert nach /Applications, startet
```

Alternativ in Xcode: `Package.swift` öffnen und mit ⌘R starten.

Beim ersten Start fragt macOS nach **Bedienungshilfen**. Das braucht Clipline, um `⌘V` für dich zu drücken.
Ohne diesen Zugriff landet der Clip trotzdem in der Zwischenablage, und du fügst ihn selbst ein.

> Nach jedem Neu-Build ändert sich die Ad-hoc-Signatur. Falls Auto-Einfügen dann nicht mehr geht, entferne Clipline unter
> *Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen* und füg die App neu hinzu.

## Aufbau

```
Sources/Clipline/
├── App/        main, AppDelegate (Menüleiste, Hotkey), Prefs
├── Model/      ClipItem, ClipStore (JSON + PNGs), ContentClassifier
├── Services/   PasteboardMonitor, ScreenshotWatcher, TextRecognizer (OCR), HotKey, Paster
└── UI/         PanelController (NSPanel), PanelModel, PanelView, ClipCard, SettingsView
```

Die Daten liegen in `~/Library/Application Support/Clipline/` (`library.json` plus `images/`).

## Noch nicht drin (Supaste-Features für v2)

- **iCloud-Sync** (CloudKit, braucht einen Apple-Developer-Account)
- **Inline Shortcuts**, also Textbausteine per Kürzel (braucht Input-Monitoring)
- **Clip Reminders** (Erinnerung per `UNUserNotificationCenter`)
- Dateien per Drag aufs Shelf ablegen
- Bulk Copy (Sammelablage mit Zähler an der Notch)
- **Apple Intelligence** zum Umschreiben und Zusammenfassen (Writing Tools API)
- Frei belegbarer Hotkey
