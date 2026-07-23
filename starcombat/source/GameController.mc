// ═══════════════════════════════════════════════════════════════
// GameController.mc — StarCombat game state + logic.
//
// All enemies and bolts are stored in parallel arrays to keep
// allocations out of the hot path.  One tick (80 ms) advances:
//   1. read calibrated accel → smooth gaze yaw/pitch
//   2. enemies fly closer, drift in world angles
//   3. project to screen; check ram damage
//   4. enemy fire timer → spawn green bolt aimed at centre
//   5. bolts advance; if they hit centre → player damage
//   6. age explosions, laser flash, shake, hit-flash
//
// State persists via Application.Storage under SC_K_* keys.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;
using Toybox.Attention;

class GameController {

    // ── Public state ──────────────────────────────────────────
    var state;                  // SC_MENU | SC_PLAY | SC_OVER
    var menuRow;
    var sens;
    var diff;

    // Game vars (PLAY).
    var score;
    var bestScore;
    var level;
    var kills;
    var killTarget;
    var ammo;
    var maxAmmo;
    var shields;
    var maxShields;
    var tick;
    var shakeT;
    var hitT;
    var scoreFlashT;
    var levelUpT;        // flash ticks when level just advanced
    var noAmmoT;         // flash ticks when shot blocked by empty mag
    var muzzleT;         // player muzzle-flash timer
    var rapidT;          // rapid-fire power-up: free shots while > 0

    // ── Meta-progression (shared, shop-ready via Progress module) ──
    var skin;            // cosmetic ship skin index (SC_SKIN_*)
    var pgUnlockMsg;     // one-shot "UNLOCKED" banner for game-over card
    var pgStreak;        // login streak snapshot for the game-over card

    // ── One-shot toast (daily bonus) ──────────────────────────
    var toastMsg;
    var toastT;

    // Aim (smoothed).
    var gazeYaw;
    var gazePitch;
    hidden var _tYaw;
    hidden var _tPitch;
    hidden var _calX;
    hidden var _calY;
    var calibrated;

    // Screen metrics (refreshed in syncDims).
    var sw;
    var sh;
    var cx;
    var cy;

    // Enemies — parallel arrays.
    var eLive;
    var eType;          // SC_ET_*
    var eHP;            // hit points (1 for most, 2 for cruiser)
    var eYaw;
    var ePitch;
    var eDist;
    var eDYaw;
    var eDPitch;
    var eSpd;
    var eHead;          // visual bank, just rotates hull on screen
    var eFireT;         // ticks until next shot
    var eFlashT;        // hit flash (visible flash after non-killing hit)
    var eSx;            // cached screen x
    var eSy;
    var eSz;            // cached half-size in px

    // Enemy bolts.  Internally bX/bY are stored in the FIRE-TIME
    // gaze frame, so they advance at fixed velocity along the line
    // toward where the player was looking when the shot was fired.
    // At render & hit-check time we project to the CURRENT gaze
    // frame by subtracting (gaze - bAim) * SC_FOV, which lets the
    // player dodge by rotating their view.
    var bLive;
    var bX;
    var bY;
    var bVx;
    var bVy;
    var bAimY;   // gazeYaw at fire time
    var bAimP;   // gazePitch at fire time

    // Explosions (screen-space).
    var xLive;
    var xX;
    var xY;
    var xAge;

    // Debris particles (screen-space) — cheap sparks on ship death.
    var pLive;
    var pX;
    var pY;
    var pVx;
    var pVy;
    var pAge;
    var pCol;

    // Power-ups — live in the same angular world as enemies, fly in
    // from deep space, and are collected by shooting them.
    var puLive;
    var puType;
    var puYaw;
    var puPitch;
    var puDist;
    var puSpd;
    var puSx;
    var puSy;
    var puSz;
    hidden var _puSpawnT;

    // Player laser flash (screen-space).
    var laserTx;
    var laserTy;
    var laserAge;

    // Star field (world angles + parallax depth layer).
    var sYaw;
    var sPitch;
    var sDepth;   // 1 (far, slow) .. 3 (near, fast) — drives parallax speed

    // Spawn timer.
    hidden var _spawnT;

    // PRNG seed.
    hidden var _rng;

    // ── Sound + haptics (OPTIONS: sc_fx) ──────────────────────
    hidden var _fxOn;          // master switch (false = OFF)
    hidden var _lastFireTone;  // tick of last fire tone (gate rapid-fire)

    // ── Init ──────────────────────────────────────────────────
    function initialize() {
        sw = 260; sh = 260; cx = 130; cy = 130;

        eLive   = new [SC_MAX_ENEMIES];
        eType   = new [SC_MAX_ENEMIES];
        eHP     = new [SC_MAX_ENEMIES];
        eYaw    = new [SC_MAX_ENEMIES];
        ePitch  = new [SC_MAX_ENEMIES];
        eDist   = new [SC_MAX_ENEMIES];
        eDYaw   = new [SC_MAX_ENEMIES];
        eDPitch = new [SC_MAX_ENEMIES];
        eSpd    = new [SC_MAX_ENEMIES];
        eHead   = new [SC_MAX_ENEMIES];
        eFireT  = new [SC_MAX_ENEMIES];
        eFlashT = new [SC_MAX_ENEMIES];
        eSx     = new [SC_MAX_ENEMIES];
        eSy     = new [SC_MAX_ENEMIES];
        eSz     = new [SC_MAX_ENEMIES];

        bLive   = new [SC_MAX_BOLTS];
        bX      = new [SC_MAX_BOLTS];
        bY      = new [SC_MAX_BOLTS];
        bVx     = new [SC_MAX_BOLTS];
        bVy     = new [SC_MAX_BOLTS];
        bAimY   = new [SC_MAX_BOLTS];
        bAimP   = new [SC_MAX_BOLTS];

        xLive   = new [SC_MAX_EXP];
        xX      = new [SC_MAX_EXP];
        xY      = new [SC_MAX_EXP];
        xAge    = new [SC_MAX_EXP];

        pLive   = new [SC_MAX_PARTS];
        pX      = new [SC_MAX_PARTS];
        pY      = new [SC_MAX_PARTS];
        pVx     = new [SC_MAX_PARTS];
        pVy     = new [SC_MAX_PARTS];
        pAge    = new [SC_MAX_PARTS];
        pCol    = new [SC_MAX_PARTS];

        puLive  = new [SC_MAX_POWERUPS];
        puType  = new [SC_MAX_POWERUPS];
        puYaw   = new [SC_MAX_POWERUPS];
        puPitch = new [SC_MAX_POWERUPS];
        puDist  = new [SC_MAX_POWERUPS];
        puSpd   = new [SC_MAX_POWERUPS];
        puSx    = new [SC_MAX_POWERUPS];
        puSy    = new [SC_MAX_POWERUPS];
        puSz    = new [SC_MAX_POWERUPS];

        sYaw    = new [SC_NSTARS];
        sPitch  = new [SC_NSTARS];
        sDepth  = new [SC_NSTARS];

        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            eLive[i]   = 0;
            eType[i]   = SC_ET_DESTROYER;
            eHP[i]     = 1;
            eFlashT[i] = 0;
            eSx[i]     = -9999;
            eSy[i]     = -9999;
            eSz[i]     = 4;
        }
        for (var i = 0; i < SC_MAX_BOLTS; i++)   { bLive[i] = 0; }
        for (var i = 0; i < SC_MAX_EXP; i++)     { xLive[i] = 0; xAge[i] = 0; }
        for (var i = 0; i < SC_MAX_PARTS; i++)   { pLive[i] = 0; }
        for (var i = 0; i < SC_MAX_POWERUPS; i++) {
            puLive[i] = 0; puSx[i] = -9999; puSy[i] = -9999; puSz[i] = 6;
        }

        state       = SC_MENU;
        menuRow     = SC_ROW_START;
        sens        = SC_SENS_NORMAL;
        diff        = SC_DIFF_NORMAL;
        score       = 0;
        bestScore   = 0;
        level       = 1;
        kills       = 0;
        killTarget  = SC_LVL_BASE + 2;
        ammo        = SC_AMMO_MAX;
        maxAmmo     = SC_AMMO_MAX;
        maxShields  = 3;
        shields     = 3;
        tick        = 0;
        shakeT      = 0;
        hitT        = 0;
        scoreFlashT = 0;
        levelUpT    = 0;
        noAmmoT     = 0;
        muzzleT     = 0;
        rapidT      = 0;
        skin        = SC_SKIN_CLASSIC;
        pgUnlockMsg = null;
        pgStreak    = 0;
        toastMsg    = null;
        toastT      = 0;
        _puSpawnT   = SC_PU_SPAWN;

        gazeYaw  = 0.0; gazePitch  = 0.0;
        _tYaw    = 0.0; _tPitch    = 0.0;
        _calX    = 0;   _calY      = 0;
        calibrated = false;

        laserTx = 0; laserTy = 0; laserAge = 0;
        _spawnT = 35;
        _rng    = 2718281;

        _fxOn        = _loadFx();
        _lastFireTone = -99;

        _loadPrefs();
        _seedStars();
    }

    // ── Screen size sync ──────────────────────────────────────
    function syncDims(w, h) {
        sw = w; sh = h; cx = w / 2; cy = h / 2;
    }

    // ── Persistence ───────────────────────────────────────────
    hidden function _li(k, d) {
        try {
            var v = Application.Storage.getValue(k);
            if (v != null && v instanceof Number) { return v; }
        } catch (e) {}
        return d;
    }
    hidden function _sv(k, v) { try { Application.Storage.setValue(k, v); } catch (e) {} }
    hidden function _loadPrefs() {
        sens      = _li(SC_K_SENS, SC_SENS_NORMAL); if (sens < 0 || sens > 2) { sens = SC_SENS_NORMAL; }
        diff      = _li(SC_K_DIFF, SC_DIFF_NORMAL); if (diff < 0 || diff > 2) { diff = SC_DIFF_NORMAL; }
        bestScore = _li(SC_K_BEST, 0);
        skin      = _li(SC_K_SKIN, SC_SKIN_CLASSIC); if (skin < 0 || skin > 2) { skin = SC_SKIN_CLASSIC; }
    }
    function savePrefs() {
        _sv(SC_K_SENS, sens);
        _sv(SC_K_DIFF, diff);
        _sv(SC_K_BEST, bestScore);
    }

    // ── Sound + haptics (best-effort; silent hardware is fine) ─────
    hidden function _loadFx() {
        try {
            var v = Application.Storage.getValue(SC_K_FX);
            if (v instanceof Number && v == 1) { return false; }
        } catch (e) { }
        return true;
    }
    // kind: 0 fire · 1 kill · 2 damage · 3 game-over · 4 level-up · 5 power-up
    hidden function _tone(kind) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t;
        if      (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
        else if (kind == 2) { t = Attention.TONE_ALERT_LO; }
        else if (kind == 3) { t = Attention.TONE_FAILURE; }
        else if (kind == 4) { t = Attention.TONE_ALERT_HI; }
        else if (kind == 5) { t = Attention.TONE_SUCCESS; }
        else                { t = Attention.TONE_KEY; }
        try { Attention.playTone(t); } catch (e) {}
    }
    hidden function _vibe(intensity, duration) {
        if (!_fxOn) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try { Attention.vibrate([new Attention.VibeProfile(intensity, duration)]); } catch (e) {}
    }

    // ── Menu ──────────────────────────────────────────────────
    function menuNext()        { menuRow = (menuRow + 1) % SC_MENU_ROWS; }
    function menuPrev()        { menuRow = (menuRow + SC_MENU_ROWS - 1) % SC_MENU_ROWS; }
    function setMenuRow(r)     { if (r >= 0 && r < SC_MENU_ROWS) { menuRow = r; } }
    function menuActivate() {
        if (menuRow == SC_ROW_SENS)  { sens = (sens + 1) % 3; savePrefs(); return; }
        if (menuRow == SC_ROW_DIFF)  { diff = (diff + 1) % 3; savePrefs(); return; }
        if (menuRow == SC_ROW_START) { _startGame(); return; }
    }
    function gotoMenu()    { state = SC_MENU; savePrefs(); }

    function sensName() {
        if (sens == SC_SENS_LOW)  { return "Low"; }
        if (sens == SC_SENS_HIGH) { return "High"; }
        return "Norm";
    }
    function diffName() {
        if (diff == SC_DIFF_EASY) { return "Easy"; }
        if (diff == SC_DIFF_HARD) { return "Hard"; }
        return "Norm";
    }

    // ── Game start / restart ─────────────────────────────────
    hidden function _startGame() {
        // Re-read the cosmetic skin picked on the shared OPTIONS screen so a
        // change made in the menu applies to the very next run.
        skin = _li(SC_K_SKIN, SC_SKIN_CLASSIC); if (skin < 0 || skin > 2) { skin = SC_SKIN_CLASSIC; }
        _fxOn = _loadFx();
        _lastFireTone = -99;
        for (var i = 0; i < SC_MAX_ENEMIES; i++) { eLive[i] = 0; eFlashT[i] = 0; }
        for (var i = 0; i < SC_MAX_BOLTS; i++)   { bLive[i] = 0; }
        for (var i = 0; i < SC_MAX_EXP; i++)     { xLive[i] = 0; }
        for (var i = 0; i < SC_MAX_PARTS; i++)   { pLive[i] = 0; }
        for (var i = 0; i < SC_MAX_POWERUPS; i++) { puLive[i] = 0; }
        gazeYaw     = 0.0; gazePitch  = 0.0;
        _tYaw       = 0.0; _tPitch    = 0.0;
        calibrated  = false;
        score       = 0;
        level       = 1;
        kills       = 0;
        killTarget  = SC_LVL_BASE + 2;
        if      (diff == SC_DIFF_EASY) { maxShields = 5; maxAmmo = 26; }
        else if (diff == SC_DIFF_HARD) { maxShields = 1; maxAmmo = 14; }
        else                            { maxShields = 3; maxAmmo = 20; }
        shields     = maxShields;
        ammo        = maxAmmo;
        tick        = 0;
        shakeT      = 0;
        hitT        = 0;
        scoreFlashT = 0;
        levelUpT    = 0;
        noAmmoT     = 0;
        muzzleT     = 0;
        rapidT      = 0;
        laserAge    = 0;
        _spawnT     = 30;
        _puSpawnT   = SC_PU_SPAWN;
        pgUnlockMsg = null;
        pgStreak    = 0;
        state       = SC_PLAY;
    }

    // ── Cosmetic skin accents (clamped to what Progress owns) ─────
    // Selected-and-owned skin drives the player laser + reticle + muzzle
    // colour. A locked pick falls back to CLASSIC, keeping selection safe
    // pre-shop and post-shop alike.
    function skinLaser() {
        if (skin == SC_SKIN_NEON && Progress.owns("skin_neon")) { return 0x33FFAA; }
        if (skin == SC_SKIN_GOLD && Progress.owns("skin_gold")) { return 0xFFD24A; }
        return 0xFF3333;
    }
    function skinAccent() {
        if (skin == SC_SKIN_NEON && Progress.owns("skin_neon")) { return 0x66FFCC; }
        if (skin == SC_SKIN_GOLD && Progress.owns("skin_gold")) { return 0xFFCC44; }
        return 0x66CCEE;
    }

    // ── One-shot toast (daily bonus) ──────────────────────────────
    function showToast(msg, ticks) { toastMsg = msg; toastT = ticks; }
    function restart() { _startGame(); }
    // Public entry used by the menu-less MainView (auto-start).
    function startGame() { _startGame(); }

    // ── Accelerometer input (called every tick from MainView) ─
    // ax, ay: raw milli-g.  On first call we capture them as
    // calibration baseline so the resting wrist is gaze (0, 0).
    function handleTilt(ax, ay) {
        if (!calibrated) {
            _calX = ax; _calY = ay;
            calibrated = true;
        }
        // Scale (rad / milli-g) depends on sensitivity preset.
        var sc;
        if      (sens == SC_SENS_LOW)  { sc = 0.0026; }
        else if (sens == SC_SENS_HIGH) { sc = 0.0058; }
        else                            { sc = 0.0040; }
        var dx = ax - _calX;
        var dy = ay - _calY;
        // Dead zone (ignore tiny noise).
        if (dx > -40 && dx < 40) { dx = 0; }
        if (dy > -40 && dy < 40) { dy = 0; }
        var ty =  dx.toFloat() * sc;
        var tp = -dy.toFloat() * sc;
        // Wrists rotate backward (look-DOWN) far less comfortably
        // than forward (look-up), so amplify the down half of the
        // pitch range past a small dead zone — small wrist tilts
        // still give fine control, larger ones reach the bottom.
        if (tp > 0.25) { tp = 0.25 + (tp - 0.25) * 1.85; }
        // Asymmetric clamp: extend the downward reach so enemies
        // that drift below the horizon are still hittable.
        var limU = 1.4;
        var limD = 2.5;
        if (ty >  1.6) { ty =  1.6; }
        if (ty < -1.6) { ty = -1.6; }
        if (tp >  limD) { tp =  limD; }
        if (tp < -limU) { tp = -limU; }
        _tYaw   = ty;
        _tPitch = tp;
    }

    function recalibrate() { calibrated = false; }

    // ── Main tick ────────────────────────────────────────────
    function tickGame() {
        if (state != SC_PLAY) { return; }
        tick++;
        if (scoreFlashT > 0) { scoreFlashT--; }
        if (shakeT > 0)      { shakeT--; }
        if (hitT > 0)        { hitT--;   }
        if (laserAge > 0)    { laserAge--; }
        if (levelUpT > 0)    { levelUpT--; }
        if (noAmmoT  > 0)    { noAmmoT--;  }
        if (muzzleT  > 0)    { muzzleT--;  }
        if (rapidT   > 0)    { rapidT--;   }
        if (toastT   > 0)    { toastT--;   }
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (eFlashT[i] > 0) { eFlashT[i]--; }
        }

        // Smooth gaze (low-pass filter).
        var a;
        if      (sens == SC_SENS_LOW)  { a = 0.12; }
        else if (sens == SC_SENS_HIGH) { a = 0.32; }
        else                            { a = 0.22; }
        gazeYaw   = gazeYaw   + (_tYaw   - gazeYaw)   * a;
        gazePitch = gazePitch + (_tPitch - gazePitch) * a;

        // Move enemies — each ship drifts on its own trajectory.  No
        // homing on the player's gaze: you have to actively aim.
        // Ships do bank-shift slowly so they don't fly straight lines,
        // but they will NOT follow you under the crosshair.
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (eLive[i] == 0) { continue; }
            eDist[i] = eDist[i] - eSpd[i];

            // Slow sinusoidal sway so the trajectory isn't a perfect
            // line — gives ships a "weaving" feel while keeping them
            // independent of where you're looking.
            var sway = Math.sin(eHead[i] * 0.5) * 0.0008;
            eYaw[i]   = eYaw[i]   + eDYaw[i]   + sway;
            ePitch[i] = ePitch[i] + eDPitch[i];

            eHead[i] = eHead[i] + 0.03;
            if (eFireT[i] > 0) { eFireT[i]--; }
        }

        // Project enemies to screen + check ram.
        _projectEnemies();
        _checkRam();

        // Enemy fires.
        _enemyFireTick();

        // Move bolts.
        _advanceBolts();

        // Age explosions.
        for (var i = 0; i < SC_MAX_EXP; i++) {
            if (xLive[i] != 0) {
                xAge[i]++;
                if (xAge[i] >= SC_EXP_T) { xLive[i] = 0; }
            }
        }

        // Advance debris particles.
        _advanceParticles();

        // Advance + project power-ups.
        _tickPowerups();

        // Spawn timer.
        _spawnT--;
        if (_spawnT <= 0) {
            _trySpawn();
            var p = 50 - level * 4 - diff * 6;
            if (p < 10) { p = 10; }
            _spawnT = p;
        }

        // Power-up spawn timer — occasional, at most one live at a time.
        _puSpawnT--;
        if (_puSpawnT <= 0) {
            _trySpawnPowerup();
            _puSpawnT = SC_PU_SPAWN + _rand(120);
        }

        // Star drift (forward flight feel, parallax by depth).
        _driftStars();
    }

    // Returns [ox, oy] screen shake offsets.
    function shakeOff() {
        if (shakeT <= 0) { return [0, 0]; }
        var s = 2;
        var ox = ((tick & 1) == 0) ? s : -s;
        var oy = ((tick & 2) == 0) ? s : -s;
        return [ox, oy];
    }

    // ── Shoot (called by InputHandler) ───────────────────────
    // No autoaim.  The shot travels straight from the centre of the
    // screen (the scope) outward — it hits an enemy only if the
    // crosshair was actually ON the sprite.  Hit-tolerance scales
    // with each ship's on-screen silhouette radius (eSz), so a
    // distant TIE Fighter is a much harder target than a close
    // cruiser.  The green reticle merely WARNS that an enemy is
    // nearby; it does NOT mean a shot will land.
    function shoot() {
        if (state == SC_OVER) { restart(); return; }
        if (state != SC_PLAY) { return; }
        // Rapid-fire power-up: shots are free while it's active.
        var freeShot = (rapidT > 0);
        // Empty magazine — flash warning, refuse to fire.
        if (!freeShot && ammo <= 0) { noAmmoT = 8; _vibe(20, 40); return; }
        if (!freeShot) { ammo--; }
        muzzleT = SC_MUZZLE_T;
        // Laser "pew" — gated so held/rapid fire can't machine-gun the buzzer.
        if (tick - _lastFireTone >= 2) { _tone(0); _lastFireTone = tick; }

        // First: did the crosshair grab a floating power-up?
        if (_tryCollectPowerup()) { return; }

        // Find closest enemy whose silhouette contains screen centre.
        var best  = -1;
        var bestD = 99999.0;
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (eLive[i] == 0) { continue; }
            var dx = eSx[i] - cx;
            var dy = eSy[i] - cy;
            var d2 = dx * dx + dy * dy;
            // Sprite hit-radius (slightly tighter than visual size so
            // edge grazes still count as misses).  Minimum 3 px so
            // very far ships are still hittable with perfect aim.
            var rad = eSz[i] * 80 / 100;
            if (rad < 3) { rad = 3; }
            if (d2 < rad * rad && eDist[i] < bestD) {
                best  = i;
                bestD = eDist[i];
            }
        }
        if (best < 0) {
            // Miss: tiny flash, no kill, ammo still consumed.
            laserTx = cx; laserTy = 4; laserAge = 1;
            return;
        }

        laserTx = eSx[best]; laserTy = eSy[best]; laserAge = SC_LASER_T;
        eHP[best] = eHP[best] - 1;
        if (eHP[best] > 0) {
            // Wounded but not destroyed — small spark, no kill.
            eFlashT[best] = 4;
            shakeT = 1;
            _vibe(30, 30);
            return;
        }

        // KILLED.
        _addExplosion(eSx[best], eSy[best]);
        _burstParticles(eSx[best], eSy[best], eType[best]);
        eLive[best] = 0;
        var pts;
        if      (eType[best] == SC_ET_CRUISER) { pts = 150 + level * 8; }
        else if (eType[best] == SC_ET_TIE)     { pts = 80  + level * 5; }
        else                                    { pts = 50  + level * 5; }
        score       = score + pts;
        scoreFlashT = 6;
        shakeT      = 2;
        // Confirmed kill — punchy beep + short kick.
        _tone(1);
        _vibe(45, 55);

        // Ammo refund per confirmed kill.
        ammo = ammo + SC_AMMO_PER_HIT;
        if (ammo > maxAmmo) { ammo = maxAmmo; }

        // Progression.
        kills++;
        if (kills >= killTarget) { _levelUp(); }
    }

    hidden function _levelUp() {
        level++;
        kills      = 0;
        killTarget = SC_LVL_BASE + level * 2;
        score      = score + 200;
        ammo       = maxAmmo;
        if (shields < maxShields) { shields++; }
        levelUpT   = 18;
        shakeT     = 3;
        // Wave cleared — triumphant rising alert + solid pulse.
        _tone(4);
        _vibe(70, 130);
        // Fresh wave: clear stale incoming bolts so the player gets
        // a brief breather before the next assault.
        for (var i = 0; i < SC_MAX_BOLTS; i++) { bLive[i] = 0; }
    }

    // ── Projection ──────────────────────────────────────────
    hidden function _projectEnemies() {
        var TPI = Math.PI * 2.0;
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (eLive[i] == 0) { eSx[i] = -9999; eSy[i] = -9999; continue; }
            var dy = eYaw[i]   - gazeYaw;
            var dp = ePitch[i] - gazePitch;
            // Wrap yaw to [-pi, pi].
            if (dy >  Math.PI) { dy = dy - TPI; }
            if (dy < -Math.PI) { dy = dy + TPI; }
            eSx[i] = (cx + dy * SC_FOV).toNumber();
            eSy[i] = (cy + dp * SC_FOV).toNumber();
            var s = SC_BASE_SZ * SC_REF_DIST / eDist[i].toNumber();
            if (s < 3)  { s = 3;  }
            if (s > 80) { s = 80; }
            eSz[i] = s;
        }
    }

    // ── Ram check ──────────────────────────────────────────
    hidden function _checkRam() {
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (eLive[i] != 0 && eDist[i] <= SC_RAM_D) {
                _addExplosion(eSx[i], eSy[i]);
                _burstParticles(eSx[i], eSy[i], eType[i]);
                eLive[i] = 0;
                _damage();
            }
        }
    }

    // ── Damage ─────────────────────────────────────────────
    hidden function _damage() {
        shields--;
        hitT   = SC_HIT_T;
        shakeT = SC_SHAKE_T;
        if (shields <= 0) {
            if (score > bestScore) { bestScore = score; }
            savePrefs();
            state = SC_OVER;
            // Hull destroyed — harsh failure tone + long, heavy rumble.
            _tone(3);
            _vibe(100, 320);
            // Reward the run with coins + XP, unlock skins by rank, and
            // capture the streak for the game-over card.
            _awardProgress();
            // Submit final score to the global leaderboard, split by
            // difficulty variant.  Called once per run end.
            Leaderboard.submitScore(LB_GAME_ID, score, diffName());
            Leaderboard.showPostGame(LB_GAME_ID, diffName(), "STAR COMBAT");
        } else {
            // Took a hit but survived — warning tone + sharp jolt.
            _tone(2);
            _vibe(80, 140);
        }
    }

    // ── Meta-progression award (shared, shop-ready via Progress) ──
    // Grants coins + XP scaled by score and waves cleared, then unlocks
    // cosmetic ship skins at rank milestones. Fully guarded — a device
    // without Storage just no-ops. Coins are the future shop's currency;
    // skin ownership is the exact set a shop purchase would grant.
    hidden function _awardProgress() {
        try {
            var coinsGain = score / 50 + level * 3;
            if (coinsGain > 120) { coinsGain = 120; }
            var xpGain = score / 40 + level * 4;
            if (coinsGain > 0) { Progress.addCoins(coinsGain); }
            if (xpGain    > 0) { Progress.addXp(xpGain); }
            var lvl = Progress.level();
            var uNeon = Progress.unlockIfReached("skin_neon", lvl, 3);
            var uGold = Progress.unlockIfReached("skin_gold", lvl, 6);
            if      (uGold) { pgUnlockMsg = "UNLOCKED: GOLD SHIP"; }
            else if (uNeon) { pgUnlockMsg = "UNLOCKED: NEON SHIP"; }
            pgStreak = Progress.currentStreak();
        } catch (e) {}
    }

    // Themed StarCombat rank ladder derived from the shared XP level.
    function pgRank() {
        var lvl = 1;
        try { lvl = Progress.level(); } catch (e) {}
        if (lvl >= 25) { return "Legend"; }
        if (lvl >= 15) { return "Ace"; }
        if (lvl >= 10) { return "Commander"; }
        if (lvl >= 6)  { return "Pilot"; }
        if (lvl >= 3)  { return "Ensign"; }
        return "Cadet";
    }
    function pgLevel() {
        try { return Progress.level(); } catch (e) {}
        return 1;
    }
    function pgCoins() {
        try { return Progress.coins(); } catch (e) {}
        return 0;
    }

    // ── Enemy fire ─────────────────────────────────────────
    hidden function _enemyFireTick() {
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (eLive[i] == 0) { continue; }
            if (eFireT[i] > 0) { continue; }
            // Fire from anywhere within engagement range; the homing
            // step already keeps them near the player's view.
            if (eDist[i] > 750) {
                eFireT[i] = 15 + _rand(20);
                continue;
            }
            var sx = eSx[i]; var sy = eSy[i];
            // Off-screen but close enough: still shoot from edge.
            var ex = sx; var ey = sy;
            if (ex < 4)            { ex = 4; }
            if (ex > sw - 4)       { ex = sw - 4; }
            if (ey < 4)            { ey = 4; }
            if (ey > sh - 4)       { ey = sh - 4; }
            _spawnBolt(ex, ey);
            // Per-type fire rate multiplier (TIE faster, Cruiser slower).
            var base = 55 - level * 3 - diff * 10;
            if      (eType[i] == SC_ET_TIE)     { base = base * 70 / 100; }
            else if (eType[i] == SC_ET_CRUISER) { base = base * 140 / 100; }
            if (base < 14) { base = 14; }
            eFireT[i] = base + _rand(15);
        }
    }

    hidden function _spawnBolt(sx, sy) {
        var dx = (cx - sx).toFloat();
        var dy = (cy - sy).toFloat();
        var d  = Math.sqrt(dx * dx + dy * dy);
        if (d < 1.0) { return; }
        var vx = dx / d * SC_BOLT_SPD;
        var vy = dy / d * SC_BOLT_SPD;
        for (var i = 0; i < SC_MAX_BOLTS; i++) {
            if (bLive[i] == 0) {
                bX[i]    = sx.toFloat();
                bY[i]    = sy.toFloat();
                bVx[i]   = vx;
                bVy[i]   = vy;
                bAimY[i] = gazeYaw;
                bAimP[i] = gazePitch;
                bLive[i] = 1;
                return;
            }
        }
    }

    // Compute current screen position of bolt `i` accounting for
    // gaze drift since the bolt was fired.  Public so UIManager can
    // draw bolts where they actually appear from the player's view.
    function boltScreenX(i) {
        return bX[i] - (gazeYaw - bAimY[i]) * SC_FOV;
    }
    function boltScreenY(i) {
        return bY[i] - (gazePitch - bAimP[i]) * SC_FOV;
    }

    hidden function _advanceBolts() {
        for (var i = 0; i < SC_MAX_BOLTS; i++) {
            if (bLive[i] == 0) { continue; }
            bX[i] = bX[i] + bVx[i];
            bY[i] = bY[i] + bVy[i];
            // Project to the CURRENT gaze frame for hit/off-screen
            // tests so dodging via wrist tilt actually works.
            var px = bX[i] - (gazeYaw   - bAimY[i]) * SC_FOV;
            var py = bY[i] - (gazePitch - bAimP[i]) * SC_FOV;
            var dx = px - cx;
            var dy = py - cy;
            // Tight hit radius (~10 px) — easy to dodge when you
            // actively re-aim, but you still get clipped if you
            // hold the crosshair on the enemy line of fire.
            if (dx * dx + dy * dy < 110) {
                bLive[i] = 0;
                _damage();
                continue;
            }
            // Off-screen on current projection?
            if (px < -30 || px > sw + 30 ||
                py < -30 || py > sh + 30) {
                bLive[i] = 0;
            }
        }
    }

    // ── Enemy spawn ─────────────────────────────────────────
    hidden function _activeEnemyCount() {
        var c = 0;
        for (var i = 0; i < SC_MAX_ENEMIES; i++) { if (eLive[i] != 0) { c++; } }
        return c;
    }
    hidden function _maxActive() {
        var m = 1 + level / 2 + diff;
        if (m > SC_MAX_ENEMIES) { m = SC_MAX_ENEMIES; }
        return m;
    }
    hidden function _trySpawn() {
        if (_activeEnemyCount() >= _maxActive()) { return; }
        for (var i = 0; i < SC_MAX_ENEMIES; i++) {
            if (eLive[i] == 0) { _spawn(i); return; }
        }
    }
    // Pick an enemy type appropriate for the current level.  TIE
    // fighters appear from level 3, heavy cruisers from level 5.
    hidden function _pickType() {
        var roll = _rand(100);
        if (level <= 2) { return SC_ET_DESTROYER; }
        if (level <= 4) {
            return (roll < 60) ? SC_ET_DESTROYER : SC_ET_TIE;
        }
        // Level 5+ : full mix.
        if (roll < 40)      { return SC_ET_DESTROYER; }
        else if (roll < 75) { return SC_ET_TIE;       }
        else                { return SC_ET_CRUISER;   }
    }

    hidden function _spawn(i) {
        eLive[i]   = 1;
        eType[i]   = _pickType();
        eFlashT[i] = 0;

        // Spawn inside player's current view but ships then fly on
        // their OWN drift vector — you must aim to hit them.
        // Spawn near the player's current gaze with modest spread so
        // ships stay within the achievable wrist-tilt range.
        eYaw[i]     = gazeYaw   + (_randf() - 0.5) * 1.0;
        var pSpawn  = gazePitch + (_randf() - 0.5) * 0.7;
        // Keep enemies within reachable pitch (player clamp is
        // [-1.4 .. +2.5]).  Leave a small margin so the crosshair
        // can actually overlap the sprite, not just brush the edge.
        if (pSpawn >  1.9) { pSpawn =  1.9; }
        if (pSpawn < -1.0) { pSpawn = -1.0; }
        ePitch[i]   = pSpawn;
        eDist[i]    = SC_SPAWN_D.toFloat() + _rand(160).toFloat();
        // Significant lateral drift so the target moves while you aim.
        eDYaw[i]    = (_randf() - 0.5) * 0.012;
        eDPitch[i]  = (_randf() - 0.5) * 0.008;
        eHead[i]    = _randf() * Math.PI * 2.0;

        // Per-type stats.
        var base = 0.50 + level.toFloat() * 0.10 + diff.toFloat() * 0.18;
        var spdMul; var fireBase;
        if (eType[i] == SC_ET_TIE) {
            eHP[i]   = 1;
            spdMul   = 1.5;
            fireBase = 35;       // shoots quicker
        } else if (eType[i] == SC_ET_CRUISER) {
            eHP[i]   = 2;
            spdMul   = 0.7;
            fireBase = 55;       // shoots slower but tougher
        } else {
            eHP[i]   = 1;
            spdMul   = 1.0;
            fireBase = 45;
        }
        eSpd[i]   = base * spdMul + _randf() * 0.30;
        eFireT[i] = fireBase + _rand(25);
    }

    // ── Explosions ─────────────────────────────────────────
    hidden function _addExplosion(x, y) {
        for (var i = 0; i < SC_MAX_EXP; i++) {
            if (xLive[i] == 0) {
                xX[i]   = x;
                xY[i]   = y;
                xAge[i] = 0;
                xLive[i] = 1;
                return;
            }
        }
    }

    // ── Debris particles ───────────────────────────────────
    // Small, short-lived sparks flung outward from a destroyed ship —
    // pure juice, drawn as fading points. Shared fixed pool, no per-hit
    // allocation. Colour is themed by the ship type.
    hidden function _burstParticles(x, y, etype) {
        var col;
        if      (etype == SC_ET_TIE)     { col = 0xAADDFF; }
        else if (etype == SC_ET_CRUISER) { col = 0xFFCC66; }
        else                              { col = 0xFF9944; }
        var n = 6;
        for (var k = 0; k < n; k++) {
            var slot = -1;
            for (var i = 0; i < SC_MAX_PARTS; i++) {
                if (pLive[i] == 0) { slot = i; break; }
            }
            if (slot < 0) { return; }  // pool full — stop, keep it cheap
            var ang = _randf() * Math.PI * 2.0;
            var spd = 1.5 + _randf() * 3.0;
            pLive[slot] = 1;
            pX[slot]    = x.toFloat();
            pY[slot]    = y.toFloat();
            pVx[slot]   = Math.cos(ang) * spd;
            pVy[slot]   = Math.sin(ang) * spd;
            pAge[slot]  = 0;
            pCol[slot]  = col;
        }
    }
    hidden function _advanceParticles() {
        for (var i = 0; i < SC_MAX_PARTS; i++) {
            if (pLive[i] == 0) { continue; }
            pX[i] = pX[i] + pVx[i];
            pY[i] = pY[i] + pVy[i];
            pVx[i] = pVx[i] * 0.90;
            pVy[i] = pVy[i] * 0.90;
            pAge[i]++;
            if (pAge[i] >= SC_PART_T) { pLive[i] = 0; }
        }
    }

    // ── Power-ups ──────────────────────────────────────────
    hidden function _trySpawnPowerup() {
        // Only one live power-up at a time to keep them special.
        for (var i = 0; i < SC_MAX_POWERUPS; i++) {
            if (puLive[i] != 0) { return; }
        }
        var slot = -1;
        for (var i = 0; i < SC_MAX_POWERUPS; i++) {
            if (puLive[i] == 0) { slot = i; break; }
        }
        if (slot < 0) { return; }
        puLive[slot]  = 1;
        // Shields power-up more likely when the player is hurting.
        var wantShield = (shields < maxShields) && (_rand(100) < 55);
        puType[slot]  = wantShield ? SC_PU_SHIELD : SC_PU_RAPID;
        puYaw[slot]   = gazeYaw   + (_randf() - 0.5) * 0.9;
        var pp        = gazePitch + (_randf() - 0.5) * 0.6;
        if (pp >  1.8) { pp =  1.8; }
        if (pp < -0.9) { pp = -0.9; }
        puPitch[slot] = pp;
        puDist[slot]  = SC_SPAWN_D.toFloat() + _rand(120).toFloat();
        puSpd[slot]   = 0.9 + _randf() * 0.4;   // drift in slowly
    }
    hidden function _tickPowerups() {
        var TPI = Math.PI * 2.0;
        for (var i = 0; i < SC_MAX_POWERUPS; i++) {
            if (puLive[i] == 0) { puSx[i] = -9999; puSy[i] = -9999; continue; }
            puDist[i] = puDist[i] - puSpd[i];
            // Missed: drifted past the player without being grabbed.
            if (puDist[i] <= SC_RAM_D) { puLive[i] = 0; puSx[i] = -9999; continue; }
            var dy = puYaw[i]   - gazeYaw;
            var dp = puPitch[i] - gazePitch;
            if (dy >  Math.PI) { dy = dy - TPI; }
            if (dy < -Math.PI) { dy = dy + TPI; }
            puSx[i] = (cx + dy * SC_FOV).toNumber();
            puSy[i] = (cy + dp * SC_FOV).toNumber();
            var s = SC_BASE_SZ * SC_REF_DIST / puDist[i].toNumber();
            if (s < 5)  { s = 5;  }
            if (s > 40) { s = 40; }
            puSz[i] = s;
        }
    }
    // Crosshair over a power-up? Collect it (grants the effect). Returns
    // true if a power-up was grabbed so shoot() can stop there.
    hidden function _tryCollectPowerup() {
        var best  = -1;
        var bestD = 99999.0;
        for (var i = 0; i < SC_MAX_POWERUPS; i++) {
            if (puLive[i] == 0) { continue; }
            var dx = puSx[i] - cx;
            var dy = puSy[i] - cy;
            var d2 = dx * dx + dy * dy;
            var rad = puSz[i] + 6;   // generous — collectibles are a reward
            if (d2 < rad * rad && puDist[i] < bestD) { best = i; bestD = puDist[i]; }
        }
        if (best < 0) { return false; }
        laserTx = puSx[best]; laserTy = puSy[best]; laserAge = SC_LASER_T;
        _addExplosion(puSx[best], puSy[best]);
        _burstParticles(puSx[best], puSy[best], SC_ET_TIE);
        if (puType[best] == SC_PU_SHIELD) {
            if (shields < maxShields) { shields++; }
            else                       { score = score + 100; }
        } else {
            rapidT = SC_RAPID_T;
            ammo   = maxAmmo;          // top off the magazine too
        }
        scoreFlashT = 6;
        // Power-up grabbed — bright success chime + happy little buzz.
        _tone(5);
        _vibe(40, 70);
        puLive[best] = 0;
        puSx[best] = -9999; puSy[best] = -9999;
        return true;
    }

    // ── Stars (parallax by depth layer) ─────────────────────
    hidden function _seedStars() {
        var r = 1618033;
        for (var i = 0; i < SC_NSTARS; i++) {
            r = (r * 1103515245 + 12345) & 0x7FFFFFFF;
            sYaw[i] = ((r % 6000).toFloat() - 3000.0) * 0.0006;
            r = (r * 1103515245 + 12345) & 0x7FFFFFFF;
            sPitch[i] = ((r % 5000).toFloat() - 2500.0) * 0.0006;
            r = (r * 1103515245 + 12345) & 0x7FFFFFFF;
            sDepth[i] = 1 + (r % 3);   // 1 (far) .. 3 (near)
        }
    }
    hidden function _driftStars() {
        for (var i = 0; i < SC_NSTARS; i++) {
            // Nearer stars streak outward faster — parallax sense of speed.
            var expand = 1.010 + sDepth[i].toFloat() * 0.010;
            sYaw[i]   = sYaw[i]   * expand;
            sPitch[i] = sPitch[i] * expand;
            var d2 = sYaw[i] * sYaw[i] + sPitch[i] * sPitch[i];
            if (d2 > 4.0) {
                _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
                sYaw[i]   = ((_rng % 800).toFloat() - 400.0) * 0.0008;
                _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
                sPitch[i] = ((_rng % 600).toFloat() - 300.0) * 0.0008;
                _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF;
                sDepth[i] = 1 + (_rng % 3);
            }
        }
    }

    // ── PRNG ───────────────────────────────────────────────
    hidden function _lcg()      { _rng = (_rng * 1103515245 + 12345) & 0x7FFFFFFF; return _rng; }
    hidden function _rand(n)    { return (n <= 1) ? 0 : _lcg() % n; }
    hidden function _randf()    { return (_lcg() % 10000).toFloat() * 0.0001; }
}
