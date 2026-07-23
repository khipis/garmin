// ═══════════════════════════════════════════════════════════════
// SkyRollMenu.mc — SkyRoll's wiring into the shared unified menu.
//
// MenuConfig (title, colours, signature iso-tile art, OPTIONS list) plus the
// GameHooks that launch a run, expose the leaderboard variant and best footer.
// The main menu itself is the shared GameMenuView.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class SkyRollHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new MainView();
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature mini-graphic: a single iso tile with a marble on top.
    function drawArt(dc, cx, cy, w, h) as Void {
        var hw = SR_TILE_HW; var hh = SR_TILE_HH;
        var top    = [cx,      cy - hh];
        var right  = [cx + hw, cy     ];
        var bottom = [cx,      cy + hh];
        var left   = [cx - hw, cy     ];
        dc.setColor(0x0F1830, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([bottom, left,  [cx - hw, cy + 4], [cx, cy + hh + 4]]);
        dc.setColor(0x182338, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([bottom, right, [cx + hw, cy + 4], [cx, cy + hh + 4]]);
        dc.setColor(0xC8D4DC, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([top, right, bottom, left]);
        dc.setColor(0x7A8898, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(top[0], top[1], right[0], right[1]);
        dc.drawLine(right[0], right[1], bottom[0], bottom[1]);
        dc.drawLine(bottom[0], bottom[1], left[0], left[1]);
        dc.drawLine(left[0], left[1], top[0], top[1]);
        dc.setColor(0x223044, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - 6, 7);
        dc.setColor(0xDCE6F8, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - 6, 6);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 2, cy - 9, 2, 2);
    }

    // Leaderboard is split by difficulty (mirrors GameController.diffName()).
    function lbVariant() as Lang.String {
        var d = SR_DIFF_NORMAL;
        try {
            var v = Application.Storage.getValue(SR_K_DIFF);
            if (v instanceof Lang.Number) { d = v; }
        } catch (e) {}
        if (d == SR_DIFF_EASY) { return "Easy"; }
        if (d == SR_DIFF_HARD) { return "Hard"; }
        return "Norm";
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue(SR_K_BEST);
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d") + " m"; }
        } catch (e) {}
        return null;
    }
}

function buildSkyRollMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => LB_GAME_ID,
        :title1  => "SKY",
        :title2  => "ROLL",
        :col1    => 0xFFE066,
        :col2    => 0xCCEEFF,
        :bg      => 0x081428,
        :circle  => 0x0F1F38,
        :accent  => 0xFFEE66,
        :lbTitle => "SKY ROLL",
        :hooks   => new SkyRollHooks(),
        :options => [
            new GmOption(SR_K_SENS, "Sensitivity", ["LOW", "NORM", "HIGH"], 1),
            new GmOption(SR_K_DIFF, "Difficulty",  ["EASY", "NORM", "HARD"], 1),
            new GmOption(SR_K_FX,   "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
