using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Attention;
using Toybox.Application;

// ── Module-level constants ─────────────────────────────────────────────────
// (visible to all source files in this project)
const GS_TITLE = 0;
const GS_RUN   = 1;
const GS_OVER  = 2;

const ET_BULLET  = 0;   // radial bullet: fixed angle, moves outward
const ET_ARCWALL = 1;   // arc wall expanding outward, gap the player must align with
const ET_LASER   = 2;   // line rotating around centre
const ET_RING    = 3;   // full ring expanding outward, gap in it

const MAX_ENEMIES     = 8;
const TRAIL_LEN       = 5;
const PART_COUNT      = 8;

// ── Title-screen menu (chess-style rows) ─────────────────────────────────────
// Two selectable rows: START and the shared global LEADERBOARD.
const ES_MENU_ROWS = 2;
const ES_ROW_START = 0;
const ES_ROW_LB    = 1;

// Global leaderboard game id (matches _LOGOS / web id).
const LB_GAME_ID = "edgesurvivor";

const PLAYER_MAX_VEL  = 5;    // deg/tick max angular speed
const DASH_DEGREES    = 34;   // degrees covered by a dash
const DASH_COOLDOWN   = 46;   // ticks (~1.5 s @ 30 fps)

const BULLET_HIT_ANG  = 12;   // angular kill threshold for bullets (degrees)
const LASER_HIT_ANG   = 9;    // angular kill threshold for lasers
const ARCWALL_TRIGGER = 15;   // radius proximity window for arc-wall / ring kill
const RING_TRIGGER    = 15;

// ── GameView ───────────────────────────────────────────────────────────────
class GameView extends WatchUi.View {

    // ── layout (computed once in onLayout) ───────────────────────────────
    hidden var _sw, _sh, _cx, _cy, _edgeR;

    // ── sin/cos lookup tables — indexed by integer degrees 0–359 ─────────
    // Values are fixed-point * 1000 (range –1000 … +1000).
    // Populated once in onLayout to eliminate Math.sin/cos in the game loop.
    hidden var _sinTab, _cosTab;

    // ── game objects ──────────────────────────────────────────────────────
    hidden var _player;
    hidden var _enemies;
    hidden var _spawner;

    // ── game state ────────────────────────────────────────────────────────
    hidden var _state;
    hidden var _score, _hiScore;
    hidden var _timer;

    // ── input flags (set by GameDelegate, read every tick) ───────────────
    var keyRight;
    var keyLeft;
    hidden var _tapRight;   // impulse countdown for swipe-based rotation
    hidden var _tapLeft;

    // ── cached player screen position (updated each tick) ────────────────
    hidden var _pX, _pY;

    // ── visual effects ────────────────────────────────────────────────────
    hidden var _flash;          // white-flash frames remaining after death
    hidden var _partX, _partY;  // death-particle positions (int arrays)
    hidden var _partVx, _partVy;
    hidden var _partT;          // particle lifetime countdown

    // ── phase notification ────────────────────────────────────────────────
    hidden var _phaseNotif;
    hidden var _lastPhase;

    // ── near-miss tracking ────────────────────────────────────────────────
    hidden var _nearMissTimer;  // brief display timer for near-miss text

    // ── title menu selection ──────────────────────────────────────────────
    hidden var _menuRow;        // ES_ROW_*

    function initialize() {
        View.initialize();
        _state      = GS_TITLE;
        _menuRow    = ES_ROW_START;
        _timer      = null;
        _flash      = 0;
        _phaseNotif = 0;
        _lastPhase  = 0;
        keyRight    = 0;
        keyLeft     = 0;
        _tapRight   = 0;
        _tapLeft    = 0;
        _score      = 0;
        _pX         = 0;
        _pY         = 0;
        _partT      = 0;
        _nearMissTimer = 0;
        // Load hi-score from persistent storage (survives app restart).
        _hiScore = _loadHi();
    }

    hidden function _loadHi() {
        try {
            var v = Application.Storage.getValue("hi");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }

    hidden function _saveHi() {
        try { Application.Storage.setValue("hi", _hiScore); } catch (e) { }
    }

    function onLayout(dc) {
        _sw    = dc.getWidth();
        _sh    = dc.getHeight();
        _cx    = _sw / 2;
        _cy    = _sh / 2;
        _edgeR = _sw * 44 / 100;

        // ── Build sin/cos LUT (once, so no Math.sin/cos in game loop) ────
        _sinTab = new [360];
        _cosTab = new [360];
        for (var i = 0; i < 360; i++) {
            var rad   = i.toFloat() * 3.14159265 / 180.0;
            _sinTab[i] = (Math.sin(rad) * 1000.0).toNumber();
            _cosTab[i] = (Math.cos(rad) * 1000.0).toNumber();
        }

        _player  = new Player();
        _enemies = new EnemyPool();
        _spawner = new SpawnManager();

        _partX  = new [PART_COUNT]; _partY  = new [PART_COUNT];
        _partVx = new [PART_COUNT]; _partVy = new [PART_COUNT];
        for (var i = 0; i < PART_COUNT; i++) {
            _partX[i] = _cx; _partY[i] = _cy;
            _partVx[i] = 0;  _partVy[i] = 0;
        }
        // Pre-seed player screen position so we don't render at (0,0) on
        // the title screen before _step() ever runs.
        _pX = _cx + _cosTab[270] * _edgeR / 1000;
        _pY = _cy + _sinTab[270] * _edgeR / 1000;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:gameTick), 33, true);
    }

    function onHide() {
        if (_timer != null) { _timer.stop(); }
    }

    // ── timer callback ────────────────────────────────────────────────────
    function gameTick() {
        if (_state == GS_RUN) { _step(); }
        if (_flash         > 0) { _flash = _flash - 1; }
        if (_phaseNotif    > 0) { _phaseNotif = _phaseNotif - 1; }
        if (_nearMissTimer > 0) { _nearMissTimer = _nearMissTimer - 1; }
        if (_partT         > 0) { _updateParticles(); _partT = _partT - 1; }
        WatchUi.requestUpdate();
    }

    // ── public controls ───────────────────────────────────────────────────
    function setKeyRight(v) { keyRight = v; }
    function setKeyLeft(v)  { keyLeft  = v; }

    // True when the game is at the title or game-over screen and a key
    // press should start a new run. Game-over screen needs a tiny delay
    // so a final key press from the previous run can't auto-restart.
    function canStart() {
        if (_state == GS_TITLE) { return true; }
        if (_state == GS_OVER && _flash == 0) { return true; }
        return false;
    }

    function doAction() {
        if (_state != GS_RUN) { _startGame(); return; }
        _player.doDash();
    }

    // Swipe gestures inject a short "held key" impulse
    function doPrevPage() {
        if (_state != GS_RUN) { _startGame(); return; }
        _tapRight = 16;
    }

    function doNextPage() {
        if (_state != GS_RUN) { _startGame(); return; }
        _tapLeft = 16;
    }

    function doBack() {
        if (_state == GS_RUN) { _killPlayer(); return true; }
        return false;
    }

    // ── title menu (START + LEADERBOARD) ──────────────────────────────────
    function inMenu() { return _state == GS_TITLE; }

    function menuUp() {
        _menuRow = (_menuRow + ES_MENU_ROWS - 1) % ES_MENU_ROWS;
        WatchUi.requestUpdate();
    }
    function menuDown() {
        _menuRow = (_menuRow + 1) % ES_MENU_ROWS;
        WatchUi.requestUpdate();
    }
    function menuSelect() {
        if (_menuRow == ES_ROW_LB) { openLeaderboard(); return; }
        _startGame();
    }
    // Tap routing: pick the row under (x,y) and activate it.
    function menuTap(x, y) {
        var rg   = _menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < ES_MENU_ROWS; i++) {
            var ry = rowY0 + i * (rowH + gap);
            if (x >= rowX && x < rowX + rowW &&
                y >= ry    && y < ry    + rowH) {
                _menuRow = i;
                menuSelect();
                return;
            }
        }
    }
    // Open the shared global leaderboard.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, "", "EDGE SURVIVOR");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Space-aware geometry for the two title rows. Rows live between a top
    // zone (under the title) and a reserved bottom margin (hint + best), so
    // nothing overlaps on small round watches. Sized ~18% smaller than the
    // reference menu (height / width / gaps all shrunk).
    //   [ rowH, rowW, rowX, rowY0, gap ]
    function _menuRowGeom() {
        var topZone      = (_sh * 48) / 100;
        var bottomMargin = (_sh * 16) / 100; if (bottomMargin < 26) { bottomMargin = 26; }
        var gap          = (_sh * 2) / 100;  if (gap < 3) { gap = 3; }
        var avail        = (_sh - bottomMargin) - topZone;
        var rowH         = (avail - gap * (ES_MENU_ROWS - 1)) / ES_MENU_ROWS;
        if (rowH > 21) { rowH = 21; }   // ~18% smaller than the 26 px reference
        if (rowH < 14) { rowH = 14; }
        var rowW = (_sw * 54) / 100; if (rowW < 98) { rowW = 98; }
        var rowX = (_sw - rowW) / 2;
        var used  = ES_MENU_ROWS * rowH + (ES_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    // ── game lifecycle ────────────────────────────────────────────────────
    hidden function _startGame() {
        _player.reset();
        _enemies.reset();
        _spawner.reset();
        _score      = 0;
        _flash      = 0;
        _phaseNotif = 0;
        _lastPhase  = 0;
        _partT      = 0;
        _nearMissTimer = 0;
        keyRight    = 0;
        keyLeft     = 0;
        _tapRight   = 0;
        _tapLeft    = 0;
        _pX         = _cx + _cosTab[270] * _edgeR / 1000;
        _pY         = _cy + _sinTab[270] * _edgeR / 1000;
        _state      = GS_RUN;
    }

    hidden function _killPlayer() {
        if (_score > _hiScore) {
            _hiScore = _score;
            _saveHi();
        }
        _flash = 14;
        _spawnDeathParticles();
        _state = GS_OVER;
        // Submit this run's score to the global leaderboard (fire-and-forget).
        Leaderboard.submitScore(LB_GAME_ID, _score, "");
        Leaderboard.showPostGame(LB_GAME_ID, "", "EDGE SURVIVOR");
        // haptic feedback
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 180)]);
        }
    }

    // ── main step ─────────────────────────────────────────────────────────
    hidden function _step() {
        // ── input (held keys + swipe impulses) ──────────────────────────
        var kr = keyRight;
        var kl = keyLeft;
        if (_tapRight > 0) { kr = 1; _tapRight = _tapRight - 1; }
        if (_tapLeft  > 0) { kl = 1; _tapLeft  = _tapLeft  - 1; }

        _player.update(kr, kl);

        // ── cache player screen coords (LUT lookup, no trig call) ────────
        var pa = _player.angle;
        _pX = _cx + _cosTab[pa] * _edgeR / 1000;
        _pY = _cy + _sinTab[pa] * _edgeR / 1000;

        // ── enemy update + spawn ─────────────────────────────────────────
        _enemies.update(_edgeR);
        _spawner.update(_score, _enemies, _edgeR, pa);

        // ── phase-change notification ────────────────────────────────────
        var phase = _spawner.getPhase();
        if (phase > _lastPhase) {
            _lastPhase  = phase;
            _phaseNotif = 70;
        }

        // ── near-miss detection (bullet passing close but not hitting) ───
        _checkNearMiss(pa);

        // ── collision (dash grants brief i-frames so the player can
        // dash THROUGH bullets — much fairer feel) ───────────────────────
        if (_player.isDashing == 0) {
            if (_enemies.checkCollision(pa, _edgeR)) {
                _killPlayer();
                return;
            }
        }

        _score = _score + 1;
    }

    // Near-miss: bullet radius just crossed edgeR, angle close but not deadly
    hidden function _checkNearMiss(pa) {
        if (_nearMissTimer > 0) { return; }
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (_enemies.isAlive(i) == 0)    { continue; }
            if (_enemies.getType(i) != ET_BULLET) { continue; }
            var ri = _enemies.getRadius(i);
            var dr = ri - _edgeR;
            if (dr < -2 || dr > 6) { continue; }
            var adiff = _enemies.getAngle(i) - pa;
            if (adiff < 0) { adiff = -adiff; }
            if (adiff > 180) { adiff = 360 - adiff; }
            // close miss: within ~24 deg but outside kill zone
            if (adiff >= BULLET_HIT_ANG && adiff < 24) {
                _nearMissTimer = 40;
                _score = _score + 15;   // bonus points
                return;
            }
        }
    }

    // ── death particles ───────────────────────────────────────────────────
    hidden function _spawnDeathParticles() {
        var step = 360 / PART_COUNT;
        for (var i = 0; i < PART_COUNT; i++) {
            var a      = i * step;
            _partX[i]  = _pX;
            _partY[i]  = _pY;
            _partVx[i] = _cosTab[a] * 6 / 1000;
            _partVy[i] = _sinTab[a] * 6 / 1000;
        }
        _partT = 28;
    }

    hidden function _updateParticles() {
        for (var i = 0; i < PART_COUNT; i++) {
            _partX[i] = _partX[i] + _partVx[i];
            _partY[i] = _partY[i] + _partVy[i];
        }
    }

    // ── rendering ─────────────────────────────────────────────────────────
    function onUpdate(dc) {
        // death flash (alternate frames)
        if (_flash > 0 && _flash % 2 == 0) {
            dc.setColor(0xFFFFFF, 0xFFFFFF);
            dc.clear();
            return;
        }

        dc.setColor(0x000000, 0x000000);
        dc.clear();

        _drawDepthRings(dc);
        _drawEdge(dc);

        // Skip live-action sprites on the title screen so it isn't cluttered
        // by stale enemies/trails from the previous run (or by the player
        // dot stuck at its starting position).
        if (_state != GS_TITLE) {
            _drawEnemies(dc);
            _drawPlayerTrail(dc);
            _drawPlayer(dc);
            _drawParticles(dc);
        }

        if (_state == GS_TITLE) {
            _drawTitle(dc);
        } else if (_state == GS_OVER) {
            _drawOver(dc);
        } else {
            _drawHUD(dc);
        }

        if (_state == GS_RUN) {
            if (_phaseNotif > 0)    { _drawPhaseNotif(dc); }
            if (_nearMissTimer > 0) { _drawNearMiss(dc); }
        }
    }

    // Faint concentric circles — depth / scale reference
    hidden function _drawDepthRings(dc) {
        dc.setColor(0x0b0b0b, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, _edgeR * 25 / 100);
        dc.drawCircle(_cx, _cy, _edgeR * 50 / 100);
        dc.drawCircle(_cx, _cy, _edgeR * 75 / 100);
        // tiny centre dot
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx, _cy, 3);
    }

    // The player's constrained path — the edge circle
    hidden function _drawEdge(dc) {
        dc.setColor(0x1a2a5a, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(_cx, _cy, _edgeR);
        dc.drawCircle(_cx, _cy, _edgeR - 1);
    }

    // ── enemy renderers ───────────────────────────────────────────────────
    hidden function _drawEnemies(dc) {
        for (var i = 0; i < MAX_ENEMIES; i++) {
            if (_enemies.isAlive(i) == 0) { continue; }
            var t  = _enemies.getType(i);
            var a  = _enemies.getAngle(i);
            var ri = _enemies.getRadius(i);
            var ex = _enemies.getExtra(i);
            if      (t == ET_BULLET)  { _drawBullet(dc, a, ri);        }
            else if (t == ET_ARCWALL) { _drawArcWall(dc, a, ri, ex);   }
            else if (t == ET_LASER)   { _drawLaser(dc, a);             }
            else if (t == ET_RING)    { _drawRing(dc, a, ri, ex);      }
        }
    }

    // Red/orange dot moving outward — brightens as it nears the edge
    hidden function _drawBullet(dc, angle, radius) {
        var bx  = _cx + _cosTab[angle] * radius / 1000;
        var by  = _cy + _sinTab[angle] * radius / 1000;
        var prx = radius * 100 / _edgeR;
        var col = (prx < 65) ? 0xFF5500 : 0xFF1111;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 5);
        dc.setColor(0xFF9944, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, 2);
    }

    // Red arc ring with a safe gap; gap marker drawn at edge when wall is close
    hidden function _drawArcWall(dc, angle, radius, gapHalf) {
        var pr = radius * 100 / _edgeR;
        var col = (pr < 65) ? 0xAA1111 : 0xFF2222;
        var a = 0;
        while (a < 360) {
            var adiff = a - angle;
            if (adiff < 0) { adiff = -adiff; }
            if (adiff > 180) { adiff = 360 - adiff; }
            if (adiff >= gapHalf) {
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                var ax = _cx + _cosTab[a] * radius / 1000;
                var ay = _cy + _sinTab[a] * radius / 1000;
                dc.fillCircle(ax, ay, 3);
            } else if (radius > _edgeR - 44) {
                // show safe-gap marker at the edge so the player knows where to stand
                dc.setColor(0x004422, Graphics.COLOR_TRANSPARENT);
                var gx = _cx + _cosTab[a] * _edgeR / 1000;
                var gy = _cy + _sinTab[a] * _edgeR / 1000;
                dc.fillCircle(gx, gy, 4);
            }
            a = a + 5;
        }
    }

    // Yellow triple-line laser rotating around the centre
    hidden function _drawLaser(dc, angle) {
        var a1 = (angle - 1 + 360) % 360;
        var a2 = (angle + 1) % 360;
        dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(_cx, _cy,
            _cx + _cosTab[angle] * _edgeR / 1000,
            _cy + _sinTab[angle] * _edgeR / 1000);
        dc.drawLine(_cx, _cy,
            _cx + _cosTab[a1] * _edgeR / 1000,
            _cy + _sinTab[a1] * _edgeR / 1000);
        dc.drawLine(_cx, _cy,
            _cx + _cosTab[a2] * _edgeR / 1000,
            _cy + _sinTab[a2] * _edgeR / 1000);
        // bright tip at edge end
        dc.setColor(0xFFFF88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_cx + _cosTab[angle] * _edgeR / 1000,
                      _cy + _sinTab[angle] * _edgeR / 1000, 3);
    }

    // Blue expanding ring; safe gap shown in dark green
    hidden function _drawRing(dc, angle, radius, gapHalf) {
        var a = 0;
        while (a < 360) {
            var adiff = a - angle;
            if (adiff < 0) { adiff = -adiff; }
            if (adiff > 180) { adiff = 360 - adiff; }
            var ax = _cx + _cosTab[a] * radius / 1000;
            var ay = _cy + _sinTab[a] * radius / 1000;
            if (adiff >= gapHalf) {
                dc.setColor(0x1166FF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ax, ay, 3);
            } else {
                dc.setColor(0x003318, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ax, ay, 3);
            }
            a = a + 5;
        }
    }

    // ── player ────────────────────────────────────────────────────────────
    hidden function _drawPlayerTrail(dc) {
        dc.setColor(0x1a3380, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < TRAIL_LEN; i++) {
            var ta = _player.trailAngle[i];
            var tx = _cx + _cosTab[ta] * _edgeR / 1000;
            var ty = _cy + _sinTab[ta] * _edgeR / 1000;
            var r  = 5 - i;
            if (r < 1) { r = 1; }
            dc.fillCircle(tx, ty, r);
        }
    }

    hidden function _drawPlayer(dc) {
        // dash flash halo
        if (_player.isDashing > 0) {
            dc.setColor(0x6688FF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(_pX, _pY, 11);
        }
        // main dot
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_pX, _pY, 6);
        // inner core
        dc.setColor(0x7799FF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(_pX, _pY, 3);

        // dash-ready indicator: tiny cyan dot slightly inside the edge
        if (_player.dashCd == 0) {
            var ia = _player.angle;
            var ix = _cx + _cosTab[ia] * (_edgeR - 11) / 1000;
            var iy = _cy + _sinTab[ia] * (_edgeR - 11) / 1000;
            dc.setColor(0x00CCFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(ix, iy, 3);
        }
    }

    // ── particles ─────────────────────────────────────────────────────────
    hidden function _drawParticles(dc) {
        if (_partT <= 0) { return; }
        var r = 2 + _partT / 7;
        if (r > 5) { r = 5; }
        dc.setColor(0xFF4422, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < PART_COUNT; i++) {
            dc.fillCircle(_partX[i], _partY[i], r);
        }
        // inner bright core
        dc.setColor(0xFF9966, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < PART_COUNT; i++) {
            dc.fillCircle(_partX[i], _partY[i], 1);
        }
    }

    // ── HUD (score + dash indicator) ──────────────────────────────────────
    hidden function _drawHUD(dc) {
        dc.setColor(0x777799, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _sh * 7 / 100, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        if (_hiScore > 0) {
            dc.setColor(0x3a3a55, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _sh * 14 / 100, Graphics.FONT_XTINY,
                "HI " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
        // dash availability
        if (_player.dashCd == 0) {
            dc.setColor(0x0077CC, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(0x1a1a33, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(_cx, _sh * 85 / 100, Graphics.FONT_XTINY,
            "DASH", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── title screen ──────────────────────────────────────────────────────
    hidden function _drawTitle(dc) {
        dc.setColor(0x2255CC, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _sh * 13 / 100, Graphics.FONT_MEDIUM,
            "EDGE", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _sh * 26 / 100, Graphics.FONT_MEDIUM,
            "SURVIVOR", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(0x2a2a44, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _sh * 41 / 100, Graphics.FONT_XTINY,
            "stay on the edge", Graphics.TEXT_JUSTIFY_CENTER);

        // Two chess-style rows: START + LEADERBOARD (space-aware geometry).
        var rg   = _menuRowGeom();
        var rowH = rg[0]; var rowW = rg[1];
        var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
        for (var i = 0; i < ES_MENU_ROWS; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == _menuRow);

            if (i == ES_ROW_LB) {
                // Hype-y gold leaderboard row from the shared library.
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            // START row.
            var bg; var bd; var fg;
            if (sel) { bg = 0x1A4400; bd = 0x44BB22; fg = 0xAAFF66; }
            else     { bg = 0x102010; bd = 0x224422; fg = 0x88AA88; }
            dc.setColor(bg, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(bd, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);
            if (sel) {
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                "START", Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x1a1a33, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _sh * 88 / 100, Graphics.FONT_XTINY,
            "UP/DN  SEL", Graphics.TEXT_JUSTIFY_CENTER);
        if (_hiScore > 0) {
            dc.setColor(0x2a2a44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, _sh * 94 / 100, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── game-over screen ──────────────────────────────────────────────────
    hidden function _drawOver(dc) {
        var bw = _sw * 42 / 100;
        var bh = _sh * 24 / 100;
        if (bw < 112) { bw = 112; }
        if (bh < 78)  { bh = 78; }
        var bx = _cx - bw / 2;
        var by = _sh * 33 / 100;

        dc.setColor(0x07070f, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 9);
        dc.setColor(0x1a1a3a, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 9);

        dc.setColor(0xCC2222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + 5, Graphics.FONT_XTINY, "GAME OVER", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x888899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + 21, Graphics.FONT_XTINY,
            _score.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);

        if (_score >= _hiScore && _hiScore > 0) {
            dc.setColor(0xFFCC00, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, by + 37, Graphics.FONT_XTINY, "NEW BEST!", Graphics.TEXT_JUSTIFY_CENTER);
        } else if (_hiScore > 0) {
            dc.setColor(0x2a2a44, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_cx, by + 37, Graphics.FONT_XTINY,
                "best " + _hiScore.format("%05d"), Graphics.TEXT_JUSTIFY_CENTER);
        }

        dc.setColor(0x1a1a33, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, by + bh - 13, Graphics.FONT_XTINY,
            "any key to retry", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── overlays ──────────────────────────────────────────────────────────
    hidden function _drawPhaseNotif(dc) {
        var col = (_phaseNotif > 40) ? 0xFF8800 : 0x664400;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _sh * 45 / 100, Graphics.FONT_SMALL,
            "PHASE " + _lastPhase.format("%d") + "!", Graphics.TEXT_JUSTIFY_CENTER);
    }

    hidden function _drawNearMiss(dc) {
        dc.setColor(0x00BBFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(_cx, _sh * 54 / 100, Graphics.FONT_XTINY,
            "NEAR MISS! +15", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
