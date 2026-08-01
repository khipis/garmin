// ═══════════════════════════════════════════════════════════════════════════
// ZombieMenu.mc — Shared unified menu wiring.
//
// The art band runs a miniature of the real scene: blood moon, skyline, the
// barricade and a shambling line of dead, so the menu already sells the game.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class ZombieHooks extends GameHooks {
    hidden var _m;
    hidden var _tick;

    function initialize() {
        GameHooks.initialize();
        _tick = 0;
        try { _m = new ZombieModel(); } catch (e) { _m = null; }
    }

    function startGame() as Void {
        try {
            var v = new ZombieView();
            WatchUi.pushView(v, new ZombieDelegate(v), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    function drawArt(dc, cx, cy, w, h) as Void {
        _tick += 1;
        var t = _tick;
        var gy = cy + h * 5 / 100;
        var span = w * 80 / 100;
        var x0 = cx - span / 2;

        // Firelight pooling behind the rooftops, same recipe as the street.
        var glowY = gy - h * 2 / 100;
        dc.setColor(0x550000, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, glowY, span * 56 / 100, h * 9 / 100);
        dc.setColor(0xAA5500, Graphics.COLOR_TRANSPARENT);
        dc.fillEllipse(cx, glowY, span * 34 / 100, h * 6 / 100);

        // Moon.
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + span * 34 / 100, cy - h * 8 / 100, h * 5 / 100);
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + span * 34 / 100, cy - h * 8 / 100, h * 4 / 100);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + span * 33 / 100, cy - h * 9 / 100, h * 2 / 100);

        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        for (var b = 0; b < 9; b++) {
            var bw = span / 11;
            var bh = h * 3 / 100 + ((b * 37) % 5) * h / 100;
            dc.fillRectangle(x0 + b * (span / 9), gy - bh - h * 2 / 100, bw, bh);
        }

        // Street.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 - 4, gy - h * 2 / 100, span + 8, h * 5 / 100);
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x0 - 4, gy - h * 2 / 100, span + 8, 1);

        // Three dead walking in, looping across the band.
        var types = [Zs.Z_WALKER, Zs.Z_RUNNER, Zs.Z_BRUTE];
        var zh = h * 11 / 100;
        for (var i = 0; i < 3; i++) {
            var pos = (t * 2 + i * 90) % 300;
            var zx = x0 + span * (300 - pos) / 300 + span * 12 / 100;
            if (zx > x0 + span) { continue; }
            try { ZsArt.drawZombie(dc, types[i], zx, gy, zh, t + i * 7, 0, 0); } catch (e) {}
        }

        // Barricade and the nest that holds it. No survivor: the whole promise
        // of the game is that the base fights on its own, and a menu showing a
        // man with a rifle would sell the wrong one.
        try {
            ZsArt.drawBarricade(dc, w, h, 0, x0 + span * 14 / 100, gy, 62, 78, false, t);
            ZsArt._mgNest(dc, x0 + span * 4 / 100, gy, h * 4 / 100, t,
                          ((t / 6) % 5) == 0);
        } catch (e) {}
    }

    // The countdown belongs on the menu: it is the reason to come back, and
    // the player should see it before they have opened anything.
    function footerText() as Lang.String or Null {
        try {
            if (_m == null) { return null; }
            if (_m.bestNight <= 0) { return "Walk. Then hold."; }
            return "Night " + _m.night + " · " + ZsHud.countdown(_m.secsToWave());
        } catch (e) { return null; }
    }

    function openBoard() as Lang.Boolean {
        try {
            var m = new ZsBoardMenu();
            WatchUi.pushView(m, new ZsBoardDelegate(), WatchUi.SLIDE_LEFT);
            return true;
        } catch (e) { return false; }
    }

    function hasReset() as Lang.Boolean { return true; }
    function resetLabel() as Lang.String { return "Reset base"; }
    function resetProgress() as Void {
        try {
            var m = (_m != null) ? _m : new ZombieModel();
            m.resetAll();
            _m = m;
        } catch (e) {}
    }
}

class ZsBoardMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({ :title => "LEADERBOARD" });
        addItem(new WatchUi.MenuItem("Furthest Night", "Best night survived", Zs.LB_DAY, null));
        addItem(new WatchUi.MenuItem("Strongest Base", "Defence rating", Zs.LB_FORT, null));
        addItem(new WatchUi.MenuItem("Most Kills", "Lifetime zombies", Zs.LB_KILLS, null));
        addItem(new WatchUi.MenuItem("Nights Held", "Waves survived", Zs.LB_WAVES, null));
    }
}

class ZsBoardDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() { Menu2InputDelegate.initialize(); }
    function onSelect(item) {
        var variant = item.getId();
        var title = item.getLabel();
        try {
            var v = new LbScoresView(Zs.GAME_ID, variant, title);
            WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

function buildZombieMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => Zs.GAME_ID,
        :title1  => "ZOMBIE",
        :title2  => "SURVIVAL",
        :col1    => Zs.COL1,
        :col2    => Zs.COL2,
        :bg      => Zs.BG,
        :circle  => Zs.CIRCLE,
        :accent  => Zs.ACCENT,
        :lbTitle => "ZOMBIE",
        :hooks   => new ZombieHooks(),
        :options => [
            new GmOption("zs_fx", "Sound & Haptics", ["ON", "OFF"], 0),
            new GmOption("zs_detail", "Detail", ["HIGH", "LOW"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
