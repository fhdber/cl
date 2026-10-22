---
name: pretix
description: >
  Plan, set up, brand, and operate ticket shops on pretix (pretix.eu hosted or
  self-hosted). Turns an event idea into a clean product/quota structure, writes
  shop copy and email templates, styles the shop and the embeddable widget to a
  brand, designs the PDF ticket, and works the pretix REST API (events, items,
  quotas, orders, vouchers, check-in, webhooks) through a zero-dependency CLI.
  Use for "pretix", "Ticketshop", "Tickets verkaufen", "Ticket-Widget einbinden",
  "Event anlegen", "Vorverkauf", "Early Bird", "Gutscheincodes", "Kontingent",
  "Check-in", "Teilnehmerliste exportieren", "Ticket-Layout", "Bestellungen
  auswerten", or any ticketing task where pretix is the platform.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# pretix

pretix is a ticket shop, not a website builder. Its power sits in four objects
and how they connect. Get those right first; everything visual comes after.

```
Event ─┬─ Category ── Item (Produkt) ── Variation
       │                 │
       └─ Quota ─────────┘   (ein Quota begrenzt 1..n Items/Variationen)
          Voucher ─→ schaltet Items frei, ändert Preis, reserviert Quota
```

- **Item** = was gekauft wird (Ticket, Merch, Add-on). Hat Preis, Steuer, Sichtbarkeit.
- **Quota** = wie viele es gibt. **Ein Item ohne Quota ist nicht kaufbar.**
  Mehrere Items in einem Quota teilen sich die Kapazität (z. B. Early Bird + Regular
  = 300 Plätze Saal).
- **Category** = Gruppierung im Shop (reine Darstellung).
- **Voucher** = Code für Rabatt, versteckte Items oder reservierte Plätze.

## Workflow

1. **Brief klären** (max. eine AskUserQuestion-Runde, nur was fehlt):
   Eventtyp (einmalig / Serie mit Terminen), Kapazität, Ticketarten + Preise,
   Verkaufszeitraum, benötigte Teilnehmerdaten, Sprachen, Instanz
   (`https://pretix.eu` oder eigene Domain), Brand-Assets (Farbe, Font, Logo).
2. **Struktur entwerfen** mit [references/setup-playbook.md](references/setup-playbook.md):
   Items, Quotas, Kategorien, Fragen, Voucher als Tabelle. Erst zeigen, dann bauen.
3. **Bauen**, je nach Zugang:
   - Mit API-Token → `scripts/pretix.mjs` (siehe unten), Event zuerst im Testmodus.
   - Ohne Token → Klickanleitung fürs Backend in exakt der Reihenfolge des Playbooks.
4. **Branding** mit [references/branding.md](references/branding.md): Shop-Theme,
   Widget-Einbindung, Ticket-PDF, E-Mail-Texte, Shop-Copy.
5. **Go-live-Check** (Playbook, Abschnitt „Vor dem Livegang"), dann `live: true`.
6. **Betrieb**: Verfügbarkeit, Bestellungen, Exporte, Check-in, Webhooks über die API.

## API-Zugang

Token im Backend: *Organisator → Teams → Team wählen → API-Tokens*. Rechte des
Teams = Rechte des Tokens; für reines Reporting ein eigenes Team mit Leserechten.

```bash
export PRETIX_URL=https://pretix.eu      # oder eigene Instanz, ohne /api/v1
export PRETIX_TOKEN=...                  # nie committen, gehört in .env
export PRETIX_ORG=mein-organizer         # Organizer-Slug aus der URL
```

CLI (Node ≥ 18, keine Abhängigkeiten):

```bash
S=.claude/skills/pretix/scripts/pretix.mjs
node $S check                                   # Token + Organizer testen
node $S get events                              # alle Events (paginiert, komplett)
node $S get events/sommerfest/items
node $S get events/sommerfest/quotas/12/availability
node $S get events/sommerfest/orders --query status=p --csv code,email,total > paid.csv
node $S post events/sommerfest/items --data @item.json --dry-run   # erst ansehen
node $S post events/sommerfest/items --data @item.json             # dann senden
node $S patch events/sommerfest --data '{"testmode": false, "live": true}'
node $S widget sommerfest --lang de             # Einbettungs-Snippet erzeugen
```

Pfade sind relativ zu `/api/v1/organizers/$PRETIX_ORG/`. Vollständige Referenz,
Feldnamen und Fallstricke: [references/api.md](references/api.md).

## Regeln

- **Schreibende Calls nur nach Bestätigung.** Erst `--dry-run` zeigen. Nie `DELETE`,
  `mark_canceled` oder Refunds ohne ausdrückliches Ja zu genau dieser Bestellung.
- **Neue Events im Testmodus** (`"testmode": true`) anlegen. Testbestellungen sind
  echte Datensätze, aber ohne Zahlung; vor Livegang löschen oder ignorieren.
- **Kein Event ohne Quota-Check.** Nach dem Anlegen jedes Items prüfen, dass es in
  mindestens einem Quota hängt. Sonst zeigt der Shop „ausverkauft".
- **Mehrsprachige Felder** sind Objekte: `{"de": "Tagesticket", "en": "Day pass"}`.
  Immer alle aktiven Shop-Sprachen befüllen.
- **Geldbeträge** sind Strings mit zwei Nachkommastellen: `"29.00"`, nie Floats.
- **Personendaten** (Bestellungen, Teilnehmer) nur so weit ausgeben wie nötig, nicht
  in Repos schreiben. Exporte landen im Scratchpad, nicht im Projektordner.
- Gebühren und Tarife von pretix.eu ändern sich. Nicht aus dem Gedächtnis zitieren;
  auf die aktuelle Preisseite verweisen.

## Was dieser Skill liefert

Je nach Auftrag eins oder mehrere davon:

- **Strukturtabelle** Items × Quotas × Preise × Verkaufsfenster
- **Shop-Copy** (Frontpage-Text, Item-Beschreibungen) in Markdown, mehrsprachig
- **E-Mail-Templates** mit korrekten Platzhaltern
- **Theme-Werte** + **Widget-Snippet** + optional CSS-Override
- **Ticket-Layout-Spezifikation** (Raster, Hierarchie, Elemente)
- **JSON-Payloads** und ausgeführte API-Calls mit Ergebnis
- **Reports** (Verkäufe pro Item, Auslastung pro Quota, Check-in-Quote)
