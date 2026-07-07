// ═══════════════════════════════════════════════════════════════
// BlocksMenu.mc — Blocks' wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BlocksHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiBlocksView();
        WatchUi.pushView(v, new BitochiBlocksDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a cluster of colourful tetromino cells, like the old
    // menu's bobbing blocks.
    function drawArt(dc, cx, cy, w, h) as Void {
        var s = 11;
        // A little S-piece + I-piece in the classic palette.
        _cell(dc, cx - 6,  cy - 11, s, 0x00EEFF);
        _cell(dc, cx + 5,  cy - 11, s, 0x00EEFF);
        _cell(dc, cx - 17, cy,      s, 0xFFDD00);
        _cell(dc, cx - 6,  cy,      s, 0xCC44FF);
        _cell(dc, cx + 5,  cy,      s, 0x44FF44);
        _cell(dc, cx + 16, cy,      s, 0xFF3333);
    }

    hidden function _cell(dc, x, y, s, col) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, s, s, 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 2, y + 2, 2, 2);
    }

    function lbVariant() as Lang.String { return ""; }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("blocks_best");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildBlocksMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "blocks",
        :title1  => "BLOCKS",
        :col1    => 0x44AAFF,
        :bg      => 0x07101C,
        :circle  => 0x0D1E2E,
        :accent  => 0x44AAFF,
        :lbTitle => "BLOCKS",
        :hooks   => new BlocksHooks(),
        :options => [
            new GmOption("blocks_tilt", "Tilt steer", ["OFF", "ON"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
