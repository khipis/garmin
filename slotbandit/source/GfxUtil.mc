// ═══════════════════════════════════════════════════════════════
// GfxUtil.mc — Shared drawing helpers: colour blending, vertical
// gradients, glossy highlights, bulb rings. Kept cheap (a handful
// of fills per call, no per-frame allocation of big structures) so
// nothing here risks the watchdog on a 50 ms tick.
// ═══════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;

module GfxUtil {

    // Blend two 0xRRGGBB colours; t in 0..100 (0 = a, 100 = b).
    function lerp(a, b, t) {
        if (t < 0) { t = 0; } if (t > 100) { t = 100; }
        var ar = (a >> 16) & 0xFF; var ag = (a >> 8) & 0xFF; var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF; var bg = (b >> 8) & 0xFF; var bb = b & 0xFF;
        var r = ar + (br - ar) * t / 100;
        var g = ag + (bg - ag) * t / 100;
        var bl = ab + (bb - ab) * t / 100;
        return (r << 16) | (g << 8) | bl;
    }

    // Scale brightness of a colour, pct 0..100+ (100 = unchanged).
    function shade(col, pct) {
        var r = ((col >> 16) & 0xFF) * pct / 100;
        var g = ((col >> 8) & 0xFF) * pct / 100;
        var b = (col & 0xFF) * pct / 100;
        if (r > 255) { r = 255; } if (g > 255) { g = 255; } if (b > 255) { b = 255; }
        return (r << 16) | (g << 8) | b;
    }

    // Vertical gradient fill using horizontal bands (cheap, ~steps fills).
    function vGradient(dc, x, y, w, h, colTop, colBot, steps) {
        if (steps < 2) { steps = 2; }
        var bandH = h / steps;
        if (bandH < 1) { bandH = 1; steps = h; }
        for (var i = 0; i < steps; i++) {
            var t = (steps <= 1) ? 0 : (i * 100 / (steps - 1));
            dc.setColor(lerp(colTop, colBot, t), Graphics.COLOR_TRANSPARENT);
            var by = y + i * bandH;
            var bh = (i == steps - 1) ? (y + h - by) : (bandH + 1);
            dc.fillRectangle(x, by, w, bh);
        }
    }

    // Same, but clipped into a rounded-rect silhouette by first filling a
    // rounded rect base colour then the gradient inside a slightly inset box.
    function vGradientRounded(dc, x, y, w, h, colTop, colBot, steps, radius) {
        dc.setColor(colTop, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, w, h, radius);
        vGradient(dc, x + 1, y + 1, w - 2, h - 2, colTop, colBot, steps);
    }

    // A ring of small "marquee" bulbs around a rectangle. `phase` steps the
    // chase animation; lit bulbs are `on`, dim ones `off`.
    function bulbRing(dc, x, y, w, h, r, spacing, phase, onCol, offCol) {
        var idx = 0;
        // top + bottom edges
        for (var bx = x; bx <= x + w; bx += spacing) {
            _bulb(dc, bx, y,       r, ((idx + phase) % 3 == 0) ? onCol : offCol); idx++;
            _bulb(dc, bx, y + h,   r, ((idx + phase) % 3 == 0) ? onCol : offCol); idx++;
        }
        // left + right edges
        for (var by = y + spacing; by < y + h; by += spacing) {
            _bulb(dc, x,     by, r, ((idx + phase) % 3 == 0) ? onCol : offCol); idx++;
            _bulb(dc, x + w, by, r, ((idx + phase) % 3 == 0) ? onCol : offCol); idx++;
        }
    }

    function _bulb(dc, cx, cy, r, col) {
        dc.setColor(shade(col, 40), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + 1);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
    }

    // Small four-point sparkle centred at (cx,cy).
    function sparkle(dc, cx, cy, s, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx, cy - s], [cx + s / 3, cy], [cx, cy + s], [cx - s / 3, cy]]);
        dc.fillPolygon([[cx - s, cy], [cx, cy - s / 3], [cx + s, cy], [cx, cy + s / 3]]);
    }
}
