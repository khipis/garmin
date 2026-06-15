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
  "minigolf",
  "battleship",
  "twentyfortyeight_time",   // 2048 speedrun: fastest time to the 2048 tile
  "akari",                   // light-up puzzle: fastest solve time
  "nonogram",                // picross: fastest solve time
  "kakuro",                  // kakuro: fastest solve time
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

async function handlePostScore(req: Request, env: Env): Promise<Response> {
  // Anti-abuse: writes require the shared submit key. Fail closed if the
  // server has no key configured.
  const reqKey = req.headers.get("X-LB-Key") ?? "";
  if (!env.LB_KEY || reqKey !== env.LB_KEY) return err("forbidden", 403);

  let body: unknown;
  try { body = await req.json(); } catch { return err("invalid JSON"); }

  const b = body as Record<string, unknown>;

  const gameRaw    = typeof b.game    === "string" ? b.game.trim()    : "";
  const userRaw    = typeof b.user    === "string" ? b.user.trim()    : "anon";
  const variantRaw = typeof b.variant === "string" ? b.variant.trim() : "";
  const score      = typeof b.score   === "number"  ? b.score          : null;

  if (!gameRaw) return err("missing: game");
  if (score === null || !Number.isFinite(score)) return err("missing/invalid: score");

  const game    = sanitizeGame(gameRaw);
  if (!game)    return err("invalid game name");

  // Sanity bounds — keep clearly invalid scores off the boards. Negative
  // scores are never valid; lower-is-better games (fastest time / fewest
  // moves) can never be 0 either, so a 0 would otherwise pin rank #1 forever.
  // The upper cap guards against overflow / abuse.
  if (score < 0 || score > 1_000_000_000) return err("score out of range");
  if (ASC_GAMES.has(game) && score <= 0)  return err("invalid score for this game");

  const user    = sanitizeUser(userRaw || "anon");
  const variant = sanitizeVariant(variantRaw);

  if (GAME_KEYS[game] !== undefined) {
    if (b.key !== GAME_KEYS[game]) return err("invalid game key", 403);
  }

  const isBot   = b.is_bot === true ? 1 : 0;
  const ts      = Math.floor(Date.now() / 1000);
  const metaStr = b.meta && typeof b.meta === "object"
    ? JSON.stringify(b.meta).slice(0, 512)
    : null;

  const ip      = req.headers.get("CF-Connecting-IP") ?? "0.0.0.0";
  const ipHash  = await hashIp(ip, env.IP_SALT ?? env.LB_KEY ?? "bito-lb");
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
      .bind(game, user, Math.round(score), ts, variant, metaStr, ipHash, country, isBot)
      .run();
  } catch (e) {
    console.error("DB insert error:", e);
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

  type Row = { user: string; s: number; c: string | null };
  let top: { r: number; u: string; s: number; c: string | null }[] = [];
  let count = 0;
  let me: { r: number; s: number } | null = null;
  let near: { r: number; u: string; s: number; c: string | null }[] = [];

  try {
    const topRes = await env.DB
      .prepare(
        `SELECT user, ${bestFn} AS s, country AS c
         FROM scores WHERE ${where}
         GROUP BY user ORDER BY s ${order} LIMIT 10`
      )
      .bind(...wbind)
      .all<Row>();
    top = (topRes.results ?? []).map((r, i) => ({ r: i + 1, u: r.user, s: r.s, c: r.c }));

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
            `SELECT user, ${bestFn} AS s, country AS c
             FROM scores WHERE ${where}
             GROUP BY user ORDER BY s ${order} LIMIT 11 OFFSET ?`
          )
          .bind(...wbind, off)
          .all<Row>();
        near = (nearRes.results ?? []).map((r, i) => ({ r: off + i + 1, u: r.user, s: r.s, c: r.c }));
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
  let totals = { games: 0, scores: 0, players: 0, devices: 0 };

  const realOnly = url.searchParams.get("real") === "1";
  const botFilter = realOnly ? "WHERE is_bot = 0" : "";

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
      .first<typeof totals>();
    if (agg) totals = agg;
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

// ── Main entry ────────────────────────────────────────────────────────────────

// ── Visitor tracking ─────────────────────────────────────────────────────────
// GET /visit  — fire-and-forget from the web frontend on page load.
// Records an anonymised visit and returns { total, online } where
// online = unique IP hashes seen in the last 5 minutes.
async function handleVisit(req: Request, env: Env): Promise<Response> {
  const ip      = req.headers.get("CF-Connecting-IP") ?? "unknown";
  const salt    = env.IP_SALT ?? env.LB_KEY ?? "bito-visit";
  const ipHash  = await hashIp(ip, salt);
  const now     = Date.now();
  const window5 = now - 5 * 60 * 1000;   // 5 min online window
  const cutoff7 = now - 7 * 24 * 3600 * 1000; // keep 7 days max

  // Insert this visit (non-blocking — ctx.waitUntil not available in basic
  // Workers, so we just fire the writes and let them resolve naturally).
  await env.DB.prepare(
    "INSERT INTO visits (ip_hash, timestamp) VALUES (?, ?)"
  ).bind(ipHash, now).run();

  // Prune rows older than 7 days to keep the table small.
  await env.DB.prepare(
    "DELETE FROM visits WHERE timestamp < ?"
  ).bind(cutoff7).run();

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
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
        },
      });
    }

    const ip = req.headers.get("CF-Connecting-IP") ?? "unknown";
    if (!checkRateLimit(ip)) {
      return err("rate limit exceeded — try again shortly", 429);
    }

    if (method === "POST" && path === "/score")       return handlePostScore(req, env);
    if (method === "GET"  && path === "/leaderboard") return handleGetLeaderboard(url, env);
    if (method === "GET"  && path === "/recent")      return handleGetRecent(url, env);
    if (method === "GET"  && path === "/games")       return handleGetGames(env);
    if (method === "GET"  && path === "/stats")       return handleGetStats(url, env);
    if (method === "GET"  && path === "/variants")    return handleGetVariants(url, env);
    if (method === "GET"  && path === "/visit")       return handleVisit(req, env);
    if (method === "GET"  && path === "/health")      return json({ ok: true, ts: Date.now() });

    return err("not found", 404);
  },
} satisfies ExportedHandler<Env>;
