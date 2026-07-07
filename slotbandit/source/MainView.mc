// ═══════════════════════════════════════════════════════════════
// MainView.mc — WatchUi.View: layout, tick driver, input entry
// points. Drawing itself lives in RenderSystem (cabinet/reels) and
// UIManager (HUD/menu/round-over), so this stays a thin coordinator.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;

class MainView extends WatchUi.View {
    hidden var _ctrl;
    hidden var _timer;

    hidden var _sw;
    hidden var _sh;
    hidden var _laidOut;
    hidden var _announced;
    hidden var _started;   // auto-start the round on first frame

    // Cached layout — recomputed once per screen size.
    hidden var _cabX;
    hidden var _cabY;
    hidden var _cabW;
    hidden var _cabH;
    hidden var _colW;
    hidden var _rowH;
    hidden var _gap;
    hidden var _hudTop;
    hidden var _bottomY;

    function initialize() {
        View.initialize();
        _ctrl    = new GameController();
        _timer   = null;
        _sw = 0; _sh = 0;
        _laidOut = false;
        _announced = false;
        _started = false;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        _timer.start(method(:onTick), TICK_MS, true);
        // Once per session, when the menu first appears: show the reset-or-launch
        // announcement (uses the previous session's cached bundle; throttled).
        if (!_announced && _ctrl.state == GS_MENU) {
            _announced = true;
            Leaderboard.announce(LB_GAME_ID, null);
        }
    }
    function onHide() { if (_timer != null) { _timer.stop(); } }

    function onTick() {
        _ctrl.step();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        if (!_laidOut) { _doLayout(); _laidOut = true; }

        // Menu lives in the shared root view — drop straight into a round and
        // never render an in-game menu here.
        if (!_started || _ctrl.state == GS_MENU) {
            _ctrl.startGame();
            _started = true;
        }

        dc.setColor(0x000000, 0x000000);
        dc.clear();

        RenderSystem.drawPlayBackground(dc, _sw, _sh);
        RenderSystem.drawCabinet(dc, _sw, _sh, _cabX, _cabY, _cabW, _cabH);
        RenderSystem.drawReels(dc, _ctrl, _cabX, _cabY, _colW, _rowH, _gap);
        RenderSystem.drawResultFlash(dc, _ctrl, _cabX, _cabY, _cabW, _cabH);
        if (_ctrl.spinState == SS_SPINNING && !_ctrl.autoPlay) {
            RenderSystem.drawNextHint(dc, _ctrl, _cabX, _cabY, _colW, _gap);
        }
        RenderSystem.drawLever(dc, _ctrl, _cabX, _cabW, _cabY, _cabH);

        UIManager.drawHUD(dc, _ctrl, _sw, _hudTop);
        UIManager.drawBottomBar(dc, _ctrl, _sw, _bottomY);

        if (_ctrl.state == GS_OVER) { UIManager.drawOver(dc, _ctrl, _sw, _sh); }
    }

    hidden function _doLayout() {
        // Bigger top/bottom insets so the HUD chips and the bottom hint/result
        // text never fall into the clipped chords of a round screen.
        _hudTop  = _sh * 12 / 100; if (_hudTop < 8) { _hudTop = 8; }
        _bottomY = _sh - (_sh * 20 / 100);

        // Cabinet shrunk further, leaving more breathing room around the reel
        // window on every screen size.
        _gap  = 4;
        _cabW = _sw * 56 / 100; if (_cabW < 118) { _cabW = 118; } if (_cabW > _sw - 60) { _cabW = _sw - 60; }
        _colW = (_cabW - _gap * 2) / 3;
        _cabW = _colW * 3 + _gap * 2;
        _cabX = (_sw - _cabW) / 2;

        var topOfCab = _hudTop + 34;
        var botOfCab = _bottomY - 14;
        var winH = botOfCab - topOfCab;
        _rowH = winH / 3;
        if (_rowH < 17) { _rowH = 17; }
        if (_rowH > 36) { _rowH = 36; }
        _cabH = _rowH * 3;
        _cabY = topOfCab + (winH - _cabH) / 2;
        if (_cabY < topOfCab) { _cabY = topOfCab; }
    }

    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, _ctrl.roundName(), "SLOT BANDIT");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // ── Input intents ────────────────────────────────────────────
    function inMenu()         { return _ctrl.state == GS_MENU; }
    function isPassiveState() { return _ctrl.state == GS_MENU || _ctrl.state == GS_OVER; }

    function navUp()   { if (_ctrl.state == GS_MENU) { _ctrl.menuPrev(); } }
    function navDown() { if (_ctrl.state == GS_MENU) { _ctrl.menuNext(); } }
    function navSelect() {
        if (_ctrl.state == GS_MENU) {
            if (_ctrl.menuRow == SB_ROW_LB) { openLeaderboard(); return; }
            _ctrl.menuActivate();
            return;
        }
        _ctrl.primaryAction();
    }
    function navLongPress() {
        if (_ctrl.state == GS_PLAY) { _ctrl.toggleAuto(); }
    }

    function handleTap(x, y) {
        if (_ctrl.state == GS_MENU) {
            var g = UIManager.menuRowGeom(_sw, _sh);
            var rowH = g[0]; var rowW = g[1]; var rowX = g[2]; var rowY0 = g[3]; var gap = g[4];
            for (var i = 0; i < SB_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    _ctrl.setMenuRow(i);
                    if (i == SB_ROW_LB) { openLeaderboard(); } else { _ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        if (_ctrl.state == GS_OVER) { _ctrl.startGame(); return; }

        // PLAY — tap a reel column to stop it directly; tap elsewhere
        // (HUD/cabinet frame) falls back to the generic spin/stop-next.
        if (_ctrl.spinState == SS_SPINNING && y >= _cabY && y <= _cabY + _cabH &&
            x >= _cabX && x <= _cabX + _cabW) {
            var idx = (x - _cabX) / (_colW + _gap);
            if (idx > 2) { idx = 2; }
            _ctrl.stopReelAt(idx);
            return;
        }
        _ctrl.primaryAction();
    }

    function handleBack() {
        // Always pop back to the shared menu.
        return false;
    }
}
