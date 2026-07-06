-- ── Default in-app messages ───────────────────────────────────────────────────
-- Seed the messages table with sensible defaults. Safe to re-run: every INSERT
-- is guarded by a NOT EXISTS check on (scope, COALESCE(game,''), placement, title)
-- so you won't get duplicates.
--
-- Apply:
--   wrangler d1 execute garmin-leaderboard --file=seed-messages.sql --remote
--
-- Edit / add more later from the "Messages" panel in stats.html (no rebuild).

-- Branded, trackable redirects (GET /go/<slug>). Messages link to the pretty
-- bitochi.com/<slug> alias, which forwards to /go/<slug>. Change destinations
-- here (or in stats.html) without editing messages or rebuilding apps.
INSERT INTO links (slug, url, clicks, created_at, updated_at)
SELECT 'coffee', 'https://buymeacoffee.com/bitochi', 0, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM links WHERE slug='coffee');
INSERT INTO links (slug, url, clicks, created_at, updated_at)
SELECT 'games', 'https://bitochi.com', 0, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM links WHERE slug='games');
INSERT INTO links (slug, url, clicks, created_at, updated_at)
SELECT 'pro', 'https://apps.garmin.com/apps/bitochi', 0, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM links WHERE slug='pro');

-- 1) GLOBAL · POST-GAME · "Support Bitochi" (via bitochi.com/coffee redirect)
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'global', NULL, 'postgame',
       'Enjoying Bitochi?',
       'Every game here is free and ad-free. If they put a smile on your face, a small tip keeps new ones coming. Thank you!',
       'https://bitochi.com/coffee', 'Buy me a coffee',
       0, 43200, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='global' AND game IS NULL AND placement='postgame' AND title='Enjoying Bitochi?');

-- 2) GLOBAL · LAUNCH · "Discover more games"
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'global', NULL, 'launch',
       'More free games',
       '40+ tiny games and tools for your watch, all free. Compete on the global leaderboards at bitochi.com.',
       'https://bitochi.com', 'See all games',
       0, 86400, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='global' AND game IS NULL AND placement='launch' AND title='More free games');

-- 3) GLOBAL · RESET · "New season" (shown once after a leaderboard wipe)
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'global', NULL, 'reset',
       'New season!',
       'The leaderboards were just reset — everyone starts from zero. Fresh shot at the #1 spot. Go get it!',
       NULL, NULL,
       0, 0, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='global' AND game IS NULL AND placement='reset' AND title='New season!');

-- 5) pets · LAUNCH · support Bitochi (coffee) shown at the very start
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'pets', 'launch',
       'Enjoying Pixel Pets?',
       'Every Bitochi game is free and ad-free. If it made you smile, a small tip keeps new ones coming. Thank you!',
       'https://bitochi.com/coffee', 'Buy me a coffee',
       10, 43200, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='game' AND game='pets' AND placement='launch' AND title='Enjoying Pixel Pets?');

-- 6) GLOBAL · ONCE · one-shot support call-to-action (shown once per game at
--    start, then never again until "re-armed" from the stats.html Messages panel).
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'global', NULL, 'once',
       'Keep Bitochi free',
       'All 60+ games and tools are free and ad-free. If they are worth a coffee to you, a one-time tip keeps them coming. Open bitochi.com/coffee on your phone. Thank you!',
       'https://bitochi.com/coffee', 'Buy me a coffee',
       0, 0, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='global' AND game IS NULL AND placement='once' AND title='Keep Bitochi free');

-- 4) breathtrainingtool · LAUNCH · invite to the paid "System" version
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'breathtrainingtool', 'launch',
       'Go deeper with PRO',
       'Loving the breath tool? Breath Training System adds a coach, adaptive plans and progression. Try it on the Connect IQ Store.',
       'https://apps.garmin.com/apps/bitochi', 'Get the System',
       10, 172800, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='game' AND game='breathtrainingtool' AND placement='launch' AND title='Go deeper with PRO');
