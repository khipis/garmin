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
-- bitochi.com/ab → the fully-hyped Activity Board world leaderboard.
INSERT INTO links (slug, url, clicks, created_at, updated_at)
SELECT 'ab', 'https://bitochi.com/?game=activityboard', 0, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM links WHERE slug='ab');

-- 1) GLOBAL · POST-GAME · "Support Bitochi" (via bitochi.com/coffee redirect)
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'global', NULL, 'postgame',
       'Worth a coffee?',
       'No ads. No tracking. No fee. Made by one person. If a game here made your day, tip the price of a coffee — open on your phone:',
       'https://bitochi.com/coffee', 'bitochi.com/coffee',
       0, 43200, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='global' AND game IS NULL AND placement='postgame' AND title='Worth a coffee?');

-- 2) GLOBAL · LAUNCH · combined discovery (new titles + idle worlds)
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'global', NULL, 'launch',
       'New Bitochi games!',
       'Daily Sport, Zombie Survival, Backrooms, Dungeon Master, Tower Defense + idle Farm, Space Colony, Mines, Creatures, Island. On your phone:',
       'https://bitochi.com', 'bitochi.com',
       0, 86400, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (
  SELECT 1 FROM messages
  WHERE scope='global' AND game IS NULL AND placement='launch'
    AND title IN ('New Bitochi games!', 'New idle games!')
);

-- spacecolony · LAUNCH · SPACE WAR / raid rivals
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'spacecolony', 'launch',
       'SPACE WAR is LIVE',
       'Rival colonies are on the board. Train marines, raise turrets, then RAID real players. They can hit YOU while you''re away — open WAR and strike first.',
       'https://bitochi.com/?game=spacecolony', 'bitochi.com',
       15, 86400, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (
  SELECT 1 FROM messages
  WHERE scope='game' AND game='spacecolony' AND placement='launch' AND title='SPACE WAR is LIVE'
);

-- creatures · LAUNCH · Arena PvP fights
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'creatures', 'launch',
       'ARENA FIGHTS are LIVE',
       'Your creatures can now ATTACK real rivals from the global board. Pick a target, fight for rank — and see who came for YOUR roster while you slept.',
       'https://bitochi.com/?game=creatures', 'bitochi.com',
       15, 86400, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (
  SELECT 1 FROM messages
  WHERE scope='game' AND game='creatures' AND placement='launch' AND title='ARENA FIGHTS are LIVE'
);

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
       'Love your pet?',
       'Your pet is free — no ads, no tracking. If it put a smile on your face, a coffee-sized tip keeps new games coming. On your phone:',
       'https://bitochi.com/coffee', 'bitochi.com/coffee',
       10, 43200, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='game' AND game='pets' AND placement='launch' AND title='Love your pet?');

-- 6) GLOBAL · ONCE · one-shot support call-to-action (shown once per game at
--    start, then never again until "re-armed" from the stats.html Messages panel).
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'global', NULL, 'once',
       'Keep them free',
       '60+ games, all free, no ads, no tracking — I build them solo. If they''re worth a coffee to you, one small tip funds the next one. Open on your phone:',
       'https://bitochi.com/coffee', 'bitochi.com/coffee',
       0, 0, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='global' AND game IS NULL AND placement='once' AND title='Keep them free');

-- 7) activityboard · LAUNCH · send players to the hyped world board (bitochi.com/ab)
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'activityboard', 'launch',
       'Your flex is LIVE 🐋',
       'Your REAL stats — steps, cardio, climb, distance & more — are ranked live against the whole world on a fully-hyped board. See where you stand: open bitochi.com/ab on your phone.',
       'https://bitochi.com/ab', 'Open the board',
       10, 43200, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='game' AND game='activityboard' AND placement='launch' AND title='Your flex is LIVE 🐋');

-- 8) activityboard · POSTGAME · after a flex, nudge them to admire the board
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'activityboard', 'postgame',
       'See your world rank',
       'That stat is now live on the global Activity Board. Watch yourself climb the real, hyped leaderboard at bitochi.com/ab.',
       'https://bitochi.com/ab', 'Open the board',
       10, 21600, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='game' AND game='activityboard' AND placement='postgame' AND title='See your world rank');

-- 4) breathtrainingtool · LAUNCH · hard invite to the paid "System" version
-- (short gap on purpose — free lite should nag toward System)
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'breathtrainingtool', 'launch',
       'You''re on the free lite',
       'Breath Training System is the real one — distraction-free, fully featured, with a coach, adaptive plans, readiness and way more. Open on your phone:',
       'https://bitochi.com/pro', 'Get Breath Training System',
       20, 1800, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='game' AND game='breathtrainingtool' AND placement='launch' AND title='You''re on the free lite');

-- 4b) breathtrainingtool · POSTGAME · nag again after every finished session
INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'breathtrainingtool', 'postgame',
       'You''re on the free lite',
       'Breath Training System is the real one — distraction-free, fully featured, with a coach, adaptive plans, readiness and way more. Open on your phone:',
       'https://bitochi.com/pro', 'Get Breath Training System',
       20, 0, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (SELECT 1 FROM messages WHERE scope='game' AND game='breathtrainingtool' AND placement='postgame' AND title='You''re on the free lite');
