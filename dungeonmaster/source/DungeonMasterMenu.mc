// ═══════════════════════════════════════════════════════════════════════════
// DungeonMasterMenu.mc — Wiring into the shared unified menu.
// OPTIONS values (class / difficulty / mode) persist through GmOption.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class DungeonMasterHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function hasResume() as Lang.Boolean {
        return SaveResume.exists("dungeonmaster");
    }

    function resumeGame() as Void {
        var v = new BitochiDungeonMasterView();
        v.loadResume(SaveResume.load("dungeonmaster"));
        WatchUi.pushView(v, new BitochiDungeonMasterDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function startGame() as Void {
        SaveResume.clear("dungeonmaster");
        var v = new BitochiDungeonMasterView();
        WatchUi.pushView(v, new BitochiDungeonMasterDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a torch-lit corridor vanishing into the dark, with a
    // skull watching from the end of it.
    function drawArt(dc, cx, cy, w, h) as Void {
        // Corridor walls in perspective
        dc.setColor(0x4A4038, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 40, cy - 20], [cx - 16, cy - 8], [cx - 16, cy + 8], [cx - 40, cy + 20]]);
        dc.fillPolygon([[cx + 40, cy - 20], [cx + 16, cy - 8], [cx + 16, cy + 8], [cx + 40, cy + 20]]);
        dc.setColor(0x2A2420, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 16, cy - 8, 32, 16);
        // Floor glow
        dc.setColor(0x3A2E22, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 40, cy + 20], [cx - 16, cy + 8], [cx + 16, cy + 8], [cx + 40, cy + 20]]);
        // Skull at the end of the hall
        dc.setColor(0xDDDDCC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy - 1, 5);
        dc.setColor(0x1A1410, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 3, cy - 2, 2, 2);
        dc.fillRectangle(cx + 1, cy - 2, 2, 2);
        // Torches
        dc.setColor(0xFF9922, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 30, cy - 10, 3);
        dc.fillCircle(cx + 30, cy - 10, 3);
        dc.setColor(0xFFDD66, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx - 30, cy - 10, 1);
        dc.fillCircle(cx + 30, cy - 10, 1);
    }

    function lbVariant() as Lang.String {
        return DmConst.lbVariant();
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("dm_best");
            if (v instanceof Lang.Number && v > 0) {
                return "DEEPEST F" + v.format("%d");
            }
        } catch (e) {}
        return null;
    }
}

function buildDungeonMasterMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "dungeonmaster",
        :title1  => "DUNGEON",
        :title2  => "MASTER",
        :col1    => 0xCC9944,
        :col2    => 0x99AACC,
        :bg      => 0x0A0806,
        :circle  => 0x161210,
        :accent  => 0xFFCC44,
        :lbTitle => "DUNGEON MASTER",
        :hooks   => new DungeonMasterHooks(),
        :options => [
            new GmOption("dm_class", "Hero", ["WARRIOR", "ROGUE", "MAGE", "PALADIN"], 0),
            new GmOption("dm_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1),
            new GmOption("dm_mode", "Dungeon", ["RANDOM", "DAILY"], 0),
            new GmOption("dm_haptic", "Rumble", ["ON", "OFF"], 0),
            new GmOption("dm_shake", "Screen shake", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
