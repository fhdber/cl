#!/usr/bin/env node
// getty-scout: builds Getty/iStock search links and, with GETTY_API_KEY,
// fetches results into a de-duplicated contact sheet. No dependencies.

import fs from 'node:fs';
import path from 'node:path';

const API = 'https://api.gettyimages.com/v3';
const AUTH = 'https://authentication.gettyimages.com/oauth2/token';
const FIELDS = 'id,title,caption,artist,collection_name,display_set,max_dimensions,license_model,date_created';

// ---------- args ----------
function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith('--')) out[key] = true;
      else { out[key] = next; i++; }
    } else out._.push(a);
  }
  return out;
}

// ---------- env ----------
function loadEnv() {
  for (const dir of [process.cwd(), path.resolve(process.cwd(), '..')]) {
    const f = path.join(dir, '.env');
    if (!fs.existsSync(f)) continue;
    for (const line of fs.readFileSync(f, 'utf8').split('\n')) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
      if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
    break;
  }
}

// ---------- query normalisation ----------
function normalise(q) {
  let phrase = String(q.phrase || '').trim();
  if (!phrase) throw new Error(`Query "${q.label || '?'}" hat keine phrase.`);
  if (q.exclude) {
    const ex = String(q.exclude).split(',').map(s => s.trim()).filter(Boolean);
    phrase += ' ' + ex.map(e => `-${e.replace(/\s+/g, '-')}`).join(' ');
  }
  return {
    label: q.label || phrase,
    phrase,
    family: q.family || 'creative',
    orientation: q.orientation,
    composition: q.composition,
    people: q.people,
    sort: q.sort || 'best',
    style: q.style,
    color: q.color ? String(q.color).replace('#', '') : undefined,
    age: q.age,
  };
}

const list = v => (v ? String(v).split(',').map(s => s.trim()).filter(Boolean) : []);
const webVal = v => v.replace(/_/g, '');
const WEB_SORT = { best: 'best', best_match: 'best', most_popular: 'mostpopular', newest: 'newest', random: 'best' };

// ---------- web links ----------
function webUrl(q, site = 'getty', locale = 'de') {
  const host = site === 'istock'
    ? (locale === 'com' ? 'https://www.istockphoto.com' : 'https://www.istockphoto.com/de')
    : (locale === 'com' ? 'https://www.gettyimages.com' : 'https://www.gettyimages.de');
  const p = new URLSearchParams();
  p.set('phrase', q.phrase);
  if (site !== 'istock') p.set('family', q.family);
  p.set('sort', WEB_SORT[q.sort] || 'best');
  if (q.orientation) p.set('orientations', list(q.orientation).map(webVal).join(','));
  if (q.composition) p.set('compositions', list(q.composition).map(webVal).join(','));
  if (q.people) p.set('numberofpeople', q.people);
  return `${host}/search/2/image?${p.toString()}`;
}

function sites(opt) {
  const s = opt || 'getty';
  return s === 'both' ? ['getty', 'istock'] : [s];
}

// ---------- api ----------
async function authHeaders() {
  const key = process.env.GETTY_API_KEY;
  if (!key) return null;
  const h = { 'Api-Key': key, Accept: 'application/json' };
  const secret = process.env.GETTY_API_SECRET;
  if (secret) {
    const body = new URLSearchParams({ grant_type: 'client_credentials', client_id: key, client_secret: secret });
    const r = await fetch(AUTH, { method: 'POST', body, headers: { 'Content-Type': 'application/x-www-form-urlencoded' } });
    if (!r.ok) throw new Error(`OAuth fehlgeschlagen: ${r.status} ${await r.text()}`);
    h.Authorization = `Bearer ${(await r.json()).access_token}`;
  }
  return h;
}

async function apiGet(url, headers) {
  const r = await fetch(url, { headers });
  if (!r.ok) throw new Error(`Getty API ${r.status}: ${(await r.text()).slice(0, 300)}`);
  return r.json();
}

function apiSearchUrl(q, pageSize) {
  const p = new URLSearchParams();
  p.set('phrase', q.phrase);
  p.set('fields', FIELDS);
  p.set('page_size', String(pageSize));
  p.set('sort_order', q.sort === 'best' ? 'best_match' : q.sort);
  if (q.orientation) p.set('orientations', list(q.orientation).join(','));
  if (q.composition) p.set('compositions', list(q.composition).join(','));
  if (q.people) p.set('number_of_people', q.people);
  if (q.style) p.set('graphical_styles', q.style);
  if (q.color) p.set('color', q.color);
  if (q.age) p.set('age_of_people', q.age);
  return `${API}/search/images/${q.family === 'editorial' ? 'editorial' : 'creative'}?${p}`;
}

function slim(img) {
  const sizes = Object.fromEntries((img.display_sizes || []).map(d => [d.name, d.uri]));
  return {
    id: img.id,
    title: img.title,
    artist: img.artist,
    collection: img.collection_name,
    license: img.license_model,
    max: img.max_dimensions ? `${img.max_dimensions.width}×${img.max_dimensions.height}` : '',
    thumb: sizes.preview || sizes.comp || sizes.thumb,
    comp: sizes.comp || sizes.preview,
    page: `https://www.gettyimages.de/detail/${img.id}`,
  };
}

// ---------- output ----------
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function linksMd(brief, queries, siteList, locale) {
  const lines = [`# Getty-Suche${brief ? ` – ${brief}` : ''}`, ''];
  for (const q of queries) {
    lines.push(`## ${q.label}`, '', `\`${q.phrase}\``, '');
    for (const s of siteList) lines.push(`- [${s === 'istock' ? 'iStock' : 'Getty'}](${webUrl(q, s, locale)})`);
    lines.push('');
  }
  return lines.join('\n');
}

function contactSheet(brief, groups) {
  const artistCount = {};
  for (const g of groups) for (const i of g.images) artistCount[i.artist] = (artistCount[i.artist] || 0) + 1;
  const sections = groups.map(g => `
  <section>
    <h2>${esc(g.label)} <small>${esc(g.phrase)} · ${g.total ?? '?'} Treffer</small></h2>
    <div class="grid">${g.images.map(i => `
      <a class="card" href="${esc(i.page)}" target="_blank" rel="noopener">
        <img loading="lazy" src="${esc(i.thumb)}" alt="${esc(i.title)}">
        <span class="id">${esc(i.id)}${artistCount[i.artist] > 1 ? ' <b title="Mehrere Treffer dieses Fotografen – Serienpotenzial">◆</b>' : ''}</span>
        <span class="meta">${esc(i.artist)} · ${esc(i.license || '')} · ${esc(i.max)}</span>
      </a>`).join('')}
    </div>
  </section>`).join('\n');
  return `<!doctype html><html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Getty Kontaktbogen</title>
<style>
:root{--bg:#f6f5f2;--fg:#151515;--mute:#777;--card:#fff}
@media (prefers-color-scheme:dark){:root{--bg:#111;--fg:#eee;--mute:#999;--card:#1b1b1b}}
body{margin:0;padding:32px 16px;background:var(--bg);color:var(--fg);font:14px/1.4 system-ui,sans-serif}
h1{font-size:20px;margin:0 0 4px}h1+p{color:var(--mute);margin:0 0 32px}
h2{font-size:15px;margin:32px 0 12px}h2 small{color:var(--mute);font-weight:400}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px}
.card{display:flex;flex-direction:column;background:var(--card);text-decoration:none;color:inherit}
.card img{width:100%;aspect-ratio:3/2;object-fit:cover;background:#ddd}
.id{padding:6px 8px 0;font-weight:600}.id b{color:#c60}
.meta{padding:0 8px 8px;color:var(--mute);font-size:12px}
</style></head><body>
<h1>Kontaktbogen</h1><p>${esc(brief || '')} · ◆ = Fotograf mehrfach vertreten (Serienpotenzial)</p>
${sections}
</body></html>`;
}

// ---------- commands ----------
async function cmdPlan(file, args) {
  const plan = JSON.parse(fs.readFileSync(file, 'utf8'));
  const defaults = plan.defaults || {};
  const queries = (plan.queries || []).map(q => normalise({ ...defaults, ...q }));
  if (!queries.length) throw new Error('Plan enthält keine queries.');
  const siteList = sites(args.site || plan.site);
  const locale = args.locale || plan.locale || 'de';
  const outDir = path.resolve(args.out || path.dirname(path.resolve(file)));
  fs.mkdirSync(outDir, { recursive: true });

  const md = linksMd(plan.brief, queries, siteList, locale);
  fs.writeFileSync(path.join(outDir, 'links.md'), md);
  console.log(md);
  console.log(`→ ${path.join(outDir, 'links.md')}`);

  if (args['links-only']) return;
  const headers = await authHeaders();
  if (!headers) {
    console.log('\nKein GETTY_API_KEY gesetzt – nur Links erzeugt.');
    return;
  }

  const pageSize = Number(args.n || plan.page_size || 24);
  const seen = new Set();
  const groups = [];
  try {
    for (const q of queries) {
      const data = await apiGet(apiSearchUrl(q, pageSize), headers);
      const images = (data.images || []).map(slim).filter(i => !seen.has(i.id) && seen.add(i.id));
      groups.push({ label: q.label, phrase: q.phrase, total: data.result_count, images });
      console.log(`${q.label}: ${data.result_count} Treffer, ${images.length} neu`);
    }
  } catch (e) {
    console.log(`\nAPI nicht erreichbar (${e.cause?.code || e.message}). Die Links oben funktionieren trotzdem.`);
    if (!groups.length) return;
  }
  fs.writeFileSync(path.join(outDir, 'results.json'), JSON.stringify({ brief: plan.brief, groups }, null, 2));
  fs.writeFileSync(path.join(outDir, 'contact-sheet.html'), contactSheet(plan.brief, groups));
  console.log(`→ ${path.join(outDir, 'contact-sheet.html')}`);
}

function cmdUrl(args) {
  if (!args.phrase) throw new Error('--phrase fehlt.');
  const q = normalise(args);
  for (const s of sites(args.site)) console.log(webUrl(q, s, args.locale || 'de'));
}

async function cmdSimilar(id, args) {
  if (!id) throw new Error('Asset-ID fehlt.');
  const headers = await authHeaders();
  if (!headers) throw new Error('similar braucht GETTY_API_KEY. Ohne API: auf der Detailseite "Ähnliche Bilder" nutzen.');
  const data = await apiGet(`${API}/images/${encodeURIComponent(id)}/similar?fields=${FIELDS}&page_size=${args.n || 30}`, headers);
  const images = (data.images || []).map(slim);
  const outDir = path.resolve(args.out || '.');
  fs.mkdirSync(outDir, { recursive: true });
  const file = path.join(outDir, `similar-${id}.html`);
  fs.writeFileSync(file, contactSheet(`Ähnlich zu ${id}`, [{ label: `Ähnlich zu ${id}`, phrase: '', total: data.result_count, images }]));
  console.log(`${images.length} ähnliche Bilder → ${file}`);
}

const HELP = `getty-scout
  plan <plan.json> [--out dir] [--site getty|istock|both] [--locale de|com] [--links-only] [--n 24]
  url --phrase "…" [--orientation …] [--composition …] [--people …] [--sort …] [--family …] [--exclude a,b] [--site …]
  similar <asset-id> [--out dir] [--n 30]`;

async function main() {
  loadEnv();
  const args = parseArgs(process.argv.slice(2));
  const [cmd, arg] = args._;
  if (cmd === 'plan') return cmdPlan(arg, args);
  if (cmd === 'url') return cmdUrl(args);
  if (cmd === 'similar') return cmdSimilar(arg, args);
  console.log(HELP);
  if (cmd && cmd !== 'help') process.exitCode = 1;
}

main().catch(e => { console.error(`Fehler: ${e.message}`); process.exit(1); });
