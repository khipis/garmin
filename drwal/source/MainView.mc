// ═══════════════════════════════════════════════════════════════
// MainView.mc — WatchUi.View: layout, tick driver, input entry
// points. Actual pixel drawing lives in RenderSystem (game world)
// and UIManager (HUD / menu / game-over chrome) so this file stays
// a thin coordinator, matching the requested architecture split.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Math;
using Toybox.Application;

class MainView extends WatchUi.View {
    hidden var _ctrl;
    hidden var _timer;

    hidden var _sw;
    hidden var _sh;
    hidden var _laidOut;

    // One-shot daily-login toast pulled from Storage (queued by DrwalApp on the
    // day's first launch). Applied to the controller once the run auto-starts so
    // it shows over the first frame rather than as a blocking view.
    hidden var _dailyPending;
    hidden var _dailyChecked;

    // Cached layout — recomputed once per screen size.
    hidden var _cx;
    hidden var _trunkW;
    hidden var _chopLineY;
    hidden var _groundY;
    hidden var _segH;
    hidden var _hudTop;
    hidden var _energyBarY;

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _sw = 0; _sh = 0;
        _laidOut = false;
        _dailyPending = null;
        _dailyChecked = false;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), TICK_MS, true);
        // Pull the queued daily-login toast exactly once (guarded Storage).
        if (!_dailyChecked) {
            _dailyChecked = true;
            try {
                var dm = Application.Storage.getValue("dr_daily_msg");
                if (dm != null) {
                    _dailyPending = dm;
                    Application.Storage.deleteValue("dr_daily_msg");
                }
            } catch (e) {}
        }
    }
    function onHide() {
        if (_timer != null) { _timer.stop(); }
        try { Leaderboard.cancelPostGame(); } catch (e) {}
    }

    function onTick() {
        _ctrl.step();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        if (!_laidOut) { _doLayout(); _laidOut = true; }

        // Menu lives in the shared root view — drop straight into play and
        // never render an in-game menu here.
        if (_ctrl.state == GS_MENU) { _ctrl.startGame(); }

        // Surface today's login-streak bonus once, AFTER the auto-start (which
        // resets per-run state) so it rides over the first game frame.
        if (_dailyPending != null) {
            _ctrl.queueDaily(_dailyPending);
            _dailyPending = null;
        }

        dc.setColor(0x000000, 0x000000);
        dc.clear();

        // Spawn particle bursts for one-shot events (layout coords live here).
        _consumeEvents();
        _emitWeather();

        var shx = 0;
        if (_ctrl.player.shakeT > 0)  { shx = (Math.rand() % 7) - 3; }
        else if (_ctrl.chopShakeT > 0) { shx = (Math.rand() % 3) - 1; }

        RenderSystem.drawBackground(dc, _sw, _sh, _groundY, _ctrl);
        RenderSystem.drawTree(dc, _ctrl, _cx, _trunkW, _chopLineY, _segH, shx);
        RenderSystem.drawPlayer(dc, _ctrl, _cx, _trunkW, _chopLineY, shx);
        RenderSystem.drawEffects(dc, _ctrl, _cx, _trunkW, _chopLineY, shx);
        _ctrl.fx.draw(dc, shx, 0);
        UIManager.drawHUD(dc, _ctrl, _sw, _hudTop, _energyBarY);
        if (_ctrl.milestoneT > 0) { UIManager.drawMilestone(dc, _ctrl, _sw, _sh); }
        if (_ctrl.dailyT > 0)     { UIManager.drawDailyToast(dc, _ctrl, _sw, _sh); }

        if (_ctrl.state == GS_OVER) { UIManager.drawOver(dc, _ctrl, _sw, _sh); }
    }

    // Turn controller one-shot event flags into particle bursts.
    hidden function _consumeEvents() {
        var half = _trunkW / 2;
        if (_ctrl.evChopSide != 0) {
            var ex = _cx + _ctrl.evChopSide * half;
            // Axe-tier chop juice (VISUAL ONLY): a better axe throws more chips,
            // faster, in a brighter shade. Oak=baseline, Iron=more, Golden=max.
            var tier = _ctrl.axeTier();
            var n1 = 8 + tier * 5;                       //  8 / 13 / 18
            var n2 = 4 + tier * 3;                       //  4 /  7 / 10
            var spd = 4.5 + tier * 1.2;                  // faster fling per tier
            var chipHi = (tier >= 2) ? 0xFFE58A : 0xE0C070;   // gold sparks on max axe
            _ctrl.fx.burst(ex, _chopLineY, n1, chipHi,  spd,       true, 12, 2 + tier, -2.0);
            _ctrl.fx.burst(ex, _chopLineY, n2, 0xB88A40, spd - 1.0, true, 12, 1 + tier, -1.0);
            if (_ctrl.evNearMiss != 0) {
                var lx = _cx + _ctrl.evNearMiss * (half + 18);
                _ctrl.fx.burst(lx, _chopLineY - _segH, 6, 0x3FA13F, 3.2, true, 14, 2, -1.0);
            }
            _ctrl.evChopSide = 0;
            _ctrl.evNearMiss = 0;
        }
        if (_ctrl.evDie) {
            var ex2 = _cx + _ctrl.player.side * half;
            _ctrl.fx.burst(ex2, _chopLineY - 10, 16, 0xE0C070, 5.5, true, 18, 3, -3.0);
            _ctrl.fx.burst(ex2, _chopLineY - 10, 10, 0x3FA13F, 4.5, true, 18, 2, -2.0);
            _ctrl.evDie = false;
        }
    }

    // Ambient drifting leaves (day/sunset) or snow (dusk/night).
    hidden function _emitWeather() {
        if (_ctrl.state != GS_PLAY) { return; }
        if (_ctrl.frame % 7 != 0)   { return; }
        var ph = _ctrl.dayPhase();
        var x  = Math.rand() % _sw;
        if (ph <= 1) {
            var leaf = ((Math.rand() % 2) == 0) ? 0x3FA13F : 0xB07A3E;
            _ctrl.fx.emit(x, -2, (Math.rand() % 3) - 1, 1.4, leaf, 40, 1, false);
        } else {
            _ctrl.fx.emit(x, -2, (Math.rand() % 3) - 1, 1.2, 0xDCE6F8, 46, 1, false);
        }
    }

    hidden function _doLayout() {
        _cx     = _sw / 2;
        _trunkW = _sw * 20 / 100;
        if (_trunkW < 20) { _trunkW = 20; }
        if (_trunkW > 54) { _trunkW = 54; }

        _hudTop     = _sh * 3 / 100; if (_hudTop < 4) { _hudTop = 4; }
        _energyBarY = _hudTop + 20;
        _groundY    = _sh - (_sh * 9 / 100);
        _chopLineY  = _groundY - (_sh * 4 / 100);

        var topOfTree = _energyBarY + 16;
        var avail     = _chopLineY - topOfTree;
        _segH = avail / TG_VISIBLE;
        if (_segH < 14) { _segH = 14; }
        if (_segH > 34) { _segH = 34; }
    }

    // ── Menu geometry — shared by UIManager.drawMenu + tap hit-test ──
    function menuRowGeom() {
        var topZone      = (_sh * 48) / 100;
        var bottomMargin = (_sh * 12) / 100; if (bottomMargin < 12) { bottomMargin = 12; }
        var gap          = (_sh * 3) / 100;  if (gap < 4) { gap = 4; }
        var avail = (_sh - bottomMargin) - topZone;
        var rowH  = (avail - gap * (DR_MENU_ROWS - 1)) / DR_MENU_ROWS;
        if (rowH > 26) { rowH = 26; }
        if (rowH < 15) { rowH = 15; }
        var rowW = (_sw * 62) / 100; if (rowW < 110) { rowW = 110; }
        var rowX = (_sw - rowW) / 2;
        var used = DR_MENU_ROWS * rowH + (DR_MENU_ROWS - 1) * gap;
        var rowY0 = topZone + (avail - used) / 2;
        if (rowY0 < topZone) { rowY0 = topZone; }
        return [rowH, rowW, rowX, rowY0, gap];
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _ctrl.diffName(), "DRWAL");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Input intents ────────────────────────────────────────────
    function inMenu()         { return _ctrl.state == GS_MENU; }
    function isPassiveState() { return _ctrl.state == GS_MENU || _ctrl.state == GS_OVER; }
    function screenW()        { return _sw; }

    function navUp() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuPrev(); return; }
        if (_ctrl.state == GS_OVER) { _ctrl.requestRestart(); return; }
        _ctrl.chopSide(SIDE_LEFT);
    }
    function navDown() {
        if (_ctrl.state == GS_MENU) { _ctrl.menuNext(); return; }
        if (_ctrl.state == GS_OVER) { _ctrl.requestRestart(); return; }
        _ctrl.chopSide(SIDE_RIGHT);
    }
    function navSelect() {
        if (_ctrl.state == GS_MENU) {
            if (_ctrl.menuRow == DR_ROW_LB) { openLeaderboard(); return; }
            _ctrl.menuActivate();
            return;
        }
        if (_ctrl.state == GS_OVER) { _ctrl.requestRestart(); return; }
        // Single-button fallback: chop again on whichever side the
        // player currently stands, without changing side.
        _ctrl.chopSide(_ctrl.player.side);
    }
    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            var g = menuRowGeom();
            var rowH = g[0]; var rowW = g[1]; var rowX = g[2]; var rowY0 = g[3]; var gap = g[4];
            for (var i = 0; i < DR_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    _ctrl.setMenuRow(i);
                    if (i == DR_ROW_LB) { openLeaderboard(); } else { _ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        if (_ctrl.state == GS_OVER) { _ctrl.requestRestart(); return; }
        // PLAY — tap the half of the screen to chop from that side.
        _ctrl.chopSide((x < _sw / 2) ? SIDE_LEFT : SIDE_RIGHT);
    }
    function handleBack() {
        // BACK always returns to the shared menu (pop the gameplay view).
        return false;
    }
}
