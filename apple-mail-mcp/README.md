# Apple Mail MCP

Steuert Apple Mail auf dem Mac aus Claude heraus: **senden, durchsuchen, lesen, Anhänge speichern.**
Läuft lokal über die Skript-Schnittstelle von Mail (`osascript`). Keine Passwörter, kein Server, keine Cloud.

## Tools

| Tool | Was es tut |
|---|---|
| `list_accounts` | Accounts, Absenderadressen, Postfächer + ungelesen-Zähler |
| `search_emails` | Suche nach Text, Absender, Betreff, Inhalt, Zeitraum, ungelesen/markiert. Standard: alle Posteingänge |
| `read_email` | Komplette Mail inkl. Anhangliste, optional als gelesen markieren |
| `save_attachments` | Anhänge in einen Ordner speichern (Standard `~/Downloads/Mail-Anhaenge`), optional gefiltert, z. B. nur `.pdf` |
| `send_email` | An/CC/BCC, Absender wählbar, Anhänge. `mode: "open"` öffnet die Mail nur zur Kontrolle |

## Installation

Voraussetzung: macOS, Apple Mail eingerichtet, Node.js ≥ 18 (`brew install node`).

```bash
cd apple-mail-mcp && npm install
```

### Claude Desktop

`~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "apple-mail": {
      "command": "node",
      "args": ["/ABSOLUTER/PFAD/zu/apple-mail-mcp/src/index.js"]
    }
  }
}
```

Danach Claude neu starten.

### Claude Code

```bash
claude mcp add apple-mail --scope user -- node /ABSOLUTER/PFAD/zu/apple-mail-mcp/src/index.js
```

### Berechtigung (einmalig)

Beim ersten Aufruf fragt macOS: „Claude möchte Mail steuern“ → **OK**.
Falls verpasst: *Systemeinstellungen → Datenschutz & Sicherheit → Automation* → bei Claude bzw. Terminal den Haken bei **Mail** setzen.

## Beispiele für Prompts

- „Such alle Mails von Studio Müller seit 1. November.“
- „Speicher alle PDF-Anhänge aus der letzten Mail von buchhaltung@… in ~/Documents/Rechnungen.“
- „Schick die Datei ~/Desktop/Logo_v3.pdf an kunde@beispiel.de, Betreff ‚Logo – finale Version‘, kurzer freundlicher Text. Erst zur Kontrolle öffnen.“

## Optionen (Umgebungsvariablen)

| Variable | Standard |
|---|---|
| `APPLE_MAIL_MCP_ATTACHMENT_DIR` | `~/Downloads/Mail-Anhaenge` |
| `APPLE_MAIL_MCP_TIMEOUT_MS` | `120000` |

In der Claude-Desktop-Config unter `"env": { … }` setzen.

## Gut zu wissen

- **Tempo:** Mail ist bei großen Postfächern langsam. Mit `since` eingrenzen; die Volltextsuche (`body`) und `allMailboxes` brauchen am längsten.
- **Anhänge bei IMAP:** Lädt Mail Anhänge nur bei Bedarf, die Mail einmal in Mail öffnen. Danach klappt das Speichern.
- **Sicherheit:** Alle Eingaben gehen als Argumente an `osascript`, nie als Code. Betreffzeilen oder Dateinamen können also nichts ausführen. Vorhandene Dateien werden nie überschrieben.
- Der Mailtext ist Plain Text, Signaturen aus Mail werden nicht automatisch angehängt.
