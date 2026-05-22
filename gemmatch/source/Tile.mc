// ═══════════════════════════════════════════════════════════════
// Tile.mc — Gem types + drawing.
//
// Tiles are encoded as plain ints (0 = empty, 1..NUM_TILE_TYPES =
// gem type). Storing them as ints avoids allocating an object per
// cell — important for performance on low-end Garmin watches.
// This class exposes constants and a stateless render helper used
// by the UI to paint a gem at any (cx, cy, size).
//
// Each type has a distinct colour AND distinct geometric shape so
// the game stays playable for colour-blind users.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

const TILE_EMPTY    = 0;
const TILE_RED      = 1;  // filled circle
const TILE_BLUE     = 2;  // filled square (rounded)
const TILE_GREEN    = 3;  // filled diamond (rotated square)
const TILE_YELLOW   = 4;  // filled triangle (apex up)
const TILE_PURPLE   = 5;  // filled five-pointed-ish star (hex approx)
const NUM_TILE_TYPES = 5;

class Tile {
    // Colour palette indexed by tile type (index 0 unused).
    static var COLORS = [0x000000, 0xFF3333, 0x3388FF, 0x33CC44, 0xFFCC22, 0xBB55EE];

    // Render a gem of `type` centred at (cx, cy) inside a square cell
    // of side `size`. `selected` adds a bright yellow outline that
    // pulses on the player's "picked" tile.
    static function draw(dc, type, cx, cy, size, selected) {
        if (type == TILE_EMPTY) { return; }

        // Slight inset so adjacent gems aren't touching.
        var r = (size * 38) / 100;     // base radius
        if (r < 3) { r = 3; }

        var col = COLORS[type];
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);

        if (type == TILE_RED) {
            dc.fillCircle(cx, cy, r);
        } else if (type == TILE_BLUE) {
            var s2 = r;  // half-side
            dc.fillRoundedRectangle(cx - s2, cy - s2, s2 * 2, s2 * 2, 3);
        } else if (type == TILE_GREEN) {
            // Diamond (rotated square)
            dc.fillPolygon([[cx, cy - r],
                            [cx + r, cy],
                            [cx, cy + r],
                            [cx - r, cy]]);
        } else if (type == TILE_YELLOW) {
            // Triangle apex up
            dc.fillPolygon([[cx,     cy - r],
                            [cx + r, cy + r - 1],
                            [cx - r, cy + r - 1]]);
        } else if (type == TILE_PURPLE) {
            // 6-point star approximated by two interleaved triangles
            dc.fillPolygon([[cx,     cy - r],
                            [cx + r, cy + r/2],
                            [cx - r, cy + r/2]]);
            dc.fillPolygon([[cx,     cy + r],
                            [cx + r, cy - r/2],
                            [cx - r, cy - r/2]]);
        }

        // Small white "highlight" dot for shine — purely cosmetic.
        if (r >= 5) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx - r/3, cy - r/3, (r/5 < 1) ? 1 : r/5);
        }

        if (selected) {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            var s = size / 2 - 1;
            dc.drawRoundedRectangle(cx - s, cy - s, s * 2, s * 2, 4);
            dc.drawRoundedRectangle(cx - s + 1, cy - s + 1, s * 2 - 2, s * 2 - 2, 3);
        }
    }

    // Draws the gem with a bright white glow ring around it — used
    // during the match-flash animation so the player can see which
    // gems are about to be cleared before they disappear.
    static function drawFlash(dc, type, cx, cy, size) {
        if (type == TILE_EMPTY) { return; }
        var r = (size * 44) / 100;
        if (r < 4) { r = 4; }
        // White glow halo slightly larger than the gem
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        // Normal gem drawn on top
        draw(dc, type, cx, cy, size, false);
    }
}
