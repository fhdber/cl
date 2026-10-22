# Setup-Playbook

Reihenfolge ist wichtig: jedes Objekt verweist auf das vorherige.

```
1 Event (Testmodus)  →  2 Steuerregel  →  3 Kategorien  →  4 Items
→  5 Quotas  →  6 Fragen  →  7 Zahlungsarten  →  8 Branding  →  9 Voucher  →  10 Live
```

## Struktur zuerst als Tabelle

Bevor irgendetwas angelegt wird, diese Tabelle mit der Person abstimmen:

| Item | Kategorie | Preis | Steuer | Verkauf bis | Max./Bestellung | Quota |
|---|---|---|---|---|---|---|
| Early Bird | Tickets | 29,00 | 7 % | 30.04. | 4 | Saal (300) |
| Regular | Tickets | 39,00 | 7 % | Eventbeginn | 6 | Saal (300) |
| Abendkasse | — (versteckt) | 45,00 | 7 % | — | 1 | Saal (300) |
| Soli-Ticket | Tickets | 15,00 | 7 % | Eventbeginn | 1 | Soli (30) + Saal |
| Tote Bag | Merch | 18,00 | 19 % | Eventbeginn | 2 | Merch (100) |

Ein Item darf in mehreren Quotas hängen. Es ist dann verfügbar, solange **alle**
seine Quotas Platz haben. So begrenzt man Untergruppen (30 Soli-Tickets) innerhalb
der Gesamtkapazität (300).

## Muster

**Early Bird ohne Handarbeit**
Early Bird mit `available_until` + eigenem kleinen Quota (z. B. 50) **und** im
Hauptquota. Endet automatisch nach Datum oder Menge, was zuerst kommt.

**Gestaffelte Preise (Tier 1/2/3)**
Drei Items, je eigenes Quota (100/100/100), alle im Hauptquota. Mit
`hidden_if_available` (im Backend: „Nur zeigen, wenn folgendes Quota ausverkauft")
erscheint Tier 2 erst, wenn Tier 1 weg ist.

**Gästeliste / Presse / Crew**
Item „Gästeliste" mit `hide_without_voucher: true`, Preis 0. Voucher-Batch mit
`tag` pro Gruppe. Kein separater Shop nötig.

**Mehrtägig (Festival)**
Variationen statt Einzel-Items: Item „Festivalpass", Variationen Fr/Sa/So/Kombi.
Pro Tag ein Quota mit den passenden Variationen; Kombi steckt in allen drei.

**Terminserie (Workshops, Führungen)**
`has_subevents: true`, Items einmal am Event, Quotas pro Subevent. Termine per
`POST subevents/` in Serie anlegen. Widget mit `list-type="calendar"`.

**Add-ons (Shuttle, Essen)**
Add-on-Kategorie mit `is_addon: true`, am Ticket-Item über `addons/` verknüpfen,
`min_count`/`max_count` setzen.

## Fragen (Teilnehmerdaten)

So wenig wie möglich. Jede Frage kostet Conversion.
Name und E-Mail regeln die Event-Settings (`attendee_names_asked`,
`attendee_emails_asked`), nicht eigene Fragen. Eigene Fragen nur für Dinge, die
am Eventtag wirklich gebraucht werden (Ernährung, T-Shirt-Größe, Barrierefreiheit).

## Vor dem Livegang

- [ ] Jedes Item hängt in mindestens einem Quota
- [ ] Quota-Summen ergeben die echte Kapazität (keine doppelte Zählung)
- [ ] Steuerregel an jedem Item, `price_includes_tax` passt zu den Preisen
- [ ] Verkaufsfenster (`presale_start/end`, `available_from/until`) in der richtigen Zeitzone
- [ ] Zahlungsart aktiv und im Testmodus einmal durchgekauft
- [ ] Impressum/AGB/Datenschutz verlinkt (Organizer-Settings)
- [ ] Bestätigungsmail gelesen: Platzhalter gefüllt, Ton stimmt, Link funktioniert
- [ ] Ticket-PDF auf Smartphone und als Ausdruck geprüft, QR-Code scanbar
- [ ] Widget auf der Zielseite getestet (Desktop + Mobile)
- [ ] Testbestellungen gelöscht, dann `testmode: false`, `live: true`
