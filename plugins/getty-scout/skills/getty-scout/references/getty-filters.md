# Getty-Filter, Plan-Format und API

## Plan-Datei (`plan.json`)

```json
{
  "brief": "Website-Hero für Architekturbüro, ruhig, Licht als Material",
  "site": "both",
  "locale": "de",
  "defaults": { "orientation": "horizontal", "family": "creative", "sort": "best" },
  "queries": [
    { "label": "Wörtlich", "phrase": "architect model wood studio window light" },
    { "label": "Detail",   "phrase": "hands cutting cardboard model close up", "composition": "close_up" },
    { "label": "Raum",     "phrase": "concrete wall sunlight shadow minimal", "people": "none", "composition": "copy_space" },
    { "label": "Metapher", "phrase": "light beam through dust empty room", "sort": "newest" }
  ]
}
```

Speichere Plan-Dateien im Arbeitsordner des Nutzers (`getty-scout/`), nicht
im Skill-Ordner. Ausgabe landet neben der Plan-Datei (`--out` überschreibt).

## Felder pro Query

| Feld | Werte | Wirkung |
|---|---|---|
| `phrase` | Text (englisch) | Pflicht |
| `label` | Text | Name des Winkels im Output |
| `family` | `creative` · `editorial` | Creative für Marke/Werbung |
| `orientation` | `horizontal` · `vertical` · `square` · `panoramic_horizontal` · `panoramic_vertical` | Format |
| `composition` | `abstract` · `candid` · `close_up` · `copy_space` · `cut_out` · `full_frame` · `full_length` · `headshot` · `looking_at_camera` · `macro` · `portrait` · `sparse` · `still_life` · `three_quarter_length` · `waist_up` | mehrere kommagetrennt |
| `people` | `none` · `one` · `two` · `group` | Personenzahl |
| `sort` | `best` · `most_popular` · `newest` · `random` | `best` = Standard |
| `style` | `photography` · `illustration` · `vector` · `fine_art` | nur API |
| `color` | Hex ohne `#`, z. B. `2f4f4f` | nur API |
| `age` | z. B. `20-29`, `adults`, `mature_adult` | nur API |
| `exclude` | Begriffe, kommagetrennt | wird als `-begriff` an die Phrase gehängt |

Alle Felder außer `phrase`/`label` gehen auch in `defaults`.

## Website-Links

Das Skript baut Links nach dem Muster
`https://www.gettyimages.de/search/2/image?phrase=…&family=creative&sort=best&orientations=horizontal&compositions=copyspace&numberofpeople=none`.

Getty ändert die Web-Parameter gelegentlich. Die `phrase` funktioniert immer;
falls ein Filter im Browser nicht greift, setzt ihn der Nutzer per Klick in der
Filterleiste. `style`, `color` und `age` wirken nur über die API.

iStock-Links (`--site istock` oder `both`) nutzen dasselbe Muster auf
`istockphoto.com/de`.

## API (optional)

- Key beantragen: developers.gettyimages.com (für Getty-Kunden/Partner).
- Als `.env` im Arbeitsordner des Nutzers oder als Umgebungsvariable:
  `GETTY_API_KEY=…` und optional `GETTY_API_SECRET=…` (dann holt das Skript
  ein OAuth-Token per Client-Credentials).
- Endpunkte: `GET /v3/search/images/creative`, `/v3/search/images/editorial`,
  `GET /v3/images/{id}/similar`. Header: `Api-Key`.
- Das Netzwerk der Umgebung muss `api.gettyimages.com` (und für OAuth
  `authentication.gettyimages.com`) erlauben. In Cloud-Sessions ist das
  standardmäßig gesperrt – dann fällt das Skript automatisch auf Links zurück.

## Skript-Befehle

```
getty.mjs plan <plan.json> [--out dir] [--site getty|istock|both] [--links-only]
getty.mjs url --phrase "…" [--orientation …] [--composition …] [--people …] [--sort …] [--family …] [--site …] [--locale de|com]
getty.mjs similar <asset-id> [--out dir]
```

Ausgaben von `plan`: `links.md` (immer), mit API zusätzlich `results.json`
und `contact-sheet.html`.
