---
name: getty-scout
description: >
  Findet die besten Stockmotive auf Getty Images (und iStock) für ein
  Brand- oder Kampagnen-Briefing. Übersetzt das Briefing in eine Bildidee,
  baut mehrere Such-Winkel mit präzisem Getty-Vokabular und Filtern, umgeht
  Stock-Klischees, liefert fertige Such-Links oder – mit API-Key – einen
  Kontaktbogen mit Treffern und kuratiert eine begründete Shortlist.
  Verwende den Skill bei "Getty", "gettyimages", "iStock", "Stockfoto",
  "Stockmotiv", "Bildrecherche", "Bildsuche", "Moodbild", "Keyvisual finden",
  "passendes Foto für", "Bildwelt aus Stock", oder wenn ein Projekt
  lizenzierbare Fotos statt generierter Bilder braucht.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# getty-scout

Gute Stockbilder findet man nicht mit dem ersten Wort, das einem einfällt.
"Business meeting" liefert 400.000 Handshakes. Die Treffer, die nach eigener
Fotografie aussehen, liegen hinter präziserem Vokabular, den richtigen Filtern
und einem klaren Bild davon, *was das Motiv leisten muss*.

**Was du lieferst:** eine Bildidee in einem Satz, 4–6 Such-Winkel als
klickbare Getty-Links (oder API-Treffer als Kontaktbogen), eine kuratierte
Shortlist mit Begründung und einen Hinweis zur Lizenz.

## Ablauf

### 1. Briefing schärfen (max. 3 Fragen)

Was du wissen musst – frag nur, was nicht schon klar ist:

- **Einsatz:** Wo landet das Bild? (Website-Hero, Social 4:5, Plakat, Deck)
  → bestimmt Format, Auflösung, Textfreiraum.
- **Aufgabe:** Was soll der Betrachter fühlen oder verstehen? Ein Verb, kein
  Thema. ("Vertrauen fassen", nicht "Versicherung".)
- **Marke:** Farbwelt, Tonalität, No-Gos. Bestehende Bildsprache? Dann eine
  Referenz zeigen lassen.

Wenn der Nutzer nur ein Thema nennt, triff sinnvolle Annahmen, nenne sie in
einer Zeile und leg los.

### 2. Bildidee formulieren

Ein Satz, der Motiv, Licht und Haltung beschreibt – nicht das Thema:

> "Eine Hand am Lenkrad im Gegenlicht, Morgendämmerung, ruhig – Freiheit
> ohne Pathos."

Dazu 1–2 Gegenideen aus einer anderen Richtung (Metapher statt Person,
Detail statt Totale). Die beste Suche testet mehrere Ideen, nicht mehrere
Synonyme derselben Idee.

### 3. Such-Winkel bauen

Lies `references/query-craft.md`. Baue 4–6 Winkel, je einer pro Strategie:

| Winkel | Beispiel für "Teamwork, Agentur" |
|---|---|
| Wörtlich, aber präzise | `designers sketching wireframes table overhead` |
| Detail / Ausschnitt | `hands moving sticky notes glass wall` |
| Metapher | `rowing team synchronized fog` |
| Licht & Stimmung zuerst | `office late evening warm lamp candid` |
| Leere / Raum für Text | `empty studio desk morning light copy space` |

Suche **auf Englisch** – Getty verschlagwortet englisch, deutsche Begriffe
liefern deutlich weniger und schlechtere Treffer.

Setze Filter gezielt (siehe `references/getty-filters.md`): Ausrichtung nach
Einsatz, `copy_space` wenn Text drauf muss, `number_of_people`, Sortierung
`best` als Standard, `newest` gegen abgenutzte Motive.

### 4. Suchen

Schreib die Winkel in eine Plan-Datei (Format: `references/getty-filters.md`)
und führ das Skript aus:

```bash
node "${CLAUDE_PLUGIN_ROOT}/skills/getty-scout/scripts/getty.mjs" plan pfad/zum/plan.json
```

- **Ohne API-Key:** Das Skript erzeugt fertige Such-Links für gettyimages.de
  (und optional istockphoto.com). Gib sie dem Nutzer als klickbare Liste mit
  einer Zeile, worauf er bei jedem Winkel achten soll.
- **Mit `GETTY_API_KEY`** (in `.env` oder Umgebung): Das Skript holt Treffer,
  entfernt Dubletten und schreibt einen Kontaktbogen (`contact-sheet.html`)
  mit Vorschaubildern. Öffne bzw. zeig ihn dem Nutzer und kuratiere daraus
  (Schritt 5).

Ein einzelner Link geht auch direkt:

```bash
node "${CLAUDE_PLUGIN_ROOT}/skills/getty-scout/scripts/getty.mjs" url --phrase "hands sticky notes glass wall" --orientation horizontal --composition copy_space
```

**Ergebnisse selbst ansehen (Cowork):** Wenn ein Browser-Tool verfügbar ist
(z. B. Claude in Chrome), öffne die Getty-Links selbst, sieh dir die erste
Trefferseite jedes Winkels an und notiere Asset-IDs vielversprechender Bilder.
Damit kuratierst du auch ohne API-Key auf Sicht. Lizenziere oder lade nichts
herunter und logge dich nicht ein.

Speichere Plan-Datei, `links.md` und Kontaktbogen im Arbeitsordner des
Nutzers (Unterordner `getty-scout/`), damit er sie wiederfindet.

Ähnliche Bilder zu einem Favoriten (nur API):

```bash
node "${CLAUDE_PLUGIN_ROOT}/skills/getty-scout/scripts/getty.mjs" similar 1234567890
```

### 5. Kuratieren

Lies `references/curation.md` und bewerte Kandidaten nach dem Raster dort.
Liefere eine Shortlist von **3–5 Bildern**, je mit:

- Asset-ID + Link
- ein Satz, warum es die Bildidee trifft
- Risiko (Klischee, Crop-Probleme, Model-Release, Exklusivität)
- Crop-Hinweis für das Zielformat

Ohne API kannst du die Bilder nicht sehen. Dann bewerte nicht blind, sondern
gib dem Nutzer das Raster als Checkliste mit und bitte ihn, seine Favoriten
(IDs oder Links) zurückzugeben – dann kuratierst du mit.

### 6. Lizenz-Check

Kurz und immer: Creative vs. Editorial (Editorial = nicht für Werbung),
Royalty-free vs. Rights-managed, Model-/Property-Release bei Personen und
Gebäuden. Details in `references/curation.md`.

## Regeln

- **Nie nur eine Suche.** Mindestens drei verschiedene Ideen, nicht drei
  Synonyme.
- **Keine Stock-Klischees** als erste Wahl (Liste in `query-craft.md`), außer
  der Nutzer will genau das – dann ironisch oder bewusst.
- **Serie vor Einzelbild:** Wenn mehrere Motive gebraucht werden, bevorzuge
  Bilder desselben Fotografen bzw. desselben Shootings. Konsistente Bildsprache
  schlägt fünf Einzeltreffer.
- **iStock mitdenken:** Viele Getty-Motive gibt es günstiger über iStock
  (gleicher Konzern). Bei kleinem Budget immer den iStock-Link mitliefern
  (`--site both`).
- **Keine Bilder herunterladen oder lizenzieren** – der Skill recherchiert,
  der Kauf bleibt beim Nutzer.
