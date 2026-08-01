// ═══════════════════════════════════════════════════════════════════════════
// BackroomsMenu.mc — Wires BACKROOMS RUN into the shared unified menu.
//
// START drops a fresh run (clearing any save), RESUME rebuilds an interrupted
// one from its seed, OPTIONS persist through GmOption, and LEADERBOARD opens a
// four-board picker instead of a single list.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class BackroomsHooks extends GameHooks {
    hidden var _tick;

    function initialize() {
        GameHooks.initialize();
        _tick = 0;
    }

    hidden function _dailyMode() {
        try {
            var v = Application.Storage.getValue("br_mode");
            return (v instanceof Lang.Number && v == 1);
        } catch (e) {}
        return false;
    }

    function hasResume() as Lang.Boolean { return SaveResume.exists(Br.GAME_ID); }

    function resumeGame() as Void {
        try {
            var blob = SaveResume.load(Br.GAME_ID);
            var v = new BackroomsView(_dailyMode(), blob);
            WatchUi.pushView(v, new BackroomsDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }

    function startGame() as Void {
        try {
            SaveResume.clear(Br.GAME_ID);
            var v = new BackroomsView(_dailyMode(), null);
            WatchUi.pushView(v, new BackroomsDelegate(v), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    // Signature art: a lit corridor vanishing into the dark, with something
    // standing at the far end that may or may not be there this frame.
    function drawArt(dc, cx, cy, w, h) as Void {
        _tick += 1;
        var half = w * 22 / 100;
        if (half < 26) { half = 26; }
        var top = cy - h * 9 / 100;
        var bot = cy + h * 9 / 100;

        // Wallpaper walls converging on a vanishing point.
        dc.setColor(0xC8B45A, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - half, top - 6], [cx - half / 4, top + 6],
                        [cx - half / 4, bot - 6], [cx - half, bot + 6]]);
        dc.setColor(0xA89448, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx + half, top - 6], [cx + half / 4, top + 6],
                        [cx + half / 4, bot - 6], [cx + half, bot + 6]]);
        // Carpet + ceiling.
        dc.setColor(0x4A3E24, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - half, bot + 6], [cx - half / 4, bot - 6],
                        [cx + half / 4, bot - 6], [cx + half, bot + 6]]);
        dc.setColor(0x6A6034, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - half, top - 6], [cx - half / 4, top + 6],
                        [cx + half / 4, top + 6], [cx + half, top - 6]]);
        // The far wall, and a flickering panel above it.
        dc.setColor(0x1A1710, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - half / 4, top + 6, half / 2, bot - top - 12);
        if ((_tick % 11) != 0) {
            dc.setColor(0xFFF6C8, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - half / 8, top + 7, half / 4, 2);
        }
        // Someone at the end of the hall, sometimes.
        if ((_tick % 40) < 16) {
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - 2, bot - 16, 5, 11);
            dc.fillCircle(cx, bot - 18, 3);
        }
    }

    function footerText() as Lang.String or Null {
        try {
            var t = BrSave.bestTime();
            if (t <= 0) { return "You should not be here"; }
            var m = t / 60;
            var s = t % 60;
            return "BEST " + m.format("%d") + ":" + s.format("%02d") +
                   " · L" + BrSave.bestDepth().format("%d");
        } catch (e) { return null; }
    }

    function openBoard() as Lang.Boolean {
        try {
            var m = new BrBoardMenu();
            WatchUi.pushView(m, new BrBoardDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        } catch (e) { return false; }
    }

    function hasReset() as Lang.Boolean { return true; }
    function resetLabel() as Lang.String { return "Reset progress"; }
    function resetProgress() as Void {
        try { BrSave.resetAll(); } catch (e) {}
    }
}

class BrBoardMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "LEADERBOARD" });
        addItem(new WatchUi.MenuItem("Longest Run", "Survival time", Br.LB_TIME, null));
        addItem(new WatchUi.MenuItem("Deepest Level", "Floors reached", Br.LB_DEPTH, null));
        addItem(new WatchUi.MenuItem("Escapes", "Exits found", Br.LB_ESCAPE, null));
        addItem(new WatchUi.MenuItem("Daily Run", "Today's seed", Br.LB_DAILY, null));
    }
}

class BrBoardDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        try {
            var v = new LbScoresView(Br.GAME_ID, item.getId(), item.getLabel());
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

function buildBackroomsMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => Br.GAME_ID,
        :title1  => "BACKROOMS",
        :title2  => "RUN",
        :col1    => Br.COL1,
        :col2    => Br.COL2,
        :bg      => Br.BG,
        :circle  => Br.CIRCLE,
        :accent  => Br.ACCENT,
        :lbTitle => "BACKROOMS",
        :hooks   => new BackroomsHooks(),
        :options => [
            new GmOption("br_mode", "Mode", ["ENDLESS", "DAILY"], 0),
            new GmOption("br_diff", "Dread", ["CALM", "NORMAL", "NIGHTMARE"], 1),
            new GmOption("br_detail", "Detail", ["LOW", "MED", "HIGH"], 1),
            new GmOption("br_fx", "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
