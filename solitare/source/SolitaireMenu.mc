// ═══════════════════════════════════════════════════════════════
// SolitaireMenu.mc — Solitaire's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class SolitaireHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new SolitaireView();
        WatchUi.pushView(v, new SolitaireDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a small fan of playing cards on the felt.
    function drawArt(dc, cx, cy, w, h) as Void {
        _miniCard(dc, cx - 24, cy - 2, 0);
        _miniCard(dc, cx - 8, cy - 6, 1);
        _miniCard(dc, cx + 8, cy - 2, 3);
        _miniCard(dc, cx + 22, cy + 2, 2);
    }

    hidden function _miniCard(dc, x, y, suit) as Void {
        var isRed = (suit == 1 || suit == 2);
        dc.setColor(0xFCFAF6, Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(x, y, 15, 22, 3);
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(x, y, 15, 22, 3);
        var tc = isRed ? 0xCC1111 : 0x111111;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        var pcx = x + 7; var pcy = y + 11;
        if (suit == 0) {
            dc.fillPolygon([[pcx, pcy - 5], [pcx - 5, pcy + 2], [pcx + 5, pcy + 2]]);
            dc.fillCircle(pcx - 2, pcy + 2, 3); dc.fillCircle(pcx + 2, pcy + 2, 3);
            dc.fillRectangle(pcx - 1, pcy + 2, 2, 4);
        } else if (suit == 1) {
            dc.fillCircle(pcx - 2, pcy - 1, 3); dc.fillCircle(pcx + 2, pcy - 1, 3);
            dc.fillPolygon([[pcx - 5, pcy], [pcx, pcy + 6], [pcx + 5, pcy]]);
        } else if (suit == 2) {
            dc.fillPolygon([[pcx, pcy - 6], [pcx + 5, pcy], [pcx, pcy + 6], [pcx - 5, pcy]]);
        } else {
            dc.fillCircle(pcx, pcy - 3, 3);
            dc.fillCircle(pcx - 3, pcy + 1, 3); dc.fillCircle(pcx + 3, pcy + 1, 3);
            dc.fillRectangle(pcx - 1, pcy + 2, 2, 4);
        }
    }

    function lbVariant() as Lang.String { return ""; }
}

function buildSolitaireMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "solitaire",
        :title1  => "SOLITAIRE",
        :title2  => null,
        :col1    => 0x33CC66,
        :bg      => 0x0A2818,
        :circle  => 0x08220F,
        :accent  => 0x44CC66,
        :lbTitle => "SOLITAIRE",
        :hooks   => new SolitaireHooks(),
        :options => [
            new GmOption("sol_draw", "Draw", ["1 CARD", "3 CARD"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
