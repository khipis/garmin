// Central configuration for the Connect IQ Store batch uploader.
// Everything the tool needs to find files / pages lives here so it's easy to
// tweak when Garmin changes their (unofficial, undocumented) developer portal.

import path from "node:path";
import { fileURLToPath } from "node:url";

export const HERE      = path.dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = path.resolve(HERE, "..");
export const STORE_DIR = path.join(REPO_ROOT, "_STORE");

// Persisted browser session (cookies/localStorage) from `login`. Never commit.
export const AUTH_FILE   = path.join(HERE, "auth.json");
// App list + slug→appId mapping (produced by `scan`, edited by hand as needed).
export const CONFIG_FILE = path.join(HERE, "apps.config.json");
// slug → store description text used by the `describe` command.
export const DESCRIPTIONS_FILE = path.join(HERE, "descriptions.json");
// Debug artifacts: screenshots + network recordings.
export const ARTIFACTS   = path.join(HERE, "artifacts");

// Garmin developer portal. START_URL is where `login` lands and where we detect
// a successful sign-in (URL no longer on the SSO host).
export const START_URL  = "https://apps.garmin.com/en-US/developer/dashboard";
export const SSO_HOSTS  = ["sso.garmin.com", "signin.garmin.com"];

// The per-app "Upload New Version" page. Single-step form: Choose file (.iq) +
// App Version (bump "Latest app version: N" → N+1) → "Upload and publish".
export function appUpdateUrl(developerId, appId) {
  return `https://apps.garmin.com/developer/${developerId}/apps/${appId}/update`;
}
// The app's public store page — the portal redirects here after a successful
// publish, so we use it as a success signal.
export function appPublicUrl(appId) {
  return `https://apps.garmin.com/apps/${appId}`;
}
// The per-app management page (has the "Edit Details" action) and the direct
// "Edit App Details" form URL. The portal has changed these before; the
// `describe` command tries the direct URL first, then falls back to clicking
// "Edit Details" on the management page.
export function appManageUrl(developerId, appId) {
  return `https://apps.garmin.com/developer/${developerId}/apps/${appId}`;
}
export function appEditUrl(developerId, appId) {
  return `https://apps.garmin.com/developer/${developerId}/apps/${appId}/edit`;
}

// Explicit slug → store appId overrides. Applied BEFORE fuzzy name-matching so
// ambiguous / generic names (e.g. "arcade" matching "Pinball: Arcade Pocket")
// map correctly. Verified from the developer dashboard.
export const OVERRIDES = {
  arcade:                 "d60d32f2-28e0-4273-b109-789f1b082a6c", // Axe Throw Arcade
  pinballpro:             "074acaed-154b-4ab2-a1bd-a28232bdd5f7", // Pinball: Arcade Pocket
  boxing:                 "322ac777-1525-42aa-9ab9-c6a962b3e336", // Boxing Game
  timer:                  "878dbace-5097-4f14-b94e-4aa334964354", // Sparring Timer
  archery:                "39adb32f-f24c-4ff0-8ef9-b9f91f25a77f", // Archer Duel
  pongpro:                "946795c7-5d75-47b5-8616-f1a0ce8f5011", // Pong: Classic Arcade
  othello_blitz:          "0b8c8d18-7984-4fae-be2b-4c3b6a525964", // Othello (Reversi) Blitz
  fakenotificationescape: "6da82371-7b2e-4e2d-b8c7-429a2126f795", // Escape Alert
  pets:                   "d61de4c6-10c7-417b-a326-2bf2c1d1b95c", // Pixel Pet Game
  run:                    "acb32878-886b-49c6-8589-3d98bd44c2c5", // Monster Escape Game
};

// The internal endpoint the dashboard calls to validate an uploaded .iq. We
// watch for it to confirm a good upload before submitting.
export const VALIDATE_PATH = "/ciq-developerservices/iqFiles/validate";

// Selectors / button texts for the per-app "Upload New Version" (/update) form.
// Confirmed by recording a manual upload:
//   #fileInput (accept=".iq") ← "Choose file", #app-version ← Latest+1,
//   button "Upload and publish" → POST validate + POST/PUT publish (204),
//   then the portal redirects to /apps/<appId>.
export const UPLOAD = {
  fileInput:     'input[type="file"][accept*=".iq"], #fileInput',
  versionInput:  "#app-version",
  // "Latest app version: N" — capture N so we can auto-bump to N+1.
  latestVersion: /Latest app version:\s*(\d+)/i,
  submitText:    /Upload and publish/i,
  cookieDismiss: /^\s*(Decline|Accept)\s*$/i,
  // Server-side .iq validation can be slow for multi-device binaries.
  validateTimeout: 180000,
  // Internal API path fragments used to confirm validation / publish.
  validatePath:  "/ciq-developerservices/iqFiles/validate",
  publishPath:   "/ciq-developerservices/developers/", // …/{dev}/apps/{appId}
  // Text that signals a validation/submit error.
  errorText:     /(failed|invalid|error|already exists|not valid|unsupported)/i,
};

// Selectors / button texts for the "Edit App Details" form used by `describe`.
// The description lives in a <textarea>; the portal has used a few ids/names for
// it over time, so we try a labelled selector first and fall back to the
// visible textarea holding the longest current text (see findDescTextarea).
export const DETAILS = {
  // Link/button that opens the details form from the management page.
  editLink:     /Edit\s*(App\s*)?Details|Edit\s*Listing/i,
  // Preferred selectors for the (English) description textarea, best → worst.
  // Confirmed from the live "Edit App Details" form: id="app-desc-en"
  // (the sibling "app-whats-new-en" is the release-notes field — leave it be).
  descTextarea: [
    'textarea#app-desc-en',
    'textarea#appDescription',
    'textarea#description',
    'textarea[name="description"]',
    'textarea[id*="desc" i]:not([id*="whats" i]):not([id*="new" i])',
    'textarea[aria-label*="description" i]',
    'textarea[placeholder*="description" i]',
  ].join(", "),
  // A "real" description textarea normally already holds more than this many
  // characters — used to pick the right one when there are several textareas.
  minDescLen:   30,
  // Save/submit button on the details form (confirmed: "Submit").
  saveText:     /^\s*(Submit|Save(\s*Changes)?|Update(\s*App)?|Publish)\s*$/i,
  // Best-effort dismissal of promo/onboarding modals that can overlay the form.
  modalDismiss: /^\s*(Not Now|Maybe Later|Dismiss)\s*$/i,
  cookieDismiss:/^\s*(Decline|Accept)\s*$/i,
  saveTimeout:  60000,
  // Internal API fragment hit on save — used to confirm the change persisted.
  savePath:     "/ciq-developerservices/developers/",
};
