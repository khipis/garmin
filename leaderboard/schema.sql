-- ── D1 schema — run ONCE to initialise the database ─────────────────────────
--
-- 1. Create the D1 database (if you haven't already):
--      wrangler d1 create garmin-leaderboard
--
-- 2. Copy the returned database_id into wrangler.toml
--
-- 3. Apply this schema:
--      wrangler d1 execute garmin-leaderboard --file=schema.sql --remote

CREATE TABLE IF NOT EXISTS scores (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  game      TEXT    NOT NULL,
  user      TEXT    NOT NULL DEFAULT 'anon',
  score     INTEGER NOT NULL,
  timestamp INTEGER NOT NULL,
  meta      TEXT                               -- JSON blob, nullable
);

-- Speeds up GET /leaderboard?game=XYZ (covers the WHERE + ORDER BY)
CREATE INDEX IF NOT EXISTS idx_scores_game_score
  ON scores (game, score DESC);
