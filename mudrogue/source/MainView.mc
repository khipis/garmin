// ═══════════════════════════════════════════════════════════════
// MainView.mc — WatchUi.View — renders the current screen and
// routes input intents to the controller.
//
// There's no game-loop timer — the game is purely turn-based, so
// we only redraw on input or first show. This drains essentially
// zero battery while the player is reading a screen.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class MainView extends WatchUi.View {

    hidden var _ctrl;
    hidden var _sw;
    hidden var _sh;
    hidden var _optY0;
    hidden var _optStride;
    hidden var _laidOut;

    function initialize() {
        View.initialize();
        _ctrl   = new GameController();
        _sw = 0; _sh = 0; _optY0 = 0; _optStride = 0;
        _laidOut = false;
        // Title screen starts with "NEW GAME" already wired by controller.
        _ctrl.gotoTitle();
    }

    function onShow() {}
    function onHide() {}

    function onUpdate(dc) {
        _sw = dc.getWidth();
        _sh = dc.getHeight();
        // Title screen has its own layout (no status row).
        if (_ctrl.state == GS_TITLE) { _drawTitle(dc); return; }

        dc.setColor(0x000814, 0x000814); dc.clear();
        var lay = UIManager.layout(_sw, _sh);
        var statusY = lay[0]; var bodyY0 = lay[1]; var bodyY1 = lay[2];
        _optY0    = lay[3];
        _optStride = lay[4];

        UIManager.drawStatus(dc, _sw, statusY, _ctrl.player, _ctrl.floor,
                             _ctrl.logColor);
        UIManager.drawBody(dc, _sw, bodyY0, bodyY1,
                           _ctrl.logTitle, _ctrl.logLine1, _ctrl.logLine2,
                           _ctrl.logColor);
        UIManager.drawOptions(dc, _sw, _optY0, _optStride,
                              _ctrl.optionLabels, _ctrl.cursor);
    }

    hidden function _drawTitle(dc) {
        dc.setColor(0x000814, 0x000814); dc.clear();
        var cx = _sw / 2;
        // Title
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 16 / 100, Graphics.FONT_MEDIUM,
                    "MUD", Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(cx, _sh * 30 / 100, Graphics.FONT_MEDIUM,
                    "ROGUE", Graphics.TEXT_JUSTIFY_CENTER);

        // Decorative @ glyph
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _sh * 47 / 100, Graphics.FONT_MEDIUM,
                    "@", Graphics.TEXT_JUSTIFY_CENTER);

        // Best floor
        if (_ctrl.bestFloor > 0) {
            dc.setColor(0xCCCCDD, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, _sh * 62 / 100, Graphics.FONT_XTINY,
                        "BEST FLOOR " + _ctrl.bestFloor.format("%d"),
                        Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Start button
        var bw = _sw * 60 / 100; if (bw < 130) { bw = 130; }
        var bh = _sh * 12 / 100; if (bh < 26)  { bh = 26;  }
        var bx = (_sw - bw) / 2;
        var by = _sh * 76 / 100;
        dc.setColor(0x111418, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 6);
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 6);
        dc.drawText(cx, by + (bh - 14) / 2, Graphics.FONT_XTINY,
                    "> NEW GAME <", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // ── Input intents called from InputHandler ──────────────────────
    function navUp()     { _ctrl.moveCursor(-1); }
    function navDown()   { _ctrl.moveCursor( 1); }
    function navSelect() { _ctrl.confirm(); }
    function handleBack(){ return _ctrl.back(); }

    function handleTap(x, y) {
        if (_ctrl.state == GS_TITLE) { _ctrl.confirm(); return; }
        // Was a tap on one of the option rows?
        if (_optStride > 0 && _ctrl.optionCount > 0) {
            for (var i = 0; i < _ctrl.optionCount; i++) {
                var rowY = _optY0 + i * _optStride;
                if (y >= rowY - 6 && y <= rowY + _optStride - 6) {
                    _ctrl.cursor = i;
                    _ctrl.confirm();
                    return;
                }
            }
        }
        // Tap elsewhere = confirm current option.
        _ctrl.confirm();
    }
}
