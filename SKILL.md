---
name: apivault
description: >-
  Integrate with ApiVault for encrypted API key management. Covers the remote
  MCP server (OAuth, scoped tools for list/get/reveal/add/update/delete keys)
  and the apivault CLI (browser login, keys CRUD, secret injection via run,
  dotenv export). Use when the user mentions ApiVault, apivault, apivault-cli,
  vault secrets, MCP server for API keys, apivault run, secret injection,
  Cursor/Claude MCP integration, or managing encrypted credentials for AI
  agents and developers. Prefer MCP inside IDE agents; prefer CLI for terminal
  workflows and process injection.
---

# ApiVault

ApiVault is a secure API key vault with two integration surfaces:

| Surface | Best for | Auth |
|---------|----------|------|
| **MCP server** | AI agents in Cursor, Claude Desktop, and other MCP clients | OAuth (browser approval, scoped tokens) |
| **CLI** (`apivault`) | Terminal workflows, CI scripts, injecting secrets into local processes | Browser connect flow (`apivault login`) |

Production endpoint: `https://apivault.tech`

Website: [apivault.tech](https://apivault.tech) · CLI Repo: [github.com/TLB-STATION/apivault](https://github.com/TLB-STATION/apivault)

Both surfaces talk to ApiVault **over HTTP only**. Never import ApiVault server code, touch Prisma, or access the database directly.

---

## Security Principles

Apply these in every workflow:

1. **Least privilege** — request only the MCP scopes needed; use masked `list_keys` / `get_key` before calling `reveal_key`.
2. **No secret leakage** — do not paste revealed values into chat, commits, logs, or issue trackers. Inject secrets via env vars or local files the user controls.
3. **Never commit** - `~/.apivault/`, exported `.env` files, tokens, or vault keys.
4. **Separate credentials** — MCP tokens and CLI tokens are independent; revoking one does not revoke the other.
5. **Custom vault mode** - when the user enables custom encryption, a `vault_key` is required for reveal/write operations and **cannot be recovered** if forgotten.

---

## MCP Server (AI Agents)

Remote MCP with OAuth. Ideal when an agent needs to browse or manage vault keys from inside an IDE.

### Setup

Use the `add-mcp` CLI to configure ApiVault MCP automatically across your tools:

```bash
npx -y add-mcp https://mcp.apivault.tech/mcp -g
```

Or add directly to your client config (Cursor, Claude Desktop, Windsurf):

```json
{
  "mcpServers": {
    "apivault": {
      "url": "https://mcp.apivault.tech/mcp"
    }
  }
}
```

On first use, the client opens a browser for OAuth approval. The user selects scopes and approves access.

### Authentication

If tools return an auth error or the server status is `needsAuth`:

1. Follow the MCP client's OAuth flow (reconnect the server or use the client's auth tool if provided).
2. User approves scopes in the browser.
3. Retry the intended tool.

Manage and revoke connections in ApiVault → **Settings → MCP Connections**.

### OAuth Scopes

| Scope | Permission |
|-------|------------|
| `keys:read` | List and view masked key metadata |
| `keys:write` | Create, update, and delete keys |
| `keys:reveal` | Decrypt and return raw secret values |

Request the minimum scopes required for the task.

### Tools

Discover schemas with MCP tool inspection before calling. Summary:

| Tool | Scope | Purpose |
|------|-------|---------|
| `list_keys` | `keys:read` | List keys (masked). Optional filters: `environment`, `service` |
| `get_key` | `keys:read` | Single key metadata by `id` (masked) |
| `reveal_key` | `keys:reveal` | Decrypt secret. Args: `id`, optional `vault_key` |
| `add_key` | `keys:write` | Create key. Required: `name`, `key`. Optional: `service`, `environment`, `notes`, `vault_key` |
| `update_key` | `keys:write` | Update metadata or value. Args: `id` + fields to change, optional `vault_key` when changing value |
| `delete_key` | `keys:write` | Permanently delete by `id` |

### MCP Workflow Patterns

**Find a key for an integration task**

1. `list_keys` with `environment` filter (e.g. `"Production"`)
2. `get_key` to confirm the correct `id`
3. Only if the raw secret is required: `reveal_key` — then use it immediately in env/config, not in chat

**Add a new credential**

1. Confirm scope includes `keys:write`
2. `add_key` with `name`, `key`, `service`, `environment`
3. Pass `vault_key` when the vault uses custom encryption

**Handle errors**

| Code | Meaning | Action |
|------|---------|--------|
| `INSUFFICIENT_SCOPE` | Token lacks required scope | Re-authenticate with broader scopes or use a different tool |
| `NOT_FOUND` | Key id invalid | Re-list keys |
| `DUPLICATE_KEY` | Key name already exists in this environment | Choose a unique name, change environment, or update existing key |
| `VAULT_KEY_REQUIRED` | Custom encryption; vault key needed | Pass `vault_key` |
| `INVALID_VAULT_KEY` | Wrong vault key | Retry with correct key |

For OAuth endpoints, token TTLs, and protocol details, see [references/mcp.md](references/mcp.md).

---

## CLI (`apivault`)

Terminal client for developers.

**Install (recommended):**

```bash
npm install -g apivault
apivault --version
```

**On-demand (no install):** `npx apivault <command>`

**Standalone script installers:**
- macOS / Linux: `curl -fsSL https://apivault.tech/install.sh | sh`
- Windows (PowerShell): `irm https://apivault.tech/install.ps1 | iex`

**From source:** [github.com/TLB-STATION/apivault](https://github.com/TLB-STATION/apivault)

```bash
git clone https://github.com/TLB-STATION/apivault.git
cd apivault
npm install && npm run build
npm install -g .
```

Development without global install: `npm run dev -- <command>`

### Requirements

- Node.js >= 18.17
- Reachable ApiVault server

### First-Time Auth

```bash
apivault login            # browser Approve/Refuse; default timeout 300s
apivault whoami           # verify session
apivault logout           # revoke token
```

Local state: `~/.apivault/` (`%USERPROFILE%\.apivault\` on Windows)

| File | Purpose |
|------|---------|
| `token.json` | CLI auth token |
| `config.json` | Defaults: `run.env`, `run.command`, `vaultKey` |

### Command Reference

Global flags: `--json`, `--timeout <seconds>`, `-V/--version`, `-h/--help`

```bash
# Keys
apivault keys list
apivault keys get <id> [--reveal] [--vault-key <vault_key>]
apivault keys add [--name --service --environment --key --notes] [--vault-key <vault_key>]
apivault keys update <id>                    # interactive only
apivault keys delete <id> [-f]

# Run — inject secrets into a child process (preferred for local dev)
apivault run --env <env> [--vault-key <vault_key>] -- <command> [args...]
apivault run                                 # uses config defaults

# Config
apivault config list | get <key> | set <key> [value] | delete <key>
# Valid keys: run.command, run.env, vaultKey

# Dotenv files
apivault env export --env <env> [-o path] [--force] [--vault-key <vault_key>]
apivault env restore [-C <project-dir>]
```

### Resolution Precedence

| Setting | Order (first wins) |
|---------|-------------------|
| Environment | `--env` → `config run.env` → error |
| Run command | args after `--` → `config run.command` → error |
| Vault key | `--vault-key` → `APIVAULT_KEY` env → `config vaultKey` → prompt |

`APIVAULT_KEY` applies to reveal, add, update, run, and env export. On `keys add`, `--key` is the API secret value; `--vault-key` is the vault key.

### CLI Workflow Patterns

**Run app without writing secrets to disk**

```bash
apivault config set run.env Production
apivault config set run.command "npm start"
apivault run
```

`run` temporarily renames local `.env*` files to `*.apivault-run-hidden`. Restores on exit. If restore fails: `apivault env restore`.

**Export for frameworks that require dotenv files**

```bash
apivault env export --env Production
apivault env export --env Staging -o .env.local --force
```

**Scripting**

```bash
apivault --json keys list
apivault --json keys get <id> --reveal
```

For HTTP routes, config schema, and CLI internals, see [references/cli.md](references/cli.md).

---

## CLI vs MCP — Decision Guide

| Task | Use |
|------|-----|
| Agent needs to look up or manage keys during a coding session | **MCP** |
| User wants secrets injected into `npm start` / local dev server | **CLI** `run` |
| CI/CD pipeline or shell script | **CLI** with `--json` |
| Export `.env` for Docker / Next.js / Vite | **CLI** `env export` |
| User asks to connect ApiVault to an MCP client | **MCP** setup |
| Revoke AI agent access | ApiVault **Settings → MCP Connections** |
| Revoke terminal access | `apivault logout` |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| MCP tools unavailable | Not authenticated | Reconnect apivault MCP server; complete OAuth in browser |
| `INSUFFICIENT_SCOPE` | Token missing scope | Re-connect with required scopes |
| CLI HTTP 401 | Not logged in | `apivault login` |
| `VAULT_KEY_REQUIRED` | Custom encryption vault | Provide `vault_key` / `--vault-key` / `APIVAULT_KEY` |
| Secrets not loading in `run` | Wrong environment or no keys | Check `list_keys` / `keys list` for environment name |
| `.env` files missing after `run` | Interrupted restore | `apivault env restore` |
| PowerShell strips `--` | Shell parsing | CLI falls back to remaining args; quote command if needed |
| Local dev against self-hosted ApiVault | Compiled server URL | Change `API_BASE_URL` in CLI `src/config.ts`, rebuild |

---

## Development

**CLI repo** — key scripts: `npm run dev`, `npm run build`, `npm run typecheck`

**ApiVault server** — MCP implementation: `src/mcp/server.ts`, route: `src/app/mcp/route.ts`

Local MCP base URL: set `MCP_BASE_URL` env on the ApiVault server.
