/**
 * Self-check: runs the built server over stdio against a local mock of the
 * Dribbble API and exits non-zero on any failure. No real token or network.
 * Run with: npm run build && npm run smoke
 */
import { strict as assert } from "node:assert";
import fs from "node:fs";
import http from "node:http";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/client";
import { getDefaultEnvironment, StdioClientTransport } from "@modelcontextprotocol/client/stdio";

const here = path.dirname(fileURLToPath(import.meta.url));
const fixture = path.join(here, "fixture-800x600.png");

// A PNG header that claims 1000x1000: enough for the size check to reject it
const wrongSize = path.join(os.tmpdir(), "dribbble-smoke-1000.png");
const header = Buffer.alloc(33);
Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]).copy(header);
header.writeUInt32BE(1000, 16);
header.writeUInt32BE(1000, 20);
fs.writeFileSync(wrongSize, header);

// ---- Mock Dribbble API ----
const shot = {
  id: 42, title: "Nordlicht Coffee: logo", description: "<p>Tide line mark.</p>", html_url: "https://dribbble.com/shots/42",
  published_at: "2026-10-01T09:00:00Z", updated_at: "2026-10-01T09:00:00Z", tags: ["logo", "coffee"], low_profile: false,
  width: 800, height: 600, animated: false, images: { normal: "https://cdn/42.png" }, projects: [], team: null
};
const calls: string[] = [];
const mock = http.createServer((req, res) => {
  let body = "";
  req.on("data", (c) => (body += c));
  req.on("end", () => {
    calls.push(`${req.method} ${req.url}`);
    if (req.headers.authorization !== "Bearer test-token") { res.writeHead(401).end("{}"); return; }
    const send = (status: number, data: unknown, headers: Record<string, string> = {}) => {
      res.writeHead(status, { "content-type": "application/json", "x-ratelimit-remaining": "59", ...headers });
      res.end(data === null ? "" : JSON.stringify(data));
    };
    if (req.method === "GET" && req.url === "/user") return send(200, { id: 1, name: "Florian", login: "florian", html_url: "https://dribbble.com/florian", pro: true, followers_count: 10, can_upload_shot: true, teams: [] });
    if (req.method === "GET" && req.url?.startsWith("/user/shots")) return send(200, [shot]);
    if (req.method === "GET" && req.url === "/shots/42") return send(200, shot);
    if (req.method === "GET" && req.url === "/shots/99") return send(404, { message: "Not found" });
    if (req.method === "POST" && req.url === "/shots") {
      assert.ok(body.includes('name="image"'), "upload must carry the image");
      assert.ok(body.includes('name="tags[]"'), "upload must carry tags[]");
      return send(202, null, { location: "https://api.dribbble.com/v2/shots/99" });
    }
    if (req.method === "PUT" && req.url === "/shots/42") {
      assert.ok(body.includes("coffee"), "update without tags must re-send the current tags");
      return send(200, { ...shot, title: "New title" });
    }
    if (req.method === "DELETE" && req.url === "/shots/42") return send(204, null);
    if (req.method === "GET" && req.url?.startsWith("/user/projects")) return send(200, [{ id: 7, name: "Nordlicht", description: null, shots_count: 3, created_at: "2026-01-01" }]);
    send(404, { message: "unknown route" });
  });
});
await new Promise<void>((r) => mock.listen(0, "127.0.0.1", r));
const port = (mock.address() as { port: number }).port;

const client = new Client({ name: "smoke-test", version: "1.0.0" });
await client.connect(new StdioClientTransport({
  command: "node",
  args: [path.join(here, "..", "dist", "index.js")],
  env: { ...getDefaultEnvironment(), DRIBBBLE_ACCESS_TOKEN: "test-token", DRIBBBLE_API_BASE_URL: `http://127.0.0.1:${port}` }
}));

const call = (name: string, args: Record<string, unknown>) => client.callTool({ name, arguments: args });
const textOf = (r: Awaited<ReturnType<typeof call>>) => (r.content as { text: string }[])[0].text;

const { tools } = await client.listTools();
assert.deepEqual(tools.map((t) => t.name).sort(), [
  "dribbble_check_image", "dribbble_create_project", "dribbble_create_shot", "dribbble_delete_shot",
  "dribbble_get_shot", "dribbble_get_user", "dribbble_list_projects", "dribbble_list_shots", "dribbble_update_shot"
]);

let r = await call("dribbble_get_user", {});
assert.ok(!r.isError && textOf(r).includes("@florian"), textOf(r));

r = await call("dribbble_list_shots", { response_format: "json" });
assert.equal((r.structuredContent as { shots: unknown[] }).shots.length, 1);

r = await call("dribbble_check_image", { file_path: fixture });
assert.equal((r.structuredContent as { ok: boolean }).ok, true, textOf(r));
r = await call("dribbble_check_image", { file_path: wrongSize });
assert.equal((r.structuredContent as { ok: boolean }).ok, false);

// Dry run is the default and must not hit the API
const before = calls.length;
r = await call("dribbble_create_shot", { image_path: fixture, title: "Nordlicht Coffee: logo", tags: ["Logo", "coffee"] });
assert.ok(textOf(r).includes('"dry_run": true') && textOf(r).includes('"logo"'), textOf(r));
assert.equal(calls.length, before, "dry run must not call the API");

r = await call("dribbble_create_shot", { image_path: wrongSize, title: "x", dry_run: false });
assert.equal(r.isError, true, "wrong size must be refused before upload");

r = await call("dribbble_create_shot", { image_path: fixture, title: "Nordlicht Coffee: logo", tags: ["logo"], dry_run: false });
assert.equal((r.structuredContent as { shot_id: number }).shot_id, 99, textOf(r));

r = await call("dribbble_get_shot", { shot_id: 99 });
assert.ok(textOf(r).includes("still processing"), textOf(r));

r = await call("dribbble_update_shot", { shot_id: 42, title: "New title" });
assert.ok(textOf(r).includes('"dry_run": true'));
r = await call("dribbble_update_shot", { shot_id: 42, title: "New title", dry_run: false });
assert.ok(!r.isError, textOf(r));

r = await call("dribbble_delete_shot", { shot_id: 42, confirm_shot_id: 43 });
assert.equal(r.isError, true);
r = await call("dribbble_delete_shot", { shot_id: 42, confirm_shot_id: 42 });
assert.ok(!r.isError && textOf(r).includes("deleted"), textOf(r));

r = await call("dribbble_list_projects", {});
assert.ok(textOf(r).includes("Nordlicht"));

r = await call("dribbble_create_shot", { image_path: fixture, title: "x", tags: Array(13).fill("t") });
assert.equal(r.isError, true, "13 tags must be rejected");

await client.close();
mock.close();
console.error("Smoke test passed");
