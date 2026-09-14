
<div align="center">

<img src="https://vmp.ir/img/VMP.png" width="140">

# VMP Scripts API WEB

### Lightweight & Optimized VMP Resources

<p>
  Developed and maintained by <strong>NEPENTII</strong>
  <img src="https://flagcdn.com/w40/ir.png" width="24" alt="Iran">
</p>

<p>
  <img src="https://img.shields.io/badge/VMP-Scripts-5865F2?style=for-the-badge">
  <img src="https://img.shields.io/badge/API-Server-00C7B7?style=for-the-badge">
  <img src="https://img.shields.io/badge/Developer-NEPENTII-111111?style=for-the-badge">
</p>

</div>

---

## 🚀 Features

| Feature | Description |
|---|---|
| 📦 VMP Scripts | Multiple useful resources for VMP servers |
| 🔌 Server API | API for communication with external applications |
| ⚡ Performance | Lightweight and optimized |
| ⚙️ Configuration | Simple and flexible configuration |
| 🔐 Validation | Server-side validation |
| 🌐 Integration | Designed for external services and web panels |

---

## 🔌 Server API

The repository includes a dedicated **Server API** for communication between the VMP server and external applications.

### Possible integrations

- 🌐 Web Panels
- 🖥️ Websites
- 👤 Player Data
- 📊 Server Statistics
- 🟢 Server Status
- 🔐 Authentication
- 🔗 External Services

---

## 📦 Installation


A single, dynamic, framework-agnostic API resource for a FiveM/VMP game
server: authentication, player identity, sessions, economy/inventory
adapters, and an activity log.

## Install

1. Drop `server-api/` into your `resources/` folder.
2. Edit `config.lua`:
   - Set `Config.Security.otpHashSalt` to a long random string.
   - Add your website's origin to `Config.Api.corsAllowlist`.
   - Leave `Config.Framework` / `Config.Economy` / `Config.Inventory` on
     `'auto'` unless detection picks the wrong resource.
3. `ensure server-api` in `server.cfg`.

## How login works

There is no username/password. A player types `/code` in the in-game chat,
gets a one-time 6-digit code (visible only to them, expires in 2 minutes),
and enters it on your website. The website calls
`POST /api/v1/auth/code/verify` with just `{ "code": "..." }` — the API
resolves which player that belongs to; the browser never sends a player ID.

## Known limitations / things to harden before production

- **Crypto**: `server/crypto.lua` implements OTP generation, hashing, and
  HMAC using only stdlib (FXServer ships no crypto library). It's adequate
  for a game-server threat model (short-lived, single-use, rate-limited
  6-digit codes) but is **not** a substitute for real SHA-256/HMAC-SHA256 if
  you have access to one (e.g. via a natives/FFI-based crypto resource) —
  swap `Crypto.Hash`/`Crypto.Hmac` for that if available.
- **JSON storage** (`server/adapters/storage.lua`) does whole-file
  read/modify/write per collection. Fine for small/medium servers; move to
  a real database by re-implementing the same 2 functions
  (`Read`/`Write`) against it if you outgrow it.
- **OTP brute-force protection** currently relies primarily on the
  per-IP rate limiter (`Config.RateLimit.maxAuthAttemptsPerWindow`), since
  a submitted code is matched by scanning stored hashes rather than being
  tied to a specific player up front. Tighten this further (e.g. a global
  failed-attempt counter with exponential backoff) if you expect targeted
  brute-forcing.
- `Config.Api.corsAllowlist` is empty by default, meaning **no cross-origin
  browser access** until you add your site's origin.

## Endpoints

See `API_DOCUMENTATION.md` for the full endpoint list.


# server-api — Central API Bank

A single, dynamic, framework-agnostic API resource for a FiveM/VMP game
server: authentication, player identity, sessions, economy/inventory
adapters, and an activity log.

## Install

1. Drop `server-api/` into your `resources/` folder.
2. Edit `config.lua`:
   - Set `Config.Security.otpHashSalt` to a long random string.
   - Add your website's origin to `Config.Api.corsAllowlist`.
   - Leave `Config.Framework` / `Config.Economy` / `Config.Inventory` on
     `'auto'` unless detection picks the wrong resource.
3. `ensure server-api` in `server.cfg`.

## How login works

There is no username/password. A player types `/code` in the in-game chat,
gets a one-time 6-digit code (visible only to them, expires in 2 minutes),
and enters it on your website. The website calls
`POST /api/v1/auth/code/verify` with just `{ "code": "..." }` — the API
resolves which player that belongs to; the browser never sends a player ID.

## Known limitations / things to harden before production

- **Crypto**: `server/crypto.lua` implements OTP generation, hashing, and
  HMAC using only stdlib (FXServer ships no crypto library). It's adequate
  for a game-server threat model (short-lived, single-use, rate-limited
  6-digit codes) but is **not** a substitute for real SHA-256/HMAC-SHA256 if
  you have access to one (e.g. via a natives/FFI-based crypto resource) —
  swap `Crypto.Hash`/`Crypto.Hmac` for that if available.
- **JSON storage** (`server/adapters/storage.lua`) does whole-file
  read/modify/write per collection. Fine for small/medium servers; move to
  a real database by re-implementing the same 2 functions
  (`Read`/`Write`) against it if you outgrow it.
- **OTP brute-force protection** currently relies primarily on the
  per-IP rate limiter (`Config.RateLimit.maxAuthAttemptsPerWindow`), since
  a submitted code is matched by scanning stored hashes rather than being
  tied to a specific player up front. Tighten this further (e.g. a global
  failed-attempt counter with exponential backoff) if you expect targeted
  brute-forcing.
- `Config.Api.corsAllowlist` is empty by default, meaning **no cross-origin
  browser access** until you add your site's origin.

## Endpoints

See `API_DOCUMENTATION.md` for the full endpoint list.


# server-api — API Documentation

Base path: `/api/v1`
All responses: `{ "success": true, "data": {...} }` or
`{ "success": false, "error": { "code": "...", "message": "..." } }`

Authenticated routes require `Authorization: Bearer <sessionToken>`.

## Auth

| Method | Path | Auth | Description |
|---|---|---|---|
| POST | `/auth/code/verify` | none | Body `{ "code": "123456" }`. Returns `{ sessionToken, expiresAt, refreshToken, refreshExpiresAt }`. |
| POST | `/auth/code/verify/:code` | none | Same as above, code in the URL — no JSON body/Content-Type header, so no CORS preflight. |
| POST | `/auth/refresh/:refreshToken` | none | One-time use. Returns a new `{ sessionToken, expiresAt, refreshToken, refreshExpiresAt }`; the old refresh token is invalidated. |
| POST | `/auth/logout` | bearer | Revokes the current session token. |
| GET | `/auth/session` | bearer | Confirms the token is valid; returns `{ playerRef, valid }`. |

In-game: players get a code via the `/code` chat command (shown in chat AND as a native notification), not an HTTP route.

## Player (`/me/*`)

| Method | Path | Description |
|---|---|---|
| GET | `/me` | Full profile: playerRef, name, online, source, onlineDuration, lastSeen |
| GET | `/me/status` | `{ online, onlineDuration }` |
| GET | `/me/identifiers` | Identifiers actually available for this player (license/steam/discord/etc — only what's present) |
| GET | `/me/economy` | `{ online, balances }` — balances come from whatever framework is detected; empty if none |
| GET | `/me/inventory` | `{ online, items }` — items come from whatever inventory system is detected; empty if none |
| GET | `/me/sessions` | Paginated (`?limit=&offset=`) join/leave sessions |
| GET | `/me/activity` | Paginated (`?limit=&offset=`) activity/event log entries |

Paginated endpoints return `{ items, total, limit, offset, hasMore }`.

## Events (poll-based)

| Method | Path | Auth | Description |
|---|---|---|---|
| GET | `/events?since=<unix ts>` | bearer | Recent events after `since`, scoped to your own playerRef only. |

Not a real push channel (FXServer's HTTP handler completes a response as soon
as it's sent, so it can't hold an SSE/WebSocket connection open). Poll this
on an interval instead of re-fetching `/me/*` — cheaper, and you get a diff.
Every event that fires a webhook also lands here (see Webhooks below).

## Webhooks

Configure targets in `Config.Webhooks` (config.lua) — each fires a `POST`
(`{ event, timestamp, data }`) on matching events: `otp_verified`,
`player_connected`, `player_disconnected`. Failures are logged and
swallowed, never block the API.

## Health / meta

| Method | Path | Description |
|---|---|---|
| GET | `/server` | `{ serverName, maxPlayers, playerCount, players: [{ source, name }] }` — public, no auth |
| GET | `/health` | `{ status, version, timestamp, metrics }` |
| GET | `/version` | `{ apiVersion, resourceVersion }` |
| GET | `/docs/openapi.json` | Full OpenAPI 3.0 spec of every fixed route (import into Postman/Swagger UI) — raw JSON, not the `{success,data}` envelope |

## Error codes

| Code | Meaning |
|---|---|
| `INVALID_CODE` | OTP wrong or expired |
| `TOO_MANY_ATTEMPTS` | OTP attempt limit hit |
| `INVALID_REFRESH_TOKEN` | Refresh token missing, expired, or already used |
| `UNAUTHORIZED` | Missing/invalid/expired session token |
| `RATE_LIMITED` | Too many requests in the current window |
