# Connect IQ Store — batch uploader

Semi-automated uploader for pushing new `.iq` builds of all Bitochi apps to the
Garmin Connect IQ Store.

## Why "semi"?

**Garmin has no official publish/upload API** (confirmed May 2026 — there's an
open developer request, still only *Acknowledged*). The developer portal is a
web app behind Garmin SSO (cookie + 2FA); there are no API keys.

So this tool does the only thing that works: it **drives the portal on your own
logged-in session** with [Playwright](https://playwright.dev) — the exact clicks
you'd do by hand, but in a loop over all apps. You log in **once** manually
(incl. 2FA); after that the batch runs unattended.

Caveats, honestly:

- Unofficial. If Garmin redesigns the portal, tune selectors in `config.mjs`.
- Garmin still **reviews/approves** every submitted version — that part can't be
  skipped.
- Your Garmin session/cookies live in `auth.json` (git-ignored). Never commit it.

## Setup

```bash
cd store-upload
npm install
npx playwright install chromium
```

## Workflow

1. **Build** the store binaries first (from the repo root):

   ```bash
   ./_build_all.sh store
   ```

   This produces `_STORE/<slug>.iq` for every app.

2. **Log in** once — a browser opens; sign in (with 2FA); then press ENTER in the
   terminal to save the session:

   ```bash
   npm run login
   ```

3. **Scan** your published apps to build the slug → store-appId map:

   ```bash
   npm run scan
   ```

   Writes `apps.config.json`. It fuzzy-matches your local app folders to the
   store listings by name. **Review it** — fix any wrong `appId`, and fill in the
   `appId` for anything listed under `_unmatchedLocal`.

4. *(only if the portal changes)* **Record** a single manual upload to re-capture
   the exact page URL, field ids and endpoints. Guided, two ENTER checkpoints:

   ```bash
   npm run record
   ```

5. **Upload**. Each app is published via its per-app **Upload New Version** page
   (`/developer/<devId>/apps/<appId>/update`): the tool attaches `_STORE/<slug>.iq`,
   reads *"Latest app version: N"* and sets the version to **N+1**, then clicks
   **Upload and publish**. Start narrow, then go wide:

   ```bash
   node index.mjs upload --only chess --dry-run          # fills the form, does NOT publish
   node index.mjs upload --only chess --pause-before-submit  # stops so you can eyeball, ENTER to publish
   node index.mjs upload --only chess                    # one app for real
   node index.mjs upload                                 # all configured apps
   ```

   Flags:
   - `--only a,b,c` — restrict to specific slugs
   - `--dry-run` — navigate + fill the form (file + version) but **don't publish**
   - `--pause-before-submit` — fill the form, then wait for ENTER before publishing
   - `--version X` — force a specific version for all queued apps (default: auto N+1)
   - `--headless` — no visible browser (default is headed so you can watch)

   No changelog / "What's New" is touched — it only swaps the binary and bumps the
   version. Screenshots + a JSON summary land in `artifacts/`. Garmin still reviews
   each submitted version before it goes live.

6. **Describe** — bulk-refresh the store **description** of every app from
   `descriptions.json` (slug → text). For each app it opens **Edit App Details**
   (`/developer/<devId>/apps/<appId>/edit`), fills the English *Description*
   field (`#app-desc-en`), and clicks **Submit**. It never touches Title,
   *What's New*, screenshots or any other field.

   **Safe by default: `describe` is a DRY RUN** — it fills the field and takes a
   screenshot but never saves. Add `--publish` to actually persist.

   ```bash
   node index.mjs describe --discover --only 8ball        # read-only: dump the form fields
   node index.mjs describe --only 8ball                   # dry run: fill + screenshot, NO save
   node index.mjs describe --only 8ball --publish --pause-before-save  # fill, wait for ENTER, then Submit
   node index.mjs describe --publish                      # push new descriptions for ALL apps
   ```

   Flags:
   - `--only a,b,c` — restrict to specific slugs
   - `--publish` — actually click **Submit** (default is a dry run)
   - `--discover` — read-only: dump each edit form's textareas/inputs/buttons to
     `artifacts/describe-discover-*.json` (use this if the portal changes and the
     description field id moves)
   - `--pause-before-save` — fill the field, then wait for ENTER before saving
   - `--headless` — no visible browser (default is headed so you can watch)

   Edit the copy in `descriptions.json`. Screenshots (`<slug>-preview.png` /
   `<slug>-saved.png`) + a JSON summary land in `artifacts/`. Garmin re-reviews an
   app after a description change, so expect a short approval delay.

## Files

| File | Purpose |
|------|---------|
| `config.mjs` | URLs, selectors, timeouts — tune here if the portal changes |
| `index.mjs` | CLI (`login` / `scan` / `record` / `upload` / `describe`) |
| `lib.mjs` | browser session + local app discovery + config I/O |
| `apps.config.json` | slug → appId map (generated by `scan`, git-ignored) |
| `descriptions.json` | slug → store description text (used by `describe`) |
| `auth.json` | saved login session (git-ignored — **secret**) |
| `artifacts/` | screenshots, network recordings, upload summaries |

## Troubleshooting

- **"Session expired"** → `npm run login` again (cookies rotate).
- **`scan` finds nothing** → check `artifacts/scan.png` and
  `artifacts/scan-anchors.json`; the app-link selector in `index.mjs` may need a
  tweak for the current portal.
- **`upload` can't find the file input / publish button** → run `npm run record`,
  inspect the saved flow (`artifacts/recording-*.json`), and adjust `UPLOAD`
  selectors / `appUpdateUrl()` in `config.mjs`. Failure screenshots are in
  `artifacts/<slug>-error.png`.
- **`describe` can't find the description field** → run
  `node index.mjs describe --discover --only <slug>`, open the resulting
  `artifacts/describe-discover-*.json`, find the description `<textarea>` id, and
  update `DETAILS.descTextarea` in `config.mjs`. Always dry-run first (no
  `--publish`) and check `artifacts/<slug>-preview.png`.
