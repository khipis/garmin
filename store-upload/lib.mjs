// Shared helpers: browser/session management, local app discovery, config I/O.

import fs from "node:fs";
import path from "node:path";
import { chromium } from "playwright";
import {
  HERE, REPO_ROOT, STORE_DIR, AUTH_FILE, CONFIG_FILE, ARTIFACTS,
} from "./config.mjs";

export const log  = (...a) => console.log(...a);
export const warn = (...a) => console.warn("⚠️ ", ...a);
export const die  = (msg) => { console.error("✖ " + msg); process.exit(1); };

export function ensureArtifacts() {
  if (!fs.existsSync(ARTIFACTS)) fs.mkdirSync(ARTIFACTS, { recursive: true });
}

// Launch a browser context, reusing the saved login session if present.
export async function openContext({ headed = false } = {}) {
  const browser = await chromium.launch({
    headless: !headed,
    args: ["--disable-blink-features=AutomationControlled"],
  });
  const hasAuth = fs.existsSync(AUTH_FILE);
  const context = await browser.newContext(
    hasAuth ? { storageState: AUTH_FILE } : {}
  );
  const page = await context.newPage();
  return { browser, context, page, hasAuth };
}

export async function saveSession(context) {
  await context.storageState({ path: AUTH_FILE });
}

export function requireAuth() {
  if (!fs.existsSync(AUTH_FILE)) {
    die("No saved session. Run `npm run login` first.");
  }
}

// ── local apps ──────────────────────────────────────────────────────────────

// Every subfolder of the repo that has a monkey.jungle AND a built _STORE/*.iq.
export function localApps() {
  const out = [];
  for (const slug of fs.readdirSync(REPO_ROOT)) {
    const dir = path.join(REPO_ROOT, slug);
    if (!fs.statSync(dir).isDirectory?.() && !safeIsDir(dir)) continue;
    if (!safeIsDir(dir)) continue;
    const jungle = path.join(dir, "monkey.jungle");
    const iq     = path.join(STORE_DIR, `${slug}.iq`);
    if (!fs.existsSync(jungle)) continue;
    out.push({
      slug,
      iq: fs.existsSync(iq) ? iq : null,
      name: readAppName(slug),
      uuid: readAppUuid(slug),
    });
  }
  return out.sort((a, b) => a.slug.localeCompare(b.slug));
}

function safeIsDir(p) {
  try { return fs.statSync(p).isDirectory(); } catch { return false; }
}

// Human-readable app name: resolve the manifest entry's name to strings.xml,
// falling back to the first string, then the slug.
export function readAppName(slug) {
  try {
    const strings = path.join(REPO_ROOT, slug, "resources", "strings.xml");
    if (fs.existsSync(strings)) {
      const xml = fs.readFileSync(strings, "utf8");
      // Prefer an id that looks like the app name.
      const m = xml.match(/<string[^>]*id="(?:AppName|app_name|appName|appname)"[^>]*>([^<]+)</i);
      if (m) return decodeXml(m[1].trim());
      const any = xml.match(/<string[^>]*>([^<]+)</i);
      if (any) return decodeXml(any[1].trim());
    }
  } catch {}
  return slug;
}

function readAppUuid(slug) {
  try {
    const manifest = path.join(REPO_ROOT, slug, "manifest.xml");
    const xml = fs.readFileSync(manifest, "utf8");
    const m = xml.match(/id="([0-9a-fA-F-]{32,36})"/);
    return m ? m[1] : null;
  } catch { return null; }
}

function decodeXml(s) {
  return s.replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
          .replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&apos;/g, "'");
}

// ── config I/O ────────────────────────────────────────────────────────────────

export function loadConfig() {
  if (!fs.existsSync(CONFIG_FILE)) return null;
  return JSON.parse(fs.readFileSync(CONFIG_FILE, "utf8"));
}

export function saveConfig(cfg) {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2) + "\n");
}

// Normalise a name for fuzzy matching (lowercase alphanumerics only).
export function norm(s) {
  return (s || "").toLowerCase().replace(/[^a-z0-9]/g, "");
}
