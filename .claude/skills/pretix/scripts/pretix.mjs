#!/usr/bin/env node
// pretix REST API CLI. Zero dependencies, Node >= 18.
//
//   node pretix.mjs check
//   node pretix.mjs get <path> [--query k=v ...] [--first] [--csv f1,f2]
//   node pretix.mjs post|patch|put <path> --data '<json>'|@file.json [--dry-run]
//   node pretix.mjs delete <path> --yes
//   node pretix.mjs widget <event> [--lang de] [--button "Tickets"] [--items item_1=1]
//
// <path> is relative to /api/v1/organizers/$PRETIX_ORG/ unless it starts with "/".
// Env: PRETIX_URL (default https://pretix.eu), PRETIX_TOKEN, PRETIX_ORG. Reads .env if present.

import { readFileSync, existsSync } from 'node:fs';

loadDotenv();

const BASE = (process.env.PRETIX_URL || 'https://pretix.eu').replace(/\/+$/, '');
const TOKEN = process.env.PRETIX_TOKEN;
const ORG = process.env.PRETIX_ORG;

const [cmd, target, ...rest] = process.argv.slice(2);
const opts = parseArgs(rest);

try {
  switch (cmd) {
    case 'check': await check(); break;
    case 'get': await get(target); break;
    case 'post': case 'patch': case 'put': await write(cmd.toUpperCase(), target); break;
    case 'delete': await del(target); break;
    case 'widget': widget(target); break;
    default: usage();
  }
} catch (err) {
  console.error(`✗ ${err.message}`);
  process.exit(1);
}

function usage() {
  console.log(readFileSync(new URL(import.meta.url), 'utf8').split('\n').slice(1, 11)
    .map(l => l.replace(/^\/\/ ?/, '')).join('\n'));
  process.exit(cmd ? 1 : 0);
}

function loadDotenv() {
  for (const p of ['.env', '../.env']) {
    if (!existsSync(p)) continue;
    for (const line of readFileSync(p, 'utf8').split('\n')) {
      const m = line.match(/^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)\s*$/);
      if (m && !(m[1] in process.env)) process.env[m[1]] = m[2].replace(/^(['"])(.*)\1$/, '$2');
    }
    return;
  }
}

function parseArgs(args) {
  const o = { query: [] };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a === '--query' || a === '-q') o.query.push(args[++i]);
    else if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = args[i + 1];
      if (next === undefined || next.startsWith('--')) o[key] = true;
      else o[key] = args[++i];
    }
  }
  return o;
}

function need(...vars) {
  const missing = vars.filter(v => !process.env[v]);
  if (missing.length) throw new Error(`Fehlende Umgebungsvariable: ${missing.join(', ')}`);
}

function url(path, query = []) {
  if (!path) throw new Error('Pfad fehlt');
  if (/^https?:\/\//.test(path)) return path;
  let p = path.startsWith('/') ? path.replace(/^\/(api\/v1\/)?/, '') : `organizers/${ORG}/${path}`;
  if (!p.includes('?') && !p.endsWith('/')) p += '/';
  const u = new URL(`${BASE}/api/v1/${p}`);
  for (const q of query) {
    const [k, ...v] = q.split('=');
    u.searchParams.append(k, v.join('='));
  }
  return u.toString();
}

async function request(method, href, body) {
  need('PRETIX_TOKEN');
  for (let attempt = 0; attempt < 5; attempt++) {
    const res = await fetch(href, {
      method,
      headers: {
        Authorization: `Token ${TOKEN}`,
        Accept: 'application/json',
        ...(body !== undefined && { 'Content-Type': 'application/json' }),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
    });
    if (res.status === 429) {
      const wait = Number(res.headers.get('retry-after')) || 2 ** attempt;
      console.error(`… Rate limit, warte ${wait}s`);
      await new Promise(r => setTimeout(r, wait * 1000));
      continue;
    }
    const text = await res.text();
    const data = text ? safeJson(text) : null;
    if (!res.ok) {
      throw new Error(`${method} ${href} → ${res.status}\n${typeof data === 'string' ? data.slice(0, 500) : JSON.stringify(data, null, 2)}`);
    }
    return data;
  }
  throw new Error('Rate limit: zu viele Wiederholungen');
}

function safeJson(t) { try { return JSON.parse(t); } catch { return t; } }

async function check() {
  need('PRETIX_TOKEN', 'PRETIX_ORG');
  const org = await request('GET', url(`/organizers/${ORG}`));
  const events = await request('GET', url('events', ['page_size=50']));
  console.log(`✓ ${BASE} · Organizer „${org.name}" (${org.slug}) · ${events.count} Events`);
  for (const e of events.results) {
    const name = typeof e.name === 'object' ? Object.values(e.name)[0] : e.name;
    const state = e.live ? 'live' : 'offline';
    console.log(`  ${e.slug.padEnd(24)} ${state.padEnd(8)}${e.testmode ? 'test ' : '     '}${(e.date_from || '').slice(0, 10)}  ${name}`);
  }
}

async function get(path) {
  need('PRETIX_ORG');
  const query = [...opts.query];
  if (!query.some(q => q.startsWith('page_size='))) query.push('page_size=50');
  let data = await request('GET', url(path, query));
  if (data && Array.isArray(data.results) && !opts.first) {
    const all = [...data.results];
    while (data.next) {
      data = await request('GET', data.next);
      all.push(...data.results);
    }
    data = all;
  } else if (data && Array.isArray(data.results)) {
    data = data.results;
  }
  output(data);
}

function output(data) {
  if (!opts.csv) return console.log(JSON.stringify(data, null, 2));
  const rows = Array.isArray(data) ? data : [data];
  const fields = opts.csv === true ? Object.keys(rows[0] || {}) : opts.csv.split(',');
  const cell = v => {
    if (v === null || v === undefined) return '';
    if (typeof v === 'object') v = Object.keys(v).every(k => /^[a-z]{2}(-[a-z]+)?$/i.test(k)) ? Object.values(v)[0] : JSON.stringify(v);
    const s = String(v);
    return /[",;\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  const pick = (obj, f) => f.split('.').reduce((o, k) => (o == null ? o : o[k]), obj);
  console.log(fields.join(','));
  for (const r of rows) console.log(fields.map(f => cell(pick(r, f))).join(','));
}

function readData() {
  if (opts.data === undefined) return undefined;
  const raw = String(opts.data).startsWith('@') ? readFileSync(opts.data.slice(1), 'utf8') : opts.data;
  try { return JSON.parse(raw); } catch (e) { throw new Error(`--data ist kein gültiges JSON: ${e.message}`); }
}

async function write(method, path) {
  need('PRETIX_ORG');
  const body = readData() ?? {};
  const href = url(path, opts.query);
  if (opts['dry-run']) {
    console.log(`DRY RUN ${method} ${href}\n${JSON.stringify(body, null, 2)}`);
    return;
  }
  const res = await request(method, href, body);
  console.log(JSON.stringify(res, null, 2));
}

async function del(path) {
  need('PRETIX_ORG');
  const href = url(path, opts.query);
  if (!opts.yes) {
    console.log(`Würde löschen: DELETE ${href}\nMit --yes ausführen.`);
    return;
  }
  await request('DELETE', href);
  console.log(`✓ gelöscht: ${href}`);
}

function widget(event) {
  need('PRETIX_ORG');
  if (!event) throw new Error('Event-Slug fehlt');
  const lang = opts.lang || 'de';
  const eventUrl = `${BASE}/${ORG}/${event}/`;
  const attrs = [`event="${eventUrl}"`];
  for (const k of ['subevent', 'items', 'categories', 'voucher', 'list-type', 'display-event-info']) {
    if (typeof opts[k] === 'string') attrs.push(`${k}="${opts[k]}"`);
  }
  for (const k of ['disable-vouchers', 'disable-iframe', 'disable-filters']) {
    if (opts[k]) attrs.push(k);
  }
  const noscript = lang === 'de'
    ? `JavaScript ist deaktiviert. <a target="_blank" rel="noopener" href="${eventUrl}">Ticketshop in neuem Fenster öffnen</a>.`
    : `JavaScript is disabled in your browser. <a target="_blank" rel="noopener" href="${eventUrl}">Open the ticket shop in a new tab</a>.`;
  const tag = opts.button
    ? `<pretix-button ${attrs.join(' ')}>${opts.button === true ? 'Tickets' : opts.button}</pretix-button>`
    : `<pretix-widget ${attrs.join(' ')}></pretix-widget>`;
  console.log(`<!-- in <head> -->
<link rel="stylesheet" type="text/css" href="${eventUrl}widget/v2.css" crossorigin>
<script type="text/javascript" src="${BASE}/widget/v2.${lang}.js" async crossorigin></script>

<!-- an der Einbaustelle -->
${tag}
<noscript>
  <div class="pretix-widget"><div class="pretix-widget-info-message">
    ${noscript}
  </div></div>
</noscript>`);
}
