// ═══════════════════════════════════════════════════════════════
// MemoMenu.mc — Memo's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class MemoHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MemoView();
        WatchUi.pushView(v, new MemoDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a trio of memory tiles — two revealed symbols and a
    // face-down card between them.
    function drawArt(dc, cx, cy, w, h) as Void {
        _tile(dc, cx - 24, cy, true, 0);   // heart
        _tile(dc, cx, cy, false, 0);       // face-down
        _tile(dc, cx + 24, cy, true, 3);   // star/diamond
    }

    hidden function _tile(dc, cx0, cy0, revealed, sym) as Void {
        var tw = 16; var th = 20;
        var x = cx0 - tw / 2; var y = cy0 - th / 2;
        if (revealed) {
            dc.setColor(0x0C1020, Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(x, y, tw, th, 3);
            dc.setColor(0x1A2A44, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(x, y, tw, th, 3);
            if (sym == 0) {
                dc.setColor(0xDD2222, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx0 - 3, cy0 - 2, 3);
                dc.fillCircle(cx0 + 3, cy0 - 2, 3);
                dc.fillPolygon([[cx0 - 5, cy0 - 1], [cx0, cy0 + 6], [cx0 + 5, cy0 - 1]]);
            } else {
                dc.setColor(0xDDCC00, Graphics.COLOR_TRANSPARENT);
                dc.fillPolygon([[cx0, cy0 - 6], [cx0 + 6, cy0], [cx0, cy0 + 6], [cx0 - 6, cy0]]);
            }
        } else {
            dc.setColor(0x1A2255, Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(x, y, tw, th, 3);
            dc.setColor(0x2A3A77, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(x, y, tw, th, 3);
            dc.setColor(0x3A4A99, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[cx0, cy0 - 4], [cx0 + 4, cy0], [cx0, cy0 + 4], [cx0 - 4, cy0]]);
        }
    }

    // Leaderboard variant = the current difficulty name the game submits with.
    function lbVariant() as Lang.String {
        var names = ["Easy", "Normal", "Hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("memo_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    // Best moves for the current difficulty (mgM0/1/2), shown under the menu.
    function footerText() as Lang.String or Null {
        try {
            var d = 1;
            var v = Application.Storage.getValue("memo_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
            var b = Application.Storage.getValue("mgM" + d.toString());
            if (b instanceof Lang.Number && b > 0) {
                return "BEST " + b.format("%d") + " mv";
            }
        } catch (e) {}
        return null;
    }
}

function buildMemoMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "memo",
        :title1  => "MEMO",
        :title2  => null,
        :col1    => 0x44DDFF,
        :bg      => 0x080818,
        :circle  => 0x0E1020,
        :accent  => 0x44CC66,
        :lbTitle => "MEMO",
        :hooks   => new MemoHooks(),
        :options => [
            new GmOption("memo_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption("memo_fx",   "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
