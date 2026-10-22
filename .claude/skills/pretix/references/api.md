# pretix REST API – Referenz

Geprüft gegen den Quellcode von pretix 2026.8.0. Bei eigener Instanz mit älterer
Version können einzelne Ressourcen fehlen.

## Grundlagen

| | |
|---|---|
| Basis | `{PRETIX_URL}/api/v1/` |
| Auth | Header `Authorization: Token <token>` (Geräte: `Device <token>`, OAuth: `Bearer`) |
| Format | JSON, `Content-Type: application/json` |
| Pagination | `{"count", "next", "previous", "results": [...]}`, `?page=2`, `?page_size=` max. **50** |
| Rate Limit | 429 mit `Retry-After` → warten, nicht hämmern. Die CLI macht das automatisch. |
| Fehler | 400 mit Feld → Fehlerliste, z. B. `{"slug": ["This slug has already been used"]}` |
| Pfade | Immer mit abschließendem `/` |

## Ressourcen

Präfix `organizers/{org}/`:

```
events/                       subevents/            webhooks/
giftcards/                    customers/            memberships/  membershiptypes/
teams/                        devices/              saleschannels/
orders/  orderpositions/  invoices/  transactions/    (organizer-weit)
settings/                     exporters/            scheduled_exports/
checkinrpc/redeem/   checkinrpc/search/   checkinrpc/annul/
```

Präfix `organizers/{org}/events/{event}/`:

```
settings/        clone/           subevents/
items/           items/{id}/variations/  addons/  bundles/  program_times/
categories/      questions/       questions/{id}/options/
quotas/          quotas/{id}/availability/
discounts/       vouchers/        vouchers/batch_create/
taxrules/        seats/           waitinglistentries/
orders/          orderpositions/  invoices/  cartpositions/
orders/{code}/payments/  orders/{code}/refunds/
checkinlists/    checkinlists/{id}/positions/
exporters/       shredders/       revokedsecrets/  blockedsecrets/
```

## Order-Aktionen

`POST organizers/{org}/events/{event}/orders/{code}/<aktion>/`

| Aktion | Wirkung | Vorsicht |
|---|---|---|
| `mark_paid/` | als bezahlt markieren | |
| `mark_canceled/` | stornieren (Body optional `{"send_email": true}`) | **irreversibel, nur nach Ja** |
| `approve/` / `deny/` | bei Freigabe-pflichtigen Items | |
| `extend/` | Zahlungsfrist verlängern, `{"expires": "2026-11-30T23:59:00+01:00"}` | |
| `resend_link/` | Bestelllink erneut mailen | |
| `regenerate_secrets/` | neue Ticket-Codes (alte ungültig) | **Tickets sind danach neu** |
| `download/pdf/` | Ticket-PDF | |

Order-Status: `n` offen, `p` bezahlt, `e` abgelaufen, `c` storniert.
Filter: `?status=p`, `?email=...`, `?search=...`, `?modified_since=ISO-Datum`, `?testmode=false`.

## Minimal-Payloads

**Event** (`POST events/`):

```json
{
  "name": {"de": "Sommerfest 2027", "en": "Summer Party 2027"},
  "slug": "sommerfest27",
  "currency": "EUR",
  "date_from": "2027-07-10T18:00:00+02:00",
  "date_to": "2027-07-11T02:00:00+02:00",
  "location": {"de": "Alte Halle, Freiburg"},
  "presale_start": "2027-03-01T10:00:00+01:00",
  "presale_end": "2027-07-10T16:00:00+02:00",
  "is_public": true,
  "live": false,
  "testmode": true,
  "has_subevents": false,
  "timezone": "Europe/Berlin"
}
```

Schneller: bestehendes Event als Vorlage klonen → `POST events/{alt}/clone/` mit
`name`, `slug`, `date_from`. Übernimmt Items, Quotas, Fragen, Settings.

**Steuerregel** (einmal pro Event, `POST taxrules/`):
`{"name": {"de": "MwSt. 7 %"}, "rate": "7.00", "price_includes_tax": true}`

**Kategorie**: `{"name": {"de": "Tickets"}, "position": 0}`

**Item** (`POST items/`):

```json
{
  "name": {"de": "Early Bird", "en": "Early Bird"},
  "description": {"de": "Limitiert, nur bis 30. April."},
  "category": 1,
  "default_price": "29.00",
  "tax_rule": 1,
  "admission": true,
  "active": true,
  "available_until": "2027-04-30T23:59:00+02:00",
  "max_per_order": 4,
  "position": 0
}
```

`admission: true` = Eintrittsticket (zählt beim Check-in). Merch/Add-ons: `false`.
Nur via Voucher sichtbar: `"hide_without_voucher": true`.

**Quota** (`POST quotas/`):
`{"name": "Saal", "size": 300, "items": [1, 2], "variations": []}`
`size: null` = unbegrenzt. Auslastung: `GET quotas/{id}/availability/`.

**Voucher-Batch** (`POST vouchers/batch_create/`, Body = Liste):

```json
[{"code": "PRESSE-A1B2", "max_usages": 1, "price_mode": "set", "value": "0.00",
  "item": 3, "valid_until": "2027-07-10T18:00:00+02:00", "tag": "presse"}]
```

`price_mode`: `none` | `set` (fester Preis) | `subtract` (Betrag ab) | `percent`.
`tag` nutzen, um Kampagnen auszuwerten (`GET vouchers/?tag=presse`).

**Webhook** (organizer-weit, `POST webhooks/`):

```json
{"target_url": "https://hook.example.com/pretix", "enabled": true,
 "all_events": true, "limit_events": [],
 "action_types": ["pretix.event.order.paid", "pretix.event.order.canceled"]}
```

Webhooks schicken nur Event, Code und Aktion. Details per API nachladen.

## Webhook-Typen (Auswahl)

```
pretix.event.order.placed            pretix.event.order.paid
pretix.event.order.canceled          pretix.event.order.expired
pretix.event.order.modified          pretix.event.order.contact.changed
pretix.event.order.approved/denied   pretix.event.order.placed.require_approval
pretix.event.order.refund.created    pretix.event.order.refund.done
pretix.event.checkin                 pretix.event.checkin.reverted
pretix.event.live.activated/deactivated
pretix.event.testmode.activated/deactivated
pretix.event.orders.waitinglist.added / .voucher_assigned
pretix.voucher.added/changed/deleted
pretix.subevent.added/changed/deleted
pretix.giftcards.created/modified    pretix.customer.created/changed
```

## Event-Settings

`GET/PATCH events/{event}/settings/` – Schlüssel für Branding und Verhalten siehe
[branding.md](branding.md). PATCH mit nur den zu ändernden Schlüsseln.
Datei-Settings (Logo, OG-Bild) werden **nicht** per JSON gesetzt, sondern im Backend
hochgeladen.

## Fallstricke

- Item ohne Quota → im Shop „ausverkauft". Immer Quota anlegen.
- `live: true` schlägt fehl, solange keine Zahlungsart aktiv ist oder Quotas fehlen.
  Die Fehlermeldung listet die offenen Punkte.
- Event-Serie (`has_subevents: true`): Quotas hängen am **Subevent**
  (`"subevent": id`), nicht am Event.
- `orderpositions` statt `orders`, wenn du Teilnehmer statt Käufer brauchst
  (eine Bestellung kann mehrere Tickets mit eigenen Namen haben).
- Für große Exporte die Exporter nutzen (`GET exporters/`, dann `POST exporters/{id}/run/`)
  statt hunderte Seiten zu paginieren.
- Testmodus-Bestellungen tauchen in der API auf. Für Reports `?testmode=false`.
