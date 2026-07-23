// ═══════════════════════════════════════════════════════════════
// PokerMenu.mc — Poker's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class PokerHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BitochiPokerView();
        WatchUi.pushView(v, new BitochiPokerDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a fanned poker hand (spade / heart / diamond) with chips.
    function drawArt(dc, cx, cy, w, h) as Void {
        _miniCard(dc, cx - 22, cy - 4, 0);
        _miniCard(dc, cx - 7, cy - 9, 1);
        _miniCard(dc, cx + 8, cy - 4, 2);
        // chips
        dc.setColor(0xEE4400, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 22, cy + 14, 5);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx + 22, cy + 14, 5);
        dc.setColor(0x2266CC, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx + 30, cy + 13, 5);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.drawCircle(cx + 30, cy + 13, 5);
    }

    hidden function _miniCard(dc, x, y, suit) as Void {
        var isRed = (suit == 1 || suit == 2);
        dc.setColor(0xFCFAF6, Graphics.COLOR_TRANSPARENT); dc.fillRoundedRectangle(x, y, 15, 22, 3);
        dc.setColor(0xBBBBBB, Graphics.COLOR_TRANSPARENT); dc.drawRoundedRectangle(x, y, 15, 22, 3);
        var tc = isRed ? 0xCC1111 : 0x222222;
        dc.setColor(tc, Graphics.COLOR_TRANSPARENT);
        var pcx = x + 7; var pcy = y + 11;
        if (suit == 0) {
            dc.fillPolygon([[pcx, pcy - 5], [pcx - 5, pcy + 2], [pcx + 5, pcy + 2]]);
            dc.fillCircle(pcx - 2, pcy + 2, 3); dc.fillCircle(pcx + 2, pcy + 2, 3);
            dc.fillRectangle(pcx - 1, pcy + 2, 2, 4);
        } else if (suit == 1) {
            dc.fillCircle(pcx - 2, pcy - 1, 3); dc.fillCircle(pcx + 2, pcy - 1, 3);
            dc.fillPolygon([[pcx - 5, pcy], [pcx, pcy + 6], [pcx + 5, pcy]]);
        } else {
            dc.fillPolygon([[pcx, pcy - 6], [pcx + 5, pcy], [pcx, pcy + 6], [pcx - 5, pcy]]);
        }
    }

    // Leaderboard variant = session length (h10/h20/h40), matching submit.
    function lbVariant() as Lang.String {
        var names = ["h10", "h20", "h40"];
        var i = 1;
        try {
            var v = Application.Storage.getValue("pk_hands");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }
}

function buildPokerMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "poker",
        :title1  => "POKER",
        :title2  => null,
        :col1    => 0xEE4400,
        :bg      => 0x080604,
        :circle  => 0x120A04,
        :accent  => 0xEE8822,
        :lbTitle => "POKER",
        :hooks   => new PokerHooks(),
        :options => [
            new GmOption("pk_hands", "Hands", ["10 HANDS", "20 HANDS", "40 HANDS"], 1),
            new GmOption("pk_fx", "Sound & Haptics", ["ON", "OFF"], 0),
            // Cosmetic card-back — unlocked by rank, shop-ready. A locked pick
            // simply renders as the classic back until it's owned.
            new GmOption("pk_skin", "Card Back", ["CLASSIC", "NEON"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
