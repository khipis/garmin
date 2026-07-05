// ═══════════════════════════════════════════════════════════════
// Tile.mc — Gem types + drawing.
//
// Tiles are encoded as plain ints (0 = empty, 1..NUM_TILE_TYPES =
// normal gem, TILE_BOMB = power gem). Storing them as ints avoids
// allocating an object per cell — important for performance on
// low-end Garmin watches. This class exposes constants and a
// stateless render helper used by the UI to paint a gem at any
// (cx, cy, size).
//
// Each type has a distinct colour AND distinct geometric shape so
// the game stays playable for colour-blind users. Every gem is now
// drawn as a small layered "jewel" — drop shadow, coloured body and
// a bright highlight facet — instead of a single flat fill.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.System;

const TILE_EMPTY    = 0;
const TILE_RED      = 1;  // filled circle
const TILE_BLUE     = 2;  // filled square (rounded)
const TILE_GREEN    = 3;  // filled diamond (rotated square)
const TILE_YELLOW   = 4;  // filled triangle (apex up)
const TILE_PURPLE   = 5;  // filled five-pointed-ish star (hex approx)
const NUM_TILE_TYPES = 5;

// Power gem — created when 4+ identical gems line up in one match.
// Sits in the grid like a normal tile (falls with gravity) until it
// is cleared (matched, swapped into, or caught in another bomb's
// blast), at which point it detonates a 3×3 area — the heart of the
// game's chain-reaction system. Never spawned randomly.
const TILE_BOMB = 6;

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

        if (type == TILE_BOMB) {
            _drawBomb(dc, cx, cy, r);
        } else {
            var col = COLORS[type];
            // Layered "jewel" look: shadow → body → glossy highlight facet.
            _shape(dc, type, cx + 1, cy + 2, r, 0x000000);
            _shape(dc, type, cx, cy, r, col);
            _shape(dc, type, cx - r / 6, cy - r / 6, (r * 55) / 100, _lighten(col));

            // Small white shine dot for extra sparkle.
            if (r >= 5) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(cx - r/3, cy - r/3, (r/5 < 1) ? 1 : r/5);
            }
        }

        if (selected) {
            dc.setColor(0xFFFF44, Graphics.COLOR_TRANSPARENT);
            var s = size / 2 - 1;
            dc.drawRoundedRectangle(cx - s, cy - s, s * 2, s * 2, 4);
            dc.drawRoundedRectangle(cx - s + 1, cy - s + 1, s * 2 - 2, s * 2 - 2, 3);
        }
    }

    // Draws the base geometric shape for `type` at (cx,cy) with radius `r`
    // in colour `col` — shared by the shadow/body/highlight layers above.
    hidden static function _shape(dc, type, cx, cy, r, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (type == TILE_RED) {
            dc.fillCircle(cx, cy, r);
        } else if (type == TILE_BLUE) {
            dc.fillRoundedRectangle(cx - r, cy - r, r * 2, r * 2, 3);
        } else if (type == TILE_GREEN) {
            dc.fillPolygon([[cx, cy - r],
                            [cx + r, cy],
                            [cx, cy + r],
                            [cx - r, cy]]);
        } else if (type == TILE_YELLOW) {
            dc.fillPolygon([[cx,     cy - r],
                            [cx + r, cy + r - 1],
                            [cx - r, cy + r - 1]]);
        } else if (type == TILE_PURPLE) {
            dc.fillPolygon([[cx,     cy - r],
                            [cx + r, cy + r/2],
                            [cx - r, cy + r/2]]);
            dc.fillPolygon([[cx,     cy + r],
                            [cx + r, cy - r/2],
                            [cx - r, cy - r/2]]);
        }
    }

    // Pulsing "danger orb" bomb gem — dark shell with a hot core that
    // flickers between orange and red so it reads as armed/ticking.
    hidden static function _drawBomb(dc, cx, cy, r) {
        dc.setColor(0x161616, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx + 1, cy + 2, r);
        dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        var pulse = (System.getTimer() / 120) % 2;
        var core  = (pulse == 0) ? 0xFF6600 : 0xFF2200;
        dc.setColor(core, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, (r * 55) / 100);
        dc.setColor(0xFFDD66, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);
        // Spark cross on top for a "fuse lit" read.
        dc.setColor(0xFFEE99, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - r, cy, cx + r, cy);
        dc.drawLine(cx, cy - r, cx, cy + r);
    }

    // Lightens `col` toward white by `pct`-ish amount — used to fake a
    // glossy highlight facet on each gem without needing gradient fills.
    hidden static function _lighten(col) {
        var r = (col >> 16) & 0xFF;
        var g = (col >> 8)  & 0xFF;
        var b =  col        & 0xFF;
        r = (r + ((255 - r) * 45) / 100).toNumber();
        g = (g + ((255 - g) * 45) / 100).toNumber();
        b = (b + ((255 - b) * 45) / 100).toNumber();
        return (r << 16) | (g << 8) | b;
    }

    // Draws the gem with a bright glow ring around it — used during the
    // match-flash animation so the player can see which gems are about to
    // be cleared before they disappear. Bomb blasts flash the same way.
    static function drawFlash(dc, type, cx, cy, size) {
        if (type == TILE_EMPTY) { return; }
        var r = (size * 46) / 100;
        if (r < 4) { r = 4; }
        var glowCol = (type == TILE_BOMB) ? 0xFF6600 : COLORS[type];
        // Outer colour-tinted glow, then a bright white core glow.
        dc.setColor(glowCol, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + 2);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        draw(dc, type, cx, cy, size, false);
    }
}
