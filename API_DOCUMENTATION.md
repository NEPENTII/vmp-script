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
