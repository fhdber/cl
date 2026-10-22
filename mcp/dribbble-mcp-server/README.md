# dribbble-mcp-server

MCP server for the Dribbble API v2. It lets Claude (or any MCP client) read your
account, list and edit your shots, upload new ones and manage projects.

Dribbble's v2 API is a publishing API: it only covers your own account. There
is no search, no popular feed and no access to other people's shots, so this
server has none either.

## Tools

| Tool | What it does | Changes data |
|---|---|---|
| `dribbble_get_user` | Account, Pro status, teams, upload permission | no |
| `dribbble_list_shots` | Your shots, paginated | no |
| `dribbble_get_shot` | One shot with description; tells you when a new upload is live | no |
| `dribbble_check_image` | Checks a local file against API or web-uploader limits (no token needed) | no |
| `dribbble_create_shot` | Uploads an image as a new shot. **Dry run by default** | yes |
| `dribbble_update_shot` | Title, description, tags, team, low profile, schedule. Keeps tags you don't touch. **Dry run by default** | yes |
| `dribbble_delete_shot` | Deletes a shot; needs the ID twice | yes |
| `dribbble_list_projects` | Your projects | no |
| `dribbble_create_project` | New project for a shot series | yes |

**API limits to know:** uploads must be PNG, JPG or GIF at exactly **800×600 or
400×300**, max 8 MB. Video, multi-image case studies and large images only work
through the web uploader. The `dribbble` skill in `.claude/skills/dribbble`
renders the matching 800×600 copies (`render_shot.mjs --api`).

## Setup

1. Create an app at https://dribbble.com/account/applications and generate an
   access token with the scopes `public upload`.
2. Build the server:
   ```bash
   cd mcp/dribbble-mcp-server && npm install && npm run build
   ```
3. Provide the token as `DRIBBBLE_ACCESS_TOKEN`:
   - **Claude Code** in this repo: `.mcp.json` at the repo root already
     registers the server and reads the variable from your shell
     (`export DRIBBBLE_ACCESS_TOKEN=...`).
   - **Claude Desktop**: add to `claude_desktop_config.json`:
     ```json
     {
       "mcpServers": {
         "dribbble": {
           "command": "node",
           "args": ["/absolute/path/to/mcp/dribbble-mcp-server/dist/index.js"],
           "env": { "DRIBBBLE_ACCESS_TOKEN": "your-token" }
         }
       }
     }
     ```

## Develop

```bash
npm run build && npm run smoke   # runs every tool against a local mock API
npx @modelcontextprotocol/inspector node dist/index.js
```

Unverified: whether Dribbble requires Pro or approval for the `upload` scope.
If uploads return 403 with a valid token, that is the likely cause.
