// ═══════════════════════════════════════════════════════════════
// DinoMenu.mc — Dino Run's wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class DinoHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new DinosaurView();
        WatchUi.pushView(v, new DinosaurDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: the chubby grey dino trotting past a little cactus.
    function drawArt(dc, cx, cy, w, h) as Void {
        // ground line
        dc.setColor(0x3C3C3C, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 38, cy + 15, 76, 2);
        // cactus
        dc.setColor(0x30B348, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx + 26, cy + 1, 5, 14, 2);
        dc.fillRoundedRectangle(cx + 22, cy + 6, 4, 6, 1);
        dc.fillRoundedRectangle(cx + 31, cy + 4, 4, 6, 1);
        // dino tail
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 26, cy + 3, 9, 4, 2);
        // dino body + head
        dc.setColor(0xDDDDDD, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - 20, cy - 2, 17, 15, 4);
        dc.fillRoundedRectangle(cx - 9, cy - 12, 14, 12, 5);
        dc.fillRoundedRectangle(cx + 3, cy - 8, 6, 4, 2);
        // legs
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 16, cy + 13, 4, 4);
        dc.fillRectangle(cx - 8, cy + 13, 4, 4);
        // eye
        dc.setColor(0x111111, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 1, cy - 8, 2);
    }

    // Leaderboard variant = base speed (s0/s1/s2), matching submit.
    function lbVariant() as Lang.String {
        var names = ["s0", "s1", "s2"];
        var i = 0;
        try {
            var v = Application.Storage.getValue("dino_spd");
            if (v instanceof Lang.Number && v >= 0 && v < names.size()) { i = v; }
        } catch (e) {}
        return names[i];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("dinoBest");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildDinoMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "dinosaur",
        :title1  => "DINO RUN",
        :title2  => null,
        :col1    => 0x30B348,
        :bg      => 0x0D0D0D,
        :circle  => 0x141414,
        :accent  => 0x44BB22,
        :lbTitle => "DINOSAUR",
        :hooks   => new DinoHooks(),
        :options => [
            new GmOption("dino_spd", "Speed", ["NORMAL", "FAST", "INSANE"], 0),
            new GmOption("dino_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
