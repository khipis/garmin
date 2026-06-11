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

CREATE TABLE IF NOT EXISTS scores (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  game      TEXT    NOT NULL,
  user      TEXT    NOT NULL DEFAULT 'anon',
  score     INTEGER NOT NULL,
  timestamp INTEGER NOT NULL,
  variant   TEXT    NOT NULL DEFAULT '',  -- optional sub-category (hill, difficulty, …)
  meta      TEXT                          -- JSON blob, nullable
);

-- Covers WHERE game=? AND variant=? ORDER BY score DESC
CREATE INDEX IF NOT EXISTS idx_scores_game_variant_score
  ON scores (game, variant, score DESC);
