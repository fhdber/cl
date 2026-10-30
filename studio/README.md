# Glide Studio

Screen-Recorder und Editor im Browser, eine Datei, keine Abhängigkeiten.

**Start:** `studio/index.html` in Chrome, Edge oder Arc öffnen (per Doppelklick oder `npx serve studio`).

## Funktionen
- Bildschirm + Systemton + Mikrofon aufnehmen, optional Kamera als zweite Spur
- Vorhandenes Video öffnen (Drag & Drop)
- Hintergrund: Verläufe, Farbe, eigenes Bild, Blur aus dem Video
- Rahmen: Abstand, Eckenradius, Schatten
- Formate: Auto, 16:9, 9:16, 1:1, 4:3
- Zooms auf der Timeline: verschieben, Länge ziehen, Stärke + Fokus setzen; aufeinanderfolgende Zooms schwenken weich ineinander
- **Auto-Zoom:** erkennt Bereiche mit lokaler Bildschirmaktivität (Tippen, Klicks, Mausbewegung) und setzt Zooms automatisch
- Trimmen (gelbe Griffe), Kamera-Bubble (Position, Form, Größe)
- Export als MP4 (wenn der Browser es kann) oder WebM, inkl. Ton

## Shortcuts
`Leertaste` Play/Pause · `Z` Zoom an Playhead · `Entf` Zoom löschen · `←/→` Frame (mit Shift: 1 s)

## Grenzen gegenüber nativen Apps
Der Browser liefert keine Cursor-Position außerhalb des Tabs. Deshalb basiert Auto-Zoom auf Bildanalyse statt Cursor-Tracking, und der Cursor ist ins Video eingebrannt (kein Glätten oder Vergrößern). Der Export läuft in Echtzeit, der Tab muss dabei im Vordergrund bleiben.
