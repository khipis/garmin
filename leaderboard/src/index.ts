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

  const user    = sanitizeUser(userRaw || "anon");
  const variant = sanitizeVariant(variantRaw);

  if (GAME_KEYS[game] !== undefined) {
    if (b.key !== GAME_KEYS[game]) return err("invalid game key", 403);
  }

  const ts      = Math.floor(Date.now() / 1000);
  const metaStr = b.meta && typeof b.meta === "object"
    ? JSON.stringify(b.meta).slice(0, 512)
    : null;

  const ip      = req.headers.get("CF-Connecting-IP") ?? "0.0.0.0";
  const ipHash  = await hashIp(ip, env.IP_SALT ?? env.LB_KEY ?? "bito-lb");

  try {
    await env.DB
      .prepare(
        "INSERT INTO scores (game, user, score, timestamp, variant, meta, ip_hash) VALUES (?, ?, ?, ?, ?, ?, ?)"
      )
      .bind(game, user, Math.round(score), ts, variant, metaStr, ipHash)
      .run();
  } catch (e) {
    console.error("DB insert error:", e);
    return err("db error", 500);
  }

  return json({ ok: true });
}

async function handleGetLeaderboard(url: URL, env: Env): Promise<Response> {
  const gameRaw    = (url.searchParams.get("game")    ?? "").trim();
  const variantRaw = (url.searchParams.get("variant") ?? "").trim();

  if (!gameRaw) return err("missing: game");

  const game    = sanitizeGame(gameRaw);
  if (!game)    return err("invalid game name");

  const variant = sanitizeVariant(variantRaw);

  const order = ASC_GAMES.has(game) ? "ASC" : "DESC";

  let rows: { user: string; score: number }[] = [];
  try {
    const result = await env.DB
      .prepare(
        `SELECT user, score FROM scores WHERE game = ? AND variant = ? ORDER BY score ${order} LIMIT ?`
      )
      .bind(game, variant, TOP_N)
      .all<{ user: string; score: number }>();
    rows = result.results ?? [];
  } catch (e) {
    console.error("DB query error:", e);
    return err("db error", 500);
  }

  const top = rows.map((r, i) => ({ r: i + 1, u: r.user, s: r.score }));

  return json(
    { game, variant, updated: Math.floor(Date.now() / 1000), top },
    200,
    { "Cache-Control": `public, max-age=${LEADERBOARD_CACHE_S}, stale-while-revalidate=60` }
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
async function handleGetStats(env: Env): Promise<Response> {
  type PerGame = { game: string; scores: number; players: number; devices: number };
  let perGame: PerGame[] = [];
  let totals = { games: 0, scores: 0, players: 0, devices: 0 };

  try {
    const byGame = await env.DB
      .prepare(
        `SELECT game,
                COUNT(*)                  AS scores,
                COUNT(DISTINCT user)      AS players,
                COUNT(DISTINCT ip_hash)   AS devices
         FROM scores
         GROUP BY game
         ORDER BY players DESC, scores DESC`
      )
      .all<PerGame>();
    perGame = byGame.results ?? [];

    const agg = await env.DB
      .prepare(
        `SELECT COUNT(DISTINCT game)     AS games,
                COUNT(*)                 AS scores,
                COUNT(DISTINCT user)     AS players,
                COUNT(DISTINCT ip_hash)  AS devices
         FROM scores`
      )
      .first<typeof totals>();
    if (agg) totals = agg;
  } catch (e) {
    console.error("DB stats error:", e);
    return err("db error", 500);
  }

  return json(
    { updated: Math.floor(Date.now() / 1000), totals, perGame },
    200,
    { "Cache-Control": `public, max-age=${LEADERBOARD_CACHE_S}, stale-while-revalidate=60` }
  );
}

async function handleGetVariants(url: URL, env: Env): Promise<Response> {
  const gameRaw = (url.searchParams.get("game") ?? "").trim();
  if (!gameRaw) return err("missing: game");

  const game = sanitizeGame(gameRaw);
  if (!game)   return err("invalid game name");

  let variants: string[] = [];
  try {
    const result = await env.DB
      .prepare(
        "SELECT DISTINCT variant FROM scores WHERE game = ? AND variant != '' ORDER BY variant ASC"
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
    if (method === "GET"  && path === "/games")       return handleGetGames(env);
    if (method === "GET"  && path === "/stats")       return handleGetStats(env);
    if (method === "GET"  && path === "/variants")    return handleGetVariants(url, env);
    if (method === "GET"  && path === "/health")      return json({ ok: true, ts: Date.now() });

    return err("not found", 404);
  },
} satisfies ExportedHandler<Env>;
