// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine + scoring + camera scroll.
//
// World coordinates: y grows upward, origin is the initial player
// spawn. The camera lock keeps the player's screen-y at the scroll
// line; whenever the player rises above that line we shift every
// platform down by the excess and add the excess to `worldHeight`
// (which IS the score). The player never falls below the camera
// floor — once they do, the run ends.
//
// Difficulty
//   `difficulty` is a 0..10 bucket derived from worldHeight. It's
//   passed to PlatformManager so the recycle logic can bias toward
//   moving / breakable platforms at higher altitudes.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;
using Toybox.Attention;
using Toybox.Lang;

const GS_MENU  = 0;
const GS_READY = 1;
const GS_PLAY  = 2;
const GS_OVER  = 3;

// Chess-style menu rows:
//   row 0 = START
//   row 1 = LEADERBOARD (global; no variant)
const JT_MENU_ROWS = 2;
const JT_ROW_START = 0;
const JT_ROW_LB    = 1;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "jumptower";

// Sound + haptics master switch (OPTIONS: jt_fx; 0 = ON, 1 = OFF).
const JT_FX_KEY = "jt_fx";

// Selectable character-colour skin (OPTIONS: jt_skin). Index 0 = CLASSIC
// (always owned), 1 = NEON, 2 = GOLD. Higher tiers are gated on the shared
// Progress ownership set (shop-ready) and unlocked by climbing / rank.
const JT_SKIN_KEY   = "jt_skin";
const JT_SKIN_NEON  = "jt_neon";
const JT_SKIN_GOLD  = "jt_gold";
// Unlock thresholds — reached via best height (metres) OR account level.
const JT_NEON_LEVEL = 3;
const JT_NEON_M     = 200;
const JT_GOLD_LEVEL = 6;
const JT_GOLD_M     = 500;

class GameController {
    var state;
    var player;
    var platforms;
    var fx;               // particle pool (juice)

    // Menu state.
    var menuRow;

    var score;            // == worldHeight, in screen pixels
    var hi;

    // Coins — collected in-run bonus currency. Lifetime total unlocks
    // cosmetic frog skins (see skinTier()); best single-run haul gets
    // its own leaderboard variant.
    var coinsRun;
    var lifeCoins;
    var bestCoinsRun;
    var coinFlash;        // ticks remaining for "+1" pop feedback
    hidden var _newCoinsFlag;

    // Jetpack power-up — while active, gravity is overridden and the
    // player rockets straight through every platform above.
    var jetpackT;
    var jetpackFlash;      // ticks remaining for "JETPACK!" banner

    // Altitude zone — the backdrop + a one-shot banner change as the
    // player climbs into a new tier. Zone crossings also pay out a
    // small coin bonus so the milestone feels rewarding.
    var zone;
    var zoneMsg;
    var zoneFlashT;

    // Screen geometry
    var screenW;
    var screenH;
    var scrollLineY;      // screen-y where the camera locks

    // Difficulty (altitude bucket, 0..10) used to bias platform recycling.
    var difficulty;

    // Difficulty SETTING from the shared OPTIONS screen (jt_diff: 0=Easy
    // 1=Normal 2=Hard). Drives platform gap (spacing) so higher settings
    // demand near-perfect hops, and segments the leaderboard.
    var diffSetting;

    // FX
    var lastSpringFlash;  // ticks remaining for "BOING" feedback
    var deathShake;
    var shake;            // generic screen-shake ticks (spring/jetpack/save)
    var fxOn;             // sound + haptics enabled (jt_fx option)

    // Shield power-up — a one-hit bubble that saves you from a single
    // fatal fall, launching you back up instead of ending the run.
    var shieldActive;
    var shieldFlash;      // ticks remaining for the "SHIELD!" pickup banner
    var shieldSaveFlash;  // ticks remaining for the "SAVED!" banner

    // Coin combo — grabbing coins in quick succession builds a streak
    // shown in the HUD. Purely feedback (no score change) so the coins
    // leaderboard stays honest.
    var comboCount;
    var comboTimer;
    var comboFlash;

    // Bookkeeping for collision sweep
    var feetPrev;         // player feet y at start of last tick

    // Shared meta-progression (coins/XP/rank/skins) — one-shot game-over
    // unlock banner + the daily login toast queued by the App's checkIn.
    var pgUnlockMsg;      // "New skin: NEON" etc., or null
    var dailyMsg;         // daily-bonus toast text, or null
    var dailyT;           // ticks remaining for the daily toast

    function initialize() {
        state          = GS_MENU;
        menuRow        = JT_ROW_START;
        player         = new Player();
        platforms      = new PlatformManager();
        fx             = new ParticlePool();
        score          = 0;
        hi             = _loadHi();
        coinsRun       = 0;
        lifeCoins      = _loadLifeCoins();
        bestCoinsRun   = _loadBestCoinsRun();
        coinFlash      = 0;
        _newCoinsFlag  = false;
        jetpackT       = 0;
        jetpackFlash   = 0;
        zone           = 0;
        zoneMsg        = "";
        zoneFlashT     = 0;
        screenW = 240; screenH = 240; scrollLineY = 96;
        difficulty     = 0;
        diffSetting    = _loadDiffSetting();
        lastSpringFlash= 0;
        deathShake     = 0;
        shake          = 0;
        fxOn           = _loadFx();
        shieldActive   = false;
        shieldFlash    = 0;
        shieldSaveFlash= 0;
        comboCount     = 0;
        comboTimer     = 0;
        comboFlash     = 0;
        feetPrev       = 0;
        pgUnlockMsg    = null;
        dailyMsg       = null;
        dailyT         = 0;
        player.skin    = skinTier();
        player.skinSel = selectedSkin();
        // Pop the daily-bonus toast queued by the App on the day's first
        // launch (shown once over the first frames of the first run).
        try {
            var dm = Application.Storage.getValue("jt_daily_msg");
            if (dm != null) {
                dailyMsg = dm; dailyT = 70;
                Application.Storage.deleteValue("jt_daily_msg");
            }
        } catch (e) {}
    }

    // ── Shared meta-progression (shop-ready via the Progress module) ─────────
    // Selected-and-owned character skin: 0 = CLASSIC, 1 = NEON, 2 = GOLD.
    // A locked pick falls back to CLASSIC so selection is always safe (before
    // and after a future shop grants ownership).
    function selectedSkin() {
        var sel = 0;
        try {
            var v = Application.Storage.getValue(JT_SKIN_KEY);
            if (v instanceof Lang.Number) { sel = v; }
        } catch (e) {}
        if (sel == 2 && Progress.owns(JT_SKIN_GOLD)) { return 2; }
        if (sel == 1 && Progress.owns(JT_SKIN_NEON)) { return 1; }
        return 0;
    }

    // Rank title for the game-over progression line.
    function rankName() { return Progress.rankName(); }

    // Grant coins + XP proportional to the height reached, and unlock the
    // cosmetic skins the first time their milestone (height OR level) is met.
    // Idempotent unlock calls make the "UNLOCKED" banner fire exactly once.
    hidden function _awardProgress() {
        var m = heightMetres();
        var coinsGain = 5 + m / 20;
        var xpGain    = 10 + m / 5;
        Progress.addCoins(coinsGain);
        Progress.addXp(xpGain);
        var lvl = Progress.level();
        var uNeon = Progress.unlockIfReached(JT_SKIN_NEON, lvl, JT_NEON_LEVEL)
                 || Progress.unlockIfReached(JT_SKIN_NEON, m,   JT_NEON_M);
        var uGold = Progress.unlockIfReached(JT_SKIN_GOLD, lvl, JT_GOLD_LEVEL)
                 || Progress.unlockIfReached(JT_SKIN_GOLD, m,   JT_GOLD_M);
        if (uGold)      { pgUnlockMsg = "UNLOCKED: GOLD"; }
        else if (uNeon) { pgUnlockMsg = "UNLOCKED: NEON"; }
    }

    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(JT_FX_KEY);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) { }
        return true;
    }

    hidden function _loadHi() {
        try {
            var v = Application.Storage.getValue("hi");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    hidden function _saveHi() {
        try { Application.Storage.setValue("hi", hi); } catch (e) { }
    }
    hidden function _loadLifeCoins() {
        try {
            var v = Application.Storage.getValue("lifeCoins");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    hidden function _saveLifeCoins() {
        try { Application.Storage.setValue("lifeCoins", lifeCoins); } catch (e) { }
    }
    hidden function _loadBestCoinsRun() {
        try {
            var v = Application.Storage.getValue("bestCoinsRun");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    // Difficulty setting from the shared OPTIONS screen (jt_diff: 0/1/2,
    // default 1 = Normal so the default climb matches today's spacing).
    hidden function _loadDiffSetting() {
        try {
            var v = Application.Storage.getValue("jt_diff");
            if (v != null && v instanceof Number && v >= 0 && v <= 2) { return v; }
        } catch (e) { }
        return 1;
    }

    // Leaderboard variant = difficulty, so Easy/Normal/Hard rank separately.
    function diffVariant() {
        return ["easy", "normal", "hard"][diffSetting];
    }
    hidden function _saveBestCoinsRun() {
        try { Application.Storage.setValue("bestCoinsRun", bestCoinsRun); } catch (e) { }
    }

    // 0 = default, 1 = Ice, 2 = Gold, 3 = Diamond. Purely cosmetic —
    // gives every coin picked up a reason to matter even after a run
    // ends in a splat.
    function skinTier() {
        if (lifeCoins >= 1500) { return 3; }
        if (lifeCoins >= 500)  { return 2; }
        if (lifeCoins >= 150)  { return 1; }
        return 0;
    }

    // 0 GROUND, 1 SKY, 2 STRATOSPHERE, 3 SPACE.
    function zoneForHeight(m) {
        if (m >= 800) { return 3; }
        if (m >= 400) { return 2; }
        if (m >= 150) { return 1; }
        return 0;
    }
    function zoneName(z) {
        if (z == 1) { return "THE SKY";      }
        if (z == 2) { return "THE STRATOSPHERE"; }
        if (z == 3) { return "OUTER SPACE";  }
        return "GROUND";
    }

    function setScreen(w, h) {
        screenW     = w;
        screenH     = h;
        scrollLineY = (h * Physics.SCROLL_LINE_PCT) / 100;

        // Scale physics linearly with screen height so the jump arc
        // always covers the same fraction of the screen — without it,
        // a 416 px watch would have an unreachable platform gap.
        var s = (h * 1.0) / 240.0;
        if (s < 0.85) { s = 0.85; }
        Physics.GRAVITY     = 0.42 * s;
        Physics.JUMP_VY     = -8.6 * s;     // a touch punchier than v1
        Physics.MAX_FALL_VY = 11.0 * s;
        Physics.MOVE_VX     = 3.6  * ((w * 1.0) / 240.0);

        var platW = (w * 28) / 100; if (platW < 38) { platW = 38; }
                                    if (platW > 80) { platW = 80; }
        var platH = (h * 3)  / 100; if (platH < 5)  { platH = 5;  }
                                    if (platH > 9)  { platH = 9;  }
        // Cap the gap to ~75 % of theoretical max jump height so the
        // climb is always reachable even with a slight mis-aim.
        var jumpH = (Physics.JUMP_VY * Physics.JUMP_VY)
                    / (2.0 * Physics.GRAVITY);
        var maxGap = (jumpH * 75) / 100;
        var gap   = (h * 16) / 100;
        // Difficulty setting scales platform spacing: Easy packs them
        // closer, Hard spreads them near the reachable limit.
        gap = (gap * [86, 100, 124][diffSetting]) / 100;
        if (gap < 30)     { gap = 30; }
        if (gap > maxGap) { gap = maxGap; }
        platforms.setBounds(w, platW, platH, gap);
    }

    function ready() {
        var bx = screenW / 2;
        var hh = (screenH * 5) / 100; if (hh < 9)  { hh = 9;  }
        var hw = (screenW * 4) / 100; if (hw < 7)  { hw = 7;  }

        // Seed the foundation first so we know exactly where to drop
        // the frog on top of it. Previously the player center was
        // placed at `by - 6` while the platform top was at `by + 4` —
        // with the half-height (≥9 px) added on, the frog's *feet*
        // ended up several pixels BELOW the foundation. The collision
        // sweep requires `feetPrev <= platform.y`, so the very first
        // tick failed the check and the frog fell straight through.
        var by = (screenH * 80) / 100;
        var foundationTopY = by + 4;
        platforms.reset();
        platforms.seed(foundationTopY, 0);

        // Position the frog so its feet rest 1 px above the platform top.
        // (feet = player.y + player.h; want feet = foundationTopY - 1)
        var spawnY = foundationTopY - hh - 1;
        player.reset(bx, spawnY, hw, hh);
        // Give the very first hop for free — Doodle-Jump-style — so the
        // game starts in motion instead of teasing a 1-frame fall.
        player.vy = Physics.JUMP_VY;

        score           = 0;
        difficulty      = 0;
        lastSpringFlash = 0;
        deathShake      = 0;
        shake           = 0;
        feetPrev        = player.y + player.h;
        coinsRun        = 0;
        coinFlash       = 0;
        _newCoinsFlag   = false;
        jetpackT        = 0;
        jetpackFlash    = 0;
        zone            = 0;
        zoneMsg         = "";
        zoneFlashT      = 0;
        fxOn            = _loadFx();
        shieldActive    = false;
        shieldFlash     = 0;
        shieldSaveFlash = 0;
        comboCount      = 0;
        comboTimer      = 0;
        comboFlash      = 0;
        fx.clear();
        player.skin     = skinTier();
        player.skinSel  = selectedSkin();
        pgUnlockMsg     = null;
        state           = GS_READY;
    }

    function gotoMenu() { state = GS_MENU; }

    // Public entry used by the auto-start MainView: seed a run and drop
    // straight into play (no in-game menu).
    function beginRun() { ready(); state = GS_PLAY; }

    // ── Menu nav ────────────────────────────────────────────
    function menuPrev()    { menuRow = (menuRow + JT_MENU_ROWS - 1) % JT_MENU_ROWS; }
    function menuNext()    { menuRow = (menuRow + 1) % JT_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < JT_MENU_ROWS) { menuRow = i; } }
    // START launches a run; the LEADERBOARD row is handled by the view
    // (MainView.openLeaderboard) because the controller can't push views.
    function menuActivate() {
        if (menuRow == JT_ROW_START) { ready(); state = GS_PLAY; }
    }

    // Hold inputs (continuous)
    function setHoldLeft(b)  { player.holdLeft  = b; }
    function setHoldRight(b) { player.holdRight = b; }
    // Tap impulse (one-shot)
    function tapDir(d) {
        if (state == GS_OVER) { beginRun(); return; }
        if (state == GS_READY) { state = GS_PLAY; }
        player.tapImpulse(d);
    }

    function step() {
        if (state == GS_MENU)  { return; }
        if (state == GS_OVER) {
            if (deathShake > 0) { deathShake = deathShake - 1; }
            return;
        }
        // READY auto-promotes to PLAY on first integration tick — keeps
        // the menu animation simple and the first jump immediate.
        if (state == GS_READY) { state = GS_PLAY; }

        // Advance particle juice.
        fx.step();

        // Remember previous feet-y for the collision sweep.
        feetPrev  = player.y + player.h;
        var yPrev = player.y;

        // Jetpack thrust overrides gravity for its duration — the frog
        // rockets straight up, passing through everything above (the
        // falling-only collision gate below naturally lets it fly
        // through since vy stays strongly negative throughout).
        if (jetpackT > 0) {
            player.vy = Physics.JUMP_VY * 1.8;
            jetpackT  = jetpackT - 1;
            // Exhaust trail — a couple of flame flecks under the frog.
            var fxx = player.x + ((Math.rand() % 5) - 2);
            var fxy = player.y + player.h + 2;
            fx.emit(fxx, fxy, (Math.rand() % 3) - 1, 1.5 + (Math.rand() % 10) / 10.0,
                    (Math.rand() % 2 == 0) ? 0xFFAA00 : 0xFF5500, 8, 3, false);
        }

        // Integrate player.
        player.step(screenW);
        player.stepFx();
        platforms.step();

        // Coins — collectable independent of falling/rising so the
        // common "grab it on the way up" case just works. Checked on
        // the raw post-integration position, before any collision
        // snap below.
        var got = platforms.collectCoins(player.x - player.w, player.x + player.w,
                                         yPrev, player.y);
        if (got > 0) {
            coinsRun    = coinsRun  + got;
            lifeCoins   = lifeCoins + got;
            coinFlash   = 14;
            player.skin = skinTier();
            // Coin combo — chained pickups within a short window build a
            // streak (feedback only; coin count is unchanged).
            if (comboTimer > 0) { comboCount = comboCount + got; }
            else                { comboCount = got; }
            comboTimer = 55;
            comboFlash = 16;
            fx.burst(player.x, player.y, 7, 0xFFE066, 3.0, false, 14, 3, -1.2);
            if (comboCount >= 3) { _tone("combo"); _vibe(20, 40); }
            else                 { _tone("coin");  }
        }
        if (comboTimer > 0) {
            comboTimer = comboTimer - 1;
            if (comboTimer == 0) { comboCount = 0; }
        }

        // Collision: only when falling (vy >= 0). A negative vy means
        // we're rising → pass UP through platforms.
        var falling = (player.vy >= 0);
        var feetNow = player.y + player.h;
        var hitInfo = platforms.tryBounce(player.x - player.w,
                                          player.x + player.w,
                                          feetPrev, feetNow, falling);
        var hit     = hitInfo[0];
        var platTop = hitInfo[1];
        if (hit > 0) {
            // Snap the player's feet to the platform top.  At terminal
            // fall speed the frog can be 15+ px BELOW the rail by the
            // time the collision is detected; without this snap the
            // jump impulse alone may not be enough to climb back above
            // the platform on the next tick, causing visible jitter
            // and — worst case — a re-tunnel on the very next tick.
            player.y = platTop - player.h;
            feetPrev = platTop;
            player.squashT = 5;
            if (hit == 1) {
                player.bounce();
                // Landing dust puff (no sound/haptic — hops are constant).
                fx.burst(player.x, platTop, 4, 0xBBAA88, 1.8, true, 10, 2, -0.4);
            } else if (hit == 2) {
                // Spring: 1.5× the normal jump.
                player.vy = Physics.JUMP_VY * 1.5;
                lastSpringFlash = 6;
                shake = 4;
                fx.burst(player.x, platTop, 9, 0x66CCFF, 3.2, false, 14, 3, -1.6);
                _tone("spring"); _vibe(35, 90);
            } else if (hit == 3) {
                // Jetpack: launch hard and keep thrusting for ~2.2 s.
                player.vy    = Physics.JUMP_VY * 1.8;
                jetpackT     = 55;
                jetpackFlash = 24;
                shake = 6;
                fx.burst(player.x, platTop, 10, 0xFFAA00, 3.5, false, 16, 3, 0.6);
                _tone("jetpack"); _vibe(60, 160);
            } else if (hit == 4) {
                // Shield pickup: a normal bounce that also arms the bubble.
                player.bounce();
                shieldActive = true;
                shieldFlash  = 24;
                fx.burst(player.x, player.y, 10, 0x66FFCC, 3.0, false, 16, 3, -0.6);
                _tone("shield"); _vibe(45, 110);
            } else {
                // Breakable rail: bounce off it as it crumbles into shards.
                player.bounce();
                fx.burst(player.x, platTop, 8, 0xE25075, 2.6, true, 14, 3, -0.2);
                _tone("hop");
            }
        }

        // Camera scroll — if player rises above the lock line on screen,
        // pull every platform down by the excess and bump score.
        var playerScreenY = _worldToScreen(player.y);
        if (playerScreenY < scrollLineY) {
            var dy = scrollLineY - playerScreenY;
            // Apply scroll to player + platforms + particles.
            player.y = player.y + dy;
            feetPrev = feetPrev + dy;
            platforms.applyScroll(dy, screenH + 20, difficulty);
            fx.applyScroll(dy);
            score = score + dy;
            _updateDifficulty();
            if (score > hi) {
                // Update mid-run so a crash doesn't lose the new best.
                hi = score;
            }

            // Altitude zone crossing — the backdrop shifts and a
            // milestone banner + coin bonus fires the first time each
            // tier is reached this run.
            var nz = zoneForHeight(heightMetres());
            if (nz > zone) {
                zone        = nz;
                zoneMsg     = "ENTERING " + zoneName(nz);
                zoneFlashT  = 70;
                coinsRun    = coinsRun  + 8;
                lifeCoins   = lifeCoins + 8;
                player.skin = skinTier();
                _tone("zone"); _vibe(50, 130);
                fx.burst(screenW / 2, scrollLineY, 12, 0xFFEE66, 4.0, false, 18, 3, 0);
            }
        }

        // Death — player fell off the bottom. A live shield spends
        // itself to save the run: pop the frog back onto the screen with
        // a big bounce instead of ending it.
        if (_worldToScreen(player.y) > screenH + 12) {
            if (shieldActive) {
                shieldActive    = false;
                shieldSaveFlash = 40;
                player.y        = scrollLineY;
                player.vy       = Physics.JUMP_VY * 1.7;
                player.squashT  = 5;
                feetPrev        = player.y + player.h;
                shake           = 8;
                fx.burst(player.x, player.y, 14, 0x66FFCC, 4.0, false, 20, 3, 0);
                _tone("save"); _vibe(80, 220);
            } else {
                _die();
            }
        }

        if (lastSpringFlash  > 0) { lastSpringFlash  = lastSpringFlash  - 1; }
        if (jetpackFlash     > 0) { jetpackFlash     = jetpackFlash     - 1; }
        if (coinFlash        > 0) { coinFlash        = coinFlash        - 1; }
        if (zoneFlashT       > 0) { zoneFlashT       = zoneFlashT       - 1; }
        if (shieldFlash      > 0) { shieldFlash      = shieldFlash      - 1; }
        if (shieldSaveFlash  > 0) { shieldSaveFlash  = shieldSaveFlash  - 1; }
        if (comboFlash       > 0) { comboFlash       = comboFlash       - 1; }
        if (shake            > 0) { shake            = shake            - 1; }
        if (dailyT           > 0) { dailyT           = dailyT           - 1; }
    }

    hidden function _die() {
        player.alive = false;
        deathShake   = 8;
        fx.burst(player.x, player.y, 16, 0x66CC44, 3.5, true, 22, 3, -1.0);
        _tone("die"); _vibe(90, 320);
        if (score > hi) { hi = score; }
        _saveHi();
        _saveLifeCoins();
        _newCoinsFlag = false;
        if (coinsRun > bestCoinsRun) {
            bestCoinsRun  = coinsRun;
            _newCoinsFlag = true;
            _saveBestCoinsRun();
        }
        // Shared meta-progression: award coins + XP and unlock height skins.
        _awardProgress();
        state = GS_OVER;
        // Submit the run's height (the metres value shown to the player)
        // to the global leaderboard. No variant for Jump Tower.
        Leaderboard.submitScore(LB_GAME_ID, heightMetres().toNumber(), diffVariant());
        Leaderboard.showPostGame(LB_GAME_ID, diffVariant(), "JUMP TOWER");
        // Secondary variant — best coin haul in a single run. Only
        // submitted on a new personal best, matching the pattern used
        // for the other games' bonus leaderboard categories.
        if (_newCoinsFlag) {
            Leaderboard.submitScore(LB_GAME_ID, bestCoinsRun, "coins");
        }
    }

    function hasNewCoinsRecord() { return _newCoinsFlag; }

    // ── Sound & haptics (gated by the jt_fx OPTION) ─────────────────
    hidden function _tone(kind) {
        if (!fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t = Attention.TONE_KEY;
        if      (kind.equals("die"))     { t = Attention.TONE_FAILURE; }
        else if (kind.equals("save"))    { t = Attention.TONE_SUCCESS; }
        else if (kind.equals("jetpack")) { t = Attention.TONE_SUCCESS; }
        else if (kind.equals("shield"))  { t = Attention.TONE_INTERVAL_ALERT; }
        else if (kind.equals("spring"))  { t = Attention.TONE_LOUD_BEEP; }
        else if (kind.equals("zone"))    { t = Attention.TONE_CANARY; }
        else if (kind.equals("combo"))   { t = Attention.TONE_LAP; }
        else if (kind.equals("coin"))    { t = Attention.TONE_KEY; }
        else if (kind.equals("hop"))     { t = Attention.TONE_KEY; }
        try { Attention.playTone(t); } catch (e) { }
    }

    hidden function _vibe(intensity, duration) {
        if (!fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try {
            Attention.vibrate([new Attention.VibeProfile(intensity, duration)]);
        } catch (e) { }
    }

    hidden function _updateDifficulty() {
        // 0..10 buckets by every ~40 metres (240 px screens).
        var d = score / (40 * screenH / 240);
        if (d > 10) { d = 10; }
        difficulty = d;
    }

    // World-y → screen-y. World-y grows upward, screen-y grows downward,
    // so we mirror around the scroll line. Player at screen Y = playerScreenY.
    function _worldToScreen(wy) {
        return wy;
    }

    // For the view: get screen Y from world Y (currently a 1:1 mapping
    // since the camera scroll mutates the world coords directly).
    function worldToScreen(wy) {
        return wy;
    }

    // Convenience for the HUD: "metres climbed" feels nicer than raw px.
    function heightMetres() {
        // Convert pixels → "metres": tuned so a 240 px screen ≈ 100 m at
        // mid-air, gives nice round numbers like 50 / 100 / 250 / 500.
        return score / 6;
    }
}
