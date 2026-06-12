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
