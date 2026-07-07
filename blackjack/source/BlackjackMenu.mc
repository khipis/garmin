// ═══════════════════════════════════════════════════════════════
// BlackjackMenu.mc — Blackjack's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BlackjackHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiBlackjackView();
        WatchUi.pushView(v, new BitochiBlackjackDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a classic blackjack pair — an Ace of spades next to a
    // face-down card back, on green felt.
    function drawArt(dc, cx, cy, w, h) as Void {
        var cw = 22; var ch = 30;
        // Card back (behind, left)
        var bx = cx - 20; var by = cy - ch / 2;
        dc.setColor(0x1A2E5A, Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(bx, by, cw, ch, 3);
        dc.setColor(0x4A6AAA, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(bx, by, cw, ch, 3);
        dc.fillPolygon([[bx + cw / 2, by + ch / 2 - 5], [bx + cw / 2 + 5, by + ch / 2],
                        [bx + cw / 2, by + ch / 2 + 5], [bx + cw / 2 - 5, by + ch / 2]]);
        // Ace of spades (front, right)
        var ax = cx - 2; var ay = cy - ch / 2 + 4;
        dc.setColor(0xFCFAF6, Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(ax, ay, cw, ch, 3);
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(ax, ay, cw, ch, 3);
        dc.setColor(0x222222, Graphics.COLOR_TRANSPARENT);
        dc.drawText(ax + 4, ay + 1, Graphics.FONT_XTINY, "A", Graphics.TEXT_JUSTIFY_LEFT);
        // Spade pip
        var sx = ax + cw / 2; var sy = ay + ch / 2;
        dc.fillPolygon([[sx, sy - 6], [sx - 6, sy + 2], [sx + 6, sy + 2]]);
        dc.fillCircle(sx - 3, sy + 3, 3); dc.fillCircle(sx + 3, sy + 3, 3);
        dc.fillRectangle(sx - 1, sy + 3, 3, 4);
    }

    // Leaderboard variant = shoe size (d1/d2/d6), matching submit.
    function lbVariant() as Lang.String {
        var names = ["d1", "d2", "d6"];
        var i = 2;
        try {
            var v = Application.Storage.getValue("bj_decks");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null { return null; }
}

function buildBlackjackMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "blackjack",
        :title1  => "BLACKJACK",
        :col1    => 0x22AA44,
        :bg      => 0x041004,
        :circle  => 0x0A2A12,
        :accent  => 0x44CC66,
        :lbTitle => "BLACKJACK",
        :hooks   => new BlackjackHooks(),
        :options => [
            new GmOption("bj_decks", "Decks", ["1 DECK", "2 DECKS", "6 DECKS"], 2)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
