// ═══════════════════════════════════════════════════════════════
// Tile.mc — Tile constants + stateless visual helpers.
//
// A tile's "value" in the grid is stored as the exponent `e` such
// that the displayed number = 1 << e. 0 means an empty cell.
//   e = 1  →  2
//   e = 2  →  4
//   ...
//   e = 11 → 2048 (win threshold)
//
// Storing exponents instead of full integers keeps merge logic
// trivial: two tiles merge ⇔ they have the same `e`, and the
// result is simply `e + 1`. This avoids any int-math in the hot
// path and makes the int values stay within a single byte.
//
// Each exponent has a flat colour matching the classic 2048
// palette, and a foreground (text) colour for legibility.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

const GRID_SIZE  = 4;          // 4 × 4 board
const GRID_CELLS = 16;
const WIN_EXP    = 11;         // 2 ^ 11 = 2048

class Tile {
    // Background colours indexed by exponent 0..16.
    // index 0 = empty cell.
    static var _BG = [
        0xCDC1B4,   // 0  empty
        0xEEE4DA,   // 1  2
        0xEDE0C8,   // 2  4
        0xF2B179,   // 3  8
        0xF59563,   // 4  16
        0xF67C5F,   // 5  32
        0xF65E3B,   // 6  64
        0xEDCF72,   // 7  128
        0xEDCC61,   // 8  256
        0xEDC850,   // 9  512
        0xEDC53F,   // 10 1024
        0xEDC22E,   // 11 2048
        0x3C3A32,   // 12 4096
        0x3C3A32,   // 13 8192
        0x3C3A32,   // 14
        0x3C3A32,   // 15
        0x3C3A32    // 16
    ];

    // Foreground colour for the digit text.
    static var _FG = [
        0xBBADA0,   // 0  empty
        0x776E65,   // 1  2
        0x776E65,   // 2  4
        0xF9F6F2,   // 3  8
        0xF9F6F2,   // 4  16
        0xF9F6F2,   // 5  32
        0xF9F6F2,   // 6  64
        0xF9F6F2,   // 7  128
        0xF9F6F2,   // 8  256
        0xF9F6F2,   // 9  512
        0xF9F6F2,   // 10 1024
        0xF9F6F2,   // 11 2048
        0xF9F6F2,   // 12 4096
        0xF9F6F2,   // 13 8192
        0xF9F6F2,   // 14
        0xF9F6F2,   // 15
        0xF9F6F2    // 16
    ];

    // 1 << e, but bounded so we never overflow.
    static function valueOf(e) {
        if (e <= 0) { return 0; }
        if (e > 16) { e = 16; }
        return 1 << e;
    }

    static function bg(e) {
        if (e < 0)  { e = 0; }
        if (e > 16) { e = 16; }
        return _BG[e];
    }

    static function fg(e) {
        if (e < 0)  { e = 0; }
        if (e > 16) { e = 16; }
        return _FG[e];
    }

    // Pick a label font that fits inside a square cell of side `s`
    // for the given exponent. Larger numbers need smaller text.
    static function fontFor(e, s) {
        var digits = 1;
        if (e >= 4)  { digits = 2; }   // 16+
        if (e >= 7)  { digits = 3; }   // 128+
        if (e >= 10) { digits = 4; }   // 1024+
        // Cell-relative thresholds chosen empirically.
        if (s >= 56 && digits <= 2) { return Graphics.FONT_MEDIUM; }
        if (s >= 44 && digits <= 3) { return Graphics.FONT_SMALL;  }
        if (s >= 32)                { return Graphics.FONT_TINY;   }
        return Graphics.FONT_XTINY;
    }

    // Stateless draw — paints background + centred number into the
    // [x, y, s × s] cell rectangle. Caller is responsible for any
    // outer padding. `merged` toggles a brief highlight ring.
    static function draw(dc, x, y, s, e, merged) {
        dc.setColor(bg(e), Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(x, y, s, s, 4);
        if (e <= 0) { return; }
        var label = valueOf(e).toString();
        var font  = fontFor(e, s);
        dc.setColor(fg(e), Graphics.COLOR_TRANSPARENT);
        // Manually centre — text is anchored top-centre, so subtract
        // half of the font's actual rendered height.
        var th = dc.getFontHeight(font);
        dc.drawText(x + s / 2, y + s / 2 - th / 2, font,
                    label, Graphics.TEXT_JUSTIFY_CENTER);
        if (merged) {
            dc.setPenWidth(2);
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(x + 1, y + 1, s - 2, s - 2, 4);
            dc.setPenWidth(1);
        }
    }
}
