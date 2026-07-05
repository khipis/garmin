// ═══════════════════════════════════════════════════════════════
// SymbolManager.mc — Symbol definitions, weighted distribution,
// payout table, and glossy icon rendering.
//
// Symbols are ranked by id: rarer symbols have a HIGHER id, which
// lets SpinLogic's skill pull-in reuse the id directly as a "value"
// score (no separate rank table needed).
//   0 Cherry (common)  1 Bell  2 Star  3 Diamond  4 Seven (rarest)
//
// Every glyph is drawn with a base shape + gradient/shade layering
// + a bright highlight so it reads as a shiny casino icon rather
// than a flat blob. Shapes are still pure vector (no PNG assets),
// so they scale to any watch size.
// ═══════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;

const SYM_CHERRY  = 0;
const SYM_BELL    = 1;
const SYM_STAR    = 2;
const SYM_DIAMOND = 3;
const SYM_SEVEN   = 4;
const SYM_COUNT   = 5;

module SymbolManager {

    // Weighted so cherries/bells show up often, diamonds/sevens are rare.
    // Total weight = 25 -> also doubles as the reel strip length.
    const WEIGHTS = [9, 7, 5, 3, 1];   // cherry, bell, star, diamond, seven
    const STRIP_LEN = 25;

    // Payout for 3-of-a-kind on the payline, indexed by symbol id.
    const PAYOUT_3 = [30, 50, 80, 120, 200];
    const PAYOUT_2 = 10;   // flat bonus for any 2-of-3 match

    // Builds one shuffled strip honouring WEIGHTS — a real "reel strip"
    // layout (not per-frame RNG), so continuous scrolling + skill-stop
    // timing is meaningful: the same strip order repeats every lap.
    function buildStrip() {
        var strip = new [STRIP_LEN];
        var i = 0;
        for (var s = 0; s < SYM_COUNT; s++) {
            for (var w = 0; w < WEIGHTS[s]; w++) {
                strip[i] = s;
                i = i + 1;
            }
        }
        for (var k = STRIP_LEN - 1; k > 0; k--) {
            var j = Math.rand() % (k + 1);
            var tmp = strip[k]; strip[k] = strip[j]; strip[j] = tmp;
        }
        return strip;
    }

    function colorFor(sym) {
        if (sym == SYM_CHERRY)  { return 0xFF3344; }
        if (sym == SYM_BELL)    { return 0xFFCC33; }
        if (sym == SYM_STAR)    { return 0xFFEE55; }
        if (sym == SYM_DIAMOND) { return 0x33DDFF; }
        return 0xFF2244; // SYM_SEVEN
    }

    function draw(dc, sym, cx, cy, size) {
        drawDim(dc, sym, cx, cy, size, 100);
    }

    // `dim` 0..100 fades off-payline rows so the active row reads clearly.
    function drawDim(dc, sym, cx, cy, size, dim) {
        if (sym == SYM_CHERRY)  { _cherry(dc, cx, cy, size, dim);  return; }
        if (sym == SYM_BELL)    { _bell(dc, cx, cy, size, dim);    return; }
        if (sym == SYM_STAR)    { _star(dc, cx, cy, size, dim);    return; }
        if (sym == SYM_DIAMOND) { _diamond(dc, cx, cy, size, dim); return; }
        _seven(dc, cx, cy, size, dim);
    }

    // ── Cherry — two glossy berries, curved stems, a leaf ────────────
    function _cherry(dc, cx, cy, size, dim) {
        var r  = size * 24 / 100;
        var dx = size * 18 / 100;
        var dy = size * 16 / 100;
        var topY = cy - size * 34 / 100;

        var stem = GfxUtil.shade(0x2E7D32, dim);
        dc.setColor(stem, Graphics.COLOR_TRANSPARENT);
        _thickArc(dc, cx, topY, cx - dx, cy + dy - r, 3);
        _thickArc(dc, cx, topY, cx + dx, cy + dy - r, 3);

        // leaf
        dc.setColor(GfxUtil.shade(0x43A047, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, topY], [cx + size * 16 / 100, topY - size * 8 / 100],
                        [cx + size * 20 / 100, topY + size * 2 / 100]]);

        _berry(dc, cx - dx, cy + dy, r, dim);
        _berry(dc, cx + dx, cy + dy, r, dim);
    }
    function _berry(dc, bx, by, r, dim) {
        dc.setColor(GfxUtil.shade(0x8E1620, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, r);
        dc.setColor(GfxUtil.shade(0xE23140, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx, by, r * 82 / 100);
        dc.setColor(GfxUtil.shade(0xFF8A94, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(bx - r / 3, by - r / 3, r / 3);
    }

    // ── Bell — golden gradient body, shine, clapper ──────────────────
    function _bell(dc, cx, cy, size, dim) {
        var bw   = size * 46 / 100;
        var topY = cy - size * 32 / 100;
        var botY = cy + size * 26 / 100;
        var bh   = botY - topY;

        // little top knob
        dc.setColor(GfxUtil.shade(0xB8860B, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, topY - 3, size * 6 / 100 + 1);

        // body: dome + flare, faux-gradient via three stacked shades
        dc.setColor(GfxUtil.shade(0xB8860B, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, topY + bw / 2, bw / 2);
        dc.fillPolygon([[cx - bw / 2, topY + bw / 2], [cx + bw / 2, topY + bw / 2],
                        [cx + bw / 2 + 6, botY], [cx - bw / 2 - 6, botY]]);
        dc.setColor(GfxUtil.shade(0xFFCC33, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, topY + bw / 2, bw / 2 - 3);
        dc.fillPolygon([[cx - bw / 2 + 3, topY + bw / 2], [cx + bw / 2 - 3, topY + bw / 2],
                        [cx + bw / 2 + 2, botY - 2], [cx - bw / 2 - 2, botY - 2]]);
        // left-side sheen
        dc.setColor(GfxUtil.shade(0xFFE9A0, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - bw / 4, topY + 3], [cx - bw / 8, topY + 3],
                        [cx - bw / 6, botY - 4], [cx - bw / 3, botY - 4]]);
        // rim + clapper
        dc.setColor(GfxUtil.shade(0x8A6508, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cx - bw / 2 - 7, botY - 3, bw + 14, 5, 2);
        dc.fillCircle(cx, botY + 5, size * 7 / 100);
    }

    // ── Star — gold star with lighter inner star + glow tips ─────────
    function _star(dc, cx, cy, size, dim) {
        _starPoly(dc, cx, cy, size * 32 / 100, size * 14 / 100, GfxUtil.shade(0xB8860B, dim));
        _starPoly(dc, cx, cy, size * 27 / 100, size * 12 / 100, GfxUtil.shade(0xFFDD33, dim));
        _starPoly(dc, cx, cy - size * 3 / 100, size * 15 / 100, size * 7 / 100, GfxUtil.shade(0xFFF3B0, dim));
    }
    function _starPoly(dc, cx, cy, R, r2, col) {
        var pts = new [10];
        for (var i = 0; i < 10; i++) {
            var ang = -Math.PI / 2 + i * Math.PI / 5;
            var rad = (i % 2 == 0) ? R : r2;
            pts[i] = [cx + (rad * Math.cos(ang)).toNumber(),
                      cy + (rad * Math.sin(ang)).toNumber()];
        }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(pts);
    }

    // ── Diamond — faceted cyan gem, table + pavilion + sparkle ───────
    function _diamond(dc, cx, cy, size, dim) {
        var hw = size * 30 / 100;
        var topY = cy - size * 24 / 100;
        var tblY = cy - size * 8 / 100;
        var botY = cy + size * 34 / 100;

        // outline gem
        dc.setColor(GfxUtil.shade(0x0E7C99, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, topY], [cx + hw, tblY], [cx, botY], [cx - hw, tblY]]);
        // inner bright body
        dc.setColor(GfxUtil.shade(0x33DDFF, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, topY + 2], [cx + hw - 3, tblY], [cx, botY - 3], [cx - hw + 3, tblY]]);
        // table facet (top-left lighter)
        dc.setColor(GfxUtil.shade(0xAEF2FF, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, topY + 2], [cx + hw - 3, tblY], [cx, tblY], [cx - hw + 3, tblY]]);
        // facet lines
        dc.setColor(GfxUtil.shade(0x0E7C99, dim), Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - hw + 3, tblY, cx + hw - 3, tblY);
        dc.drawLine(cx, topY + 2, cx, botY - 3);
        // sparkle
        GfxUtil.sparkle(dc, cx - hw / 3, tblY - size * 4 / 100, size * 9 / 100, GfxUtil.shade(0xFFFFFF, dim));
    }

    // ── Seven — a VECTOR "7" (top bar + slanted leg) so it scales to the
    // reel cell instead of overflowing like a fixed-size font glyph.
    // Drawn as: gold outline (offset copies) → deep-red shadow → red body
    // → white sheen streak. ──────────────────────────────────────────
    function _seven(dc, cx, cy, size, dim) {
        // gold outline via a few offset copies
        var gold = GfxUtil.shade(0xFFCC33, dim);
        var off = [[-2,0],[2,0],[0,-2],[0,2],[-2,-2],[2,-2],[-2,2],[2,2]];
        for (var i = 0; i < off.size(); i++) {
            _sevenShapes(dc, cx + off[i][0], cy + off[i][1], size, gold);
        }
        _sevenShapes(dc, cx + 1, cy + 2, size, GfxUtil.shade(0x7A0A16, dim)); // shadow
        _sevenShapes(dc, cx, cy, size, GfxUtil.shade(0xE21B2C, dim));         // body

        // white sheen on the top bar
        var w  = size * 52 / 100; var h = size * 60 / 100;
        var bt = size * 16 / 100;
        var left = cx - w / 2; var top = cy - h / 2;
        dc.setColor(GfxUtil.shade(0xFF9AA2, dim), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(left + 2, top + 2, w - 6, bt / 3 + 1);
    }

    // The two quads that make up the "7", shifted to (cx,cy) in `col`.
    function _sevenShapes(dc, cx, cy, size, col) {
        var w  = size * 52 / 100;
        var h  = size * 60 / 100;
        var bt = size * 16 / 100;   // top-bar thickness
        var dw = size * 17 / 100;   // leg thickness
        var left  = cx - w / 2;
        var right = cx + w / 2;
        var top   = cy - h / 2;
        var bottom = cy + h / 2;
        var barBot = top + bt;
        var legBotL = cx - w * 6 / 100;

        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        // top bar
        dc.fillPolygon([[left, top], [right, top], [right, barBot], [left, barBot]]);
        // slanted leg from under the bar's right end down to bottom-centre
        dc.fillPolygon([[right - dw, barBot], [right, barBot],
                        [legBotL + dw, bottom], [legBotL, bottom]]);
    }

    // Thick line via a short filled quad — cheap "brush stroke".
    function _thickArc(dc, x1, y1, x2, y2, w) {
        dc.fillPolygon([[x1 - w, y1], [x1 + w, y1], [x2 + w, y2], [x2 - w, y2]]);
    }
}
