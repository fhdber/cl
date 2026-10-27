# App-Icon

`AppIcon.png` (1024 × 1024, macOS-Raster mit 824er Squircle) wird beim Build zu `AppIcon.icns`.

Konzepte (SVG zum Weiterbearbeiten, PNG gerendert):

- `A-shelf`: das Shelf hängt aus dem oberen Rand, mit drei Clips, einer davon ausgewählt
- `B-stack`: aufgefächerter Stapel, der neueste Clip liegt vorn
- `C-line`: Clips auf einer Linie, einer ist angehoben und ausgewählt
- `D-glossy`: Verlauf von Blau nach Indigo, durchscheinende Karten im Hintergrund, vorn ein weißer Clip mit der Clip-Linie-Marke (**aktuell aktiv**)

Icon wechseln: die gewünschte PNG nach `AppIcon.png` kopieren und `./scripts/build-app.sh --install` ausführen.
