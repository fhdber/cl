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

## Szenenbilder (`scenes.py`)

Vier Looks, orientiert an aktuellen Spirits-Packshots auf BP&O, The Brand Identity, Visuelle und Visual Journal: eine Farbe als Raum, harte Schatten als zweite Form, echte Materialien statt Deko.

| Szene | Idee | Licht |
|---|---|---|
| `pink` – Hard Light | Markenpink als Hohlkehle, schwarzer Sockel, der lange Schatten als Grafik | Sonne flach von links, Strip rechts für die Glaskante |
| `noir` – Film Noir | Schwarzer Raum, Spiegelboden, Flasche als Silhouette | Spot von oben, Rim links weiß, rechts Pink |
| `stone` – Botanicals | Travertin-Blöcke, halbe Grapefruit, Wacholder (aus dem Rezept) | Warme Sonne durch eine Jalousie, weiches Fill |
| `set` – It's a Wrap | Filmset: Half Apple Box, Gaffer-X in Pink | Harter Key-Spot, Pink-Gel von hinten |

```bash
blender -b -P scenes.py -- --scene noir --render noir.png          # 1200 × 1500 (4:5), 192 Samples
blender -b -P scenes.py -- --scene all --outdir renders/
blender -b -P scenes.py -- --scene stone --save stone.blend         # zum Weiterbauen
```

Die Glas- und Gin-Materialien lassen in den Szenen 75 % des Schattenlichts durch. Das ist physikalisch geschummelt, ergibt aber den hellen, glasigen Schatten wie im Foto (echte Kaustiken wären um ein Vielfaches teurer).
