// ═══════════════════════════════════════════════════════════════════════════
// GmConfig.mc — Per-game configuration for the shared unified menu.
//
// Every game builds ONE MenuConfig (usually in its App) describing how the
// shared GameMenuView should present it while keeping the game's own vibe:
//   • title (1-2 lines) + per-line colours + "by Bitochi" attribution
//   • background / round-inset / accent colours
//   • an optional signature "art" band (frog, snake, court…) via GameHooks
//   • the OPTIONS list: per-game settings (difficulty / speed / mode / …)
//   • leaderboard id + title (+ dynamic variant via GameHooks)
//
// The main menu itself is ALWAYS the same three clean rows:
//   START · OPTIONS · LEADERBOARD
// so every game feels identical and premium; per-game knobs live in OPTIONS.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Lang;
using Toybox.Graphics;

// ── Hooks: the only game-specific behaviour the shared menu calls back into ──
// Subclass in each game and override what you need. All methods are optional
// except startGame().
class GameHooks {
    function initialize() {}

    // REQUIRED: launch the actual gameplay (push the game view). Called when the
    // player picks START.
    function startGame() as Void {}

    // Draw the game's signature art inside the reserved band. (cx,cy) is the
    // band centre; w/h are the full screen dims. Default: nothing.
    function drawArt(dc, cx, cy, w, h) as Void {}

    // Leaderboard variant for the LEADERBOARD row (e.g. current difficulty).
    // Default: no variant.
    function lbVariant() as Lang.String { return ""; }

    // Optional one-line footer under the rows (e.g. "WINS 12"), or null.
    function footerText() as Lang.String or Null { return null; }
}

// ── A single OPTIONS setting: a labelled cycler persisted in Storage ─────────
// Values are display strings; the stored value is the selected index (0-based),
// which the game reads back from `key` to configure itself at start.
class GmOption {
    var key;      // Application.Storage key
    var label;    // row label, e.g. "Difficulty"
    var values;   // Array<String> display values, e.g. ["EASY","MED","HARD"]
    var def;      // default index when unset

    // When set, this option only applies to the full/unlocked version: picking a
    // gated value while locked routes the player to the unlock screen instead.
    var lockedFrom;  // first index that requires unlock, or -1 for none

    function initialize(k as Lang.String, lbl as Lang.String,
                        vals as Lang.Array, defIdx as Lang.Number) {
        key = k; label = lbl; values = vals; def = defIdx; lockedFrom = -1;
    }

    // Fluent: mark indices >= from as premium-only.
    function gatedFrom(from as Lang.Number) as GmOption { lockedFrom = from; return self; }

    function index() as Lang.Number {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number && v >= 0 && v < values.size()) { return v; }
        } catch (e) {}
        return def;
    }

    function valueStr() as Lang.String { return values[index()]; }

    // Advance to the next value (wrapping) and persist. Returns the new index.
    function cycle() as Lang.Number {
        var n = (index() + 1) % values.size();
        try { Application.Storage.setValue(key, n); } catch (e) {}
        return n;
    }

    function isGated(idx as Lang.Number) as Lang.Boolean {
        return lockedFrom >= 0 && idx >= lockedFrom;
    }
}

// ── The full per-game menu configuration ─────────────────────────────────────
class MenuConfig {
    var gameId;    // leaderboard/entitlement id, e.g. "pongpro"
    var title1;    // headline line 1 (required)
    var title2;    // headline line 2 or null
    var col1;      // title line 1 colour
    var col2;      // title line 2 colour
    var brand;     // attribution line, default "by Bitochi"
    var bg;        // background colour
    var circle;    // round-watch inset fill colour
    var accent;    // START / selection accent colour
    var lbTitle;   // title shown on the leaderboard screen
    var hooks;     // GameHooks instance
    var options;   // Array<GmOption> (may be empty)

    function initialize(p as Lang.Dictionary) {
        gameId  = p[:gameId];
        title1  = p[:title1];
        title2  = p.hasKey(:title2)  ? p[:title2]  : null;
        col1    = p.hasKey(:col1)    ? p[:col1]    : 0x00D4FF;
        col2    = p.hasKey(:col2)    ? p[:col2]    : col1;
        brand   = p.hasKey(:brand)   ? p[:brand]   : "by Bitochi";
        bg      = p.hasKey(:bg)      ? p[:bg]      : 0x080808;
        circle  = p.hasKey(:circle)  ? p[:circle]  : 0x101418;
        accent  = p.hasKey(:accent)  ? p[:accent]  : 0x34D399;
        lbTitle = p.hasKey(:lbTitle) ? p[:lbTitle] : title1;
        hooks   = p[:hooks];
        options = p.hasKey(:options) ? p[:options] : [];
    }

    function isUnlocked() as Lang.Boolean { return Entitlement.isUnlocked(gameId); }
}
