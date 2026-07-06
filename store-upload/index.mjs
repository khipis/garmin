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
  START_URL, SSO_HOSTS, AUTH_FILE, ARTIFACTS, UPLOAD, appUpdateUrl, REPO_ROOT, OVERRIDES,
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

  // Scrape anchors (both raw + absolute href) so we can match the portal's
  // relative routes (/apps/<uuid>, /developer/<uuid>/apps) reliably.
  const found = await page.$$eval("a[href]", (as) =>
    as.map((a) => ({
      raw: a.getAttribute("href") || "",
      abs: a.href || "",
      text: (a.textContent || "").trim(),
    }))
  );
  await page.screenshot({ path: path.join(ARTIFACTS, "scan.png"), fullPage: true }).catch(() => {});
  fs.writeFileSync(path.join(ARTIFACTS, "scan-anchors.json"), JSON.stringify(found, null, 2));

  const UUID = "[0-9a-fA-F-]{36}";
  const appRe = new RegExp(`/apps/(${UUID})(?:[/?#]|$)`);
  const devRe = new RegExp(`/developer/(${UUID})/apps`);
  const seen = new Map();
  let developerId = null;
  for (const { raw, abs, text } of found) {
    const dm = raw.match(devRe) || abs.match(devRe);
    if (dm) developerId = developerId || dm[1];
    const am = raw.match(appRe) || abs.match(appRe);
    if (!am) continue;
    const appId = am[1];
    const prev = seen.get(appId);
    // Keep the richest text + a good absolute URL.
    if (!prev || (text && !prev.name)) {
      seen.set(appId, { appId, name: text || (prev && prev.name) || "", url: abs || (prev && prev.url) || "" });
    }
  }
  const storeApps = [...seen.values()];
  log(`Found ${storeApps.length} store app(s); developerId=${developerId ?? "?"}`);

  if (!storeApps.length) {
    warn(`No app links matched. Inspect ${rel(path.join(ARTIFACTS, "scan.png"))} and ${rel(path.join(ARTIFACTS, "scan-anchors.json"))}.`);
    await browser.close();
    die("Nothing to map.");
  }

  // Match store apps to local slugs. Store names carry marketing suffixes
  // ("… - Global Leaderboard"), so match the local display name / slug as a
  // substring of the (normalised) store name.
  const locals = localApps();
  const byId = new Map(storeApps.map((s) => [s.appId, s]));
  const usedLocal = new Set();
  const usedStore = new Set();
  const apps = [];
  const pushMatch = (local, store) => {
    usedLocal.add(local.slug);
    usedStore.add(store.appId);
    apps.push({
      slug: local.slug, appId: store.appId, storeName: store.name,
      url: store.url || null,
      iq: local.iq ? path.relative(REPO_ROOT, local.iq) : null,
    });
  };

  // 1) Explicit overrides win.
  for (const [slug, appId] of Object.entries(OVERRIDES)) {
    const local = locals.find((l) => l.slug === slug);
    const store = byId.get(appId);
    if (local && store && !usedLocal.has(slug) && !usedStore.has(appId)) pushMatch(local, store);
  }

  // 2) Fuzzy name-matching for the rest.
  for (const s of storeApps) {
    if (usedStore.has(s.appId)) continue;
    const n = norm(s.name);
    const cand = (fn) => locals.find((l) => !usedLocal.has(l.slug) && fn(l, norm(l.name), norm(l.slug)));
    const hit =
        cand((l, ln) => ln && ln === n)                          // exact
     || cand((l, ln) => ln.length >= 4 && n.includes(ln))       // name inside store text
     || cand((l, ln, ls) => ls.length >= 4 && n.includes(ls))   // slug inside store text
     || null;
    if (hit) pushMatch(hit, s);
  }
  const unmatchedStore = storeApps.filter((s) => !usedStore.has(s.appId));
  const unmatchedLocal = locals.filter((l) => !usedLocal.has(l.slug)).map((l) => ({ slug: l.slug, name: l.name }));

  const cfg = {
    developerId,
    note: "Check the slug↔appId mapping. Fill appId+url for any _unmatchedLocal by copying from _unmatchedStore.",
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
// Guided capture of ONE manual "Upload New Version" so we can lock in the exact
// entry URL, form field ids, button texts and network endpoints. Two ENTER
// checkpoints: (A) the empty upload form, (B) after submit.
async function cmdRecord() {
  requireAuth();
  ensureArtifacts();
  const { browser, page } = await openContext({ headed: true });
  const events = [];
  const navs = [];
  const capture = (kind) => (reqOrRes) => {
    try {
      const url = reqOrRes.url();
      if (!/garmin\.com/i.test(url)) return;
      if (!/\/api\/|iqFiles|version|upload|validate|apps\/|developerservices/i.test(url)) return;
      const rec = { kind, url, method: reqOrRes.method?.() };
      if (kind === "request") { rec.postData = safe(() => reqOrRes.postData()); }
      else { rec.status = reqOrRes.status?.(); }
      events.push(rec);
    } catch {}
  };
  page.on("request", capture("request"));
  page.on("response", capture("response"));
  page.on("framenavigated", (f) => { try { if (f === page.mainFrame()) navs.push(f.url()); } catch {} });

  const snapshot = async (label) => {
    const dom = await page.evaluate(() => {
      const btns = [...new Set([...document.querySelectorAll("button, a[role=button], input[type=submit]")]
        .map((e) => (e.textContent || e.value || "").trim()).filter(Boolean))];
      const inputs = [...document.querySelectorAll("input, textarea, select")].map((e) => ({
        tag: e.tagName, type: e.type || null, id: e.id || null, name: e.name || null,
        accept: e.getAttribute("accept") || null, placeholder: e.placeholder || null,
      }));
      const latest = (document.body.innerText.match(/Latest app version:\s*\d+/i) || [null])[0];
      return { url: location.href, latest, buttons: btns, inputs };
    }).catch((e) => ({ error: String(e) }));
    log(`  · [${label}] url=${dom.url || "?"}${dom.latest ? "  (" + dom.latest + ")" : ""}`);
    return { label, at: Date.now(), ...dom };
  };

  await page.goto(START_URL, { waitUntil: "domcontentloaded" }).catch(() => {});
  await dismissCookie(page);

  log("STEP 1 — In the browser, open ONE app and click 'Upload New Version'.");
  log("        Get to the form that shows 'Choose file' + 'App Version (Latest app version: N)'.");
  await waitForEnter("        When that form is visible, press ENTER here… ");
  const formSnap = await snapshot("upload-form");
  await shot(page, "record", "form");

  log("STEP 2 — Now finish the upload: choose the .iq, set version to N+1, Submit.");
  await waitForEnter("        When it's fully submitted, press ENTER here… ");
  const doneSnap = await snapshot("after-submit");
  await shot(page, "record", "done");

  const out = path.join(ARTIFACTS, `recording-${Date.now()}.json`);
  fs.writeFileSync(out, JSON.stringify({ navigations: navs, form: formSnap, done: doneSnap, network: events }, null, 2));
  log(`\n✔ Saved recording to ${rel(out)} (${events.length} net events, ${navs.length} navigations).`);
  log(`  Screenshots: ${rel(path.join(ARTIFACTS, "record-form.png"))}, record-done.png`);
  await browser.close();
}

// ── upload ────────────────────────────────────────────────────────────────────
async function cmdUpload() {
  requireAuth();
  ensureArtifacts();
  const cfg = loadConfig();
  if (!cfg) die("No apps.config.json — run `npm run scan` first.");
  const { developerId } = cfg;
  if (!developerId) die("apps.config.json is missing developerId — re-run scan.");

  const only   = flags.only ? new Set(String(flags.only).split(",").map((s) => s.trim())) : null;
  const dry    = flags["dry-run"] === true;
  const headed = flags.headless === true ? false : true; // default headed so you can watch
  const version = flags.version != null ? String(flags.version) : null; // override auto-bump
  const pauseBeforeSubmit = flags["pause-before-submit"] === true;
  const rmOnSuccess = flags["rm-on-success"] === true; // delete _STORE/<slug>.iq after publish

  let queue = cfg.apps.filter((a) => a.iq && a.appId);
  if (only) queue = queue.filter((a) => only.has(a.slug));
  const noIq = cfg.apps.filter((a) => !a.iq || !a.appId).map((a) => a.slug);
  if (noIq.length) warn(`Skipping (no built .iq or appId): ${noIq.join(", ")}`);
  if (!queue.length) die("Nothing to upload.");

  log(`Uploading ${queue.length} app(s)${dry ? " [DRY RUN]" : ""}…`);
  const { browser, page } = await openContext({ headed });
  await page.goto(START_URL, { waitUntil: "domcontentloaded" }).catch(() => {});
  await dismissCookie(page);
  const results = [];

  for (const app of queue) {
    const iqAbs = path.isAbsolute(app.iq) ? app.iq : path.join(REPO_ROOT, app.iq);
    log(`\n── ${app.slug} (appId=${app.appId}) ──`);
    if (!fs.existsSync(iqAbs)) { warn("  missing .iq"); results.push({ slug: app.slug, ok: false, reason: "no iq" }); continue; }

    try {
      // Go straight to the per-app "Upload New Version" (/update) form.
      await page.goto(appUpdateUrl(developerId, app.appId), { waitUntil: "domcontentloaded" });
      await page.waitForLoadState("networkidle", { timeout: 20000 }).catch(() => {});
      await dismissCookie(page);
      await page.waitForSelector(UPLOAD.fileInput, { state: "attached", timeout: 20000 });

      // Version: explicit override, or auto-bump "Latest app version: N" → N+1.
      let ver = app.version || version;
      if (!ver) {
        const bodyText = await page.evaluate(() => document.body.innerText);
        const m = bodyText.match(UPLOAD.latestVersion);
        if (m) ver = String(parseInt(m[1], 10) + 1);
      }
      if (!ver) throw new Error("could not read 'Latest app version' (pass --version)");
      log(`  version → ${ver}`);

      // Fill the form: .iq + version.
      await page.locator(UPLOAD.fileInput).first().setInputFiles(iqAbs);
      await page.locator(UPLOAD.versionInput).fill(ver);
      await page.waitForTimeout(800);

      if (dry) {
        await shot(page, app.slug, "form");
        results.push({ slug: app.slug, ok: true, reason: "dry-run (form filled, not published)" });
        continue;
      }
      if (pauseBeforeSubmit) {
        await shot(page, app.slug, "before-publish");
        await waitForEnter(`  [${app.slug}] paused before publish — ENTER to publish (Ctrl+C to abort)… `);
      }

      // "Upload and publish" → validate + publish; confirm via 2xx publish
      // response or the redirect off /update.
      const pub = await publishAndConfirm(page, developerId, app.appId);
      if (!pub.ok) throw new Error(pub.error || "publish not confirmed");
      await shot(page, app.slug, "done");
      let removed = false;
      if (rmOnSuccess) {
        try { fs.unlinkSync(iqAbs); removed = true; } catch (e) { warn(`  (could not remove ${app.iq}: ${e.message})`); }
      }
      results.push({ slug: app.slug, ok: true, reason: `v${ver}`, removed });
      log(`  ✔ published v${ver}${removed ? "  · removed .iq from _STORE" : ""}`);
    } catch (e) {
      await shot(page, app.slug, "error");
      warn(`  ✖ ${app.slug}: ${e.message}`);
      results.push({ slug: app.slug, ok: false, reason: e.message });
    }
  }

  await browser.close();
  const ok = results.filter((r) => r.ok);
  const bad = results.filter((r) => !r.ok);
  log(`\n=== DONE: ${ok.length}/${results.length} ok ===`);
  if (ok.length) log(`  ✔ published: ${ok.map((r) => `${r.slug}(${r.reason})`).join(", ")}`);
  if (bad.length) {
    log(`  ✖ FAILED (kept in _STORE): ${bad.map((r) => r.slug).join(", ")}`);
    for (const r of bad) log(`      ${r.slug}: ${r.reason || "failed"}`);
  }
  const summary = path.join(ARTIFACTS, `upload-${Date.now()}.json`);
  fs.writeFileSync(summary, JSON.stringify(results, null, 2));
  log(`Summary: ${rel(summary)} · screenshots in ${rel(ARTIFACTS)}`);
}

// ── helpers ───────────────────────────────────────────────────────────────────
async function dismissCookie(page) {
  try {
    const b = page.getByRole("button", { name: UPLOAD.cookieDismiss }).first();
    if (await b.count()) await b.click({ timeout: 3000 }).catch(() => {});
  } catch {}
}

// Click a button by text regex, optionally waiting until it's enabled.
async function clickBtn(page, rx, { waitEnabled = false, timeout = 20000 } = {}) {
  const btn = page.getByRole("button", { name: rx }).first();
  if (waitEnabled) {
    await page.waitForFunction(
      (src) => {
        const re = new RegExp(src.replace(/^\/|\/i$/g, ""), "i");
        const b = [...document.querySelectorAll("button")].find((x) => re.test(x.textContent || ""));
        return b && !b.disabled;
      },
      rx.toString(),
      { timeout }
    );
  }
  await btn.click({ timeout: 8000 });
}

// Click "Upload and publish" and confirm the new version went live. Success is
// a 2xx on the publish endpoint (…/developers/{dev}/apps/{appId}) or the portal
// redirecting off the /update page. Retries once — the portal 400s if the
// button is clicked before server-side validation of the .iq completes.
async function publishAndConfirm(page, dev, appId) {
  const pubFrag = UPLOAD.publishPath + dev + "/apps/" + appId;
  for (let attempt = 1; attempt <= 2; attempt++) {
    const respP = page.waitForResponse(
      (r) => r.url().includes(pubFrag) && ["POST", "PUT"].includes(r.request().method()),
      { timeout: UPLOAD.validateTimeout }
    ).catch(() => null);
    try {
      await clickBtn(page, UPLOAD.submitText, { waitEnabled: true, timeout: 30000 });
    } catch (e) {
      if (attempt === 2) return { ok: false, error: "'Upload and publish' never became clickable" };
      await page.waitForTimeout(2000);
      continue;
    }
    const resp = await respP;
    if (resp && resp.status() >= 200 && resp.status() < 300) return { ok: true };
    await page.waitForTimeout(1500);
    if (!page.url().includes("/update")) return { ok: true }; // redirected → published
    await page.waitForTimeout(2500); // 400/no-confirm → let validation settle, retry
  }
  if (!page.url().includes("/update")) return { ok: true };
  return { ok: false, error: "publish not confirmed (still on /update)" };
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

function safe(fn) { try { return fn(); } catch { return null; } }
function escapeRe(s) { return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
function rel(p) { return path.relative(process.cwd(), p) || p; }
