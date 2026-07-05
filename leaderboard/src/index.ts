// Garmin Games — Global Leaderboard API
// Cloudflare Worker + D1 (SQLite)

export interface Env {
  DB: D1Database;
  // Shared submit key. POST /score is rejected (403) unless the request
  // carries a matching `X-LB-Key` header. Set via `wrangler secret put LB_KEY`.
  LB_KEY?: string;
  // Optional salt for the anonymised IP hash used in player stats. Falls back
  // to LB_KEY, then a constant, so stats keep working even if unset.
  IP_SALT?: string;
}

// ── Config ────────────────────────────────────────────────────────────────────

// Optional per-game API keys.  Set {} to disable.
const GAME_KEYS: Record<string, string> = {
  // "mygame": "supersecretkey123",
};

const RATE_LIMIT_WINDOW_MS = 10_000;
const RATE_LIMIT_MAX       = 20;
const LEADERBOARD_CACHE_S  = 45;
const TOP_N                = 50;

// Games where a LOWER score is better (completion time in seconds, move/stroke
// counts). Everything else defaults to higher-is-better (DESC).
const ASC_GAMES = new Set<string>([
  "sudoku",
  "minesweeper",
  "solitaire",
  "lightsout",
  "battleship",
  "twentyfortyeight_time",   // 2048 speedrun: fastest time to the 2048 tile
  "akari",                   // light-up puzzle: fastest solve time
  "memo",                    // memo: fewest moves to match all pairs
]);

const ipHits = new Map<string, { count: number; windowStart: number }>();

// ── Helpers ───────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200, extra: HeadersInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
      ...extra,
    },
  });
}

function err(msg: string, status = 400): Response {
  return json({ ok: false, error: msg }, status);
}

function sanitizeGame(raw: string): string {
  return raw.toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 40);
}

function sanitizeUser(raw: string): string {
  return raw.replace(/[\x00-\x1f\x7f]/g, "").slice(0, 32) || "anon";
}

function sanitizeVariant(raw: string): string {
  // Allow alphanumeric, spaces, dash, underscore — max 60 chars
  return raw.replace(/[^a-zA-Z0-9 _-]/g, "").slice(0, 60).trim();
}

// Anonymised, non-reversible per-device fingerprint for unique-player stats.
// 64-bit salted SHA-256 prefix — enough to estimate uniqueness without storing
// or exposing the raw IP.
async function hashIp(ip: string, salt: string): Promise<string> {
  const data = new TextEncoder().encode(salt + "|" + ip);
  const digest = await crypto.subtle.digest("SHA-256", data);
  const bytes = new Uint8Array(digest);
  let hex = "";
  for (let i = 0; i < 8; i++) hex += bytes[i].toString(16).padStart(2, "0");
  return hex;
}

// Period → unix-seconds cutoff (inclusive lower bound), or null for all-time.
// "day"  = since 00:00 UTC today, "week" = since Monday 00:00 UTC this week.
// These are rolling windows that auto-reset, giving daily/weekly seasons with
// no destructive wipes (all-time is always preserved).
function periodCutoff(period: string): number | null {
  const now = new Date();
  if (period === "day") {
    const d = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate());
    return Math.floor(d / 1000);
  }
  if (period === "week") {
    const dow = (now.getUTCDay() + 6) % 7; // 0 = Monday
    const d = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - dow);
    return Math.floor(d / 1000);
  }
  return null; // all-time
}

function normPeriod(raw: string): string {
  return (raw === "day" || raw === "week") ? raw : "all";
}

function checkRateLimit(ip: string): boolean {
  const now = Date.now();
  const rec = ipHits.get(ip);
  if (!rec || now - rec.windowStart > RATE_LIMIT_WINDOW_MS) {
    ipHits.set(ip, { count: 1, windowStart: now });
    return true;
  }
  rec.count += 1;
  return rec.count <= RATE_LIMIT_MAX;
}

// ── Route handlers ────────────────────────────────────────────────────────────

// Logs a non-403 error to the api_errors table for monitoring in stats.html.
// Fire-and-forget — we don't await this on the critical path.
async function logError(env: Env, game: string | null, code: number, msg: string, ipHash: string): Promise<void> {
  try {
    await env.DB.prepare(
      "INSERT INTO api_errors (timestamp, game, error_code, error_msg, ip_hash) VALUES (?, ?, ?, ?, ?)"
    ).bind(Date.now(), game, code, msg, ipHash).run();
  } catch (_) { /* silent */ }
}

async function handlePostScore(req: Request, env: Env): Promise<Response> {
  // Anti-abuse: writes require the shared submit key. Fail closed if the
  // server has no key configured.
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  const ip     = req.headers.get("CF-Connecting-IP") ?? "0.0.0.0";
  const ipHash = await hashIp(ip, env.IP_SALT ?? env.LB_KEY ?? "bito-lb");

  let body: unknown;
  try { body = await req.json(); } catch {
    await logError(env, null, 400, "invalid JSON", ipHash);
    return err("invalid JSON");
  }

  const b = body as Record<string, unknown>;

  const gameRaw    = typeof b.game    === "string" ? b.game.trim()    : "";
  const userRaw    = typeof b.user    === "string" ? b.user.trim()    : "anon";
  const variantRaw = typeof b.variant === "string" ? b.variant.trim() : "";
  const score      = typeof b.score   === "number"  ? b.score          : null;

  if (!gameRaw) { await logError(env, null,    400, "missing: game",  ipHash); return err("missing: game"); }
  if (score === null || !Number.isFinite(score)) { await logError(env, gameRaw || null, 400, "missing/invalid: score", ipHash); return err("missing/invalid: score"); }

  const game    = sanitizeGame(gameRaw);
  if (!game)    { await logError(env, gameRaw, 400, "invalid game name", ipHash); return err("invalid game name"); }

  // Sanity bounds — keep clearly invalid scores off the boards. Negative
  // scores are never valid; lower-is-better games (fastest time / fewest
  // moves) can never be 0 either, so a 0 would otherwise pin rank #1 forever.
  // The upper cap guards against overflow / abuse.
  if (score < 0 || score > 1_000_000_000) { await logError(env, game, 400, `score out of range: ${score}`, ipHash); return err("score out of range"); }
  if (ASC_GAMES.has(game) && score <= 0)  { await logError(env, game, 400, `invalid score for ASC game: ${score}`, ipHash); return err("invalid score for this game"); }

  const user    = sanitizeUser(userRaw || "anon");
  const variant = sanitizeVariant(variantRaw);

  // Anon uniquification: give every "anon" player a stable short tag derived
  // from their IP hash so they appear as separate leaderboard entries.
  // Same network → same tag (e.g. "anon-a3f2"); bots keep their own names.
  const isBot   = b.is_bot === true ? 1 : 0;
  const uniqueUser = (user === "anon" && !isBot)
    ? `anon-${ipHash.slice(0, 4)}`
    : user;
  if (GAME_KEYS[game] !== undefined) {
    if (b.key !== GAME_KEYS[game]) return err("invalid game key", 403);
  }

  const ts      = Math.floor(Date.now() / 1000);
  const metaStr = b.meta && typeof b.meta === "object"
    ? JSON.stringify(b.meta).slice(0, 512)
    : null;

  const cf      = (req as unknown as { cf?: { country?: string } }).cf;
  // Bots carry an explicit country code in the body; real Garmin clients use CF edge.
  const cfCountry = (cf && typeof cf.country === "string" && cf.country.length === 2)
    ? cf.country : null;
  const botCountry = (isBot && typeof b.country === "string" && b.country.length === 2)
    ? b.country.toUpperCase() : null;
  const country = botCountry ?? cfCountry;

  try {
    await env.DB
      .prepare(
        "INSERT INTO scores (game, user, score, timestamp, variant, meta, ip_hash, country, is_bot) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)"
      )
      .bind(game, uniqueUser, Math.round(score), ts, variant, metaStr, ipHash, country, isBot)
      .run();
  } catch (e) {
    console.error("DB insert error:", e);
    await logError(env, game, 500, `db error: ${String(e).slice(0,120)}`, ipHash);
    return err("db error", 500);
  }

  return json({ ok: true });
}

// Enriched leaderboard. Returns the best-score-per-user top list plus, when a
// `user` is supplied, that player's global rank, a ±5 "near you" window, and a
// "target" (median of the top scores) for the "beat this" mechanic.
//
// Query: game, variant?, period(all|day|week)?, user?
async function handleGetLeaderboard(url: URL, env: Env): Promise<Response> {
  const gameRaw    = (url.searchParams.get("game")    ?? "").trim();
  const variantRaw = (url.searchParams.get("variant") ?? "").trim();
  const period     = normPeriod((url.searchParams.get("period") ?? "").trim());
  const userRaw    = (url.searchParams.get("user")    ?? "").trim();

  if (!gameRaw) return err("missing: game");
  const game = sanitizeGame(gameRaw);
  if (!game)   return err("invalid game name");

  const variant  = sanitizeVariant(variantRaw);
  const user     = userRaw ? sanitizeUser(userRaw) : "";
  const realOnly = url.searchParams.get("real") === "1";

  const asc    = ASC_GAMES.has(game);
  const order  = asc ? "ASC" : "DESC";
  const better = asc ? "<" : ">";              // "is a better score than"
  const bestFn = asc ? "MIN(score)" : "MAX(score)";

  // Shared WHERE: game + variant (+ optional period + optional bot filter).
  const cutoff = periodCutoff(period);
  const botClause = realOnly ? " AND is_bot = 0" : "";
  const where  = cutoff != null
    ? `game = ? AND variant = ? AND timestamp >= ?${botClause}`
    : `game = ? AND variant = ?${botClause}`;
  const wbind  = cutoff != null ? [game, variant, cutoff] : [game, variant];

  // `meta` (m) rides along via SQLite's documented bare-column behaviour: when
  // a query has exactly one MIN()/MAX() aggregate, any other non-aggregated,
  // non-GROUP-BY column is taken from the row that produced that min/max —
  // same trick already used here for `country`. Lets per-score extras (fish
  // species/rarity, ...) surface on the enriched leaderboard without a
  // separate lookup.
  type Row = { user: string; s: number; c: string | null; m: string | null };
  let top: { r: number; u: string; s: number; c: string | null; m: string | null }[] = [];
  let count = 0;
  let me: { r: number; s: number } | null = null;
  let near: { r: number; u: string; s: number; c: string | null; m: string | null }[] = [];

  try {
    const topRes = await env.DB
      .prepare(
        `SELECT user, ${bestFn} AS s, country AS c, meta AS m
         FROM scores WHERE ${where}
         GROUP BY user ORDER BY s ${order} LIMIT 10`
      )
      .bind(...wbind)
      .all<Row>();
    top = (topRes.results ?? []).map((r, i) => ({ r: i + 1, u: r.user, s: r.s, c: r.c, m: r.m }));

    const cntRes = await env.DB
      .prepare(`SELECT COUNT(DISTINCT user) AS c FROM scores WHERE ${where}`)
      .bind(...wbind)
      .first<{ c: number }>();
    count = cntRes?.c ?? 0;

    if (user) {
      const meBest = await env.DB
        .prepare(`SELECT ${bestFn} AS s FROM scores WHERE ${where} AND user = ?`)
        .bind(...wbind, user)
        .first<{ s: number | null }>();

      if (meBest && meBest.s != null) {
        const myScore = meBest.s;
        const betterCnt = await env.DB
          .prepare(
            `SELECT COUNT(*) AS c FROM (
               SELECT user, ${bestFn} AS b FROM scores WHERE ${where} GROUP BY user
             ) WHERE b ${better} ?`
          )
          .bind(...wbind, myScore)
          .first<{ c: number }>();
        const myRank = (betterCnt?.c ?? 0) + 1;
        me = { r: myRank, s: myScore };

        const off = Math.max(0, myRank - 6);
        const nearRes = await env.DB
          .prepare(
            `SELECT user, ${bestFn} AS s, country AS c, meta AS m
             FROM scores WHERE ${where}
             GROUP BY user ORDER BY s ${order} LIMIT 11 OFFSET ?`
          )
          .bind(...wbind, off)
          .all<Row>();
        near = (nearRes.results ?? []).map((r, i) => ({ r: off + i + 1, u: r.user, s: r.s, c: r.c, m: r.m }));
      }
    }
  } catch (e) {
    console.error("DB query error:", e);
    return err("db error", 500);
  }

  // "Target" = median of the visible top scores (the score to beat).
  let target: number | null = null;
  if (top.length > 0) {
    const vals = top.map(t => t.s);
    target = vals[Math.floor((vals.length - 1) / 2)];
  }

  return json(
    { game, variant, period, asc, updated: Math.floor(Date.now() / 1000), count, target, top, me, near },
    200,
    { "Cache-Control": `public, max-age=${LEADERBOARD_CACHE_S}, stale-while-revalidate=60` }
  );
}

// Compact "standing" for the in-game engagement card: the player's rank and how
// far they are from the current #1 across all-time (Hall of Fame), today and this
// week — all in one request. Everything is best-score-per-user aware.
//
// Query: game, variant?, user (required for gaps)
async function handleGetStanding(url: URL, env: Env): Promise<Response> {
  const gameRaw    = (url.searchParams.get("game")    ?? "").trim();
  const variantRaw = (url.searchParams.get("variant") ?? "").trim();
  const userRaw    = (url.searchParams.get("user")    ?? "").trim();

  if (!gameRaw) return err("missing: game");
  const game = sanitizeGame(gameRaw);
  if (!game)   return err("invalid game name");

  const variant = sanitizeVariant(variantRaw);
  const user    = userRaw ? sanitizeUser(userRaw) : "";

  const asc    = ASC_GAMES.has(game);
  const order  = asc ? "ASC" : "DESC";
  const better = asc ? "<" : ">";
  const bestFn = asc ? "MIN(score)" : "MAX(score)";

  async function periodStanding(period: string) {
    const cutoff = periodCutoff(period);
    const where  = cutoff != null
      ? `game = ? AND variant = ? AND timestamp >= ?`
      : `game = ? AND variant = ?`;
    const wbind  = cutoff != null ? [game, variant, cutoff] : [game, variant];

    const top1Res = await env.DB
      .prepare(`SELECT ${bestFn} AS s FROM scores WHERE ${where}`)
      .bind(...wbind)
      .first<{ s: number | null }>();
    const top1 = top1Res?.s ?? null;

    const cntRes = await env.DB
      .prepare(`SELECT COUNT(DISTINCT user) AS c FROM scores WHERE ${where}`)
      .bind(...wbind)
      .first<{ c: number }>();
    const count = cntRes?.c ?? 0;

    let myBest: number | null = null;
    let myRank: number | null = null;
    if (user) {
      const meRes = await env.DB
        .prepare(`SELECT ${bestFn} AS s FROM scores WHERE ${where} AND user = ?`)
        .bind(...wbind, user)
        .first<{ s: number | null }>();
      if (meRes && meRes.s != null) {
        myBest = meRes.s;
        const rankRes = await env.DB
          .prepare(
            `SELECT COUNT(*) AS c FROM (
               SELECT user, ${bestFn} AS b FROM scores WHERE ${where} GROUP BY user
             ) WHERE b ${better} ?`
          )
          .bind(...wbind, myBest)
          .first<{ c: number }>();
        myRank = (rankRes?.c ?? 0) + 1;
      }
    }
    return { top1, count, myBest, myRank };
  }

  try {
    const [all, day, week] = await Promise.all([
      periodStanding("all"),
      periodStanding("day"),
      periodStanding("week"),
    ]);
    return json(
      { game, variant, asc, all, day, week, updated: Math.floor(Date.now() / 1000) },
      200,
      { "Cache-Control": "public, max-age=15, stale-while-revalidate=60" }
    );
  } catch (e) {
    console.error("standing query error:", e);
    return err("db error", 500);
  }
}

// Recent submissions (raw, newest first) — makes the board feel alive.
async function handleGetRecent(url: URL, env: Env): Promise<Response> {
  const gameRaw    = (url.searchParams.get("game")    ?? "").trim();
  const variantRaw = (url.searchParams.get("variant") ?? "").trim();
  const period     = normPeriod((url.searchParams.get("period") ?? "").trim());

  if (!gameRaw) return err("missing: game");
  const game = sanitizeGame(gameRaw);
  if (!game)   return err("invalid game name");
  const variant = sanitizeVariant(variantRaw);

  const cutoff = periodCutoff(period);
  const where  = cutoff != null
    ? "game = ? AND variant = ? AND timestamp >= ?"
    : "game = ? AND variant = ?";
  const wbind  = cutoff != null ? [game, variant, cutoff] : [game, variant];

  let recent: { u: string; s: number; c: string | null; t: number }[] = [];
  try {
    const res = await env.DB
      .prepare(
        `SELECT user AS u, score AS s, country AS c, timestamp AS t
         FROM scores WHERE ${where} ORDER BY timestamp DESC LIMIT 8`
      )
      .bind(...wbind)
      .all<{ u: string; s: number; c: string | null; t: number }>();
    recent = res.results ?? [];
  } catch (e) {
    console.error("DB query error:", e);
    return err("db error", 500);
  }

  return json(
    { game, variant, period, updated: Math.floor(Date.now() / 1000), recent },
    200,
    { "Cache-Control": `public, max-age=30, stale-while-revalidate=60` }
  );
}

async function handleGetGames(env: Env): Promise<Response> {
  let games: string[] = [];
  try {
    const result = await env.DB
      .prepare("SELECT DISTINCT game FROM scores ORDER BY game ASC")
      .all<{ game: string }>();
    games = (result.results ?? []).map(r => r.game);
  } catch (e) {
    console.error("DB query error:", e);
    return err("db error", 500);
  }

  return json(
    { games },
    200,
    { "Cache-Control": `public, max-age=${LEADERBOARD_CACHE_S}, stale-while-revalidate=60` }
  );
}

// Aggregate player stats, computed live from the scores table. Used by the
// "Stats" tab on bitochi.com for development/planning.
// ?real=1 → exclude bot-seeded rows so the owner sees authentic traffic only.
async function handleGetStats(url: URL, env: Env): Promise<Response> {
  type PerGame    = { game: string; scores: number; players: number; devices: number };
  type PerCountry = { country: string | null; players: number; scores: number };
  let perGame:    PerGame[]    = [];
  let perCountry: PerCountry[] = [];
  let totals = {
    games: 0, scores: 0, players: 0, devices: 0,
    returning: 0, ret3: 0, ret4: 0, ret5: 0, ret6: 0, loyal: 0,
    newPlayers7d: 0, dau30d: 0, avgScoresPerPlayer: 0,
    lifetimeGames: 0, lifetimePlayers: 0, lifetimeLaunches: 0
  };

  const realOnly = url.searchParams.get("real") === "1";
  const w  = realOnly ? "WHERE is_bot = 0" : "";
  const wa = realOnly ? "AND is_bot = 0"   : "";
  // Backwards-compat alias for the old name used below
  const botFilter = w;

  try {
    const byGame = await env.DB
      .prepare(
        `SELECT game,
                COUNT(*)                  AS scores,
                COUNT(DISTINCT user)      AS players,
                COUNT(DISTINCT ip_hash)   AS devices
         FROM scores
         ${botFilter}
         GROUP BY game
         ORDER BY players DESC, scores DESC`
      )
      .all<PerGame>();
    perGame = byGame.results ?? [];

    const byCountry = await env.DB
      .prepare(
        `SELECT country,
                COUNT(DISTINCT user) AS players,
                COUNT(*)             AS scores
         FROM scores
         ${botFilter}
         GROUP BY country
         ORDER BY players DESC, scores DESC`
      )
      .all<PerCountry>();
    perCountry = byCountry.results ?? [];

    const agg = await env.DB
      .prepare(
        `SELECT COUNT(DISTINCT game)     AS games,
                COUNT(*)                 AS scores,
                COUNT(DISTINCT user)     AS players,
                COUNT(DISTINCT ip_hash)  AS devices
         FROM scores
         ${botFilter}`
      )
      .first<{ games: number; scores: number; players: number; devices: number }>();
    if (agg) Object.assign(totals, agg);

    // Full retention funnel: 2–7 distinct play-days, single query.
    // `returning` (2+) and `loyal` (7+) kept for backwards-compat.
    const funnel = await env.DB
      .prepare(
        `SELECT
           COUNT(CASE WHEN d >= 2 THEN 1 END) AS r2,
           COUNT(CASE WHEN d >= 3 THEN 1 END) AS r3,
           COUNT(CASE WHEN d >= 4 THEN 1 END) AS r4,
           COUNT(CASE WHEN d >= 5 THEN 1 END) AS r5,
           COUNT(CASE WHEN d >= 6 THEN 1 END) AS r6,
           COUNT(CASE WHEN d >= 7 THEN 1 END) AS r7
         FROM (
           SELECT ip_hash, COUNT(DISTINCT DATE(timestamp, 'unixepoch')) AS d
           FROM scores ${w} GROUP BY ip_hash
         )`
      )
      .first<{ r2:number; r3:number; r4:number; r5:number; r6:number; r7:number }>();
    if (funnel) {
      totals.returning = funnel.r2;
      totals.ret3      = funnel.r3;
      totals.ret4      = funnel.r4;
      totals.ret5      = funnel.r5;
      totals.ret6      = funnel.r6;
      totals.loyal     = funnel.r7;
    }

    // New players in the last 7 days (ip_hash whose first score arrived ≤7d ago).
    const now7d = Date.now() - 7 * 86400 * 1000;
    const newP = await env.DB
      .prepare(
        `SELECT COUNT(*) AS cnt FROM (
           SELECT ip_hash FROM scores ${w}
           GROUP BY ip_hash
           HAVING MIN(timestamp) > ?
         )`
      )
      .bind(now7d)
      .first<{ cnt: number }>();
    if (newP) totals.newPlayers7d = newP.cnt;

    // Average daily actives (distinct ip_hash per calendar day) over last 30 days.
    const now30d = Date.now() - 30 * 86400 * 1000;
    const dauRow = await env.DB
      .prepare(
        `SELECT ROUND(AVG(n), 1) AS dau FROM (
           SELECT DATE(timestamp, 'unixepoch') AS day,
                  COUNT(DISTINCT ip_hash)      AS n
           FROM scores
           WHERE timestamp > ? ${wa}
           GROUP BY day
         )`
      )
      .bind(now30d)
      .first<{ dau: number }>();
    if (dauRow?.dau) totals.dau30d = dauRow.dau;

    // Average scores per player (engagement depth).
    const avgRow = await env.DB
      .prepare(
        `SELECT ROUND(CAST(COUNT(*) AS REAL) / MAX(1, COUNT(DISTINCT ip_hash)), 1) AS avg
         FROM scores ${w}`
      )
      .first<{ avg: number }>();
    if (avgRow?.avg) totals.avgScoresPerPlayer = avgRow.avg;

    // Lifetime activity from launches (not reset by score season wipes).
    // Keep this independent from `scores`, so owner can still see active users
    // and game opens even when the leaderboard is intentionally reset.
    try {
      const life = await env.DB
        .prepare(
          `SELECT COUNT(DISTINCT game)    AS lifetimeGames,
                  COUNT(DISTINCT ip_hash) AS lifetimePlayers,
                  COUNT(*)                AS lifetimeLaunches
           FROM launches`
        )
        .first<{
          lifetimeGames: number;
          lifetimePlayers: number;
          lifetimeLaunches: number;
        }>();
      if (life) Object.assign(totals, life);
    } catch (e) {
      // Don't fail /stats if launches table is unavailable in a local/older DB.
      console.warn("lifetime launches stats unavailable:", e);
    }

  } catch (e) {
    console.error("DB stats error:", e);
    return err("db error", 500);
  }

  return json(
    { updated: Math.floor(Date.now() / 1000), totals, perGame, perCountry },
    200,
    { "Cache-Control": `public, max-age=${LEADERBOARD_CACHE_S}, stale-while-revalidate=60` }
  );
}

// ── Hall of Fame ────────────────────────────────────────────────────────────
// GET /hof — public, returns all entries ordered by game then added_at DESC.
async function handleGetHoF(env: Env): Promise<Response> {
  try {
    const rows = await env.DB
      .prepare(`SELECT id, game, variant, user, score, country, added_at, note
                FROM hall_of_fame ORDER BY game ASC, variant ASC, added_at DESC`)
      .all<{ id:number; game:string; variant:string; user:string; score:number;
             country:string|null; added_at:number; note:string|null }>();
    return json({ entries: rows.results ?? [] });
  } catch (e) {
    console.error("hof get error:", e);
    return err("db error", 500);
  }
}

// POST /hof — authenticated.
// Mode A (add single): { game, variant?, user, score, country?, note? }
// Mode B (promote):    { promote: true, note? }
//   → finds the best real score per game+variant from `scores` and inserts them.
async function handlePostHoF(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let body: Record<string, unknown>;
  try { body = await req.json() as Record<string, unknown>; } catch { return err("invalid JSON"); }

  const note = typeof body.note === "string" ? body.note.trim().slice(0, 120) || null : null;

  // ── Mode B: promote current best per game/variant ──────────────────────────
  if (body.promote === true) {
    try {
      const leaders = await env.DB
        .prepare(
          `SELECT game, variant,
                  user, MAX(score) AS score, country
           FROM scores
           WHERE is_bot = 0
           GROUP BY game, variant
           ORDER BY game ASC, variant ASC`
        )
        .all<{ game:string; variant:string; user:string; score:number; country:string|null }>();

      const rows = leaders.results ?? [];
      if (!rows.length) return json({ ok: true, promoted: 0 });

      const now = Date.now();
      const stmt = env.DB.prepare(
        "INSERT INTO hall_of_fame (game, variant, user, score, country, added_at, note) VALUES (?, ?, ?, ?, ?, ?, ?)"
      );
      // D1 batch insert
      await env.DB.batch(
        rows.map(r => stmt.bind(r.game, r.variant ?? "", r.user, r.score, r.country ?? null, now, note))
      );
      return json({ ok: true, promoted: rows.length });
    } catch (e) {
      console.error("hof promote error:", e);
      return err("db error", 500);
    }
  }

  // ── Mode A: add single entry ───────────────────────────────────────────────
  const gameRaw = typeof body.game === "string" ? body.game.trim() : "";
  const game    = sanitizeGame(gameRaw);
  if (!game) return err("missing/invalid: game");

  const user  = typeof body.user  === "string" ? body.user.trim().slice(0, 40)  : "";
  const score = typeof body.score === "number" ? Math.round(body.score) : NaN;
  if (!user)        return err("missing: user");
  if (isNaN(score)) return err("missing/invalid: score");

  const variant = typeof body.variant === "string" ? body.variant.trim().slice(0, 40) : "";
  const country = typeof body.country === "string" && body.country.length === 2
    ? body.country.toUpperCase() : null;

  try {
    const run = await env.DB
      .prepare("INSERT INTO hall_of_fame (game, variant, user, score, country, added_at, note) VALUES (?, ?, ?, ?, ?, ?, ?)")
      .bind(game, variant, user, score, country, Date.now(), note)
      .run();
    return json({ ok: true, id: run.meta?.last_row_id ?? null });
  } catch (e) {
    console.error("hof insert error:", e);
    return err("db error", 500);
  }
}

// DELETE /hof — authenticated. Body: { id }
async function handleDeleteHoF(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let body: Record<string, unknown>;
  try { body = await req.json() as Record<string, unknown>; } catch { return err("invalid JSON"); }

  const id = typeof body.id === "number" ? body.id : parseInt(String(body.id), 10);
  if (!id || isNaN(id)) return err("missing/invalid: id");

  try {
    await env.DB.prepare("DELETE FROM hall_of_fame WHERE id = ?").bind(id).run();
    return json({ ok: true });
  } catch (e) {
    console.error("hof delete error:", e);
    return err("db error", 500);
  }
}

// ── Season snapshot ────────────────────────────────────────────────────────
// POST /snapshot { label? } — captures the current real-only stats as a
// permanent record. Called automatically by reset-stats.sh before a wipe so
// retention / engagement metrics survive season resets.
async function handleSnapshot(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let label: string | null = null;
  try {
    const body = await req.json() as Record<string, unknown>;
    if (typeof body.label === "string") label = body.label.trim().slice(0, 100) || null;
  } catch { /* label is optional */ }

  const w = "WHERE is_bot = 0";
  try {
    const [aggRow, funnelRow, topGames, topCountries] = await Promise.all([
      env.DB.prepare(
        `SELECT COUNT(DISTINCT game) AS games, COUNT(*) AS scores,
                COUNT(DISTINCT user) AS players, COUNT(DISTINCT ip_hash) AS devices
         FROM scores ${w}`
      ).first<{ games:number; scores:number; players:number; devices:number }>(),

      env.DB.prepare(
        `SELECT COUNT(CASE WHEN d >= 2 THEN 1 END) AS r2,
                COUNT(CASE WHEN d >= 3 THEN 1 END) AS r3,
                COUNT(CASE WHEN d >= 4 THEN 1 END) AS r4,
                COUNT(CASE WHEN d >= 5 THEN 1 END) AS r5,
                COUNT(CASE WHEN d >= 6 THEN 1 END) AS r6,
                COUNT(CASE WHEN d >= 7 THEN 1 END) AS r7
         FROM (SELECT ip_hash, COUNT(DISTINCT DATE(timestamp,'unixepoch')) AS d
               FROM scores ${w} GROUP BY ip_hash)`
      ).first<{ r2:number; r3:number; r4:number; r5:number; r6:number; r7:number }>(),

      env.DB.prepare(
        `SELECT game, COUNT(DISTINCT ip_hash) AS players, COUNT(*) AS scores
         FROM scores ${w} GROUP BY game ORDER BY players DESC LIMIT 20`
      ).all<{ game:string; players:number; scores:number }>(),

      env.DB.prepare(
        `SELECT country, COUNT(DISTINCT ip_hash) AS players, COUNT(*) AS scores
         FROM scores ${w} GROUP BY country ORDER BY players DESC LIMIT 15`
      ).all<{ country:string; players:number; scores:number }>(),
    ]);

    const totals = {
      games:    aggRow?.games    ?? 0,
      scores:   aggRow?.scores   ?? 0,
      players:  aggRow?.players  ?? 0,
      devices:  aggRow?.devices  ?? 0,
      returning: funnelRow?.r2   ?? 0,
      ret3:      funnelRow?.r3   ?? 0,
      ret4:      funnelRow?.r4   ?? 0,
      ret5:      funnelRow?.r5   ?? 0,
      ret6:      funnelRow?.r6   ?? 0,
      loyal:     funnelRow?.r7   ?? 0,
    };

    const data = JSON.stringify({
      totals,
      topGames:     topGames.results     ?? [],
      topCountries: topCountries.results ?? [],
    });

    const run = await env.DB
      .prepare("INSERT INTO snapshots (taken_at, label, data) VALUES (?, ?, ?)")
      .bind(Date.now(), label, data)
      .run();

    return json({ ok: true, id: run.meta?.last_row_id ?? null, label });
  } catch (e) {
    console.error("snapshot error:", e);
    return err("db error", 500);
  }
}

// ── Season reset ───────────────────────────────────────────────────────────
// POST /reset { game?, snapshot?, note? }
//   game     — if set, wipe only that game; otherwise wipe everything.
//   snapshot — if true, saves a named snapshot before wiping.
//   note     — label for the snapshot (optional).
// Requires X-LB-Key authentication.
async function handleReset(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let body: Record<string, unknown> = {};
  try { body = await req.json() as Record<string, unknown>; } catch { /* no body is fine */ }

  const game     = typeof body.game     === "string" ? body.game.trim()   : null;
  const doSnap   = body.snapshot !== false;  // default true
  const note     = typeof body.note     === "string" ? body.note.trim()   : null;

  // ── Optional pre-reset snapshot ─────────────────────────────────────────
  let snapId: number | null = null;
  if (doSnap) {
    const w   = "WHERE is_bot = 0";
    const wg  = game ? `WHERE is_bot = 0 AND game = ?` : w;
    const label = note ?? (game ? `${game}-reset-${new Date().toISOString().slice(0,10)}` : `season-reset-${new Date().toISOString().slice(0,10)}`);
    try {
      const [aggRow, funnelRow, topGames, topCountries] = await Promise.all([
        (game
          ? env.DB.prepare(`SELECT COUNT(DISTINCT game) AS games, COUNT(*) AS scores, COUNT(DISTINCT user) AS players, COUNT(DISTINCT ip_hash) AS devices FROM scores ${wg}`).bind(game)
          : env.DB.prepare(`SELECT COUNT(DISTINCT game) AS games, COUNT(*) AS scores, COUNT(DISTINCT user) AS players, COUNT(DISTINCT ip_hash) AS devices FROM scores ${w}`)
        ).first<{ games:number; scores:number; players:number; devices:number }>(),
        (game
          ? env.DB.prepare(`SELECT COUNT(CASE WHEN d>=2 THEN 1 END) AS r2, COUNT(CASE WHEN d>=3 THEN 1 END) AS r3, COUNT(CASE WHEN d>=4 THEN 1 END) AS r4, COUNT(CASE WHEN d>=5 THEN 1 END) AS r5, COUNT(CASE WHEN d>=6 THEN 1 END) AS r6, COUNT(CASE WHEN d>=7 THEN 1 END) AS r7 FROM (SELECT ip_hash, COUNT(DISTINCT DATE(timestamp,'unixepoch')) AS d FROM scores WHERE is_bot=0 AND game=? GROUP BY ip_hash)`).bind(game)
          : env.DB.prepare(`SELECT COUNT(CASE WHEN d>=2 THEN 1 END) AS r2, COUNT(CASE WHEN d>=3 THEN 1 END) AS r3, COUNT(CASE WHEN d>=4 THEN 1 END) AS r4, COUNT(CASE WHEN d>=5 THEN 1 END) AS r5, COUNT(CASE WHEN d>=6 THEN 1 END) AS r6, COUNT(CASE WHEN d>=7 THEN 1 END) AS r7 FROM (SELECT ip_hash, COUNT(DISTINCT DATE(timestamp,'unixepoch')) AS d FROM scores ${w} GROUP BY ip_hash)`)
        ).first<{ r2:number; r3:number; r4:number; r5:number; r6:number; r7:number }>(),
        (game
          ? env.DB.prepare(`SELECT game, COUNT(DISTINCT ip_hash) AS players, COUNT(*) AS scores FROM scores WHERE is_bot=0 AND game=? GROUP BY game ORDER BY players DESC LIMIT 20`).bind(game)
          : env.DB.prepare(`SELECT game, COUNT(DISTINCT ip_hash) AS players, COUNT(*) AS scores FROM scores ${w} GROUP BY game ORDER BY players DESC LIMIT 20`)
        ).all<{ game:string; players:number; scores:number }>(),
        env.DB.prepare(`SELECT country, COUNT(DISTINCT ip_hash) AS players, COUNT(*) AS scores FROM scores ${w} GROUP BY country ORDER BY players DESC LIMIT 15`).all<{ country:string; players:number; scores:number }>(),
      ]);
      const data = JSON.stringify({
        totals: { games: aggRow?.games??0, scores: aggRow?.scores??0, players: aggRow?.players??0, devices: aggRow?.devices??0, returning: funnelRow?.r2??0, ret3: funnelRow?.r3??0, ret4: funnelRow?.r4??0, ret5: funnelRow?.r5??0, ret6: funnelRow?.r6??0, loyal: funnelRow?.r7??0 },
        topGames:     topGames.results     ?? [],
        topCountries: topCountries.results ?? [],
      });
      const run = await env.DB.prepare("INSERT INTO snapshots (taken_at, label, data) VALUES (?, ?, ?)").bind(Date.now(), label, data).run();
      snapId = run.meta?.last_row_id ?? null;
    } catch (e) {
      console.warn("pre-reset snapshot failed:", e);
    }
  }

  // ── Delete scores ────────────────────────────────────────────────────────
  try {
    if (game) {
      await env.DB.prepare("DELETE FROM scores WHERE game = ?").bind(game).run();
    } else {
      await env.DB.prepare("DELETE FROM scores").run();
      await env.DB.prepare("DELETE FROM sqlite_sequence WHERE name='scores'").run().catch(() => {/* optional */});
    }
    // Log the reset so games can detect "the board was wiped since I last
    // played" and show the configured 'reset' re-engagement message once.
    // A NULL game means a global reset (affects every game's lookup).
    try {
      await env.DB.prepare("INSERT INTO resets (game, at) VALUES (?, ?)")
        .bind(game ?? null, Date.now()).run();
    } catch (e) { console.warn("reset log failed:", e); }
    return json({ ok: true, scope: game ?? "all", snapshotId: snapId });
  } catch (e) {
    console.error("reset error:", e);
    return err("db error", 500);
  }
}

// GET /snapshots — returns all historical season snapshots, newest first.
// No auth required — data is just aggregated stats, nothing sensitive.
async function handleGetSnapshots(env: Env): Promise<Response> {
  try {
    const rows = await env.DB
      .prepare("SELECT id, taken_at, label, data FROM snapshots ORDER BY taken_at DESC LIMIT 50")
      .all<{ id:number; taken_at:number; label:string|null; data:string }>();

    const snapshots = (rows.results ?? []).map(r => ({
      id:       r.id,
      taken_at: r.taken_at,
      label:    r.label,
      data:     (() => { try { return JSON.parse(r.data); } catch { return {}; } })(),
    }));

    return json({ snapshots });
  } catch (e) {
    console.error("snapshots read error:", e);
    return err("db error", 500);
  }
}
// POST /launch { game } — fire-and-forget ping the shared lib sends on app
// start. Records that a game was opened so we can see play activity even for
// games/sessions that never submit a score. Auth: same shared submit key.
async function handleLaunch(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let body: unknown;
  try { body = await req.json(); } catch { return err("invalid JSON"); }
  const b = body as Record<string, unknown>;

  const gameRaw = typeof b.game === "string" ? b.game.trim() : "";
  const game = sanitizeGame(gameRaw);
  if (!game) return err("missing/invalid: game");

  const ip      = req.headers.get("CF-Connecting-IP") ?? "0.0.0.0";
  const ipHash  = await hashIp(ip, env.IP_SALT ?? env.LB_KEY ?? "bito-lb");
  const cf      = (req as unknown as { cf?: { country?: string } }).cf;
  const country = (cf && typeof cf.country === "string" && cf.country.length === 2)
    ? cf.country : null;

  try {
    await env.DB
      .prepare("INSERT INTO launches (game, timestamp, ip_hash, country) VALUES (?, ?, ?, ?)")
      .bind(game, Date.now(), ipHash, country)
      .run();
  } catch (e) {
    console.error("launch insert error:", e);
    return err("db error", 500);
  }
  return json({ ok: true });
}

// GET /launches — aggregate launch activity for the admin page. Returns play
// counts (and unique-device counts) split by game and by country, plus totals.
// This is independent of the scores table, so it surfaces games that are being
// played even when the leaderboard never receives a submission.
async function handleGetLaunchStats(url: URL, env: Env): Promise<Response> {
  type ByGame    = { game: string; launches: number; players: number };
  type ByCountry = { country: string | null; launches: number; players: number };
  let byGame: ByGame[] = [];
  let byCountry: ByCountry[] = [];
  let totals = { launches: 0, games: 0, players: 0 };

  try {
    const g = await env.DB
      .prepare(
        `SELECT game,
                COUNT(*)                AS launches,
                COUNT(DISTINCT ip_hash) AS players
         FROM launches
         GROUP BY game
         ORDER BY launches DESC`
      )
      .all<ByGame>();
    byGame = g.results ?? [];

    const c = await env.DB
      .prepare(
        `SELECT country,
                COUNT(*)                AS launches,
                COUNT(DISTINCT ip_hash) AS players
         FROM launches
         GROUP BY country
         ORDER BY launches DESC`
      )
      .all<ByCountry>();
    byCountry = c.results ?? [];

    const agg = await env.DB
      .prepare(
        `SELECT COUNT(*)                AS launches,
                COUNT(DISTINCT game)    AS games,
                COUNT(DISTINCT ip_hash) AS players
         FROM launches`
      )
      .first<typeof totals>();
    if (agg) totals = agg;
  } catch (e) {
    console.error("launch stats error:", e);
    return err("db error", 500);
  }

  return json({ updated: Math.floor(Date.now() / 1000), totals, byGame, byCountry });
}

async function handleGetVariants(url: URL, env: Env): Promise<Response> {
  const gameRaw  = (url.searchParams.get("game") ?? "").trim();
  if (!gameRaw) return err("missing: game");

  const game = sanitizeGame(gameRaw);
  if (!game)   return err("invalid game name");

  const realOnly  = url.searchParams.get("real") === "1";
  const botClause = realOnly ? " AND is_bot = 0" : "";

  let variants: string[] = [];
  try {
    const result = await env.DB
      .prepare(
        `SELECT DISTINCT variant FROM scores WHERE game = ? AND variant != ''${botClause} ORDER BY variant ASC`
      )
      .bind(game)
      .all<{ variant: string }>();
    variants = (result.results ?? []).map(r => r.variant);
  } catch (e) {
    console.error("DB query error:", e);
    return err("db error", 500);
  }

  return json({ game, variants });
}

// ── Custom messages / announcements ───────────────────────────────────────────
// The shared client fetches these on launch and shows them at the right moment
// (launch / postgame / reset). Owner-configurable from stats.html.

type MsgRow = {
  id: number; scope: string; game: string | null; placement: string;
  title: string; body: string; url: string | null; url_label: string | null;
  weight: number; min_gap_s: number; active: number;
  starts_at: number | null; ends_at: number | null;
  created_at: number; updated_at: number;
};

const MSG_PLACEMENTS = new Set(["launch", "postgame", "reset"]);

// Compact shape the watch client consumes (keeps the payload tiny).
function slimMsg(m: MsgRow | undefined): unknown {
  if (!m) return null;
  return {
    id:        m.id,
    title:     m.title,
    body:      m.body,
    url:       m.url,
    url_label: m.url_label,
    min_gap_s: m.min_gap_s,
  };
}

// GET /messages
//   ?game=X            → resolved bundle for a game: one best message per
//                        placement (launch/postgame/reset) + reset_at.
//   ?all=1             → every row, for the stats.html admin editor.
async function handleGetMessages(url: URL, env: Env): Promise<Response> {
  if (url.searchParams.get("all") === "1") {
    try {
      const rows = await env.DB
        .prepare("SELECT * FROM messages ORDER BY scope ASC, game ASC, placement ASC, weight DESC, id DESC")
        .all<MsgRow>();
      return json({ messages: rows.results ?? [] });
    } catch (e) {
      console.error("messages list error:", e);
      return err("db error", 500);
    }
  }

  const gameRaw = (url.searchParams.get("game") ?? "").trim();
  const game    = sanitizeGame(gameRaw);
  const now     = Date.now();

  let launch: unknown = null;
  let postgame: unknown = null;
  let reset: unknown = null;
  let reset_at = 0;

  try {
    // Active messages that apply to this game (global OR this game's own),
    // within their optional time window. Game-scoped rows sort first so they
    // win over a global message for the same placement.
    const rows = await env.DB
      .prepare(
        `SELECT * FROM messages
         WHERE active = 1
           AND (scope = 'global' OR (scope = 'game' AND game = ?))
           AND (starts_at IS NULL OR starts_at <= ?)
           AND (ends_at   IS NULL OR ends_at   >= ?)
         ORDER BY (scope = 'game') DESC, weight DESC, id DESC`
      )
      .bind(game, now, now)
      .all<MsgRow>();

    const picked: Record<string, MsgRow> = {};
    for (const r of rows.results ?? []) {
      if (!picked[r.placement]) picked[r.placement] = r;
    }
    launch   = slimMsg(picked["launch"]);
    postgame = slimMsg(picked["postgame"]);
    reset    = slimMsg(picked["reset"]);

    // Latest reset that affects this game (its own reset or a global one).
    const rr = await env.DB
      .prepare("SELECT MAX(at) AS at FROM resets WHERE game IS NULL OR game = ?")
      .bind(game)
      .first<{ at: number | null }>();
    reset_at = rr?.at ?? 0;
  } catch (e) {
    console.error("messages resolve error:", e);
    return err("db error", 500);
  }

  return json(
    { ts: Math.floor(now / 1000), reset_at, launch, postgame, reset },
    200,
    { "Cache-Control": "public, max-age=120, stale-while-revalidate=300" }
  );
}

// POST /messages — authenticated create/update (upsert by id).
// Body: { id?, scope, game?, placement, title, body?, url?, url_label?,
//         weight?, min_gap_s?, active?, starts_at?, ends_at? }
async function handlePostMessage(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let b: Record<string, unknown>;
  try { b = await req.json() as Record<string, unknown>; } catch { return err("invalid JSON"); }

  const scope = b.scope === "game" ? "game" : "global";
  const placement = typeof b.placement === "string" ? b.placement.trim() : "";
  if (!MSG_PLACEMENTS.has(placement)) return err("invalid placement");

  const title = typeof b.title === "string" ? b.title.trim().slice(0, 60) : "";
  if (!title) return err("missing: title");

  const game = scope === "game"
    ? sanitizeGame(typeof b.game === "string" ? b.game.trim() : "")
    : null;
  if (scope === "game" && !game) return err("missing/invalid: game (required for scope=game)");

  const body      = typeof b.body === "string" ? b.body.slice(0, 200) : "";
  const urlv      = typeof b.url === "string" && b.url.trim() ? b.url.trim().slice(0, 200) : null;
  const urlLabel  = typeof b.url_label === "string" && b.url_label.trim() ? b.url_label.trim().slice(0, 40) : null;
  const weight    = typeof b.weight === "number" ? Math.round(b.weight) : 0;
  const minGap    = typeof b.min_gap_s === "number" && b.min_gap_s >= 0 ? Math.round(b.min_gap_s) : 21600;
  const active    = b.active === false || b.active === 0 ? 0 : 1;
  const startsAt  = typeof b.starts_at === "number" ? Math.round(b.starts_at) : null;
  const endsAt    = typeof b.ends_at === "number" ? Math.round(b.ends_at) : null;
  const now       = Date.now();

  try {
    const id = typeof b.id === "number" ? b.id : (b.id ? parseInt(String(b.id), 10) : NaN);
    if (!isNaN(id) && id > 0) {
      await env.DB
        .prepare(
          `UPDATE messages SET scope=?, game=?, placement=?, title=?, body=?, url=?,
             url_label=?, weight=?, min_gap_s=?, active=?, starts_at=?, ends_at=?, updated_at=?
           WHERE id=?`
        )
        .bind(scope, game, placement, title, body, urlv, urlLabel, weight, minGap, active, startsAt, endsAt, now, id)
        .run();
      return json({ ok: true, id });
    }
    const run = await env.DB
      .prepare(
        `INSERT INTO messages (scope, game, placement, title, body, url, url_label,
           weight, min_gap_s, active, starts_at, ends_at, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(scope, game, placement, title, body, urlv, urlLabel, weight, minGap, active, startsAt, endsAt, now, now)
      .run();
    return json({ ok: true, id: run.meta?.last_row_id ?? null });
  } catch (e) {
    console.error("message upsert error:", e);
    return err("db error", 500);
  }
}

// DELETE /messages — authenticated. Body: { id }
async function handleDeleteMessage(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let b: Record<string, unknown>;
  try { b = await req.json() as Record<string, unknown>; } catch { return err("invalid JSON"); }
  const id = typeof b.id === "number" ? b.id : parseInt(String(b.id), 10);
  if (!id || isNaN(id)) return err("missing/invalid: id");

  try {
    await env.DB.prepare("DELETE FROM messages WHERE id = ?").bind(id).run();
    return json({ ok: true });
  } catch (e) {
    console.error("message delete error:", e);
    return err("db error", 500);
  }
}

// ── Redirect links / short URLs ───────────────────────────────────────────────
// Branded, trackable redirects. Messages link to bitochi.com/<slug> (a static
// page that forwards to /go/<slug>); this handler 302s to the configured
// destination and counts the click, so the target can be changed in one place
// (D1 / stats.html) without editing messages or rebuilding any app.

const LINK_FALLBACK = "https://bitochi.com";

function sanitizeSlug(raw: string): string {
  return raw.toLowerCase().replace(/[^a-z0-9_-]/g, "").slice(0, 40);
}

// GET /go/<slug>
async function handleGo(slugRaw: string, env: Env): Promise<Response> {
  const slug = sanitizeSlug(slugRaw);
  if (!slug) return Response.redirect(LINK_FALLBACK, 302);
  try {
    const row = await env.DB
      .prepare("SELECT url FROM links WHERE slug = ?")
      .bind(slug)
      .first<{ url: string }>();
    if (!row || !row.url) return Response.redirect(LINK_FALLBACK, 302);
    // Count the click (small, fast — worth awaiting so it isn't dropped after
    // the response is returned).
    try {
      await env.DB
        .prepare("UPDATE links SET clicks = clicks + 1, updated_at = ? WHERE slug = ?")
        .bind(Date.now(), slug)
        .run();
    } catch (_) { /* never block the redirect on a stats write */ }
    return Response.redirect(row.url, 302);
  } catch (e) {
    console.error("go redirect error:", e);
    return Response.redirect(LINK_FALLBACK, 302);
  }
}

// GET /links — all redirects (public; used by stats.html and harmless to expose).
async function handleGetLinks(env: Env): Promise<Response> {
  try {
    const rows = await env.DB
      .prepare("SELECT slug, url, clicks, updated_at FROM links ORDER BY clicks DESC, slug ASC")
      .all<{ slug: string; url: string; clicks: number; updated_at: number }>();
    return json({ links: rows.results ?? [] });
  } catch (e) {
    console.error("links list error:", e);
    return err("db error", 500);
  }
}

// POST /links — authenticated upsert. Body: { slug, url }
async function handlePostLink(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let b: Record<string, unknown>;
  try { b = await req.json() as Record<string, unknown>; } catch { return err("invalid JSON"); }

  const slug = sanitizeSlug(typeof b.slug === "string" ? b.slug.trim() : "");
  if (!slug) return err("missing/invalid: slug");
  const url = typeof b.url === "string" ? b.url.trim().slice(0, 400) : "";
  if (!/^https?:\/\//i.test(url)) return err("url must start with http(s)://");

  const now = Date.now();
  try {
    await env.DB
      .prepare(
        `INSERT INTO links (slug, url, clicks, created_at, updated_at)
         VALUES (?, ?, 0, ?, ?)
         ON CONFLICT(slug) DO UPDATE SET url = excluded.url, updated_at = excluded.updated_at`
      )
      .bind(slug, url, now, now)
      .run();
    return json({ ok: true, slug });
  } catch (e) {
    console.error("link upsert error:", e);
    return err("db error", 500);
  }
}

// DELETE /links — authenticated. Body: { slug }
async function handleDeleteLink(req: Request, env: Env): Promise<Response> {
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let b: Record<string, unknown>;
  try { b = await req.json() as Record<string, unknown>; } catch { return err("invalid JSON"); }
  const slug = sanitizeSlug(typeof b.slug === "string" ? b.slug.trim() : "");
  if (!slug) return err("missing/invalid: slug");

  try {
    await env.DB.prepare("DELETE FROM links WHERE slug = ?").bind(slug).run();
    return json({ ok: true });
  } catch (e) {
    console.error("link delete error:", e);
    return err("db error", 500);
  }
}

// ── Main entry ────────────────────────────────────────────────────────────────

// ── Error log reader ─────────────────────────────────────────────────────────
// GET /errors?limit=100&game=xyz  — private endpoint for stats.html monitoring.
// Returns recent api_errors rows (newest first) plus per-game error counts for
// the last 24 h. No auth needed — data is anonymised (no raw IPs).
async function handleGetErrors(url: URL, env: Env): Promise<Response> {
  const limitRaw = parseInt(url.searchParams.get("limit") ?? "100", 10);
  const limit    = Math.min(Math.max(limitRaw, 1), 500);
  const gameFilter = (url.searchParams.get("game") ?? "").trim();
  const since24h   = Date.now() - 24 * 3600 * 1000;

  try {
    const [recentRes, summaryRes] = await Promise.all([
      // Recent error rows
      gameFilter
        ? env.DB.prepare(
            "SELECT id, timestamp, game, error_code, error_msg FROM api_errors WHERE game = ? ORDER BY timestamp DESC LIMIT ?"
          ).bind(gameFilter, limit).all<{ id: number; timestamp: number; game: string; error_code: number; error_msg: string }>()
        : env.DB.prepare(
            "SELECT id, timestamp, game, error_code, error_msg FROM api_errors ORDER BY timestamp DESC LIMIT ?"
          ).bind(limit).all<{ id: number; timestamp: number; game: string; error_code: number; error_msg: string }>(),

      // Per-game summary for last 24 h
      env.DB.prepare(
        `SELECT game, error_code, COUNT(*) AS cnt
         FROM api_errors WHERE timestamp > ?
         GROUP BY game, error_code
         ORDER BY cnt DESC LIMIT 100`
      ).bind(since24h).all<{ game: string; error_code: number; cnt: number }>(),
    ]);

    return json({
      recent:  recentRes.results  ?? [],
      summary: summaryRes.results ?? [],
    });
  } catch (e) {
    return err("db error", 500);
  }
}

// ── Visitor tracking ─────────────────────────────────────────────────────────
// GET /visit  — fire-and-forget from the web frontend on page load.
// Records an anonymised visit and returns { total, online } where
// online = unique IP hashes seen in the last 5 minutes.
// Deduplication: same IP counted at most once per 30-minute window.
async function handleVisit(req: Request, env: Env): Promise<Response> {
  const ip      = req.headers.get("CF-Connecting-IP") ?? "unknown";
  const salt    = env.IP_SALT ?? env.LB_KEY ?? "bito-visit";
  const ipHash  = await hashIp(ip, salt);
  const now     = Date.now();
  const window5  = now - 5  * 60 * 1000;   // 5 min  → online window
  const window30 = now - 30 * 60 * 1000;   // 30 min → dedup window
  const cutoff7  = now - 7  * 24 * 3600 * 1000; // 7 days → prune

  // Only insert if this IP hasn't been seen in the last 30 minutes.
  const recent = await env.DB.prepare(
    "SELECT 1 FROM visits WHERE ip_hash = ? AND timestamp > ? LIMIT 1"
  ).bind(ipHash, window30).first();

  if (!recent) {
    await env.DB.prepare(
      "INSERT INTO visits (ip_hash, timestamp) VALUES (?, ?)"
    ).bind(ipHash, now).run();

    // Prune old rows (only bother when we actually insert, not every request).
    await env.DB.prepare(
      "DELETE FROM visits WHERE timestamp < ?"
    ).bind(cutoff7).run();
  }

  const [totalRow, onlineRow] = await Promise.all([
    env.DB.prepare("SELECT COUNT(*) AS n FROM visits").first<{ n: number }>(),
    env.DB.prepare(
      "SELECT COUNT(DISTINCT ip_hash) AS n FROM visits WHERE timestamp > ?"
    ).bind(window5).first<{ n: number }>(),
  ]);

  return json({ total: totalRow?.n ?? 0, online: onlineRow?.n ?? 0 });
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url    = new URL(req.url);
    const path   = url.pathname;
    const method = req.method.toUpperCase();

    if (method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin":  "*",
          "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type, X-LB-Key",
        },
      });
    }

    const ip = req.headers.get("CF-Connecting-IP") ?? "unknown";
    if (!checkRateLimit(ip)) {
      // Log rate-limit hit (fire-and-forget, don't await on hot path)
      const ipH = await hashIp(ip, env.IP_SALT ?? env.LB_KEY ?? "bito-lb");
      await logError(env, null, 429, "rate limit exceeded", ipH);
      return err("rate limit exceeded — try again shortly", 429);
    }

    if (method === "POST"   && path === "/score")       return handlePostScore(req, env);
    if (method === "POST"   && path === "/launch")      return handleLaunch(req, env);
    if (method === "POST"   && path === "/snapshot")    return handleSnapshot(req, env);
    if (method === "POST"   && path === "/reset")       return handleReset(req, env);
    if (method === "POST"   && path === "/hof")         return handlePostHoF(req, env);
    if (method === "DELETE" && path === "/hof")         return handleDeleteHoF(req, env);
    if (method === "GET"    && path === "/messages")    return handleGetMessages(url, env);
    if (method === "POST"   && path === "/messages")    return handlePostMessage(req, env);
    if (method === "DELETE" && path === "/messages")    return handleDeleteMessage(req, env);
    if (method === "GET"    && path.startsWith("/go/")) return handleGo(path.slice(4), env);
    if (method === "GET"    && path === "/links")       return handleGetLinks(env);
    if (method === "POST"   && path === "/links")       return handlePostLink(req, env);
    if (method === "DELETE" && path === "/links")       return handleDeleteLink(req, env);
    if (method === "GET"    && path === "/leaderboard") return handleGetLeaderboard(url, env);
    if (method === "GET"    && path === "/standing")    return handleGetStanding(url, env);
    if (method === "GET"    && path === "/recent")      return handleGetRecent(url, env);
    if (method === "GET"    && path === "/games")       return handleGetGames(env);
    if (method === "GET"    && path === "/stats")       return handleGetStats(url, env);
    if (method === "GET"    && path === "/launches")    return handleGetLaunchStats(url, env);
    if (method === "GET"    && path === "/snapshots")   return handleGetSnapshots(env);
    if (method === "GET"    && path === "/hof")         return handleGetHoF(env);
    if (method === "GET"    && path === "/variants")    return handleGetVariants(url, env);
    if (method === "GET"    && path === "/visit")       return handleVisit(req, env);
    if (method === "GET"    && path === "/errors")      return handleGetErrors(url, env);
    if (method === "GET"    && path === "/health")      return json({ ok: true, ts: Date.now() });

    return err("not found", 404);
  },
} satisfies ExportedHandler<Env>;
