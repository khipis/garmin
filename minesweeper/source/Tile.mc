// ═══════════════════════════════════════════════════════════════
// Tile.mc — Constants + render helpers for a single board cell.
//
// State lives in three flat ByteArrays inside GridManager:
//   mines[i]   1 if cell holds a mine, 0 otherwise
//   state[i]   bit0 revealed, bit1 flagged
//   numbers[i] 0..8 adjacent-mine count for non-mine cells
//
// We keep cells primitive (bytes) so even a 100×100 board fits in a
// few tens of KB and renders fast enough for a per-tick refresh.
//
// `draw` accepts a `withText` flag: when the cell is too small to
// render legible digits (set by MainView's MIN_TEXT_PX threshold) we
// fall back to coloured dots, which scale gracefully down to ~4 px
// cells.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

const ST_REVEALED = 1;
const ST_FLAGGED  = 2;

class Tile {
    static var DIGIT_COLORS = [
        0x000000,
        0x4488FF,
        0x44CC44,
        0xFF4444,
        0x2244AA,
        0xAA4422,
        0x22AAAA,
        0x000000,
        0x666666
    ];

    static function draw(dc, x, y, size, state, number, mine,
                         cursor, ended, withText) {
        var revealed = (state & ST_REVEALED) != 0;
        var flagged  = (state & ST_FLAGGED)  != 0;

        if (revealed) {
            if (mine) {
                dc.setColor(ended ? 0xCC2222 : 0x333344, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, size, size);
            } else {
                dc.setColor(0x202028, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, size, size);
            }
            if (size >= 8) {
                dc.setColor(0x101018, Graphics.COLOR_TRANSPARENT);
                dc.drawRectangle(x, y, size, size);
            }
        } else {
            dc.setColor(0x606078, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, size, size);
            if (size >= 6) {
                dc.setColor(0x8888A0, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y, size, 1);
                dc.fillRectangle(x, y, 1, size);
                dc.setColor(0x303040, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, y + size - 1, size, 1);
                dc.fillRectangle(x + size - 1, y, 1, size);
            }
        }

        if (revealed) {
            if (mine) {
                _drawBomb(dc, x, y, size);
            } else if (number > 0) {
                if (withText) {
                    dc.setColor(DIGIT_COLORS[number], Graphics.COLOR_TRANSPARENT);
                    dc.drawText(x + size / 2, y - 1, Graphics.FONT_XTINY,
                                number.format("%d"),
                                Graphics.TEXT_JUSTIFY_CENTER);
                } else {
                    _drawDot(dc, x, y, size, number);
                }
            }
        } else if (flagged) {
            if (size >= 10) {
                _drawFlag(dc, x, y, size);
            } else {
                dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
                var r = size / 3; if (r < 1) { r = 1; }
                dc.fillCircle(x + size / 2, y + size / 2, r);
            }
        }

        if (cursor) {
            dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x, y, size, size);
            if (size >= 8) {
                dc.drawRectangle(x + 1, y + 1, size - 2, size - 2);
            }
        }
    }

    // Small coloured dot at cell centre — used when the cell is too
    // tiny to fit a legible digit. The colour matches the digit's
    // palette so the gameplay reading is still consistent.
    hidden static function _drawDot(dc, x, y, size, number) {
        var cx = x + size / 2;
        var cy = y + size / 2;
        var r = size / 4;
        if (r < 1) { r = 1; }
        dc.setColor(DIGIT_COLORS[number], Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
    }

    hidden static function _drawFlag(dc, x, y, size) {
        var cx = x + size / 2;
        var cy = y + size / 2;
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - 1, cy - size / 3, 2, size * 2 / 3);
        dc.setColor(0xFF2222, Graphics.COLOR_TRANSPARENT);
        var tw = size / 2;
        var th = size / 3;
        dc.fillPolygon([[cx,        cy - size / 3],
                        [cx,        cy - size / 3 + th],
                        [cx - tw,   cy - size / 3 + th / 2]]);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - tw / 2, cy + size / 3 - 1,
                         tw, 2);
    }

    hidden static function _drawBomb(dc, x, y, size) {
        var cx = x + size / 2;
        var cy = y + size / 2;
        var r  = size / 3; if (r < 2) { r = 2; }
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        if (size >= 12) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx - r / 2, cy - r / 2, 1, 1);
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(cx,         cy - r - 2, cx,         cy - r);
            dc.drawLine(cx,         cy + r,     cx,         cy + r + 2);
            dc.drawLine(cx - r - 2, cy,         cx - r,     cy);
            dc.drawLine(cx + r,     cy,         cx + r + 2, cy);
        }
    }
}
