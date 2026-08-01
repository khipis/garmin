// ═══════════════════════════════════════════════════════════════════════════
// DailySportMenu.mc — Wiring into the shared Bitochi menu.
//
// The menu is the root view: START drops straight into today's briefing, and
// every OPTIONS choice is persisted the moment it is cycled, so preferences
// survive leaving the app.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.WatchUi;

class DailySportHooks extends GameHooks {

    // The shared menu repaints on a 66 ms tick, so counting draws is a free
    // animation clock for the attract shot.
    hidden var _f;

    function initialize() { GameHooks.initialize(); _f = 0; }

    function startGame() as Void {
        // "Start in" decides whether the run is ranked; the engine downgrades
        // it to practice by itself when the day's energy is spent.
        var ranked = (DsUtil.optIndex(DS_K_MODE, 0, 2) == 0);
        var v = new MainView(ranked);
        WatchUi.pushView(v, new InputHandler(v), WatchUi.SLIDE_LEFT);
    }

    // Signature art: an endless attract shot of whatever the world is playing
    // today. One projectile, one arc, and the target swapped for the sport of
    // the day — so the front page answers "what is it today?" before the
    // player has pressed anything.
    function drawArt(dc, cx, cy, w, h) as Void {
        _f = (_f + 1) % 100000;

        var sport = "basketball";
        try { sport = ChallengeManager.today().sportId; } catch (e) {}

        var span = w * 30 / 100;            // shot length
        var sx   = cx - span / 2 - w / 40;  // release
        var hx   = sx + span;               // target centre
        var base = cy + h * 6 / 100;        // ground line
        var half = w * 5 / 100; if (half < 7) { half = 7; }
        var br   = w * 25 / 1000; if (br < 4) { br = 4; }

        // 90 frames per cycle: 62 of flight, the rest a beat on the target.
        var k = _f % 90;
        var t = (k < 62) ? (k / 62.0) : 1.0;
        var hit = (k >= 58 && k < 74) ? ((74 - k) / 16.0) : 0.0;

        // Flat sports fly flat: the arc height is the sport's own signature
        // long before the target it is heading for comes into view.
        var lofty = sport.equals("basketball") || sport.equals("golf");
        var arc   = lofty ? (h * 20 / 100) : (h * 7 / 100);
        var drop  = lofty ? 0.25 : 0.55;
        var bx = (sx + span * t).toNumber();
        var by = (base - h * 4 / 100 - 4 * arc * t * (1.0 - t)
                       - (base - cy) * t * drop).toNumber();

        dc.setColor(0x550055, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 9; i++) {
            dc.fillCircle(cx - w * 20 / 100 + i * (w * 5 / 100),
                          cy - h * 5 / 100, 2);
        }
        dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - w * 26 / 100, base, w * 52 / 100, 2);

        _drawTarget(dc, sport, hx, base, half, br, h, hit);

        // Trailing arc behind the projectile, brightest at the projectile.
        for (var i = 1; i <= 4; i++) {
            var tt = t - i * 0.055;
            if (tt < 0.0) { break; }
            var px = (sx + span * tt).toNumber();
            var py = (base - h * 4 / 100 - 4 * arc * tt * (1.0 - tt)
                           - (base - cy) * tt * drop).toNumber();
            dc.setColor(i < 2 ? 0xAA5500 : 0x550000, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px, py, br - i / 2);
        }

        // The athlete, and the projectile itself.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(sx - br - 2, base - h * 5 / 100, br + 2,
                                h * 5 / 100, 2);
        dc.setColor(0xFFAA55, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx - br / 2, base - h * 6 / 100, br * 3 / 4);

        _drawFlier(dc, sport, bx, by, br);
    }

    // The target of the day, drawn at the same scale whichever sport it is so
    // the composition does not jump around from morning to morning.
    hidden function _drawTarget(dc, sport, hx, base, half, br, h, hit) as Void {
        if (sport.equals("football")) {
            DsSportArt.goal(dc, hx - half, base - h * 15 / 100, base,
                            half, hit > 0.0);
            return;
        }
        if (sport.equals("archery")) {
            DsSportArt.targetFace(dc, hx, base - h * 11 / 100, half, hit > 0.0);
            return;
        }
        if (sport.equals("tennis")) {
            DsSportArt.tennisNet(dc, hx - half, base - h * 9 / 100, base);
            DsSportArt.serviceBox(dc, hx - half / 2, hx + half * 2, base,
                                  hx + half, h);
            return;
        }
        if (sport.equals("golf")) {
            DsSportArt.hole(dc, hx, base, br);
            DsSportArt.pin(dc, hx, base, h * 13 / 100, 0.6, hit > 0.0);
            return;
        }
        if (sport.equals("hillride")) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillPolygon([[hx - half * 2, base - h * 8 / 100],
                            [hx + half * 2, base],
                            [hx + half * 2, base + h * 6 / 100],
                            [hx - half * 2, base + h * 6 / 100]]);
            DsSportArt.hillMark(dc, hx + half, base - h / 100, h, 0xFF0000);
            return;
        }

        // Basketball: the rig, with the net whipping just after the drop.
        var netY = base - h * 8 / 100;
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hx + half + 3, base - h * 14 / 100, 3, h * 12 / 100);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(hx + half, base - h * 13 / 100, 3, h * 6 / 100);
        var sway = (hit * half / 2).toNumber();
        dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i <= 3; i++) {
            dc.drawLine(hx - half + (half * 2 * i) / 3, netY + 2,
                        hx - half / 2 + (half * i) / 3 + sway, netY + br * 2);
        }
        dc.setColor(DS_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(hx - half, netY - 1, half * 2, 3, 1);
    }

    hidden function _drawFlier(dc, sport, bx, by, br) as Void {
        if (sport.equals("football")) {
            DsSportArt.soccerBall(dc, bx, by, br, _f * 0.25);
        } else if (sport.equals("archery")) {
            DsSportArt.arrow(dc, bx, by, 1.0, 0.10, br * 4);
        } else if (sport.equals("tennis")) {
            DsSportArt.tennisBall(dc, bx, by, br, _f * 0.3);
        } else if (sport.equals("golf")) {
            DsSportArt.golfBall(dc, bx, by, br);
        } else if (sport.equals("hillride")) {
            DsSportArt.jumper(dc, bx, by, 1.0, 0.35, br * 3);
        } else {
            DsArt.ballArt(dc, ProgressionManager.ballIndex(), bx, by, br,
                          _f * 0.3);
        }
    }

    // Board = today's objective, so everyone on it played the same challenge.
    function lbVariant() as Lang.String { return LeaderboardManager.variant(); }

    function footerText() as Lang.String or Null {
        try {
            var best = ProgressionManager.todayBest();
            var days = ProgressionManager.streakDays();
            if (best > 0) {
                var s = "TODAY " + best.toString();
                if (days > 1) { s = s + "   " + days.toString() + "d"; }
                return s;
            }
            var left = ProgressionManager.energyLeft();
            return ChallengeManager.today().sportName() +
                   "  " + left.toString() + " TRIES";
        } catch (e) {}
        return null;
    }

    function hasReset()   as Lang.Boolean { return true; }
    function resetLabel() as Lang.String  { return "Reset profile"; }

    function resetProgress() as Void {
        try { ProgressionManager.resetAll(); } catch (e) {}
    }
}

function buildDailySportMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => DS_GAME_ID,
        :title1  => "DAILY SPORT",
        :title2  => "CHALLENGE",
        :col1    => 0xFF5500,
        :col2    => 0xFFAA00,
        :bg      => 0x000000,
        :circle  => 0x000000,
        :accent  => 0x00FFAA,
        :lbTitle => "DAILY SPORT",
        :hooks   => new DailySportHooks(),
        :options => [
            new GmOption(DS_K_MODE,  "Start in",  ["DAILY", "PRACTICE"], 0),
            new GmOption(DS_K_SPORT, "Practice sport",
                         ["TODAY", "BASKETBALL", "FOOTBALL", "ARCHERY",
                          "TENNIS", "GOLF", "HILL RIDE"], 0),
            new GmOption(DS_K_GUIDE, "Aim guide", ["SHORT", "FULL", "OFF"], 0),
            new GmOption(DS_K_BALL,  "Ball",      ["CLASSIC", "GOLDEN", "FLAME"], 0),
            new GmOption(DS_K_COURT, "Venue",     ["DAY", "NIGHT", "SUNSET", "STADIUM"], 0),
            new GmOption(DS_K_FX,    "Sound & Haptics", ["ON", "OFF"], 0)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
