// Unattended-friendly login: opens a browser, waits for you to sign in
// (including the reCAPTCHA), and AUTO-SAVES the session the moment your Garmin
// developer dashboard loads — no ENTER keypress required. This lets you sign in
// once and then leave the agent to run uploads on its own.

import { openContext, saveSession, log, warn } from "./lib.mjs";
import { START_URL, SSO_HOSTS } from "./config.mjs";

const onSso = (u) => SSO_HOSTS.some((h) => u.includes(h));
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

const DEADLINE_MS = 20 * 60 * 1000; // give the human up to 20 minutes to sign in
const POLL_MS = 2500;

const { browser, context, page } = await openContext({ headed: true });

log("──────────────────────────────────────────────────────────────");
log(" A Garmin sign-in window is open.");
log(" 1) Enter email + password");
log(" 2) Solve the 'I'm not a robot' reCAPTCHA");
log(" 3) Click Sign In — then you can walk away.");
log(" The session saves itself once the developer dashboard loads.");
log("──────────────────────────────────────────────────────────────");

await page.goto(START_URL, { waitUntil: "domcontentloaded" }).catch(() => {});

const start = Date.now();
let saved = false;

while (Date.now() - start < DEADLINE_MS) {
  await sleep(POLL_MS);

  let url = "";
  try {
    url = page.url();
  } catch (e) {
    warn("Browser window was closed before sign-in completed.");
    break;
  }

  if (onSso(url)) { continue; }                 // still on the login flow
  if (!url.includes("apps.garmin.com")) { continue; }

  // Back on the Garmin apps host — confirm the cookies really land on the
  // developer dashboard (and don't bounce back to SSO) before saving.
  try {
    await page.goto(START_URL, { waitUntil: "domcontentloaded" });
    await page.waitForLoadState("networkidle", { timeout: 15000 }).catch(() => {});
  } catch (e) {
    continue;
  }

  let finalUrl = "";
  try { finalUrl = page.url(); } catch (e) { break; }
  if (onSso(finalUrl)) { continue; }            // not actually authenticated yet

  await saveSession(context);
  saved = true;
  log("SESSION_SAVED ✔ auth.json written — you can leave; uploads will run unattended.");
  break;
}

if (!saved) {
  warn("Timed out waiting for sign-in — no session saved. Re-run when ready.");
}

await browser.close().catch(() => {});
process.exit(saved ? 0 : 1);
