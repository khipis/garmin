-- ── Persuasion refresh for support / promo messages ─────────────────────────────
-- Rewrites live copy for the coffee/support asks and the launch discovery promo.
-- The watch card can't open links, so every ask ends with a plain-language
-- instruction ("open on your phone:") and the URL renders underneath in cyan.
-- Apply:  wrangler d1 execute bitochi-leaderboard --file=update-messages.sql --remote

-- 1) GLOBAL · POST-GAME · the main coffee ask (shown after a run, max every 12h).
UPDATE messages
SET title     = 'Worth a coffee?',
    body      = 'No ads. No tracking. No fee. Made by one person. If a game here made your day, tip the price of a coffee — open on your phone:',
    url        = 'https://bitochi.com/coffee',
    url_label  = 'bitochi.com/coffee',
    updated_at = strftime('%s','now')*1000
WHERE id = 1;

-- 6) GLOBAL · ONCE · the one guaranteed first-session ask.
UPDATE messages
SET title     = 'Keep them free',
    body      = '60+ games, all free, no ads, no tracking — I build them solo. If they''re worth a coffee to you, one small tip funds the next one. Open on your phone:',
    url        = 'https://bitochi.com/coffee',
    url_label  = 'bitochi.com/coffee',
    updated_at = strftime('%s','now')*1000
WHERE id = 6;

-- 5) pets · LAUNCH · pet-flavored coffee ask.
UPDATE messages
SET title     = 'Love your pet?',
    body      = 'Your pet is free — no ads, no tracking. If it put a smile on your face, a coffee-sized tip keeps new games coming. On your phone:',
    url        = 'https://bitochi.com/coffee',
    url_label  = 'bitochi.com/coffee',
    updated_at = strftime('%s','now')*1000
WHERE id = 5;

-- 2) GLOBAL · LAUNCH · discovery / retention nudge (every 24h).
-- Now promotes the brand-new idle games so every player hears about them.
UPDATE messages
SET title     = 'New idle games!',
    body      = 'Four new idle worlds just landed: Space Colony, Island, Mines and Creatures. Build, dig and evolve while you''re away, then climb the boards. On your phone:',
    url        = 'https://bitochi.com',
    url_label  = 'bitochi.com',
    updated_at = strftime('%s','now')*1000
WHERE id = 2;
