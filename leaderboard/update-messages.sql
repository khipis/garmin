-- ── Promo refresh: new games + idle + SPACE WAR / ARENA ───────────────────────
-- Apply:
--   cd leaderboard && wrangler d1 execute bitochi-leaderboard --file=update-messages.sql --remote
--
-- Watch card limits: title ≤ 60 chars, body ≤ 200 chars.

-- 2) GLOBAL · LAUNCH · one combined discovery card (new titles + idle worlds).
UPDATE messages
SET title     = 'New Bitochi games!',
    body      = 'Daily Sport, Zombie Survival, Backrooms, Dungeon Master, Tower Defense + idle Farm, Space Colony, Mines, Creatures, Island. On your phone:',
    url        = 'https://bitochi.com',
    url_label  = 'bitochi.com',
    updated_at = strftime('%s','now')*1000
WHERE id = 2
   OR (scope = 'global' AND game IS NULL AND placement = 'launch' AND title IN ('New idle games!', 'New Bitochi games!'));

-- spacecolony · LAUNCH · SPACE WAR / raid rivals (beats global via weight).
UPDATE messages
SET title      = 'SPACE WAR is LIVE',
    body       = 'Rival colonies are on the board. Train marines, raise turrets, then RAID real players. They can hit YOU while you''re away — open WAR and strike first.',
    url        = 'https://bitochi.com/?game=spacecolony',
    url_label  = 'bitochi.com',
    weight     = 15,
    min_gap_s  = 86400,
    active     = 1,
    updated_at = strftime('%s','now')*1000
WHERE scope = 'game' AND game = 'spacecolony' AND placement = 'launch'
  AND title IN ('SPACE WAR is LIVE', 'Raid rival colonies!');

INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'spacecolony', 'launch',
       'SPACE WAR is LIVE',
       'Rival colonies are on the board. Train marines, raise turrets, then RAID real players. They can hit YOU while you''re away — open WAR and strike first.',
       'https://bitochi.com/?game=spacecolony', 'bitochi.com',
       15, 86400, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (
  SELECT 1 FROM messages
  WHERE scope = 'game' AND game = 'spacecolony' AND placement = 'launch'
);

-- creatures · LAUNCH · Arena PvP fights (beats global via weight).
UPDATE messages
SET title      = 'ARENA FIGHTS are LIVE',
    body       = 'Your creatures can now ATTACK real rivals from the global board. Pick a target, fight for rank — and see who came for YOUR roster while you slept.',
    url        = 'https://bitochi.com/?game=creatures',
    url_label  = 'bitochi.com',
    weight     = 15,
    min_gap_s  = 86400,
    active     = 1,
    updated_at = strftime('%s','now')*1000
WHERE scope = 'game' AND game = 'creatures' AND placement = 'launch'
  AND title IN ('ARENA FIGHTS are LIVE', 'Arena fights are LIVE!');

INSERT INTO messages (scope, game, placement, title, body, url, url_label, weight, min_gap_s, active, created_at, updated_at)
SELECT 'game', 'creatures', 'launch',
       'ARENA FIGHTS are LIVE',
       'Your creatures can now ATTACK real rivals from the global board. Pick a target, fight for rank — and see who came for YOUR roster while you slept.',
       'https://bitochi.com/?game=creatures', 'bitochi.com',
       15, 86400, 1, strftime('%s','now')*1000, strftime('%s','now')*1000
WHERE NOT EXISTS (
  SELECT 1 FROM messages
  WHERE scope = 'game' AND game = 'creatures' AND placement = 'launch'
);
