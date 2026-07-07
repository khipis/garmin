// ═══════════════════════════════════════════════════════════════
// BlobsMenu.mc — Blobs' wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BlobsHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiBlobsView();
        WatchUi.pushView(v, new BitochiBlobsDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: two round googly blobs, matching the in-game palette.
    function drawArt(dc, cx, cy, w, h) as Void {
        _blob(dc, cx - 16, cy, 11, 0x44AAFF, 0x2277DD);
        _blob(dc, cx + 15, cy + 2, 9, 0xFF6644, 0xDD3311);
    }

    hidden function _blob(dc, x, y, r, col, dark) as Void {
        dc.setColor(dark, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y + 1, r);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - r / 3, y - r / 4, r / 3);
        dc.fillCircle(x + r / 3, y - r / 4, r / 3);
        dc.setColor(0x101010, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - r / 3, y - r / 4, r / 6 + 1);
        dc.fillCircle(x + r / 3, y - r / 4, r / 6 + 1);
    }

    function lbVariant() as Lang.String { return ""; }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("blobBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildBlobsMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "blobs",
        :title1  => "BLOBS",
        :title2  => null,
        :col1    => 0xFF6644,
        :bg      => 0x0E1828,
        :circle  => 0x122036,
        :accent  => 0x44EE66,
        :lbTitle => "BLOBS",
        :hooks   => new BlobsHooks(),
        :options => [
            new GmOption("blob_2p", "Players", ["1 PLAYER", "2 PLAYERS"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
