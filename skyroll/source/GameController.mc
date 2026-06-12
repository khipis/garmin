// ═══════════════════════════════════════════════════════════════
// GameController.mc — State machine + subsystem orchestrator.
//
// State flow:
//   SR_MENU  ──[START]──▶ SR_PLAY
//   SR_PLAY  ──[fell ]──▶ SR_FALL ──[anim done]──▶ SR_OVER
//   SR_OVER  ──[tap  ]──▶ SR_PLAY (restart, same settings)
//   SR_OVER  ──[back ]──▶ SR_MENU
//
// All subsystems are owned here and exposed as public fields so
// UIManager / RenderSystem can pull what they need without
// passing a dozen parameters per call.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;
using Toybox.Math;
using Toybox.WatchUi;

class GameController {

    // Subsystems.
    var gyro;
    var physics;
    var path;
    var cam;

    // Screen geometry (filled in by MainView.onLayout).
    var sw;     var sh;
    var cx;     var cy;

    // Game state.
    var state;
    var menuRow;
    var sensMode;
    var diffMode;
    var bestScore;
    var distance;
    var boostFlash;
    var fallT;
    var startY;
    // Grace period counter — how many consecutive ticks the ball
    // has been "off" the path.  We only enter SR_FALL after 2+
    // consecutive misses so a single numerical edge-of-tile artefact
    // (common at turn-segment transitions) doesn't kill the player.
    hidden var _missStreak;

    function initialize() {
        gyro      = new GyroInput();
        physics   = new PhysicsSystem();
        path      = new PathGenerator();
        cam       = new CameraSystem();
        sw        = 260; sh = 260;
        cx        = 130; cy = 130;
        state     = SR_MENU;
        menuRow   = SR_ROW_START;
        sensMode  = SR_SENS_NORMAL;
        diffMode  = SR_DIFF_NORMAL;
        bestScore = 0;
        distance  = 0;
        boostFlash= 0;
        fallT     = 0;
        startY    = 0;
        _loadPersist();
        gyro.setSensitivity(sensMode);
    }

    function setScreen(w, h) {
        sw = w; sh = h; cx = w / 2; cy = h / 2;
    }

    // ── Persistence ──────────────────────────────────────────
    hidden function _loadPersist() {
        var s = Application.Storage.getValue(SR_K_SENS);
        if (s instanceof Number && s >= 0 && s <= 2) { sensMode = s; }
        var d = Application.Storage.getValue(SR_K_DIFF);
        if (d instanceof Number && d >= 0 && d <= 2) { diffMode = d; }
        var b = Application.Storage.getValue(SR_K_BEST);
        if (b instanceof Number && b >= 0) { bestScore = b; }
    }
    hidden function _savePersist() {
        Application.Storage.setValue(SR_K_SENS, sensMode);
        Application.Storage.setValue(SR_K_DIFF, diffMode);
        Application.Storage.setValue(SR_K_BEST, bestScore);
    }

    // ── Menu helpers ────────────────────────────────────────
    function sensName() {
        if      (sensMode == SR_SENS_LOW)  { return "Low"; }
        else if (sensMode == SR_SENS_HIGH) { return "High"; }
        return "Norm";
    }
    function diffName() {
        if      (diffMode == SR_DIFF_EASY) { return "Easy"; }
        else if (diffMode == SR_DIFF_HARD) { return "Hard"; }
        return "Norm";
    }

    function menuUp() {
        menuRow = menuRow - 1;
        if (menuRow < 0) { menuRow = SR_MENU_ROWS - 1; }
    }
    function menuDown() {
        menuRow = menuRow + 1;
        if (menuRow >= SR_MENU_ROWS) { menuRow = 0; }
    }
    function menuSelect() {
        if      (menuRow == SR_ROW_SENS) {
            sensMode = (sensMode + 1) % 3;
            gyro.setSensitivity(sensMode);
            _savePersist();
        } else if (menuRow == SR_ROW_DIFF) {
            diffMode = (diffMode + 1) % 3;
            _savePersist();
        } else if (menuRow == SR_ROW_START) {
            startRun();
        } else if (menuRow == SR_ROW_LB) {
            openLeaderboard();
        }
    }

    // Open the shared global leaderboard for the current difficulty.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, diffName(), "SKY ROLL");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Tap dispatch — coords are pre-translated screen pixels.
    function menuTap(x, y) {
        var rg = UIManager.rowGeom(sw, sh);
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < SR_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x <= rowX + rowW
                && y >= ry && y <= ry + rowH) {
                menuRow = i; menuSelect(); return;
            }
        }
    }

    // ── Run lifecycle ───────────────────────────────────────
    function startRun() {
        var seed = System.getTimer();
        path.reset(seed, diffMode);
        // Burn in some starter rows so the ball starts on solid ground.
        path.ensureAhead(0, 14);
        physics.reset(0, 2);
        startY    = physics.py;
        cam.reset(); cam.snapTo(physics.px, physics.py);
        gyro.recalibrate();
        boostFlash= 0;
        fallT     = 0;
        distance  = 0;
        _missStreak = 0;
        state     = SR_PLAY;
    }

    function backToMenu() {
        state = SR_MENU;
        menuRow = SR_ROW_START;
    }

    // ── Per-tick update ─────────────────────────────────────
    // ax, ay : milli-g from MainView's sensor read.
    function tick(ax, ay) {
        if (state == SR_MENU) { return; }

        // Update tilt every tick so play and fall both respond.
        gyro.feed(ax, ay);

        if (state == SR_PLAY) {
            physics.tick(gyro.tiltX, gyro.tiltY, path.speedMul());
            // Driver of difficulty ramp — total tiles travelled
            // in y (forward only).  Negative dy never decreases it.
            var dy = physics.py - startY;
            if (dy < 0) { dy = 0; }
            path.distScore = dy;
            distance = dy.toNumber();

            // Generate more path ahead.
            path.ensureAhead(physics.py, 20);
            path.tick(physics.py);

            // Collision sample.
            var r = CollisionSystem.sample(physics.px, physics.py,
                                            path, physics);
            var fell = r[0]; var boosted = r[2];
            if (boosted)             { boostFlash = 12; }
            if (boostFlash > 0)      { boostFlash = boostFlash - 1; }

            // Grace period: require 2 consecutive missed-tile ticks
            // before triggering SR_FALL.  A single artefact tick at
            // a turn-segment boundary is absorbed silently.
            if (fell) {
                _missStreak = _missStreak + 1;
            } else {
                _missStreak = 0;
            }
            if (_missStreak >= 2) {
                state = SR_FALL;
                fallT = 0;
                _missStreak = 0;
                if (distance > bestScore) {
                    bestScore = distance;
                    _savePersist();
                }
                // Run ended — submit distance to the global leaderboard
                // once, split by difficulty variant. Higher is better.
                Leaderboard.submitScore(LB_GAME_ID, distance, diffName());
                Leaderboard.showPostGame(LB_GAME_ID, diffName(), "SKY ROLL");
            }
        } else if (state == SR_FALL) {
            fallT = fallT + 1;
            // No physics; the renderer drops the ball visually.
            if (fallT >= SR_FALL_TICKS) { state = SR_OVER; }
        }

        // Camera follows on all live states.
        cam.tick(physics.px, physics.py);
    }

    // Input dispatch from MainView.
    function handleTap(x, y) {
        if (state == SR_MENU) { menuTap(x, y); }
        else if (state == SR_OVER) { startRun(); }
        else if (state == SR_PLAY) { /* steering is gyro-only */ }
    }
    function handleNav(dir) {
        // dir : -1 = up, +1 = down, 0 = select
        if (state == SR_MENU) {
            if      (dir == -1) { menuUp();   }
            else if (dir ==  1) { menuDown(); }
            else                { menuSelect(); }
            return true;
        }
        if (state == SR_OVER) {
            startRun(); return true;
        }
        if (state == SR_PLAY) {
            // UP physical key = recalibrate; everything else ignored.
            if (dir == -1) { gyro.recalibrate(); }
            return true;
        }
        return false;
    }
    function handleBack() {
        if (state == SR_MENU)      { return false; }  // exit app
        if (state == SR_PLAY)      {
            // First back: bail out to menu (and bank score).
            if (distance > bestScore) { bestScore = distance; _savePersist(); }
            backToMenu(); return true;
        }
        backToMenu();
        return true;
    }
}
