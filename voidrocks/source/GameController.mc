// ═══════════════════════════════════════════════════════════════
// GameController.mc — VoidRocks game flow.
//
// States: VR_MENU → VR_PLAY → VR_OVER → VR_MENU
// (no VR_WIN — Asteroids is endless; "win" is a high score)
//
// Menu (chess-style, 3 rows):
//   0  Difficulty (Easy / Normal / Hard)
//   1  Lives (1..5)
//   2  START
//
// Difficulty influences:
//   • starting asteroid speed (Easy 0.9× / Normal 1.2× / Hard 1.6×)
//   • per-wave speed bonus
//
// Tick (80 ms, driven by MainView):
//   1. Ship integrates (friction + Euler).
//   2. Bullets integrate; bullet↔asteroid hits resolved, splits.
//   3. Asteroids integrate.
//   4. Compact dead asteroids.
//   5. Ship vs asteroid: any overlap → lose life (if not invul).
//   6. If no asteroids remain → next wave.
//
// Persistence keys:
//   vr_best   high score
//   vr_diff   difficulty
//   vr_lives  starting lives
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.Math;

const VR_MENU = 0;
const VR_PLAY = 1;
const VR_OVER = 2;

// Chess-style menu rows. Row 3 is the global LEADERBOARD (split by
// difficulty variant); it pushes a view from the View layer.
const VR_MENU_ROWS = 4;
const VR_ROW_DIFF  = 0;
const VR_ROW_LIVES = 1;
const VR_ROW_START = 2;
const VR_ROW_LB    = 3;

// Global leaderboard game id (matches _LOGOS / web id).
const VR_LB_GAME_ID = "voidrocks";

const VR_BEST_KEY  = "vr_best";
const VR_DIFF_KEY  = "vr_diff";
const VR_LIVES_KEY = "vr_lives";

const VR_DIFF_EASY   = 0;
const VR_DIFF_NORMAL = 1;
const VR_DIFF_HARD   = 2;

// Tilt-steering knobs.  Accel values are in milli-G; 1000 ≈ 1 g.
// VR_TILT_DEADZONE  — projection magnitude below which we ignore the
//                     tilt (avoids jitter when the watch is held flat).
// VR_TILT_SMOOTH    — fraction of the angle gap closed each tick
//                     (higher = snappier, but more jittery).
//
// IMPORTANT: tilt ONLY rotates the ship.  Thrust is exclusively
// driven by the left-bottom (DOWN) button.  Auto-thrust on hard
// tilt was removed because a casual tap on the screen made the
// wrist dip enough to trigger it, so the ship moved on every fire.
const VR_TILT_DEADZONE   = 180;
const VR_TILT_SMOOTH     = 0.30;
const VR_PI              = 3.14159;

class GameController {
    var state;
    var menuRow;
    var menuDiff;
    var menuLives;

    var ship;
    var bullets;
    var rocks;

    var wave;
    var lives;
    var score;
    var bestScore;

    // Cached screen dims (refreshed each draw before tick).
    var sw;
    var sh;
    var baseR;          // base rock radius (scaled by min dim)

    function initialize() {
        state     = VR_MENU;
        menuRow   = 0;
        menuDiff  = VR_DIFF_NORMAL;
        menuLives = 3;

        ship    = new Ship();
        bullets = new ProjectileSystem();
        rocks   = new AsteroidManager();

        wave = 1; lives = 3; score = 0; bestScore = 0;
        sw = 0; sh = 0; baseR = 0;
        _loadAll();
    }

    // ── Persistence ─────────────────────────────────────────────
    hidden function _loadAll() {
        try {
            var b = Application.Storage.getValue(VR_BEST_KEY);
            if (b != null) { bestScore = b; }
        } catch (e) {}
        try {
            var d = Application.Storage.getValue(VR_DIFF_KEY);
            if (d instanceof Number && d >= 0 && d <= 2) { menuDiff = d; }
        } catch (e) {}
        try {
            var l = Application.Storage.getValue(VR_LIVES_KEY);
            if (l instanceof Number && l >= 1 && l <= 5) { menuLives = l; }
        } catch (e) {}
    }
    hidden function _saveBest() {
        try { Application.Storage.setValue(VR_BEST_KEY, bestScore); } catch (e) {}
    }
    hidden function _saveSettings() {
        try { Application.Storage.setValue(VR_DIFF_KEY,  menuDiff);  } catch (e) {}
        try { Application.Storage.setValue(VR_LIVES_KEY, menuLives); } catch (e) {}
    }

    // ── Menu ───────────────────────────────────────────────────
    function menuNext() { menuRow = (menuRow + 1) % VR_MENU_ROWS; }
    function menuPrev() { menuRow = (menuRow + VR_MENU_ROWS - 1) % VR_MENU_ROWS; }
    function setMenuRow(i) { if (i >= 0 && i < VR_MENU_ROWS) { menuRow = i; } }
    function menuActivate() {
        if (menuRow == VR_ROW_DIFF) {
            menuDiff = (menuDiff + 1) % 3;
            _saveSettings();
        } else if (menuRow == VR_ROW_LIVES) {
            menuLives = (menuLives % 5) + 1;
            _saveSettings();
        } else if (menuRow == VR_ROW_START) {
            _startGame();
        }
        // VR_ROW_LB is handled by MainView.openLeaderboard().
    }

    function gotoMenu() { state = VR_MENU; }

    function difficultyName() {
        if (menuDiff == VR_DIFF_EASY)   { return "Easy";   }
        if (menuDiff == VR_DIFF_NORMAL) { return "Normal"; }
        return "Hard";
    }

    hidden function _diffSpeedMul() {
        if (menuDiff == VR_DIFF_EASY)   { return 0.85; }
        if (menuDiff == VR_DIFF_NORMAL) { return 1.10; }
        return 1.45;
    }

    // Speed for the current wave + diff combination.
    hidden function _waveSpeed() {
        var base = 1.0 + 0.12 * (wave - 1);    // +12 %/wave
        if (base > 2.2) { base = 2.2; }
        return base * _diffSpeedMul();
    }

    // ── Lifecycle ───────────────────────────────────────────────
    hidden function _startGame() {
        wave  = 1;
        lives = menuLives;
        score = 0;
        _ensureDims();
        ship.respawn(sw, sh, _shipRadius());
        bullets.reset();
        rocks.spawnWave(wave, sw, sh, baseR, _waveSpeed(),
                         ship.x, ship.y);
        state = VR_PLAY;
    }

    // MainView is the source of truth for screen size; it pushes
    // the values here before every tick / draw.
    function syncDims(sw_, sh_) {
        if (sw_ == sw && sh_ == sh) { return; }
        sw = sw_; sh = sh_;
        var m = (sw < sh) ? sw : sh;
        baseR = (m * 10) / 100;          // large rock ~ 10 % of min dim
        if (baseR < 9) { baseR = 9; }
    }

    hidden function _ensureDims() {
        if (sw == 0 || sh == 0) { return; }      // first frame; MainView will sync
    }

    hidden function _shipRadius() {
        var m = (sw < sh) ? sw : sh;
        var r = (m * 4) / 100;
        if (r < 5) { r = 5; }
        return r;
    }

    // ── Input intents (forwarded by MainView/InputHandler) ──────
    function rotL()   { if (state == VR_PLAY && ship.alive) { ship.rotateLeft();  } }
    function rotR()   { if (state == VR_PLAY && ship.alive) { ship.rotateRight(); } }
    function thrust() { if (state == VR_PLAY && ship.alive) { ship.applyThrust(); } }
    function fire()   { if (state == VR_PLAY && ship.alive) { bullets.fire(ship); } }

    // Wrist-tilt steering.  `ax, ay` are the accelerometer X and Y
    // components in milli-G.  We project gravity onto the watch face
    // and treat the resulting 2D vector as the ship's desired pointing
    // direction.  A small projection (watch held mostly flat) is
    // ignored.  Tilt ROTATES ONLY — thrust is on the DOWN button.
    //
    // Heading convention:  angle 0 = ship points UP, increases CW.
    //   atan2(ax, -ay) gives 0 when ay < 0 (top of watch dipped toward
    //   the user), π/2 when ax > 0 (right side dipped), etc.
    function handleTilt(ax, ay) {
        if (state != VR_PLAY) { return; }
        if (!ship.alive)      { return; }
        var mag2 = ax * ax + ay * ay;
        if (mag2 < VR_TILT_DEADZONE * VR_TILT_DEADZONE) { return; }

        var target = Math.atan2(ax, -ay);
        if (target < 0) { target = target + VR_TWO_PI; }

        // Shortest-arc lerp toward target.
        var diff = target - ship.angle;
        while (diff >  VR_PI) { diff = diff - VR_TWO_PI; }
        while (diff < -VR_PI) { diff = diff + VR_TWO_PI; }
        ship.angle = ship.angle + diff * VR_TILT_SMOOTH;
        if (ship.angle <  0)             { ship.angle = ship.angle + VR_TWO_PI; }
        if (ship.angle >= VR_TWO_PI)     { ship.angle = ship.angle - VR_TWO_PI; }
    }

    // ── Tick ────────────────────────────────────────────────────
    function tick() {
        if (state != VR_PLAY) { return; }
        if (sw == 0 || sh == 0) { return; }   // dims not yet known

        // 1. Ship motion.
        ship.integrate(sw, sh);

        // 2. Bullets + asteroid hits.
        bullets.tick(sw, sh);
        var hits = bullets.collideAsteroids(rocks.rocks, sw, sh);
        for (var i = 0; i < hits.size(); i++) {
            score = score + rocks.hit(hits[i], baseR);
        }
        rocks.compact();

        // 3. Asteroids motion.
        rocks.tick(sw, sh);

        // 4. Ship vs asteroid (when not invulnerable).
        if (ship.invul == 0) {
            for (var k = 0; k < rocks.rocks.size(); k++) {
                var a = rocks.rocks[k];
                if (!a.alive) { continue; }
                if (PhysicsEngine.circlesHit(ship.x, ship.y, ship.radius - 1,
                                              a.x,    a.y,    a.radius - 1,
                                              sw, sh)) {
                    _onPlayerHit();
                    return;
                }
            }
        }

        // 5. Wave clear?
        if (rocks.allDead()) {
            score = score + 100 + wave * 50;
            wave  = wave + 1;
            rocks.spawnWave(wave, sw, sh, baseR, _waveSpeed(),
                             ship.x, ship.y);
            // Reward: ship gets a fresh invul window each new wave.
            ship.invul = 30;
        }
    }

    hidden function _onPlayerHit() {
        lives = lives - 1;
        if (lives <= 0) {
            state = VR_OVER;
            if (score > bestScore) { bestScore = score; _saveBest(); }
            // Submit to the global leaderboard, split by difficulty variant.
            Leaderboard.submitScore(VR_LB_GAME_ID, score, difficultyName());
            Leaderboard.showPostGame(VR_LB_GAME_ID, difficultyName(), "VOID ROCKS");
            return;
        }
        // Respawn at center with grace period.
        ship.respawn(sw, sh, _shipRadius());
        bullets.reset();
    }
}
