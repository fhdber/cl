# Branding: Shop, Widget, Ticket, E-Mail

pretix lässt wenig Gestaltung zu. Genau deshalb zählt jede Stellschraube. Ziel:
Der Shop fühlt sich an wie die Marke, ohne gegen das System zu kämpfen.

## 1. Shop-Theme (Event-Settings)

`PATCH events/{event}/settings/` oder Backend *Einstellungen → Shop-Design*.

| Schlüssel | Wirkung | Empfehlung |
|---|---|---|
| `primary_color` | Buttons, Links, Akzente | Markenfarbe, Kontrast ≥ 4.5:1 auf Weiß prüfen |
| `theme_color_background` | Seitenhintergrund um den Content | leicht getönt statt reinweiß, nie gesättigt |
| `theme_color_success` / `theme_color_danger` | Status-Meldungen | nur ändern, wenn Grün/Rot mit der Palette kollidiert |
| `theme_round_borders` | runde vs. eckige Kanten | an die Marke anpassen (eckig = editorial, rund = freundlich) |
| `primary_font` | Schrift (Auswahl aus mitgelieferten Fonts) | die nächstliegende zur Hausschrift |
| `logo_image` | Logo im Header (Upload im Backend) | SVG/PNG mit Transparenz |
| `logo_image_large` | Logo als Vollbreite-Header | Für Key-Visual-Banner statt Logo |
| `logo_show_title` | Eventtitel neben Logo zeigen | aus, wenn das Banner den Titel enthält |
| `og_image` | Vorschaubild beim Teilen | 1200×630, Titel + Datum im Bild |
| `frontpage_text` | Text über der Ticketliste (Markdown) | siehe Shop-Copy |
| `event_list_type` | Darstellung bei Serien: `list`, `week`, `calendar` | |

Organizer-weite Defaults unter `organizers/{org}/settings/`: einmal setzen, alle
Events erben.

**Header-Banner:** `logo_image_large` mit `logo_show_title: false`. Format ca.
1140×200 px (breit, flach), wichtige Inhalte mittig, da mobil beschnitten wird.

## 2. Widget auf der eigenen Website

Snippet erzeugen: `node scripts/pretix.mjs widget <event> --lang de`
oder Backend *Event → Einstellungen → Widget*. Aufbau:

```html
<!-- in <head> -->
<link rel="stylesheet" type="text/css" href="https://pretix.eu/ORG/EVENT/widget/v2.css" crossorigin>
<script type="text/javascript" src="https://pretix.eu/widget/v2.de.js" async crossorigin></script>

<!-- an der Stelle der Ticketliste -->
<pretix-widget event="https://pretix.eu/ORG/EVENT/"></pretix-widget>
<noscript>
  <div class="pretix-widget"><div class="pretix-widget-info-message">
    JavaScript ist deaktiviert. <a target="_blank" rel="noopener" href="https://pretix.eu/ORG/EVENT/">Ticketshop in neuem Fenster öffnen</a>.
  </div></div>
</noscript>
```

Die Versionsnummer (`v2`) im CSS/JS-Pfad gibt das Backend vor; im Zweifel das
Snippet von dort kopieren.

**Attribute** am `<pretix-widget>`:

| Attribut | Zweck |
|---|---|
| `event="…"` | Shop-URL (Pflicht). Organizer-URL zeigt alle Events. |
| `subevent="123"` | direkt auf einen Termin einer Serie |
| `items="1,2"` / `categories="3"` / `variations="…"` | nur ausgewählte Produkte zeigen |
| `voucher="CODE"` | Gutschein vorbelegen (z. B. Partnerseite) |
| `list-type="list\|week\|calendar"` | Darstellung bei Serien |
| `filter="…"` | Events nach Metadaten filtern (Organizer-Widget) |
| `display-event-info="false"` | Eventinfos (Titel, Datum) ausblenden, wenn die Seite sie schon zeigt |
| `disable-vouchers` | Gutscheinfeld ausblenden |
| `disable-filters` | Filter im Organizer-Widget ausblenden |
| `disable-iframe` | Checkout im neuen Tab statt im Overlay |
| `skip-ssl-check` | nur für lokale Tests ohne HTTPS |

**Button statt Liste** – für Hero-CTAs:

```html
<pretix-button event="https://pretix.eu/ORG/EVENT/" items="item_1=1">Tickets sichern</pretix-button>
```

`items="item_<id>=<anzahl>"` legt direkt in den Warenkorb. Button-Optik per CSS
auf `.pretix-button` an die Website angleichen.

**CSS-Override** (nach dem Widget-CSS laden, Selektoren unter `.pretix-widget-wrapper`
scopen, damit nichts auf die Seite leckt):

```css
.pretix-widget-wrapper .pretix-widget { border: 0; font-family: inherit; }
.pretix-widget-wrapper .pretix-widget-item-row { padding: 16px 0; }
.pretix-widget-wrapper button,
.pretix-widget-wrapper .pretix-widget-button { border-radius: 0; letter-spacing: .02em; }
```

Prinzip: Schrift und Abstände von der Website erben lassen, Farben kommen aus
`primary_color`. Nicht jede Klasse überschreiben – Widget-Updates brechen sonst
das Layout. Nach Updates kurz visuell prüfen.

## 3. Ticket-PDF

Backend *Event → Einstellungen → Tickets → PDF-Editor*. Kein API-Weg für das Layout;
der Skill liefert eine **Spezifikation**, die im Editor nachgebaut wird.

Hierarchie, die am Einlass funktioniert:

1. **QR-Code** groß (≥ 35 mm), viel Weißraum drumherum, nie auf Bild/Farbfläche
2. **Ticketart** (Item-Name) – am Einlass das Wichtigste nach dem Code
3. **Name** des Teilnehmenden
4. **Datum · Uhrzeit · Ort**
5. Bestellcode klein (Support-Fälle)
6. Key Visual als Hintergrund **nur außerhalb** der QR-Zone

Format: A4 mit Ticket im oberen Drittel (wird gedruckt und gefaltet) oder eigenes
Format für Wallet/Mobil. Für Apple/Google Wallet gibt es eigene Plugins mit
separaten Bildvorgaben (Logo, Strip-Image).

## 4. E-Mail-Templates

Backend *Einstellungen → E-Mail*, Keys z. B. `mail_text_order_placed`,
`mail_text_order_paid`. Platzhalter in geschweiften Klammern:

| Platzhalter | Inhalt |
|---|---|
| `{event}` | Eventname |
| `{event_location}`, `{event_begin_time}`, `{event_admission_time}` | Ort, Beginn, Einlass |
| `{code}` | Bestellcode |
| `{url}` / `{url_button}` | Link zur Bestellung (Text / als Button) |
| `{total_with_currency}`, `{currency}` | Summe |
| `{expire_date}` | Zahlungsfrist |
| `{payment_info}` | Zahlungsanweisungen der gewählten Zahlungsart |
| `{name}`, `{name_for_salutation}` | Name der bestellenden Person |
| `{invoice_name}`, `{invoice_company}` | Rechnungsdaten |
| `{attendee_name}`, `{product}` | pro Ticket (Teilnehmer-Mails) |
| `{url_cancel}`, `{url_info_change}` | Storno- bzw. Datenänderungslink |

Das Backend zeigt unter jedem Feld die gültigen Platzhalter für genau diese Mail.
Unbekannte Platzhalter bleiben sichtbar stehen – immer Testmail schicken.

Struktur für Bestätigungsmails:

```
Betreff: Deine Tickets für {event}

Hallo {name_for_salutation},

danke, du bist dabei. Deine Tickets findest du hier:
{url_button}

{event} · {event_begin_time} · {event_location}
Einlass ab {event_admission_time}.

Bestellnummer: {code}
```

Kurz, eine Handlung pro Mail, Infos in der Reihenfolge, in der man sie braucht.

## 5. Shop-Copy

`frontpage_text` (Markdown) – drei Blöcke, nicht mehr:

1. **Eine Zeile Versprechen** (was erlebt man) – keine Wiederholung des Titels
2. **Fakten** als kurze Liste: Datum, Einlass, Ort, Altersfreigabe, Barrierefreiheit
3. **Ein Satz zu Tickets** (z. B. „Early Bird bis 30. April, danach regulär")

Item-Beschreibungen: ein Satz, was drin ist und was es von den anderen Items
unterscheidet. Keine Preise im Text – die zeigt pretix selbst.
