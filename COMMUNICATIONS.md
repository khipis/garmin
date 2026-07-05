# Communications — in-app messages & announcements

A small, owner-configurable messaging layer built into the **shared leaderboard**
module (`_shared/leaderboard`). It lets you push short, contextual messages to
players **without rebuilding any app**: you edit them server-side and every game
picks them up on its next launch.

Typical uses:

- **Support ask** after a game — "Enjoying Bitochi? Buy me a coffee ☕" with a link.
- **Cross-promotion** before a game — "Check out my other games" (+ a link to bitochi.com).
- **Season reset** re-engagement — auto-shown once after you wipe a leaderboard.
- **Paid-version invite** for tools without a leaderboard (e.g. `breathtrainingtool`
  → *Breath Training System*).

The player's rank engagement ("YOU #12 / 4,300 · +40 to next") is **already** shown
by the post-game leaderboard pop-up (`LbScoresView`) and is *not* part of this
message system — the two complement each other.

---

## 1. Concepts

Every message has:

| Field        | Meaning |
|--------------|---------|
| `scope`      | `global` (applies to every game) or `game` (only `game`) |
| `game`       | game id, required when `scope = game` (e.g. `slotbandit`) |
| `placement`  | **when** it shows: `launch`, `postgame`, or `reset` |
| `title`      | short headline (≤ 60 chars) |
| `body`       | message text, word-wrapped on the watch (≤ 200 chars) |
| `url`        | optional link, opened on the paired **phone** via Garmin Connect |
| `url_label`  | button caption for the link (e.g. "Buy me a coffee") |
| `weight`     | tie-breaker — higher wins when several messages match a placement |
| `min_gap_s`  | client throttle: don't re-show sooner than this many seconds |
| `active`     | `0` disables without deleting |
| `starts_at` / `ends_at` | optional unix-ms window for time-limited campaigns |

### Placements

- **`launch`** — shown once per session when a game's **main menu** appears
  (throttled by `min_gap_s`). Good for cross-promo and paid-version invites.
- **`postgame`** — shown after a run ends, layered **on top of** the leaderboard
  pop-up (throttled). Good for the support/tip ask.
- **`reset`** — shown **once** after the player's board was wiped since they last
  played (see [reset detection](#4-reset-detection)). Not throttled by time; it
  fires a single time per reset. Good for "New season!" re-engagement.

### Selection rules (server-side)

For a given game the server returns **one** message per placement:

1. Only `active = 1` messages inside their optional `starts_at`/`ends_at` window.
2. Messages whose `scope = global` **or** whose `scope = game AND game = <this game>`.
3. **Game-scoped beats global** for the same placement; then higher `weight`; then
   newest.

So a per-game message always overrides the global default for that placement.

---

## 2. Data model (D1)

Two tables (see `leaderboard/schema.sql`):

- **`messages`** — the configured messages (fields above).
- **`resets`** — one row per leaderboard wipe (`game` = `NULL` means a global,
  all-games reset). Written automatically by `POST /reset`.

Apply the schema / migration:

```bash
cd leaderboard
wrangler d1 execute garmin-leaderboard --file=schema.sql --remote
```

Seed the sensible defaults (idempotent — safe to re-run):

```bash
wrangler d1 execute garmin-leaderboard --file=seed-messages.sql --remote
```

The seed creates: a global **post-game** support/Buy-Me-a-Coffee card, a global
**launch** "more free games" card, a global **reset** "New season!" card, and a
per-game **launch** invite for `breathtrainingtool`.

---

## 3. API endpoints (Cloudflare Worker)

| Method & path                | Auth | Purpose |
|------------------------------|------|---------|
| `GET /messages?game=<id>`    | none | **Client bundle** for one game (see below). Cached ~2 min. |
| `GET /messages?all=1`        | none | Every row — used by the `stats.html` admin editor. |
| `POST /messages`             | `X-LB-Key` | Create (no `id`) or update (`id` present). |
| `DELETE /messages`           | `X-LB-Key` | Delete by `{ id }`. |

The **client bundle** is deliberately tiny:

```jsonc
{
  "ts": 1717000000,
  "reset_at": 1716900000000,     // ms of the latest reset affecting this game (0 = none)
  "launch":   { "id":2, "title":"…", "body":"…", "url":null, "url_label":null, "min_gap_s":86400 },
  "postgame": { "id":1, "title":"…", "body":"…", "url":"https://…", "url_label":"Buy me a coffee", "min_gap_s":43200 },
  "reset":    { "id":3, "title":"New season!", "body":"…", "url":null, "url_label":null, "min_gap_s":0 }
}
```

Any slot may be `null` if nothing is configured.

---

## 4. Client behaviour

Code lives in `_shared/leaderboard/LbMessages.mc` (views + fetcher) and
`_shared/leaderboard/Leaderboard.mc` (public API). All state is stored per-app in
`Application.Storage`:

| Key                     | Meaning |
|-------------------------|---------|
| `lb_msg_cache`          | last fetched bundle (a `Dictionary`) |
| `lb_msg_fetch`          | unix-sec of the last successful fetch |
| `lb_msg_reset_ack`      | the `reset_at` value already acknowledged |
| `lb_msg_shown_<place>`  | unix-sec a placement was last shown (throttle) |

### Fetch-then-show (why messages appear from the *previous* session)

`Leaderboard.logLaunch(game)` (already called in every game's `App.onStart`) now
**also** fetches the bundle in the background and caches it. Showing a message
reads the **cached** bundle — from the previous session — so the UI never blocks
on the network at startup. This run's fetch simply refreshes the cache for next
time. On a brand-new install the cache is empty, so nothing shows unless you pass
a **fallback** (below).

### Throttling

Each placement is throttled by its `min_gap_s`: a launch/post-game message won't
re-appear until that many seconds have passed since it was last shown. `reset`
ignores time and fires once per reset event.

### Reset detection

On show, the client compares the bundle's `reset_at` with the locally stored
`lb_msg_reset_ack`:

- If `reset_at > ack` → show the `reset` message once, then store `ack = reset_at`.
- On a fresh install (`ack == 0`) it records the baseline and stays silent — a
  first-time player is never told about a reset they didn't live through.

### Public API

```monkeyc
// Fire-and-forget fetch (auto-called by logLaunch; rarely needed directly).
Leaderboard.fetchMessages(game);

// Show the message for a placement if cached & due (throttled). `fallback` is an
// optional {title,body,url,url_label,min_gap_s} used when nothing is cached yet.
Leaderboard.showMessage(game, Leaderboard.MSG_LAUNCH, fallback);   // "launch"
Leaderboard.showMessage(game, Leaderboard.MSG_POSTGAME, null);     // "postgame"

// Show the reset message once if the board was wiped since last time.
Leaderboard.showResetMessageIfAny(game);

// Convenience: reset message first, else the launch message. Call when the main
// menu becomes visible.
Leaderboard.announce(game, fallback);
```

The message card view opens `url` on the paired phone via
`Communications.openWebPage` when the player presses **SELECT** (falls back to
doing nothing on watches that lack it); **BACK** closes it.

---

## 5. Integrating a game (recipe)

Most leaderboard games need **zero** changes for the `postgame` support message —
it's shown automatically by `Leaderboard.showPostGame(...)`, which every game
already calls at game-over.

To add the **launch / reset** announcement, call `announce` once when the menu
appears (guard with a per-session flag):

```monkeyc
// In your menu View.onShow():
if (!_announced && inMenuState) {
    _announced = true;
    Leaderboard.announce("slotbandit", null);
}
```

### Games *without* a leaderboard (e.g. breathtrainingtool)

They can still use messages — they just need:

1. `Communications` permission in `manifest.xml`.
2. The shared module on the jungle sourcePath:
   `base.sourcePath = source;../_shared/leaderboard`
3. `Leaderboard.logLaunch("<gameid>")` in `App.onStart` (fetches the bundle).
4. `Leaderboard.announce("<gameid>", fallback)` when the home screen shows.

For these, pass a **fallback** so the message works offline / on first run even
before anything is cached; the server config (matched by `<gameid>`) overrides it
once fetched. Example from `breathtrainingtool`:

```monkeyc
Leaderboard.announce("breathtrainingtool", {
    "title"     => "Go deeper with PRO",
    "body"      => "Loving this tool? Breath Training System adds a coach, adaptive plans and progression. Find it on the Connect IQ Store.",
    "url"       => "https://apps.garmin.com/apps/bitochi",
    "url_label" => "Get the System",
    "min_gap_s" => 172800
});
```

---

## 6. Editing messages (no rebuild)

Open **`stats.html`** → the **✉️ Messages** panel:

- The table lists all configured messages (filter by *Global* / *Per-game*).
- **➕ Add message** opens an inline form; **✎** edits, **✕** deletes.
- *Min gap* is entered in **hours** in the UI and stored as seconds.
- Writes require your `LB_KEY` (prompted once, then cached in the tab's
  `sessionStorage` for the session).

Changes take effect the next time each game launches and refreshes its cache
(the `GET /messages` response is edge-cached ~2 minutes).

---

## 7. Worked examples

**Global support ask (post-game).**
scope `global`, placement `postgame`, title *"Enjoying Bitochi?"*, url
`https://buymeacoffee.com/bitochi`, label *"Buy me a coffee"*, gap `12h`.

**Promote your catalogue (launch).**
scope `global`, placement `launch`, title *"More free games"*, body listing
bitochi.com, url `https://bitochi.com`, gap `24h`.

**Per-game campaign that beats the global default.**
scope `game`, game `slotbandit`, placement `postgame`, weight `10` → this replaces
the global post-game card *only* inside Slot Bandit.

**Season reset.**
scope `global`, placement `reset`, title *"New season!"*. Then wipe via the
`stats.html` **🗑️ Reset scores** button (or `POST /reset`) — the reset is logged
and players see the message once on their next launch.

**Time-limited banner.**
Any message with `starts_at` / `ends_at` set (unix ms) only serves within that
window — handy for a weekend event.

---

## 8. Trackable links / redirects

Message links don't point at the final URL directly — they use a **branded,
trackable redirect** so you can change the destination in one place and count
clicks.

Flow: `bitochi.com/coffee` → `api.bitochi.com/go/coffee` → the real URL.

- `bitochi.com/coffee` is a tiny static page (`leaderboard/coffee/index.html`)
  that forwards to the worker. GitHub Pages has no server-side redirects, hence
  the static forward page.
- `GET /go/<slug>` (worker) looks up the slug in the D1 **`links`** table, bumps
  its `clicks` counter, and `302`s to `url`. Unknown slugs fall back to
  `bitochi.com`.

**Why bother instead of a raw `buymeacoffee.com` link:**

- Change the destination (BMC → Ko-fi / Patreon / PayPal) with **no app rebuild
  and no message edit** — just update the link's `url`.
- Short, on-brand, trustworthy URL.
- Click counts per slug, surfaced in `stats.html`.

**Endpoints:** `GET /links` (list), `POST /links` `{slug,url}` (auth, upsert),
`DELETE /links` `{slug}` (auth).

**Manage** from the **🔗 Links** panel in `stats.html`. Seeded slugs: `coffee`
(→ Buy Me a Coffee), `games` (→ bitochi.com), `pro` (→ Connect IQ Store). To add
a new pretty alias `bitochi.com/<slug>`, create `leaderboard/<slug>/index.html`
forwarding to `/go/<slug>` (copy the `coffee` page) and add the slug via the
panel.
