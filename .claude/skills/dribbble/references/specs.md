# Dribbble specs

Researched October 2026 from search summaries of the official help center and
developer docs. The primary pages could not be fetched directly, so treat
numbers marked *unverified* as likely, and re-check the help center when a
limit actually blocks something. `scripts/dribbble.mjs check` enforces the
verified ones.

## Web uploader (dribbble.com/uploads/new)

| | Limit | Source |
|---|---|---|
| Image types | PNG, JPG, GIF | help.dribbble.com/en/articles/11062601 |
| Image size | 10 MB per file | same |
| Video types | MP4, MOV | same |
| Video size | 20 MB per file | same |
| Width | min. 1600 px recommended | same |
| Aspect ratio | free since 2018; thumbnail is cropped to 4:3 | dribbble.com/stories/2018/08/22 |
| Blocks | image, video, text, gallery | help center |
| Thumbnail | chosen and cropped from any block in "Final Touches" | help center |
| Tags | max. 12 | developer.dribbble.com/v2/shots |
| Title | no max found; aim for 40–70 characters, min. ~15 | help article 11062453 |
| WebP | not listed, do not rely on it | |
| Video duration | *unverified*; old guides say 24 s, keep loops under 20 s | |

**Default canvas: 1600×1200 (4:3), rendered at 2× = 3200×2400.** 4:3 is no
longer required, but the feed thumbnail is 4:3, so a 4:3 first block is the
only shape where thumbnail and detail view show the same composition.

## API v2

Base URL `https://api.dribbble.com/v2`. Auth header
`Authorization: Bearer <token>`.

**OAuth**
- Authorize: `https://dribbble.com/oauth/authorize?client_id=…&redirect_uri=…&scope=public+upload&state=…`
- Token: `POST https://dribbble.com/oauth/token` with `client_id`,
  `client_secret`, `code`, `redirect_uri`. Tokens do not expire.
- Scopes: `public` (read), `upload` (create, update, delete shots). Whether
  `upload` needs approval or a Pro account is *unverified*: if uploads return
  403 with a valid token, that is the likely reason; fall back to the web
  uploader.

**Endpoints used by `scripts/dribbble.mjs`**

| Call | Notes |
|---|---|
| `GET /user` | the authenticated account |
| `GET /user/shots?page=&per_page=` | own shots only |
| `GET /shots/:id` | 404 while a new upload is still processing |
| `POST /shots` | multipart: `image`, `title` (required), `description`, `tags[]`, `team_id`, `low_profile`, `scheduled_for` (ISO 8601, Pro/team only) |
| `PUT /shots/:id` | same fields minus `image`; **tags you omit are removed** |
| `DELETE /shots/:id` | own shots only |
| `GET /user/projects`, `POST /projects` | projects (name, description) |

**`POST /shots` image rules: exactly 400×300 or 800×600, max 8 MB, GIF/JPG/PNG.
No video.** Response is `202 Accepted` with `Location: …/v2/shots/:id`.

**Rate limits:** 60 requests/minute, 1,440/day per user, reported in
`X-RateLimit-Limit`, `-Remaining` and `-Reset`; 429 when exceeded. A monthly
upload quota (48/month, 5/day) is mentioned in old changelogs, *unverified*.

**Not available any more:** popular, recent or search listings, other users'
shots, likes and buckets of others. v2 is a publishing API only.

## Terms that shape the skill

From developer.dribbble.com/terms:
- The API is the only permitted source of Dribbble data; no scraping, copying
  or storing.
- No automated actions on a user's behalf unless the user specifically asked.
- Do not build something that replaces or competes with Dribbble.

Hence: research uses web search and the user's own material, and every
publish action needs explicit confirmation of that specific shot.
