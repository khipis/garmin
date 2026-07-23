// ═══════════════════════════════════════════════════════════════
// CellWarsMenu.mc — Cell Wars' wiring into the shared unified menu.
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class CellWarsHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var v = new CellWarsView();
        WatchUi.pushView(v, new CellWarsDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: a little glowing colony grid in the NEON palette.
    function drawArt(dc, cx, cy, w, h) as Void {
        var cols = [0x00EEFF, 0xFF6600, 0xCC22FF, 0x00FF88];
        // 7x5 cell pattern (a fixed "still-life"-ish blob), 8px cells.
        var pat = [
            [0,1,1,0,1,1,0],
            [1,1,0,1,0,1,1],
            [0,0,1,1,1,0,0],
            [1,1,0,1,0,1,1],
            [0,1,1,0,1,1,0]
        ];
        var cz = 8;
        var ox = cx - (7 * cz) / 2;
        var oy = cy - (5 * cz) / 2;
        for (var r = 0; r < 5; r++) {
            for (var c = 0; c < 7; c++) {
                if (pat[r][c] == 0) { continue; }
                dc.setColor(cols[(r + c) % 4], Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ox + c * cz, oy + r * cz, cz - 1, cz - 1);
            }
        }
    }
}

function buildCellWarsMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "cellwars",
        :title1  => "CELL",
        :title2  => "WARS",
        :col1    => 0x00EEFF,
        :col2    => 0xCC22FF,
        :bg      => 0x000308,
        :circle  => 0x061018,
        :accent  => 0x00FF88,
        :lbTitle => "CELL WARS",
        :hooks   => new CellWarsHooks(),
        :options => [
            new GmOption("cw_mode",  "Mode",  ["BATTLE", "RUMBLE", "CONWAY", "HIGHLIFE", "DAY+N", "MAZE", "SEEDS"], 0),
            new GmOption("cw_teams", "Teams", ["2", "3", "4"], 1),
            new GmOption("cw_speed", "Speed", ["1", "2", "3", "4", "5"], 2),
            new GmOption("cw_fill",  "Fill",  ["LOW", "MED", "HIGH"], 1),
            new GmOption("cw_theme", "Theme", ["NEON", "OCEAN", "FIRE", "FOREST"], 0),
            new GmOption("cw_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
