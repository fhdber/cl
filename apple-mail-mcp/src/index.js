#!/usr/bin/env node
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { jxa, osascript } from './osascript.js';
import { LIST_ACCOUNTS, SEARCH, READ, SAVE_ATTACHMENTS, SEND } from './scripts.js';

const DEFAULT_DIR = process.env.APPLE_MAIL_MCP_ATTACHMENT_DIR || path.join(os.homedir(), 'Downloads', 'Mail-Anhaenge');

const server = new McpServer({ name: 'apple-mail', version: '1.0.0' });

const ok = (data) => ({ content: [{ type: 'text', text: typeof data === 'string' ? data : JSON.stringify(data, null, 2) }] });
const fail = (e) => ({ isError: true, content: [{ type: 'text', text: `Fehler: ${e.message || e}` }] });
const wrap = (fn) => async (args) => { try { return ok(await fn(args)); } catch (e) { return fail(e); } };

const expandHome = (p) => (p.startsWith('~') ? path.join(os.homedir(), p.slice(1)) : p);

const messageRef = {
  account: z.string().describe('Account-Name, wie von search_emails geliefert'),
  mailbox: z.string().describe('Postfach-Name, wie von search_emails geliefert'),
  id: z.number().int().describe('Nachrichten-ID, wie von search_emails geliefert'),
};

// ── Accounts & Postfächer ────────────────────────────────────────────────
server.registerTool('list_accounts', {
  title: 'Accounts & Postfächer',
  description: 'Listet alle Mail-Accounts mit Absenderadressen und Postfächern (inkl. ungelesen-Zähler).',
  inputSchema: {},
  annotations: { readOnlyHint: true },
}, wrap(() => jxa(LIST_ACCOUNTS)));

// ── Suchen ───────────────────────────────────────────────────────────────
server.registerTool('search_emails', {
  title: 'E-Mails durchsuchen',
  description:
    'Durchsucht Apple Mail. Standard: Posteingang aller Accounts. Filter werden UND-verknüpft. ' +
    'Liefert account/mailbox/id je Treffer – damit read_email oder save_attachments aufrufen. ' +
    'Tipp: Mit "since" eingrenzen, das macht große Postfächer deutlich schneller.',
  inputSchema: {
    query: z.string().optional().describe('Text in Betreff ODER Absender'),
    subject: z.string().optional().describe('Text im Betreff'),
    from: z.string().optional().describe('Text im Absender (Name oder Adresse)'),
    body: z.string().optional().describe('Text im Nachrichtentext – langsam, am besten mit since kombinieren'),
    since: z.string().optional().describe('Nur ab diesem Datum, ISO z. B. 2026-11-01'),
    until: z.string().optional().describe('Nur bis zu diesem Datum, ISO'),
    unreadOnly: z.boolean().optional().describe('Nur ungelesene'),
    flaggedOnly: z.boolean().optional().describe('Nur markierte'),
    account: z.string().optional().describe('Nur dieser Account (Name aus list_accounts)'),
    mailbox: z.string().optional().describe('Postfach: inbox (Standard), sent, drafts, trash, junk, archive oder ein eigener Ordnername'),
    allMailboxes: z.boolean().optional().describe('Alle Postfächer durchsuchen (langsam)'),
    limit: z.number().int().min(1).max(200).optional().describe('Max. Treffer, Standard 20'),
  },
  annotations: { readOnlyHint: true },
}, wrap(async (a) => {
  for (const k of ['since', 'until']) {
    if (a[k] && Number.isNaN(Date.parse(a[k]))) throw new Error(`Ungültiges Datum in "${k}": ${a[k]}`);
  }
  return jxa(SEARCH, a);
}));

// ── Lesen ────────────────────────────────────────────────────────────────
server.registerTool('read_email', {
  title: 'E-Mail lesen',
  description: 'Liest eine E-Mail vollständig: Kopfzeilen, Text und Liste der Anhänge.',
  inputSchema: {
    ...messageRef,
    maxChars: z.number().int().min(200).optional().describe('Text kürzen auf N Zeichen, Standard 20000'),
    markRead: z.boolean().optional().describe('Als gelesen markieren'),
  },
}, wrap((a) => jxa(READ, { maxChars: 20000, ...a })));

// ── Anhänge speichern ────────────────────────────────────────────────────
server.registerTool('save_attachments', {
  title: 'Anhänge speichern',
  description:
    `Speichert die Anhänge einer E-Mail in einen Ordner (Standard: ${DEFAULT_DIR}). ` +
    'Vorhandene Dateien werden nie überschrieben, sondern durchnummeriert.',
  inputSchema: {
    ...messageRef,
    directory: z.string().optional().describe('Zielordner (absolut oder mit ~). Wird angelegt, falls nötig.'),
    nameContains: z.string().optional().describe('Nur Anhänge, deren Dateiname diesen Text enthält, z. B. ".pdf"'),
  },
}, wrap(async (a) => {
  const dir = path.resolve(expandHome(a.directory || DEFAULT_DIR));
  fs.mkdirSync(dir, { recursive: true });
  const result = await jxa(SAVE_ATTACHMENTS, { ...a, dir, existing: fs.readdirSync(dir) });
  if (!result.saved.length && !result.failed.length) return `Keine passenden Anhänge gefunden.`;
  return { directory: dir, ...result };
}));

// ── Senden ───────────────────────────────────────────────────────────────
const addressList = z.union([z.string(), z.array(z.string())]).optional();
const toList = (v) => (v == null ? [] : (Array.isArray(v) ? v : v.split(/[,;\n]/)).map((s) => s.trim()).filter(Boolean));

server.registerTool('send_email', {
  title: 'E-Mail senden',
  description:
    'Erstellt eine E-Mail in Apple Mail. mode "send" verschickt sofort, ' +
    'mode "open" öffnet das fertige Fenster zur Kontrolle, ohne zu senden.',
  inputSchema: {
    to: z.union([z.string(), z.array(z.string())]).describe('Empfänger, Liste oder kommagetrennt'),
    cc: addressList.describe('CC-Empfänger'),
    bcc: addressList.describe('BCC-Empfänger'),
    subject: z.string(),
    body: z.string().describe('Nachrichtentext (Plain Text)'),
    from: z.string().optional().describe('Absenderadresse eines eigenen Accounts, z. B. "Name <a@b.de>". Leer = Standard-Account'),
    attachments: z.array(z.string()).optional().describe('Dateipfade der Anhänge (absolut oder mit ~)'),
    mode: z.enum(['send', 'open']).optional().describe('send (Standard) oder open'),
  },
  annotations: { destructiveHint: false, openWorldHint: true },
}, wrap(async (a) => {
  const to = toList(a.to), cc = toList(a.cc), bcc = toList(a.bcc);
  if (!to.length) throw new Error('Mindestens ein Empfänger nötig.');
  const files = (a.attachments || []).map((p) => path.resolve(expandHome(p)));
  const missing = files.filter((f) => !fs.existsSync(f));
  if (missing.length) throw new Error(`Anhang nicht gefunden: ${missing.join(', ')}`);
  const mode = a.mode || 'send';
  const res = await osascript('AppleScript', SEND, [
    a.subject, a.body, a.from || '', to.join('\n'), cc.join('\n'), bcc.join('\n'), files.join('\n'), mode,
  ]);
  return res === 'sent'
    ? `Gesendet an ${[...to, ...cc, ...bcc].join(', ')}${files.length ? ` mit ${files.length} Anhang/Anhängen` : ''}.`
    : 'E-Mail-Fenster in Mail geöffnet – bereit zur Kontrolle.';
}));

if (process.platform !== 'darwin') console.error('[apple-mail-mcp] Achtung: läuft nur auf macOS mit Apple Mail.');
await server.connect(new StdioServerTransport());
