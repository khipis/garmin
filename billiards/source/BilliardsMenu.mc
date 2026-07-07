// ═══════════════════════════════════════════════════════════════
// BilliardsMenu.mc — Billiards' wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BilliardsHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new BilliardView();
        WatchUi.pushView(v, new BilliardDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a small green-felt rack — cue ball on the left with a
    // triangle of coloured balls, echoing the old menu's decorative rack.
    function drawArt(dc, cx, cy, w, h) as Void {
        // Cue ball
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(cx - 26, cy, 5);
        // Apex + triangle
        _ball(dc, cx - 4, cy,      0xFFDD00);
        _ball(dc, cx + 6, cy - 6,  0xDD2222);
        _ball(dc, cx + 6, cy + 6,  0x2255DD);
        _ball(dc, cx + 16, cy - 12, 0x111111);
        _ball(dc, cx + 16, cy,      0xFF7700);
        _ball(dc, cx + 16, cy + 12, 0x228833);
    }

    hidden function _ball(dc, x, y, col) as Void {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillCircle(x, y, 5);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT); dc.fillCircle(x - 1, y - 1, 1);
    }

    // Match BilliardGame.lbVariant() exactly (keyed on the stored game type).
    function lbVariant() as Lang.String {
        var gt = 1;  // default GT_9BALL
        try {
            var v = Application.Storage.getValue("billGT");
            if (v instanceof Lang.Number) { gt = v; }
        } catch (e) {}
        if (gt == 0) { return "3-ball"; }
        if (gt == 2) { return "8-ball"; }
        if (gt == 3) { return "snooker"; }
        if (gt == 4) { return "timeattack"; }
        return "9-ball";
    }

    function footerText() as Lang.String or Null { return null; }
}

function buildBilliardsMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "billiards",
        :title1  => "BILLIARDS",
        :col1    => 0xFFFFFF,
        :bg      => 0x0A1A0A,
        :circle  => 0x0C3010,
        :accent  => 0x66FFAA,
        :lbTitle => "BILLIARDS",
        :hooks   => new BilliardsHooks(),
        :options => [
            // Index order matches GT_* consts: 0=3BALL,1=9BALL,2=8BALL,3=SNOOKER,4=TIMEATTACK
            new GmOption("billGT", "Mode",
                ["3-BALL", "9-BALL", "8-BALL", "SNOOKER", "TIME ATK"], 1),
            new GmOption("bill_vs", "Players", ["P vs AI", "P vs P"], 0),
            new GmOption("billDiff", "Difficulty", ["EASY", "MEDIUM", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
