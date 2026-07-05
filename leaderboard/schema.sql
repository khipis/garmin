-- ── D1 schema ─────────────────────────────────────────────────────────────────
--
-- Initial setup:
--   1. wrangler d1 create garmin-leaderboard
--   2. Copy database_id into wrangler.toml
--   3. wrangler d1 execute garmin-leaderboard --file=schema.sql --remote
--
-- Migration (existing DB — run once):
--   ALTER TABLE scores ADD COLUMN variant TEXT NOT NULL DEFAULT '';
--   DROP INDEX IF EXISTS idx_scores_game_score;
--   CREATE INDEX IF NOT EXISTS idx_scores_game_variant_score ON scores (game, variant, score DESC);
--   -- player-stats: anonymised per-device uniqueness estimate
--   ALTER TABLE scores ADD COLUMN ip_hash TEXT;
--   -- country flag (ISO-3166 alpha-2 from Cloudflare edge)
--   ALTER TABLE scores ADD COLUMN country TEXT;
--   -- bot-seeded rows flag (1 = bot, 0 = real player)
--   ALTER TABLE scores ADD COLUMN is_bot INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS scores (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  game      TEXT    NOT NULL,
  user      TEXT    NOT NULL DEFAULT 'anon',
  score     INTEGER NOT NULL,
  timestamp INTEGER NOT NULL,
  variant   TEXT    NOT NULL DEFAULT '',  -- optional sub-category (hill, difficulty, …)
  meta      TEXT,                         -- JSON blob, nullable
  ip_hash   TEXT,                         -- salted SHA-256 of client IP (anonymised), for unique-player stats
  country   TEXT,                         -- ISO-3166 alpha-2 from the Cloudflare edge (flags), nullable
  is_bot    INTEGER NOT NULL DEFAULT 0    -- 1 = bot-seeded, 0 = real player
);

-- Covers WHERE game=? AND variant=? ORDER BY score DESC
CREATE INDEX IF NOT EXISTS idx_scores_game_variant_score
  ON scores (game, variant, score DESC);

-- Covers period filters + recent-players ordering
CREATE INDEX IF NOT EXISTS idx_scores_game_variant_ts
  ON scores (game, variant, timestamp DESC);

-- ── Visitor tracking ──────────────────────────────────────────────────────────
-- Migration (run once on existing DB):
--   CREATE TABLE IF NOT EXISTS visits (ip_hash TEXT NOT NULL, timestamp INTEGER NOT NULL);
--   CREATE INDEX IF NOT EXISTS idx_visits_ts ON visits (timestamp DESC);

CREATE TABLE IF NOT EXISTS visits (
  ip_hash   TEXT    NOT NULL,   -- salted SHA-256 of client IP (anonymised)
  timestamp INTEGER NOT NULL    -- unix ms
);

CREATE INDEX IF NOT EXISTS idx_visits_ts ON visits (timestamp DESC);

-- ── API error log ─────────────────────────────────────────────────────────────
-- Migration (run once on existing DB):
--   CREATE TABLE IF NOT EXISTS api_errors (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER NOT NULL, game TEXT, error_code INTEGER NOT NULL, error_msg TEXT, ip_hash TEXT);
--   CREATE INDEX IF NOT EXISTS idx_errors_ts ON api_errors (timestamp DESC);
--   CREATE INDEX IF NOT EXISTS idx_errors_game ON api_errors (game, timestamp DESC);

CREATE TABLE IF NOT EXISTS api_errors (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp  INTEGER NOT NULL,
  game       TEXT,                  -- game ID if parseable from the request
  error_code INTEGER NOT NULL,      -- HTTP status: 400, 429, 500
  error_msg  TEXT,                  -- short human-readable reason
  ip_hash    TEXT                   -- anonymised IP
);

CREATE INDEX IF NOT EXISTS idx_errors_ts   ON api_errors (timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_errors_game ON api_errors (game, timestamp DESC);

-- ── Game launches ─────────────────────────────────────────────────────────────
-- A row per app open (fire-and-forget POST /launch from the shared lib's
-- App.onStart). Lets us see which games are actually being played, even when a
-- session never submits a score.
-- Migration (run once on existing DB):
--   CREATE TABLE IF NOT EXISTS launches (id INTEGER PRIMARY KEY AUTOINCREMENT, game TEXT NOT NULL, timestamp INTEGER NOT NULL, ip_hash TEXT, country TEXT);
--   CREATE INDEX IF NOT EXISTS idx_launches_game ON launches (game, timestamp DESC);
--   CREATE INDEX IF NOT EXISTS idx_launches_ts ON launches (timestamp DESC);

CREATE TABLE IF NOT EXISTS launches (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  game      TEXT    NOT NULL,
  timestamp INTEGER NOT NULL,   -- unix ms
  ip_hash   TEXT,               -- anonymised device id (unique-player estimate)
  country   TEXT                -- ISO-3166 alpha-2 from the Cloudflare edge
);

CREATE INDEX IF NOT EXISTS idx_launches_game ON launches (game, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_launches_ts   ON launches (timestamp DESC);

-- ── Season snapshots ──────────────────────────────────────────────────────────
-- One row per season/reset. Saved automatically by reset-stats.sh before wiping
-- the `scores` table. Ensures all retention/engagement metrics survive resets.
-- Migration (run once on existing DB):
--   CREATE TABLE IF NOT EXISTS snapshots (id INTEGER PRIMARY KEY AUTOINCREMENT, taken_at INTEGER NOT NULL, label TEXT, data TEXT NOT NULL);
--   CREATE INDEX IF NOT EXISTS idx_snapshots_ts ON snapshots (taken_at DESC);

CREATE TABLE IF NOT EXISTS snapshots (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  taken_at INTEGER NOT NULL,  -- unix ms
  label    TEXT,              -- e.g. "Season 2026-06", optional
  data     TEXT NOT NULL      -- JSON: { totals, topGames, topCountries }
);

CREATE INDEX IF NOT EXISTS idx_snapshots_ts ON snapshots (taken_at DESC);

-- ── Hall of Fame ──────────────────────────────────────────────────────────────
-- Permanent all-time records per game. NOT wiped by season resets.
-- Admin adds entries manually or via --hof in reset-stats.sh and removes
-- them at will via the stats.html management panel.
-- Migration (run once on existing DB):
--   CREATE TABLE IF NOT EXISTS hall_of_fame (id INTEGER PRIMARY KEY AUTOINCREMENT, game TEXT NOT NULL, variant TEXT NOT NULL DEFAULT '', user TEXT NOT NULL, score INTEGER NOT NULL, country TEXT, added_at INTEGER NOT NULL, note TEXT);
--   CREATE INDEX IF NOT EXISTS idx_hof_game ON hall_of_fame (game, variant, added_at DESC);

CREATE TABLE IF NOT EXISTS hall_of_fame (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  game     TEXT    NOT NULL,
  variant  TEXT    NOT NULL DEFAULT '',
  user     TEXT    NOT NULL,
  score    INTEGER NOT NULL,
  country  TEXT,               -- ISO-3166 alpha-2, optional
  added_at INTEGER NOT NULL,   -- unix ms
  note     TEXT                -- e.g. "Season 2026-05 Champion"
);

CREATE INDEX IF NOT EXISTS idx_hof_game ON hall_of_fame (game, variant, added_at DESC);

-- ── Custom messages / announcements ───────────────────────────────────────────
-- Configurable in-app messages the games fetch on launch and show at defined
-- moments (pre-game / post-game / after a leaderboard reset). Owner-editable
-- from stats.html, no app rebuild needed.
--   scope     'global' (all games) | 'game' (only the given game id)
--   placement 'launch' | 'postgame' | 'reset'  — when the client shows it
--   weight    higher wins when several messages match the same placement
--             (a game-scoped message always beats a global one for that game)
--   min_gap_s client-side throttle: don't re-show sooner than this many seconds
--   active    0 disables without deleting
--   starts_at / ends_at  optional unix-ms window (NULL = always)
-- Migration (run once on existing DB): the CREATE TABLE below is idempotent.
CREATE TABLE IF NOT EXISTS messages (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  scope      TEXT    NOT NULL DEFAULT 'global',   -- 'global' | 'game'
  game       TEXT,                                -- NULL for global scope
  placement  TEXT    NOT NULL DEFAULT 'postgame', -- 'launch' | 'postgame' | 'reset'
  title      TEXT    NOT NULL,
  body       TEXT    NOT NULL DEFAULT '',
  url        TEXT,                                -- optional link opened on the phone
  url_label  TEXT,                                -- e.g. "Buy me a coffee"
  weight     INTEGER NOT NULL DEFAULT 0,
  min_gap_s  INTEGER NOT NULL DEFAULT 21600,      -- 6 h default throttle
  active     INTEGER NOT NULL DEFAULT 1,
  starts_at  INTEGER,                             -- unix ms, optional
  ends_at    INTEGER,                             -- unix ms, optional
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_messages_lookup
  ON messages (active, placement, scope, game);

-- ── Reset log ─────────────────────────────────────────────────────────────────
-- One row per leaderboard reset (written by POST /reset). Games compare the
-- latest applicable reset timestamp against a locally-stored "acknowledged"
-- value to detect "the board was wiped since I last played" and show the
-- configured 'reset' re-engagement message once.
--   game NULL = a global (all-games) reset; otherwise a single-game reset.
-- Migration (run once on existing DB):
--   CREATE TABLE IF NOT EXISTS resets (id INTEGER PRIMARY KEY AUTOINCREMENT, game TEXT, at INTEGER NOT NULL);
--   CREATE INDEX IF NOT EXISTS idx_resets_game ON resets (game, at DESC);
CREATE TABLE IF NOT EXISTS resets (
  id   INTEGER PRIMARY KEY AUTOINCREMENT,
  game TEXT,                -- NULL = global reset (affects every game)
  at   INTEGER NOT NULL     -- unix ms
);

CREATE INDEX IF NOT EXISTS idx_resets_game ON resets (game, at DESC);

-- ── Redirect links / short URLs ───────────────────────────────────────────────
-- Branded, trackable redirects: GET /go/<slug> 302s to `url` and bumps `clicks`.
-- Messages point at bitochi.com/coffee (a static page that forwards to
-- /go/coffee) so the destination can be changed here without touching any app,
-- and clicks are counted for the stats page. Owner-editable from stats.html.
-- Migration (run once on existing DB): the CREATE TABLE below is idempotent.
CREATE TABLE IF NOT EXISTS links (
  slug       TEXT PRIMARY KEY,     -- e.g. "coffee", "games", "pro"
  url        TEXT NOT NULL,        -- absolute destination
  clicks     INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
