// ═══════════════════════════════════════════════════════════════
// TowerDefenseMenu.mc — Shared unified menu wiring.
// Options (map / difficulty) persist via GmOption → Application.Storage.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class TowerDefenseHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function hasResume() as Lang.Boolean {
        return SaveResume.exists("towerdefense");
    }

    function resumeGame() as Void {
        var v = new BitochiTowerDefenseView();
        v.loadResume(SaveResume.load("towerdefense"));
        WatchUi.pushView(v, new BitochiTowerDefenseDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function startGame() as Void {
        SaveResume.clear("towerdefense");
        var v = new BitochiTowerDefenseView();
        WatchUi.pushView(v, new BitochiTowerDefenseDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a slice of the real board — cobbled road bending past a
    // manned turret, with a grunt walking into its range ring.
    function drawArt(dc, cx, cy, w, h) as Void {
        TdArt.prep();
        TdArt.frame(2, 4);
        var u = w / 26;
        if (u < 4) { u = 4; }

        // Grass patch behind the scene.
        dc.setColor(0x1E4028, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - u * 7, cy - u * 3, u * 14, u * 6);

        // Road: shoulder, dirt, cobbles.
        dc.setPenWidth(u * 3 / 2 + 2);
        dc.setColor(0x3E301E, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - u * 7, cy + u, cx + u, cy + u);
        dc.drawLine(cx + u, cy + u, cx + u, cy - u * 2);
        dc.drawLine(cx + u, cy - u * 2, cx + u * 7, cy - u * 2);
        dc.setPenWidth(u * 3 / 2 - 1);
        dc.setColor(0x6A5436, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - u * 7, cy + u, cx + u, cy + u);
        dc.drawLine(cx + u, cy + u, cx + u, cy - u * 2);
        dc.drawLine(cx + u, cy - u * 2, cx + u * 7, cy - u * 2);
        dc.setPenWidth(1);
        dc.setColor(0x8A8272, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 5; i++) {
            dc.fillRectangle(cx - u * 6 + i * u * 3 / 2, cy + u - 1, u / 2 + 1, u / 2 + 1);
        }

        // Keep at the end of the road.
        dc.setColor(0x4A5260, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx + u * 6, cy - u * 3, u * 2, u * 2);
        dc.setColor(0x44CC88, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + u * 7, cy - u * 2, u / 2);

        // Range ring, then the turret itself aiming down the road.
        dc.setColor(0x2E5478, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx - u * 2, cy - u * 2, u * 4);
        TdArt.aim(-1.0, 0.0);
        TdArt.tower(dc, TW_GUN, 3, cx - u * 2, cy - u * 2, u, 0, false);

        // Grunt walking in.
        TdArt.aim(1.0, 0.0);
        TdArt.enemy(dc, EN_GRUNT, cx - u * 5, cy + u, u * 3 / 4, 0, 0, 100, 0);
    }

    function lbVariant() as Lang.String {
        return TdUtil.lbVariant();
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("td_best");
            if (v instanceof Lang.Number && v > 0) {
                return "BEST W" + v.format("%d");
            }
        } catch (e) {}
        return null;
    }
}

function buildTowerDefenseMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "towerdefense",
        :title1  => "TOWER",
        :title2  => "DEFENSE",
        :col1    => 0x66AAFF,
        :col2    => 0x44CC88,
        :bg      => 0x060A12,
        :circle  => 0x0C1524,
        :accent  => 0x44CC88,
        :lbTitle => "TOWER DEFENSE",
        :hooks   => new TowerDefenseHooks(),
        :options => [
            new GmOption("td_map", "Map", ["BEND", "SNAKE", "RING", "GATE", "DAILY"], 0),
            new GmOption("td_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption("td_pace", "Pace", ["NORMAL", "FAST"], 0),
            new GmOption("td_hints", "Coach tips", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
