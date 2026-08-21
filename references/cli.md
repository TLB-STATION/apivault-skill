# ApiVault CLI — Reference

## Local Configuration

Directory: `~/.apivault/` (Windows: `%USERPROFILE%\.apivault\`)

### config.json

```json
{
  "run": {
    "command": "npm start",
    "env": "Production"
  },
  "vaultKey": "your-custom-vault-key"
}
```

Valid config keys: `run.command`, `run.env`, `vaultKey`

Unix file permissions: `0600` for `token.json` and `config.json`.

### token.json

```json
{
  "apiToken": "...",
  "email": "user@example.com",
  "name": "User Name",
  "createdAt": "2026-01-01T00:00:00.000Z"
}
```

## Environment Variables

| Variable | Used by | Purpose |
|----------|---------|---------|
| `APIVAULT_KEY` | reveal, add, update, run, env export | Custom vault encryption key |
| `NO_COLOR` | UI | Disable terminal colors |
| `FORCE_COLOR=0` | UI | Disable terminal colors |

## Server URL

Compiled into the CLI at build time:

```
src/config.ts → API_BASE_URL
```

Default: `https://apivault.tech`

Change and rebuild for local or self-hosted development. Not user-configurable at runtime.

## HTTP API (CLI & Backend)

| Action | Method | Route | Description |
|--------|--------|-------|-------------|
| Login start | POST | `/api/cli/request` | Create one-time CLI pairing request |
| Login poll | POST | `/api/cli/status` | Poll pairing status with requestToken |
| Logout | DELETE | `/api/cli/token` | Revoke CLI API token |
| Whoami | GET | `/api/cli/me` | Return authenticated user metadata |
| List keys | GET | `/api/keys` | List keys with masked preview |
| Filter keys | GET | `/api/keys?environment=<env>` | Filter keys by environment (or `&service=`) |
| Add key | POST | `/api/keys` | Create single encrypted key |
| Bulk import | POST | `/api/keys/bulk` | Batch import `.env` keys atomically |
| Update key | PUT | `/api/keys/:id` | Update metadata or encrypted value |
| Delete key | DELETE | `/api/keys/:id` | Delete key permanently |
| Decrypt | POST | `/api/keys/:id/decrypt` | Decrypt and return raw secret |

Decrypt / Write request headers:

```
Authorization: Bearer <apiToken>
X-Vault-Key: <vault_key>    # when custom encryption enabled
```

## Standalone Install Scripts

- **macOS / Linux:** `curl -fsSL https://apivault.tech/install.sh | sh`
- **Windows (PowerShell):** `irm https://apivault.tech/install.ps1 | iex`

Installs standalone Node runtime bundle into `~/.local/share/apivault` and links binary without requiring npm or sudo.

## Login Flow

1. `POST /api/cli/request` → `{ requestId, requestToken, expiresAt }`
2. Browser opens to connect page (`/cli/connect?rid=<requestId>`)
3. User approves or refuses
4. CLI polls `POST /api/cli/status { requestToken }`
5. On approval → token saved to `token.json`

## apivault run Internals

1. Fetch keys: `GET /api/keys?environment=<env>`
2. Decrypt each key (prompt for vault key if needed)
3. Rename `.env`, `.env.local`, `.env.*` → `*.apivault-run-hidden`
4. Build env from decrypted keys; set `__NEXT_PROCESSED_ENV=true` for Next.js
5. Spawn child via `cross-spawn` (no shell — Windows `.cmd` compatible)
6. Restore hidden dotenv files on exit or SIGINT/SIGTERM

Empty environment: warning only; command runs without injected secrets.

## env export Internals

1. Fetch and decrypt keys for environment
2. **Error** if zero keys (stricter than `run`)
3. Parse existing output file if present
4. Merge by default; `--force` replaces entirely
5. Write header comment; `0600` permissions on Unix

## keys add (Non-Interactive)

```bash
apivault keys add \
  --name "Stripe Production" \
  --service stripe \
  --environment Production \
  --key "sk_live_..." \
  --notes "Main account" \
  --vault-key "your-vault-key"
```

On `keys add`, `--key` is the **API secret value**; `--vault-key` is the vault key.

## CLI Error Codes

| Code / Status | Meaning |
|---------------|---------|
| HTTP 401 | Not signed in |
| HTTP 0 | Network / connectivity failure |
| `DUPLICATE_KEY` / HTTP 409 | A key with this name already exists in this environment |
| `VAULT_KEY_REQUIRED` | Custom encryption; vault key needed |
| `INVALID_VAULT_KEY` | Wrong vault key |

## Source Layout (apivault-cli)

```
apivault-cli/
├── src/
│   ├── index.ts              # Commander entry
│   ├── config.ts             # API_BASE_URL, persistence
│   ├── connect.ts            # login, logout, whoami
│   ├── http.ts               # ApiClient, ApiError
│   ├── run-env.ts            # dotenv hide/restore
│   ├── env-file.ts           # parse/merge .env
│   ├── commands/
│   │   ├── keys.ts
│   │   ├── run.ts
│   │   ├── config.ts
│   │   └── env.ts
│   └── ui/format.ts          # colors, tables, JSON
├── dist/cli.js
└── package.json              # bin: apivault
```

## Build Scripts

| Script | Command | Purpose |
|--------|---------|---------|
| `dev` | `tsx src/index.ts` | Run without build |
| `build` | `tsup` | Bundle to `dist/cli.js` |
| `typecheck` | `tsc --noEmit` | TypeScript validation |

Requirements: Node.js >= 18.17
