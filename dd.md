@ -1,55 +1,48 @@
<div align="center">

<img src="https://vmp.ir/img/VMP.png" width="140">

# VMP Scripts API WEB

### Lightweight & Optimized VMP Resources

Developed and maintained by **NEPENTII**

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

Clone the repository:

```bash
git clone https://github.com/NEPENTII/vmp-script
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