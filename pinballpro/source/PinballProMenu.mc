// ═══════════════════════════════════════════════════════════════
// PinballProMenu.mc — Pinball Pro's wiring into the shared menu.
//
// Builds the MenuConfig (two-line title, colours, bumper emblem, OPTIONS
// = Table) and the GameHooks that launch a match, expose the per-table
// leaderboard variant and a best-score footer.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class PinballProHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    // START → drop straight into a match. Pinball's MainView needs a
    // back-reference to its delegate for the touch-hold safety net.
    function startGame() as Void {
        var v = new MainView();
        var d = new InputHandler(v);
        v.setDelegate(d);
        WatchUi.pushView(v, d, WatchUi.SLIDE_LEFT);
    }

    // Signature emblem: three demo pop-bumpers + a chrome ball.
    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0xFF3344, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 24, cy, 6);
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 6);
        dc.setColor(0x44FF66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 24, cy, 6);
        dc.setColor(0xCCCCDD, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 12, cy + 12, 3);
    }

    // Leaderboard variant = the current table name (mirrors the submit
    // in GameController._resolveDrains()).
    function lbVariant() as Lang.String {
        return TableLibrary.NAMES[_table()];
    }

    // Best score footer — mirrors the old menu's BEST line.
    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("hi");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + _fmt(v); }
        } catch (e) {}
        return null;
    }

    hidden function _table() {
        try {
            var v = Application.Storage.getValue("table");
            if (v instanceof Lang.Number && v >= 0 && v < TableLibrary.COUNT) { return v; }
        } catch (e) {}
        return 0;
    }

    // Comma-grouped thousands (same as MainView._formatScore).
    hidden function _fmt(n) {
        var s = n.format("%d");
        var len = s.length();
        if (len <= 3) { return s; }
        var out = "";
        for (var i = 0; i < len; i++) {
            if (i > 0 && (len - i) % 3 == 0) { out = out + ","; }
            out = out + s.substring(i, i + 1);
        }
        return out;
    }
}

// Factory used by the App's getInitialView().
function buildPinballProMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "pinballpro",
        :title1  => "PINBALL",
        :title2  => "PRO",
        :col1    => 0xFF3344,
        :col2    => 0x44CCFF,
        :bg      => 0x080808,
        :circle  => 0x101418,
        :accent  => 0x44BB22,
        :lbTitle => "PINBALL PRO",
        :hooks   => new PinballProHooks(),
        :options => [
            new GmOption("table", "Table",
                ["CLASSIC", "NOVA", "DERBY", "STINGER", "ECLIPSE"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
