#!/usr/bin/env node
// Batch uploader for Bitochi Connect IQ apps.
//
//   node index.mjs login     → open a browser, sign in manually, save the session
//   node index.mjs scan      → discover your store apps + build apps.config.json
//   node index.mjs record    → capture the network flow of ONE manual upload
//   node index.mjs upload     → push _STORE/<slug>.iq for every configured app
//
// Garmin has NO official publish API — this drives the developer portal on your
// saved login session (the same thing you do by hand, in a loop). It's an
// unofficial helper: if the portal layout changes, tune config.mjs.

import fs from "node:fs";
import path from "node:path";
import readline from "node:readline";
import {
  START_URL, SSO_HOSTS, AUTH_FILE, ARTIFACTS, UPLOAD, VALIDATE_PATH, appEditUrl, REPO_ROOT,
} from "./config.mjs";
import {
  log, warn, die, ensureArtifacts, openContext, saveSession, requireAuth,
  localApps, loadConfig, saveConfig, norm,
} from "./lib.mjs";

const [, , cmd, ...rest] = process.argv;
const flags = parseFlags(rest);

switch (cmd) {
  case "login":  await cmdLogin();  break;
  case "scan":   await cmdScan();   break;
  case "record": await cmdRecord(); break;
  case "upload": await cmdUpload(); break;
  default:
    log(`Usage: node index.mjs <login|scan|record|upload> [flags]

  login                       sign in once (headed), save session to auth.json
  scan                        list your store apps, write apps.config.json
  record                      capture network of one manual upload (headed)
  upload [--only a,b] [--dry-run] [--headed] [--headless]
                              upload _STORE/<slug>.iq for configured apps
`);
    process.exit(cmd ? 1 : 0);
}

// ── login ─────────────────────────────────────────────────────────────────────
async function cmdLogin() {
  const { browser, context, page } = await openContext({ headed: true });
  log("Opening Garmin developer portal — sign in (including 2FA) in the window.");
  await page.goto(START_URL, { waitUntil: "domcontentloaded" }).catch(() => {});
  await waitForEnter("When you can see your developer dashboard, press ENTER here to save the session… ");
  await saveSession(context);
  log(`✔ Session saved to ${rel(AUTH_FILE)}`);
  await browser.close();
}

// ── scan ──────────────────────────────────────────────────────────────────────
async function cmdScan() {
  requireAuth();
  ensureArtifacts();
  const { browser, page } = await openContext({ headed: flags.headed === true });
  log("Loading developer dashboard…");
  await page.goto(START_URL, { waitUntil: "domcontentloaded" }).catch(() => {});
  await page.waitForLoadState("networkidle", { timeout: 30000 }).catch(() => {});

  if (SSO_HOSTS.some((h) => page.url().includes(h))) {
    await browser.close();
    die("Session expired — run `npm run login` again.");
  }

  // Scrape every anchor that looks like a developer app link.
  const found = await page.$$eval("a[href]", (as) =>
    as.map((a) => ({ href: a.getAttribute("href") || "", text: (a.textContent || "").trim() }))
  );
  await page.screenshot({ path: path.join(ARTIFACTS, "scan.png"), fullPage: true }).catch(() => {});

  const re = /\/developer\/([^/]+)\/apps\/([^/?#]+)/;
  const seen = new Map();
  let developerId = null;
  for (const { href, text } of found) {
    const m = href.match(re);
    if (!m) continue;
    developerId = developerId || m[1];
    const appId = m[2];
    if (appId === "new" || appId === "create") continue;
    if (!seen.has(appId) || (text && !seen.get(appId).name)) {
      seen.set(appId, { appId, name: text });
    }
  }
  const storeApps = [...seen.values()];
  log(`Found ${storeApps.length} store app link(s); developerId=${developerId ?? "?"}`);

  if (!storeApps.length) {
    warn(`No app links matched. Inspect ${rel(path.join(ARTIFACTS, "scan.png"))} and the raw dump below, then adjust the selector in scan.`);
    fs.writeFileSync(path.join(ARTIFACTS, "scan-anchors.json"), JSON.stringify(found, null, 2));
    await browser.close();
    die("Nothing to map.");
  }

  // Fuzzy-match store apps to local slugs (by name, then by slug substring).
  const locals = localApps();
  const usedLocal = new Set();
  const apps = [];
  const unmatchedStore = [];
  for (const s of storeApps) {
    const n = norm(s.name);
    let hit = locals.find((l) => !usedLocal.has(l.slug) && n && norm(l.name) === n)
           || locals.find((l) => !usedLocal.has(l.slug) && n && (norm(l.name).includes(n) || n.includes(norm(l.slug))))
           || null;
    if (hit) {
      usedLocal.add(hit.slug);
      apps.push({ slug: hit.slug, appId: s.appId, storeName: s.name, iq: hit.iq ? path.relative(REPO_ROOT, hit.iq) : null });
    } else {
      unmatchedStore.push(s);
    }
  }
  const unmatchedLocal = locals.filter((l) => !usedLocal.has(l.slug)).map((l) => ({ slug: l.slug, name: l.name }));

  const cfg = {
    developerId,
    note: "Edit `appId` mappings if any are wrong. Apps in `_unmatchedLocal` need their store appId filled into `apps` manually.",
    apps: apps.sort((a, b) => a.slug.localeCompare(b.slug)),
    _unmatchedStore: unmatchedStore,
    _unmatchedLocal: unmatchedLocal,
  };
  saveConfig(cfg);
  log(`✔ Wrote apps.config.json — ${apps.length} matched, ${unmatchedStore.length} store-only, ${unmatchedLocal.length} local-only.`);
  if (unmatchedLocal.length) warn(`Unmatched local apps: ${unmatchedLocal.map((x) => x.slug).join(", ")}`);
  await browser.close();
}

// ── record ────────────────────────────────────────────────────────────────────
async function cmdRecord() {
  requireAuth();
  ensureArtifacts();
  const { browser, page } = await openContext({ headed: true });
  const events = [];
  const capture = (kind) => (reqOrRes) => {
    try {
      const url = reqOrRes.url();
      if (!url.includes("apps.garmin.com")) return;
      if (!/\/api\/|iqFiles|version|upload|validate/i.test(url)) return;
      const rec = { kind, url, method: reqOrRes.method?.() };
      if (kind === "request") {
        rec.postData = safe(() => reqOrRes.postData());
        rec.headers = safe(() => reqOrRes.headers());
      } else {
        rec.status = reqOrRes.status?.();
      }
      events.push(rec);
    } catch {}
  };
  page.on("request", capture("request"));
  page.on("response", capture("response"));

  await page.goto(START_URL, { waitUntil: "domcontentloaded" }).catch(() => {});
  log("Now do ONE manual app-version upload in the browser (upload .iq, submit).");
  await waitForEnter("When finished, press ENTER to save the captured network flow… ");
  const out = path.join(ARTIFACTS, `recording-${Date.now()}.json`);
  fs.writeFileSync(out, JSON.stringify(events, null, 2));
  log(`✔ Saved ${events.length} API events to ${rel(out)}`);
  await browser.close();
}

// ── upload ────────────────────────────────────────────────────────────────────
async function cmdUpload() {
  requireAuth();
  ensureArtifacts();
  const cfg = loadConfig();
  if (!cfg) die("No apps.config.json — run `npm run scan` first.");
  const { developerId } = cfg;
  if (!developerId) die("apps.config.json is missing developerId — re-run scan or set it.");

  const only = flags.only ? new Set(String(flags.only).split(",").map((s) => s.trim())) : null;
  const dry  = flags["dry-run"] === true;
  const headed = flags.headless === true ? false : true; // default headed so you can watch

  let queue = cfg.apps.filter((a) => a.appId && a.iq);
  if (only) queue = queue.filter((a) => only.has(a.slug));
  const skipped = cfg.apps.filter((a) => !a.appId || !a.iq).map((a) => a.slug);
  if (skipped.length) warn(`Skipping (missing appId or .iq): ${skipped.join(", ")}`);
  if (!queue.length) die("Nothing to upload.");

  log(`Uploading ${queue.length} app(s)${dry ? " [DRY RUN]" : ""}…`);
  const { browser, page } = await openContext({ headed });
  const results = [];

  for (const app of queue) {
    const iqAbs = path.isAbsolute(app.iq) ? app.iq : path.join(REPO_ROOT, app.iq);
    log(`\n── ${app.slug} (appId=${app.appId}) ──`);
    if (!fs.existsSync(iqAbs)) { warn(`missing .iq: ${app.iq}`); results.push({ slug: app.slug, ok: false, reason: "no iq" }); continue; }

    try {
      await page.goto(appEditUrl(developerId, app.appId), { waitUntil: "domcontentloaded" });
      await page.waitForLoadState("networkidle", { timeout: 20000 }).catch(() => {});

      const fileInput = await page.$(UPLOAD.fileInput);
      if (!fileInput) throw new Error("file input not found on edit page");

      // Watch for the validate call so we know the .iq was accepted.
      const validateP = page.waitForResponse(
        (r) => r.url().includes(VALIDATE_PATH),
        { timeout: UPLOAD.validateTimeout }
      ).catch(() => null);

      await fileInput.setInputFiles(iqAbs);
      const vres = await validateP;
      const vok  = vres && vres.status() >= 200 && vres.status() < 300;
      log(`  validate: ${vres ? vres.status() : "no response"}`);

      if (dry) {
        await shot(page, app.slug, "dryrun");
        results.push({ slug: app.slug, ok: !!vok, reason: dry ? "dry-run (not submitted)" : "" });
        continue;
      }

      const clicked = await clickFirst(page, UPLOAD.submitTexts);
      if (!clicked) throw new Error("no submit button found");
      await page.waitForLoadState("networkidle", { timeout: 20000 }).catch(() => {});
      await clickFirst(page, UPLOAD.confirmTexts).catch(() => {});
      await page.waitForTimeout(1500);
      await shot(page, app.slug, "done");
      results.push({ slug: app.slug, ok: true });
      log("  ✔ submitted");
    } catch (e) {
      await shot(page, app.slug, "error");
      warn(`  ✖ ${app.slug}: ${e.message}`);
      results.push({ slug: app.slug, ok: false, reason: e.message });
    }
  }

  await browser.close();
  const ok = results.filter((r) => r.ok).length;
  log(`\n=== DONE: ${ok}/${results.length} ok ===`);
  for (const r of results.filter((x) => !x.ok)) log(`  ✖ ${r.slug}: ${r.reason || "failed"}`);
  const summary = path.join(ARTIFACTS, `upload-${Date.now()}.json`);
  fs.writeFileSync(summary, JSON.stringify(results, null, 2));
  log(`Summary: ${rel(summary)} · screenshots in ${rel(ARTIFACTS)}`);
}

// ── helpers ───────────────────────────────────────────────────────────────────
async function clickFirst(page, texts) {
  for (const t of texts) {
    const btn = page.locator(
      `button:visible, [role="button"]:visible, input[type="submit"]:visible, a:visible`,
      { hasText: new RegExp(`^\\s*${escapeRe(t)}\\s*$`, "i") }
    ).first();
    if (await btn.count().catch(() => 0)) {
      try { await btn.click({ timeout: 4000 }); return t; } catch {}
    }
  }
  return null;
}

async function shot(page, slug, tag) {
  await page.screenshot({ path: path.join(ARTIFACTS, `${slug}-${tag}.png`), fullPage: true }).catch(() => {});
}

function parseFlags(args) {
  const f = {};
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (a.startsWith("--")) {
      const key = a.slice(2);
      const next = args[i + 1];
      if (next && !next.startsWith("--")) { f[key] = next; i++; }
      else f[key] = true;
    }
  }
  return f;
}

function waitForEnter(prompt) {
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  return new Promise((res) => rl.question(prompt, () => { rl.close(); res(); }));
}

const safe = (fn) => { try { return fn(); } catch { return null; } };
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const rel = (p) => path.relative(process.cwd(), p) || p;
