// Garmin Games — Global Leaderboard API
// Cloudflare Worker + D1 (SQLite)

export interface Env {
  DB: D1Database;
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

  try {
    await env.DB
      .prepare(
        "INSERT INTO scores (game, user, score, timestamp, variant, meta) VALUES (?, ?, ?, ?, ?, ?)"
      )
      .bind(game, user, Math.round(score), ts, variant, metaStr)
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

  let rows: { user: string; score: number }[] = [];
  try {
    const result = await env.DB
      .prepare(
        "SELECT user, score FROM scores WHERE game = ? AND variant = ? ORDER BY score DESC LIMIT ?"
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
    if (method === "GET"  && path === "/variants")    return handleGetVariants(url, env);
    if (method === "GET"  && path === "/health")      return json({ ok: true, ts: Date.now() });

    return err("not found", 404);
  },
} satisfies ExportedHandler<Env>;
