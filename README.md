# Clipline

Clipboard- und Screenshot-Verlauf für macOS, gebaut nach dem Vorbild von [Supaste](https://www.supaste.com/).
Native SwiftUI und AppKit, die Daten bleiben lokal. Keine Abhängigkeiten.

**Copy once. Reuse anytime.**

## Funktionen

| | |
|---|---|
| **Visuelle Timeline** | `⌃⌘V` öffnet eine Leiste am unteren Bildschirmrand, mit allen Clips als Karten und nach Tagen gruppiert. |
| **Alles wird erfasst** | Text, Links, Code, Farben (`#hex`, `rgb()`, `hsl()`), Bilder, Dateien und Screenshots. Der Typ wird automatisch erkannt. |
| **Screenshot-OCR** | Text in Bildern und Screenshots wird auf dem Gerät erkannt (Vision, DE und EN) und ist durchsuchbar. |
| **Finden nach Typ und App** | Filter-Chips für Typen und die meistgenutzten Quell-Apps. `Tab` / `⇧Tab` schaltet durch. |
| **Eigene Sammlungen** | Clips per Rechtsklick in Sammlungen ablegen. Sammlungen und angeheftete Clips fallen nie aus dem Verlauf. |
| **Letzte 10 Clips** | `⌘1` … `⌘0` fügt direkt ein. |
| **Multi-Clip Copy** | Mit `⇧←/→`, `⌘`-Klick oder `⇧`-Klick mehrere Clips wählen. `↩` fügt sie als einen Block ein. |
| **Einfügen ohne App-Wechsel** | Das Panel aktiviert sich nicht selbst. `↩` drückt `⌘V` in der App, in der du gerade bist. |
| **Drag & Drop** | Karten lassen sich direkt in andere Apps ziehen. |
| **Privat** | Inhalte, die Passwort-Manager als vertraulich markieren, werden ignoriert. Dazu kommt eine Blockliste für Apps und eine Pause in der Menüleiste. |

### Tastatur im Panel

| Taste | Aktion |
|---|---|
| `←` `→` | Clip wählen (mit `⇧` mehrere) |
| `↩` / Doppelklick | Einfügen |
| `⌘C` | Nur kopieren |
| `⌘1` … `⌘0` | Einen der letzten 10 Clips einfügen |
| `⌘P` | Anheften / Lösen |
| `⌘⌫` | Löschen |
| `Tab` | Nächster Filter |
| `Esc` | Suche leeren / schließen |
| `⌘,` | Einstellungen |

## Bauen & starten

Voraussetzungen: macOS 14 (Sonoma) oder neuer, Xcode 15 oder neuer (oder die Command Line Tools).

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
- **Notch-Shelf** zum Zwischenparken per Drag
- **Apple Intelligence** zum Umschreiben und Zusammenfassen (Writing Tools API)
- Frei belegbarer Hotkey
