---
name: dribbble
description: >
  Turn brand, identity, UI and motion work into Dribbble shots, from start to
  posted. Plan a shot series from a project, compose 4:3 shot canvases as HTML
  and render them to PNG, write titles, descriptions and tags that rank in
  Dribbble search, upload, update or schedule shots through the Dribbble API v2,
  and research what the Dribbble field already looks like for a topic so the
  work can stand apart from it. Use whenever the user mentions Dribbble, a
  "shot", "Dribbble post", "Dribbble portfolio", "Dribbble upload", "Dribbble
  Beschreibung", "Shot-Titel", tags for Dribbble, presenting a logo or brand
  identity as a showcase image, "what's trending on Dribbble", or wants to
  publish design work to a design community, even if they do not name the
  platform explicitly but describe a 4:3 portfolio presentation image.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# dribbble

A Dribbble shot is not a portfolio page. It is one frame that has to work twice:
as a 4:3 thumbnail in a feed of hundreds, where it gets under a second, and as a
detail page someone opens because the thumbnail made a promise. Search drives
over 80% of what people see on Dribbble, so the words around the image decide
whether anyone sees the thumbnail at all.

The skill has four modes. Most requests touch more than one; run them in this
order and skip what the request does not need:

| Mode | When | Output |
|---|---|---|
| **1. Research** | before a series, or "what does Dribbble look like for X" | field brief: patterns, gaps, a position |
| **2. Produce** | user has a project and wants shots | shot plan + rendered PNGs |
| **3. Copy** | always alongside Produce, or on its own | title, description, tags per shot |
| **4. Publish** | user wants it on Dribbble | API upload, or a ready-to-paste upload sheet |

Talk to the user in their language. Write shot copy in English unless they ask
otherwise: Dribbble search and its audience are international, and a German
title finds German searchers only.

Exact platform limits (file sizes, tag count, API image sizes) live in
`references/specs.md`. Read it before rendering or uploading, because the web
uploader and the API accept very different files.

---

## Mode 1: Research

Goal: know the visual default of the category before designing against it. A
shot that looks like the top ten results for "fintech logo" disappears among
them.

Dribbble's developer terms forbid scraping, and API v2 can no longer list or
search other people's shots. So never crawl dribbble.com with scripts. Use, in
this order:

1. **Material the user gives you**: screenshots, saved collections, URLs they
   paste. Read images directly; they are the best evidence.
2. **Web search** for `site:dribbble.com <topic>` and Dribbble "Stories"
   articles. Search result titles and snippets show how the field names and
   tags its work.
3. **Curated reference tools**, if connected: the Details MCP
   (`search_inspirations`) or the `image-deep-research` skill for open-licence
   images and moodboards.

Then write the field brief using `references/research.md`. Its core is three
lines the user can act on: **what everyone does**, **what nobody does**, and
**where this project sits**. Name concrete visual moves (gradient blob mascot,
logo on 3D-rendered business card, bento grid of brand assets), not adjectives.

## Mode 2: Produce

### Plan the series first

One project rarely fits one shot. Plan 3–6 shots that each answer a single
question, then post them over weeks rather than in one dump. The default
series for brand identity work:

1. **Mark**: the logo alone, large, on the brand's own colour. Answers: what is it?
2. **Idea**: the concept behind the mark (grid, sketch-to-final, symbol origin).
3. **System**: colour, type, pattern and secondary elements as one grid.
4. **Applications**: 2–3 real touchpoints (signage, packaging, app icon, social).
5. **Motion** (optional): logo animation or system in motion, as MP4.
6. **Case study** (optional): a long multi-block shot combining 1–4 with text.

Adapt it: for UI work swap in key screen, flow, component detail; for type
design swap in specimen, glyph detail, in-use. Present the plan as a short
table (shot, question it answers, layout, assets needed) and confirm it before
rendering, since this is where the user's judgement matters most.

### Compose

Build shots as HTML from `assets/shot-template.html`. It is a token-driven
1600×1200 canvas with layouts for each series step (`mark`, `idea`, `system`,
`applications`, `split`, `specimen`). Copy it next to the user's assets, set the
brand tokens on `:root`, drop in the real files, delete the sections you do not
need. `references/composition.md` explains each layout and the rules that
make thumbnails read; skim it before the first shot.

The rules that matter most, because they are where shots usually fail:

- **Thumbnail test.** Every shot must read at 400×300. One focal point, large.
  Fine detail belongs in later blocks of a multi-block shot, not the thumbnail.
- **Brand colour as background, not white.** A full-bleed brand colour is what
  makes a thumbnail recognisable in a grid.
- **Real assets only.** Use the user's logo files, photos and mockups. Never
  invent a logo, a client name or a fake brand. If an asset is missing, leave
  a labelled placeholder and list it in your reply.
- **No interface chrome.** No fake browser bars, no "Dribbble" watermark, no
  "01/05" counters unless the series really is numbered.
- **Quiet text.** At most a short label in the image. The explanation goes in
  the description, where search can read it.

### Render

```bash
node <skill>/scripts/render_shot.mjs shots.html --out shots/ --scale 2
```

Each `<section class="shot" id="...">` becomes `shots/<id>.png`. `--scale 2`
gives 3200×2400 for the web uploader; the script re-encodes to JPG if a PNG
goes over the 10 MB limit. Add `--api` to also write 800×600 copies, the only
size API v2 accepts. Always view the rendered PNGs yourself (Read the file)
and check the thumbnail test at small size before showing the user.

For motion, render the frames or use the user's own export; check it with
`scripts/dribbble.mjs check file.mp4` (20 MB limit). Motion shots can only be
posted through the web uploader.

## Mode 3: Copy

Write per shot: **title**, **description**, **12 tags max**. Formulas, examples
and a tag strategy are in `references/copy.md`. In short:

- **Title** says what it is and for whom: `Nordlicht Coffee: brand identity for
  a Hamburg roastery`. Not `Exploration 03`, not emoji.
- **Description** is a short project summary: context, the idea, what is shown,
  one line of call-to-action. 40–120 words. Keywords appear in natural sentences.
- **Tags** go from specific to broad: discipline, deliverable, industry, style,
  tool. Only what is actually in the image; stuffing gets shots dropped from
  categories.

Deliver copy as a block the user can paste, one per shot.

## Mode 4: Publish

Two paths. Pick by what the shot is:

- **Web uploader** (dribbble.com/uploads/new): needed for video, GIFs over
  8 MB, multi-block case studies, and anything larger than 800×600. Produce an
  **upload sheet**: file order, thumbnail choice, title, description, tags,
  schedule. This is the default for most brand work.
- **API v2** (`scripts/dribbble.mjs`): single-image shots at exactly 800×600 or
  400×300, scripted edits of titles and tags, scheduling, listing own shots.

If the `dribbble` MCP server is connected (tools named `dribbble_*`, source in
`mcp/dribbble-mcp-server`), prefer its tools over the script: same API, same
dry-run-first behaviour (`dry_run` defaults to true), and `dribbble_update_shot`
keeps existing tags automatically.

API setup, once: the user registers an app at dribbble.com/account/applications,
gets an access token with `public upload` scope, and puts it in `.env` as
`DRIBBBLE_ACCESS_TOKEN`. Never ask them to paste the token into the chat;
`node scripts/dribbble.mjs auth-url` and `token --code ...` walk the OAuth
flow locally if they only have client ID and secret.

```bash
node <skill>/scripts/dribbble.mjs me
node <skill>/scripts/dribbble.mjs check shots/mark-api.png
node <skill>/scripts/dribbble.mjs upload --image shots/mark-api.png \
  --title "..." --description-file mark.md --tags "brand identity,logo" --dry-run
```

Posting is public and outward-facing, and Dribbble's terms only allow actions
the user specifically asked for. So: always run `--dry-run` first, show the user
the exact payload, and only send the real upload, update or delete after they
confirm that specific shot. `delete` also requires `--yes`. Uploads return
`202 Accepted` and process asynchronously; use `status <id>` to wait for the
live URL, then give the user the link.

---

## Done looks like

- Research: a field brief with the three lines, sources listed.
- Produce: the shot plan, rendered PNGs you have looked at, a list of missing
  assets if any.
- Copy: paste-ready title, description, tags per shot.
- Publish: either a live shot URL per upload, or an upload sheet, plus a
  posting schedule (1–2 shots a week, case study last).

Keep the reply short: show the shots, the copy, and one or two proactive
suggestions (a stronger thumbnail crop, a shot the series is missing), not a
recap of the process.
