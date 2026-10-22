#!/usr/bin/env node
/**
 * Render every <section class="shot" id="..."> of an HTML file to PNG.
 *
 *   node render_shot.mjs shots.html --out shots/ [--scale 2] [--api] [--only mark,system]
 *
 * Writes per shot:
 *   <id>.png        1600x1200 * scale, for the web uploader (JPG if PNG > 10 MB)
 *   <id>-thumb.png  400x300, for the thumbnail test
 *   <id>-api.png    800x600, only with --api (the only large size API v2 accepts)
 */
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { execSync } from "node:child_process";
import { pathToFileURL } from "node:url";

const WEB_MAX = 10 * 1024 * 1024;
const API_MAX = 8 * 1024 * 1024;

// Resolve playwright from the project first, then from a global install.
function loadChromium() {
  const roots = [path.join(process.cwd(), "package.json")];
  try { roots.push(path.join(execSync("npm root -g").toString().trim(), "noop.js")); } catch {}
  for (const root of roots) {
    for (const pkg of ["playwright", "playwright-core"]) {
      try { return createRequire(root)(pkg).chromium; } catch {}
    }
  }
  console.error("Playwright not found. Run `npm i playwright-core` in this folder.");
  process.exit(1);
}

const argv = process.argv.slice(2);
const arg = (n, d) => { const i = argv.indexOf(n); return i > -1 && argv[i + 1] ? argv[i + 1] : d; };
const has = (n) => argv.includes(n);

const input = argv.find((a) => !a.startsWith("--") && /\.html?$/i.test(a));
if (!input) { console.error("usage: render_shot.mjs <file.html> --out <dir> [--scale 2] [--api] [--only a,b]"); process.exit(1); }
const OUT = path.resolve(arg("--out", "shots"));
const SCALE = parseFloat(arg("--scale", "2"));
const ONLY = arg("--only", "")?.split(",").filter(Boolean);
fs.mkdirSync(OUT, { recursive: true });

const chromium = loadChromium();
const browser = await chromium.launch();

async function shoot(scale, suffix, sizeLimit) {
  const page = await browser.newPage({ viewport: { width: 1800, height: 1400 }, deviceScaleFactor: scale });
  await page.goto(pathToFileURL(path.resolve(input)).href, { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts.ready);
  const shots = await page.$$("section.shot[id]");
  const results = [];
  for (const el of shots) {
    const id = await el.getAttribute("id");
    if (ONLY.length && !ONLY.includes(id)) continue;
    let file = path.join(OUT, `${id}${suffix}.png`);
    await el.screenshot({ path: file });
    if (sizeLimit && fs.statSync(file).size > sizeLimit) {
      fs.unlinkSync(file);
      file = path.join(OUT, `${id}${suffix}.jpg`);
      await el.screenshot({ path: file, type: "jpeg", quality: 90 });
    }
    const box = await el.boundingBox();
    results.push({ id, file, w: Math.round(box.width * scale), h: Math.round(box.height * scale), kb: Math.round(fs.statSync(file).size / 1024) });
  }
  await page.close();
  return results;
}

const all = [
  ...(await shoot(SCALE, "", WEB_MAX)),
  ...(await shoot(0.25, "-thumb", 0)),
  ...(has("--api") ? await shoot(0.5, "-api", API_MAX) : []),
];
await browser.close();

if (!all.length) { console.error("No <section class=\"shot\" id=\"...\"> found."); process.exit(1); }
for (const r of all) {
  const warn = r.w / r.h !== 4 / 3 ? "  (not 4:3: thumbnail will crop)" : "";
  const rel = path.relative(process.cwd(), r.file);
  console.log(`${rel.startsWith("..") ? r.file : rel}  ${r.w}x${r.h}  ${r.kb} KB${warn}`);
}
