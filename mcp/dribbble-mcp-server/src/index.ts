#!/usr/bin/env node
/**
 * MCP server for the Dribbble API v2 (stdio).
 *
 * Dribbble's v2 API is a publishing API: it covers the authenticated account,
 * its shots and projects. It has no search or public feeds, so neither does
 * this server.
 */
import fs from "node:fs";
import path from "node:path";
import { McpServer } from "@modelcontextprotocol/server";
import { serveStdio } from "@modelcontextprotocol/server/stdio";
import * as z from "zod/v4";
import { apiRequest } from "./api.js";
import { checkImage, LIMITS } from "./image.js";

const CHARACTER_LIMIT = 25_000;

enum ResponseFormat {
  MARKDOWN = "markdown",
  JSON = "json"
}

const responseFormat = z.enum(ResponseFormat).default(ResponseFormat.MARKDOWN)
  .describe("'markdown' for readable text, 'json' for structured data");

// ---- Upstream shapes (only the fields we use) ----

interface RawShot {
  id: number;
  title: string;
  description: string | null;
  html_url: string;
  published_at: string | null;
  updated_at: string;
  tags: string[];
  low_profile: boolean;
  width: number;
  height: number;
  animated: boolean;
  images?: { hidpi?: string | null; normal?: string; teaser?: string };
  projects?: { id: number; name: string }[];
  team?: { id: number; name: string } | null;
  scheduled_for?: string | null;
}

interface RawUser {
  id: number;
  name: string;
  login: string;
  html_url: string;
  bio?: string;
  location?: string | null;
  pro: boolean;
  followers_count: number;
  can_upload_shot?: boolean;
  teams?: { id: number; name: string; login: string }[];
}

interface RawProject {
  id: number;
  name: string;
  description: string | null;
  shots_count: number;
  created_at: string;
}

const stripHtml = (html: string | null) => (html ?? "").replace(/<br\s*\/?>/gi, "\n").replace(/<\/p>\s*<p>/gi, "\n\n").replace(/<[^>]+>/g, "").trim();

function shotSummary(s: RawShot) {
  return {
    id: s.id,
    title: s.title,
    url: s.html_url,
    published_at: s.published_at,
    scheduled_for: s.scheduled_for ?? null,
    tags: s.tags,
    low_profile: s.low_profile,
    size: `${s.width}x${s.height}`,
    animated: s.animated,
    image: s.images?.hidpi ?? s.images?.normal ?? null,
    projects: (s.projects ?? []).map((p) => p.name),
    team: s.team?.name ?? null
  };
}

function shotMarkdown(s: RawShot, withDescription = false): string {
  const lines = [`## ${s.title} (${s.id})`, `- URL: ${s.html_url}`];
  lines.push(`- Published: ${s.published_at ? s.published_at.slice(0, 10) : s.scheduled_for ? `scheduled for ${s.scheduled_for}` : "not yet"}`);
  lines.push(`- Tags (${s.tags.length}/12): ${s.tags.join(", ") || "none"}`);
  if (s.low_profile) lines.push("- Low profile (hidden from feeds)");
  if (s.projects?.length) lines.push(`- Projects: ${s.projects.map((p) => p.name).join(", ")}`);
  if (withDescription && s.description) lines.push("", stripHtml(s.description));
  return lines.join("\n");
}

const text = (t: string) => ({ content: [{ type: "text" as const, text: t }] });
const json = <T extends Record<string, unknown>>(data: T) => ({
  content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
  structuredContent: data
});

// ---- Shared input fields for create/update ----

const tagsField = z.array(z.string().min(1).max(50)).max(LIMITS.tags)
  .describe("Up to 12 tags, specific to broad, e.g. ['brand identity', 'logo', 'coffee', 'monogram']. Lowercased before sending.");
const descriptionField = z.string().max(5000)
  .describe("Shot description, plain text or simple HTML. 40-120 words work best: context, idea, what the shot shows, one call to action.");
const titleField = z.string().min(1).max(200)
  .describe("Shot title, e.g. 'Nordlicht Coffee: brand identity for a Hamburg roastery'");
const scheduledField = z.string().datetime({ offset: true })
  .describe("ISO 8601 publish time, e.g. '2026-11-03T09:00:00+01:00'. Only Pro and team accounts can schedule.");

function appendShotFields(fd: FormData, f: { title?: string; description?: string; tags?: string[]; team_id?: number; low_profile?: boolean; scheduled_for?: string }) {
  if (f.title !== undefined) fd.append("title", f.title);
  if (f.description !== undefined) fd.append("description", f.description);
  for (const t of f.tags ?? []) fd.append("tags[]", t.trim().toLowerCase());
  if (f.team_id !== undefined) fd.append("team_id", String(f.team_id));
  if (f.low_profile !== undefined) fd.append("low_profile", String(f.low_profile));
  if (f.scheduled_for !== undefined) fd.append("scheduled_for", f.scheduled_for);
}

// ---- Server factory ----

function createServer(): McpServer {
  const server = new McpServer({ name: "dribbble-mcp-server", version: "1.0.0" });

  server.registerTool(
    "dribbble_get_user",
    {
      title: "Get Dribbble account",
      description: "Get the Dribbble account the access token belongs to: name, login, profile URL, Pro status, follower count, teams and whether it may upload shots. Call this first to confirm the token works and which teams exist for team_id.",
      inputSchema: z.strictObject({ response_format: responseFormat }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true }
    },
    async ({ response_format }, ctx) => {
      const { data: u } = await apiRequest<RawUser>("GET", "/user", ctx.mcpReq.signal);
      const user = {
        id: u.id, name: u.name, login: u.login, url: u.html_url, pro: u.pro,
        followers: u.followers_count, can_upload_shot: u.can_upload_shot ?? null,
        location: u.location ?? null, teams: (u.teams ?? []).map((t) => ({ id: t.id, name: t.name }))
      };
      if (response_format === ResponseFormat.JSON) return json(user);
      return text([
        `# ${u.name} (@${u.login})`, `- Profile: ${u.html_url}`, `- Pro: ${u.pro ? "yes" : "no"}`,
        `- Followers: ${u.followers_count}`, `- Can upload shots: ${u.can_upload_shot ?? "unknown"}`,
        ...(user.teams.length ? [`- Teams: ${user.teams.map((t) => `${t.name} (${t.id})`).join(", ")}`] : [])
      ].join("\n"));
    }
  );

  server.registerTool(
    "dribbble_list_shots",
    {
      title: "List my Dribbble shots",
      description: `List the authenticated account's own shots, newest first, with ID, title, URL, publish date and tags.

Dribbble's API cannot list other people's shots, popular shots or search results.
Use dribbble_get_shot for a single shot with its full description.`,
      inputSchema: z.strictObject({
        page: z.number().int().min(1).default(1).describe("Page number, starting at 1"),
        per_page: z.number().int().min(1).max(100).default(30).describe("Shots per page, max 100"),
        response_format: responseFormat
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true }
    },
    async ({ page, per_page, response_format }, ctx) => {
      const { data } = await apiRequest<RawShot[]>("GET", `/user/shots?page=${page}&per_page=${per_page}`, ctx.mcpReq.signal);
      const hasMore = data.length === per_page;
      if (data.length === 0) return text(page === 1 ? "This account has no shots yet." : `No shots on page ${page}.`);

      const render = (shots: RawShot[]) => {
        const result = { page, count: shots.length, has_more: hasMore || shots.length < data.length, ...(hasMore ? { next_page: page + 1 } : {}), shots: shots.map(shotSummary) };
        if (response_format === ResponseFormat.JSON) return { result, out: JSON.stringify(result, null, 2) };
        const lines = [`# My shots, page ${page}`, "", shots.map((s) => shotMarkdown(s)).join("\n\n")];
        if (shots.length < data.length) lines.push("", `Output shortened to ${shots.length} shots. Call again with a smaller per_page.`);
        else if (hasMore) lines.push("", `More shots: call again with page=${page + 1}.`);
        return { result, out: lines.join("\n") };
      };
      let shots = data;
      let r = render(shots);
      while (shots.length > 1 && r.out.length > CHARACTER_LIMIT) {
        shots = shots.slice(0, Math.ceil(shots.length / 2));
        r = render(shots);
      }
      return response_format === ResponseFormat.JSON ? json(r.result) : text(r.out);
    }
  );

  server.registerTool(
    "dribbble_get_shot",
    {
      title: "Get a Dribbble shot",
      description: "Get one of your shots by ID, including the full description. Also the way to check whether a new upload has finished processing: it returns 'still processing' until the shot is live, then the shot with its URL.",
      inputSchema: z.strictObject({
        shot_id: z.number().int().positive().describe("Shot ID, from dribbble_list_shots or dribbble_create_shot"),
        response_format: responseFormat
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true }
    },
    async ({ shot_id, response_format }, ctx) => {
      let shot: RawShot;
      try {
        ({ data: shot } = await apiRequest<RawShot>("GET", `/shots/${shot_id}`, ctx.mcpReq.signal));
      } catch (e) {
        if ((e as { status?: number }).status === 404) {
          return text(`Shot ${shot_id} is not available yet. If it was just uploaded, Dribbble is still processing it: check again in a minute. If it persists, the ID is wrong or the shot was deleted.`);
        }
        throw e;
      }
      if (response_format === ResponseFormat.JSON) return json({ ...shotSummary(shot), description: stripHtml(shot.description) });
      return text(shotMarkdown(shot, true));
    }
  );

  server.registerTool(
    "dribbble_check_image",
    {
      title: "Check an image against Dribbble limits",
      description: `Check a local image or video file against Dribbble's limits before posting. Works without a token.

target='api': what dribbble_create_shot accepts (PNG/JPG/GIF, exactly 800x600 or 400x300, max 8 MB, no video).
target='web': the web uploader (images up to 10 MB, video up to 20 MB, 1600px+ wide, 4:3 so the thumbnail is not cropped).
Returns ok=true or a list of problems with fixes.`,
      inputSchema: z.strictObject({
        file_path: z.string().min(1).describe("Absolute path to the file, e.g. '/Users/me/shots/mark-api.png'"),
        target: z.enum(["api", "web"]).default("api").describe("Which upload path to check against")
      }),
      outputSchema: z.object({
        path: z.string(), type: z.string(), width: z.number().optional(), height: z.number().optional(),
        size_mb: z.number(), target: z.string(), ok: z.boolean(), problems: z.array(z.string())
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false }
    },
    async ({ file_path, target }) => json({ ...checkImage(path.resolve(file_path), target) })
  );

  server.registerTool(
    "dribbble_create_shot",
    {
      title: "Upload a Dribbble shot",
      description: `Publish a new shot from a local image. Posting is public, so this runs as a dry run by default: it validates the file and returns the exact payload without sending anything.

Workflow: call with dry_run=true (default), show the user the payload, and only after they confirm this specific shot call again with dry_run=false.
The API only takes PNG/JPG/GIF at exactly 800x600 or 400x300, max 8 MB. Video, multi-image shots and larger images need the web uploader at https://dribbble.com/uploads/new.
Dribbble processes uploads asynchronously: the result gives the new shot_id; poll dribbble_get_shot until it is live.`,
      inputSchema: z.strictObject({
        image_path: z.string().min(1).describe("Absolute path to the image file"),
        title: titleField,
        description: descriptionField.optional(),
        tags: tagsField.optional(),
        team_id: z.number().int().positive().optional().describe("Post on behalf of a team you belong to (IDs from dribbble_get_user)"),
        low_profile: z.boolean().optional().describe("true keeps the shot out of feeds; only people with the link or on your profile see it"),
        scheduled_for: scheduledField.optional(),
        dry_run: z.boolean().default(true).describe("true (default): validate and preview only. false: actually publish. Set false only after the user confirmed.")
      }),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true }
    },
    async ({ image_path, dry_run, ...fields }, ctx) => {
      const file = path.resolve(image_path);
      const check = checkImage(file, "api");
      if (!check.ok) {
        return { isError: true, content: [{ type: "text" as const, text: `Not uploadable through the API:\n- ${check.problems.join("\n- ")}` }] };
      }
      const payload = { image: { path: file, size: `${check.width}x${check.height}`, size_mb: check.size_mb }, ...fields, tags: fields.tags?.map((t) => t.trim().toLowerCase()) };
      if (dry_run) {
        return json({ dry_run: true, would_send: "POST /v2/shots", payload, next_step: "Show this to the user. After they confirm, call again with dry_run=false." });
      }
      const fd = new FormData();
      const mime = check.type === "jpg" ? "image/jpeg" : `image/${check.type}`;
      fd.append("image", new Blob([fs.readFileSync(file)], { type: mime }), path.basename(file));
      appendShotFields(fd, fields);
      const res = await apiRequest<null>("POST", "/shots", ctx.mcpReq.signal, fd);
      const shotId = Number(res.location?.split("/").pop());
      return json({
        accepted: true,
        shot_id: Number.isFinite(shotId) ? shotId : null,
        status: "processing",
        next_step: "Call dribbble_get_shot with this shot_id in about a minute to get the live URL.",
        rate_limit_remaining: res.rateRemaining
      });
    }
  );

  server.registerTool(
    "dribbble_update_shot",
    {
      title: "Edit a Dribbble shot",
      description: `Change the title, description, tags, team, low-profile flag or schedule of one of your shots. The image cannot be replaced.

Dribbble's PUT removes every tag it is not sent, so when tags is omitted this tool re-sends the shot's current tags. When tags is given, it replaces the full list.
Runs as a dry run by default and shows before/after; call again with dry_run=false after the user confirms.`,
      inputSchema: z.strictObject({
        shot_id: z.number().int().positive().describe("Shot ID"),
        title: titleField.optional(),
        description: descriptionField.optional(),
        tags: tagsField.optional(),
        team_id: z.number().int().positive().optional().describe("Move the shot to a team you belong to"),
        low_profile: z.boolean().optional(),
        scheduled_for: scheduledField.optional(),
        dry_run: z.boolean().default(true).describe("true (default): preview the change. false: apply it.")
      }),
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: true }
    },
    async ({ shot_id, dry_run, ...changes }, ctx) => {
      if (Object.values(changes).every((v) => v === undefined)) {
        return { isError: true, content: [{ type: "text" as const, text: "Nothing to change. Pass at least one of title, description, tags, team_id, low_profile, scheduled_for." }] };
      }
      const { data: current } = await apiRequest<RawShot>("GET", `/shots/${shot_id}`, ctx.mcpReq.signal);
      const fields = { ...changes, tags: changes.tags ?? current.tags };
      const before = { title: current.title, description: stripHtml(current.description), tags: current.tags, low_profile: current.low_profile };
      const after = { ...before, ...fields, ...(fields.description !== undefined ? { description: fields.description } : {}) };
      if (dry_run) return json({ dry_run: true, would_send: `PUT /v2/shots/${shot_id}`, before, after, next_step: "Show this to the user. After they confirm, call again with dry_run=false." });

      const fd = new FormData();
      appendShotFields(fd, fields);
      const { data: updated } = await apiRequest<RawShot>("PUT", `/shots/${shot_id}`, ctx.mcpReq.signal, fd);
      return json({ updated: true, shot: shotSummary(updated) });
    }
  );

  server.registerTool(
    "dribbble_delete_shot",
    {
      title: "Delete a Dribbble shot",
      description: "Permanently delete one of your shots, including its likes and comments. This cannot be undone. Only call after the user explicitly asked to delete this shot; pass its ID twice (shot_id and confirm_shot_id) as confirmation.",
      inputSchema: z.strictObject({
        shot_id: z.number().int().positive().describe("Shot ID to delete"),
        confirm_shot_id: z.number().int().positive().describe("The same ID again, to confirm the user asked for this deletion")
      }),
      annotations: { readOnlyHint: false, destructiveHint: true, idempotentHint: true, openWorldHint: true }
    },
    async ({ shot_id, confirm_shot_id }, ctx) => {
      if (shot_id !== confirm_shot_id) {
        return { isError: true, content: [{ type: "text" as const, text: "shot_id and confirm_shot_id differ. Nothing was deleted." }] };
      }
      await apiRequest<null>("DELETE", `/shots/${shot_id}`, ctx.mcpReq.signal);
      return text(`Shot ${shot_id} deleted.`);
    }
  );

  server.registerTool(
    "dribbble_list_projects",
    {
      title: "List my Dribbble projects",
      description: "List the account's projects (groups of shots) with ID, name, description and shot count.",
      inputSchema: z.strictObject({
        page: z.number().int().min(1).default(1).describe("Page number, starting at 1"),
        per_page: z.number().int().min(1).max(100).default(30).describe("Projects per page"),
        response_format: responseFormat
      }),
      annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: true }
    },
    async ({ page, per_page, response_format }, ctx) => {
      const { data } = await apiRequest<RawProject[]>("GET", `/user/projects?page=${page}&per_page=${per_page}`, ctx.mcpReq.signal);
      const projects = data.map((p) => ({ id: p.id, name: p.name, description: stripHtml(p.description), shots: p.shots_count }));
      const hasMore = data.length === per_page;
      if (response_format === ResponseFormat.JSON) return json({ page, count: projects.length, has_more: hasMore, projects });
      if (!projects.length) return text(page === 1 ? "No projects yet. Create one with dribbble_create_project." : `No projects on page ${page}.`);
      return text([`# My projects, page ${page}`, "", ...projects.map((p) => `- **${p.name}** (${p.id}), ${p.shots} shots${p.description ? `: ${p.description}` : ""}`), ...(hasMore ? ["", `More: call again with page=${page + 1}.`] : [])].join("\n"));
    }
  );

  server.registerTool(
    "dribbble_create_project",
    {
      title: "Create a Dribbble project",
      description: "Create a project to group a shot series, e.g. all shots of one brand identity. Visible on the public profile, so confirm the name with the user first.",
      inputSchema: z.strictObject({
        name: z.string().min(1).max(100).describe("Project name, e.g. 'Nordlicht Coffee'"),
        description: z.string().max(1000).optional().describe("Short project description")
      }),
      annotations: { readOnlyHint: false, destructiveHint: false, idempotentHint: false, openWorldHint: true }
    },
    async ({ name, description }, ctx) => {
      const fd = new FormData();
      fd.append("name", name);
      if (description) fd.append("description", description);
      const { data } = await apiRequest<RawProject>("POST", "/projects", ctx.mcpReq.signal, fd);
      return json({ created: true, id: data.id, name: data.name });
    }
  );

  return server;
}

serveStdio(createServer);
console.error("dribbble-mcp-server running on stdio");
