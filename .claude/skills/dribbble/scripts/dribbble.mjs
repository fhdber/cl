#!/usr/bin/env node
/**
 * Dribbble API v2 helper. No dependencies, Node 18+.
 *
 *   node dribbble.mjs auth-url --client-id ID --redirect-uri URI
 *   node dribbble.mjs token --code CODE --client-id ID --client-secret S --redirect-uri URI
 *   node dribbble.mjs me
 *   node dribbble.mjs shots [--page 1]
 *   node dribbble.mjs projects
 *   node dribbble.mjs check <file> [--api]
 *   node dribbble.mjs upload --image F --title T [--description D | --description-file F]
 *                            [--tags "a,b"] [--team-id N] [--low-profile] [--scheduled-for ISO] [--dry-run]
 *   node dribbble.mjs update <id> [--title ..] [--description ..] [--tags ..] [--dry-run]
 *   node dribbble.mjs status <id> [--wait]
 *   node dribbble.mjs delete <id> --yes
 *
 * Token: DRIBBBLE_ACCESS_TOKEN from the environment or a .env file in the
 * current directory. Never pass it on the command line.
 */
import fs from "node:fs";
import path from "node:path";

const API = "https://api.dribbble.com/v2";
const LIMITS = {
  web: { image: 10 * 1024 * 1024, video: 20 * 1024 * 1024, minWidth: 1600 },
  api: { image: 8 * 1024 * 1024, sizes: ["400x300", "800x600"] },
  tags: 12,
};

const [cmd, ...argv] = process.argv.slice(2);
const arg = (n, d) => { const i = argv.indexOf(n); return i > -1 && argv[i + 1] !== undefined ? argv[i + 1] : d; };
const has = (n) => argv.includes(n);
const positional = argv[0] && !argv[0].startsWith("--") ? argv[0] : undefined;
const die = (msg) => { console.error(msg); process.exit(1); };

function token() {
  if (process.env.DRIBBBLE_ACCESS_TOKEN) return process.env.DRIBBBLE_ACCESS_TOKEN;
  const env = path.join(process.cwd(), ".env");
  if (fs.existsSync(env)) {
    const m = fs.readFileSync(env, "utf8").match(/^\s*DRIBBBLE_ACCESS_TOKEN\s*=\s*"?([^"\n]+)"?/m);
    if (m) return m[1].trim();
  }
  die("DRIBBBLE_ACCESS_TOKEN missing. Put it in .env (see .env.example).");
}

async function api(method, route, body) {
  const res = await fetch(API + route, { method, headers: { Authorization: `Bearer ${token()}` }, body });
  const left = res.headers.get("x-ratelimit-remaining");
  if (left !== null && Number(left) < 10) console.error(`rate limit: ${left} requests left`);
  const text = await res.text();
  let data; try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: res.status, location: res.headers.get("location"), data };
}
const fail = (r) => die(`HTTP ${r.status}: ${typeof r.data === "string" ? r.data : JSON.stringify(r.data)}` +
  (r.status === 403 ? "\nToken lacks the upload scope, or the account may not use API uploads. Use the web uploader." : ""));

// --- file inspection --------------------------------------------------------
function dimensions(buf) {
  if (buf.slice(1, 4).toString() === "PNG") return { type: "png", w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
  if (buf.slice(0, 3).toString() === "GIF") return { type: "gif", w: buf.readUInt16LE(6), h: buf.readUInt16LE(8) };
  if (buf[0] === 0xff && buf[1] === 0xd8) {
    let i = 2;
    while (i < buf.length) {
      if (buf[i] !== 0xff) { i++; continue; }
      const marker = buf[i + 1];
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker))
        return { type: "jpg", h: buf.readUInt16BE(i + 5), w: buf.readUInt16BE(i + 7) };
      i += 2 + buf.readUInt16BE(i + 2);
    }
    return { type: "jpg" };
  }
  if (buf.slice(4, 8).toString() === "ftyp") return { type: "video" };
  return { type: "unknown" };
}

function check(file, forApi) {
  if (!fs.existsSync(file)) die(`not found: ${file}`);
  const size = fs.statSync(file).size;
  const d = dimensions(fs.readFileSync(file));
  const problems = [];
  const mb = (n) => `${(n / 1024 / 1024).toFixed(1)} MB`;
  if (d.type === "unknown") problems.push("unsupported type (PNG, JPG, GIF, MP4/MOV only)");
  if (d.type === "video") {
    if (forApi) problems.push("API v2 does not accept video: use the web uploader");
    if (size > LIMITS.web.video) problems.push(`video ${mb(size)} > 20 MB`);
  } else if (forApi) {
    if (!LIMITS.api.sizes.includes(`${d.w}x${d.h}`)) problems.push(`API needs exactly 400x300 or 800x600, got ${d.w}x${d.h} (render with --api)`);
    if (size > LIMITS.api.image) problems.push(`${mb(size)} > 8 MB API limit`);
  } else {
    if (size > LIMITS.web.image) problems.push(`${mb(size)} > 10 MB`);
    if (d.w && d.w < LIMITS.web.minWidth) problems.push(`width ${d.w}px < 1600px recommended`);
    if (d.w && Math.abs(d.w / d.h - 4 / 3) > 0.01) problems.push(`ratio ${d.w}x${d.h} is not 4:3, the thumbnail will crop`);
  }
  return { file, ...d, size: mb(size), target: forApi ? "api" : "web", ok: problems.length === 0, problems };
}

function shotFields(fd) {
  const title = arg("--title");
  let description = arg("--description");
  if (arg("--description-file")) description = fs.readFileSync(arg("--description-file"), "utf8").trim();
  const tags = arg("--tags")?.split(",").map((t) => t.trim().toLowerCase()).filter(Boolean);
  if (tags && tags.length > LIMITS.tags) die(`${tags.length} tags, Dribbble allows ${LIMITS.tags}`);
  const fields = { title, description, tags, team_id: arg("--team-id"), low_profile: has("--low-profile") || undefined, scheduled_for: arg("--scheduled-for") };
  for (const [k, v] of Object.entries(fields)) {
    if (v === undefined) continue;
    if (k === "tags") v.forEach((t) => fd.append("tags[]", t));
    else fd.append(k, String(v));
  }
  return Object.fromEntries(Object.entries(fields).filter(([, v]) => v !== undefined));
}

// --- commands ---------------------------------------------------------------
const out = (x) => console.log(JSON.stringify(x, null, 2));

switch (cmd) {
  case "auth-url": {
    const id = arg("--client-id") || die("--client-id required");
    const u = new URL("https://dribbble.com/oauth/authorize");
    u.searchParams.set("client_id", id);
    if (arg("--redirect-uri")) u.searchParams.set("redirect_uri", arg("--redirect-uri"));
    u.searchParams.set("scope", "public upload");
    u.searchParams.set("state", Math.random().toString(36).slice(2));
    console.log(u.href);
    break;
  }
  case "token": {
    const body = new URLSearchParams({ client_id: arg("--client-id", ""), client_secret: arg("--client-secret", process.env.DRIBBBLE_CLIENT_SECRET || ""), code: arg("--code", "") });
    if (arg("--redirect-uri")) body.set("redirect_uri", arg("--redirect-uri"));
    const res = await fetch("https://dribbble.com/oauth/token", { method: "POST", body });
    const data = await res.json().catch(() => ({}));
    if (!data.access_token) die(`token exchange failed: HTTP ${res.status} ${JSON.stringify(data)}`);
    console.log(`scope: ${data.scope}\nAdd this line to .env (do not paste it into a chat):\nDRIBBBLE_ACCESS_TOKEN=${data.access_token}`);
    break;
  }
  case "me": {
    const r = await api("GET", "/user"); if (r.status !== 200) fail(r);
    const { id, name, login, html_url, pro, followers_count, shots_count } = r.data; out({ id, name, login, html_url, pro, followers_count, shots_count });
    break;
  }
  case "shots": {
    const r = await api("GET", `/user/shots?per_page=30&page=${arg("--page", "1")}`); if (r.status !== 200) fail(r);
    out(r.data.map(({ id, title, html_url, published_at, tags, low_profile }) => ({ id, title, html_url, published_at, tags, low_profile })));
    break;
  }
  case "projects": {
    const r = await api("GET", "/user/projects"); if (r.status !== 200) fail(r);
    out(r.data.map(({ id, name, shots_count }) => ({ id, name, shots_count })));
    break;
  }
  case "check": {
    const res = check(positional || die("file required"), has("--api")); out(res); process.exit(res.ok ? 0 : 2);
  }
  case "upload": {
    const image = arg("--image") || die("--image required");
    if (!arg("--title")) die("--title required");
    const c = check(image, true);
    if (!c.ok) die(`not uploadable through the API:\n- ${c.problems.join("\n- ")}`);
    const fd = new FormData();
    const fields = shotFields(fd);
    if (has("--dry-run")) { out({ dryRun: true, method: "POST /shots", image: c, ...fields }); break; }
    fd.append("image", new Blob([fs.readFileSync(image)], { type: `image/${c.type === "jpg" ? "jpeg" : c.type}` }), path.basename(image));
    const r = await api("POST", "/shots", fd); if (r.status !== 202) fail(r);
    const id = r.location?.split("/").pop();
    console.log(`accepted, processing. shot id: ${id}\nnext: node dribbble.mjs status ${id} --wait`);
    break;
  }
  case "update": {
    const id = positional || die("shot id required");
    const fd = new FormData(); const fields = shotFields(fd);
    if (!Object.keys(fields).length) die("nothing to update");
    // PUT drops every tag it is not sent, so carry the current ones over.
    if (fields.tags === undefined) {
      const cur = await api("GET", `/shots/${id}`); if (cur.status !== 200) fail(cur);
      fields.tags = cur.data.tags || [];
      fields.tags.forEach((t) => fd.append("tags[]", t));
    }
    if (has("--dry-run")) { out({ dryRun: true, method: `PUT /shots/${id}`, ...fields }); break; }
    const r = await api("PUT", `/shots/${id}`, fd); if (r.status >= 300) fail(r);
    out({ id: r.data.id, title: r.data.title, tags: r.data.tags, html_url: r.data.html_url });
    break;
  }
  case "status": {
    const id = positional || die("shot id required");
    for (let i = 0; i < (has("--wait") ? 30 : 1); i++) {
      const r = await api("GET", `/shots/${id}`);
      if (r.status === 200) { out({ id, ready: true, html_url: r.data.html_url, published_at: r.data.published_at }); process.exit(0); }
      if (r.status !== 404) fail(r);
      if (has("--wait")) await new Promise((s) => setTimeout(s, 5000));
    }
    out({ id, ready: false, note: "still processing (404). Try again in a minute." });
    break;
  }
  case "delete": {
    const id = positional || die("shot id required");
    if (!has("--yes")) die("deleting is permanent. Re-run with --yes after the user confirmed this shot.");
    const r = await api("DELETE", `/shots/${id}`); if (r.status !== 204 && r.status !== 200) fail(r);
    console.log(`deleted ${id}`);
    break;
  }
  default:
    die("commands: auth-url, token, me, shots, projects, check, upload, update, status, delete");
}
