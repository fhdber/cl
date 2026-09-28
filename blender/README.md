# WRAP Gin – Blender-Flasche

Parametrische 50-cl-Flasche mit Glas, Gin, Kork, Holzkappe, Front- und Rücketikett und Studiolicht. Die Silhouette wurde aus dem Mockup vermessen, alle Maße sind echt (Meter).

## Start

1. Etiketten als `textures/label_front.png` und `textures/label_back.png` ablegen (709:1240, möglichst hochaufgelöst, z. B. 1654 × 2894 px bei 300 dpi).
2. Blender (5.x) → Scripting → `gin_bottle.py` öffnen → Run Script (Alt+P).

Oder headless:

```bash
blender -b -P gin_bottle.py -- --render wrap.png            # 1500 × 2000, 256 Samples
blender -b -P gin_bottle.py -- --render test.png --samples 64 --res 750x1000
blender -b -P gin_bottle.py -- --save wrap_gin.blend
```

## Aufbau

| Objekt | Inhalt |
|---|---|
| `GEO-glass` | Rotationskörper: Außenkontur aus dem Mockup, 3,5 mm Wand, 11 mm Boden, Mündungswulst |
| `GEO-gin` | Flüssigkeit, 0,3 mm ins Glas überlappend (saubere Brechung), Füllhöhe knapp im Hals |
| `GEO-cork`, `GEO-cap` | Korkschaft in der Mündung, Kappe aus hellem Holz (prozedurale Maserung) |
| `GEO-label-*` | Papier (0,15 mm), Etikett 57 × 99,5 mm; die Rückseite des Papiers bleibt blank, das Rücketikett wirkt deshalb durch den Gin wie echt |
| `COL-studio` | weißer Hintergrund und Boden, schwarze Flags für dunkle Glaskanten, 2 Strip-Softboxen, Top-Light, 85-mm-Kamera |

## Stellschrauben

- **Maße:** `DIM` oben im Skript (Füllhöhe, Kappe, Etikettgröße und -höhe), die Schulterform steht in `SHOULDER`.
- **Glaskanten:** Abstand und Größe von `GEO-flag-L/R`. Näher und größer ergibt härtere, grafischere Konturen.
- **Farbe:** View Transform steht auf *Standard*, damit Pink und Weiß 1:1 aus der Druckdatei kommen.
- **Hintergrund in Markenfarbe:** Farbe von `MAT-backdrop` und die Emission in `MAT-floor` gleich setzen.
