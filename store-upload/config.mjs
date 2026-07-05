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
// Debug artifacts: screenshots + network recordings.
export const ARTIFACTS   = path.join(HERE, "artifacts");

// Garmin developer portal. START_URL is where `login` lands and where we detect
// a successful sign-in (URL no longer on the SSO host).
export const START_URL  = "https://apps.garmin.com/en-US/developer/dashboard";
export const SSO_HOSTS  = ["sso.garmin.com", "signin.garmin.com"];

// Build the per-app "edit / new version" URL once we know the developer id and
// the store app id. Adjust the pattern here if the portal layout changes.
export function appEditUrl(developerId, appId) {
  return `https://apps.garmin.com/en-US/developer/${developerId}/apps/${appId}/edit`;
}

// The internal endpoint the dashboard calls to validate an uploaded .iq. We
// watch for it to confirm a good upload before submitting.
export const VALIDATE_PATH = "/ciq-developerservices/iqFiles/validate";

// Selectors / button texts used during upload. Centralised + overridable so a
// portal redesign only needs edits here (not in the flow code). Texts are
// matched case-insensitively as substrings.
export const UPLOAD = {
  fileInput:      'input[type="file"]',
  // Buttons we may need to click, tried in order. First visible match wins.
  submitTexts:    ["save", "submit", "publish", "update", "next", "continue"],
  // If a confirmation dialog appears.
  confirmTexts:   ["yes", "confirm", "ok", "publish", "submit"],
  // Max time to wait for the validate call / navigation (ms).
  validateTimeout: 60000,
};
