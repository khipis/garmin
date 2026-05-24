// ═══════════════════════════════════════════════════════════════
// ResourceManager.mc — Score / level progression.
//
// Centralises tile→points conversion so balance tweaks live in one
// place.  Also tracks current level number and "best run" record.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;

const GM_BEST_KEY = "gm_best";

class ResourceManager {
    var oreCount;
    var gemCount;
    var score;
    var level;
    var bestScore;

    function initialize() {
        oreCount = 0; gemCount = 0; score = 0; level = 1;
        bestScore = 0;
        loadBest();
    }

    function reset() {
        oreCount = 0; gemCount = 0; score = 0;
    }

    static function tilePoints(t) {
        if (t == GM_ORE) { return 25; }
        if (t == GM_GEM) { return 100; }
        return 0;
    }

    // Reward for mining a tile.  Returns points added.
    function collect(t) {
        var pts = tilePoints(t);
        if (t == GM_ORE) { oreCount = oreCount + 1; }
        if (t == GM_GEM) { gemCount = gemCount + 1; }
        score = score + pts;
        return pts;
    }

    function loadBest() {
        try {
            var v = Application.Storage.getValue(GM_BEST_KEY);
            if (v != null) { bestScore = v; }
        } catch (e) {}
    }

    function commitBest() {
        if (score > bestScore) {
            bestScore = score;
            try { Application.Storage.setValue(GM_BEST_KEY, bestScore); } catch (e) {}
        }
    }
}
