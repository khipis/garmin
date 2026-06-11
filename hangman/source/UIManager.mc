// ═══════════════════════════════════════════════════════════════
// UIManager.mc — Stateless drawing helpers.
//
// Three responsibilities:
//   • drawMenu     — title, category/difficulty selectors, Start
//   • drawGame     — gallows + masked word + on-screen keyboard
//   • drawOverlay  — win / lose screens
//
// All drawing is anchored relative to the supplied (w, h) so the
// game adapts to round and square screens of any size. The keyboard
// builds a fresh layout each call so HangmanRenderer + GameController
// stay completely UI-free.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.WatchUi;

// Theme — soft cream "notebook paper" palette
const COL_PAPER    = 0xF4E8D8;
const COL_INK      = 0x222222;
const COL_INK_DIM  = 0x666666;
const COL_HIT      = 0x2A8A3E;   // green — correct letter
const COL_MISS     = 0xC83A3A;   // red   — wrong letter
const COL_SELECT   = 0x1F6FEB;   // blue  — cursor highlight

// Keyboard cell geometry computed by layoutKeyboard()
class KbLayout {
    var x0;       // left edge of grid
    var y0;       // top edge of grid
    var cellW;
    var cellH;
    var cols;
    var rows;
    function initialize() {
        x0 = 0; y0 = 0; cellW = 0; cellH = 0; cols = KB_COLS; rows = KB_ROWS;
    }
    function rectFor(idx) {
        var r = idx / cols;
        var c = idx % cols;
        return [x0 + c * cellW, y0 + r * cellH, cellW, cellH];
    }
    // VERY forgiving hit-test: any tap anywhere on the screen snaps
    // to the nearest keyboard cell. Tapping on the gallows, the
    // masked word, or the bezel is treated as "I meant the closest
    // letter to where my finger landed". This is what makes the
    // touch experience feel right on small round watches where the
    // keyboard cells are only a few pixels wide.
    //
    // The previous version rejected taps outside a 1/3-cell slack
    // around the keyboard, which on a 240px round watch meant nearly
    // half the screen was a dead zone — players reported tapping and
    // nothing happening at all. Removing the bounds check fixes that
    // entirely: every tap now resolves to a letter.
    function indexAt(px, py) {
        if (cellW <= 0 || cellH <= 0) { return -1; }
        var c = (px - x0) / cellW;
        var r = (py - y0) / cellH;
        if (c < 0)       { c = 0;        }
        if (c >= cols)   { c = cols - 1; }
        if (r < 0)       { r = 0;        }
        if (r >= rows)   { r = rows - 1; }
        var idx = r * cols + c;
        if (idx < 0)     { idx = 0;      }
        if (idx >= 26)   { idx = 25;     }
        return idx;
    }
}

class UIManager {
    // ── MENU ────────────────────────────────────────────────────────
    // Chess-style three-row menu — dark background, full-width rounded
    // rows with the focussed row tinted brighter and a small arrow on
    // the left edge. "by Bitochi" attribution sits just below the
    // title. Rows: CATEGORY, DIFFICULTY, START.
    static function drawMenu(dc, ctrl, w, h) {
        var cx = w / 2;
        dc.setColor(0x080808, 0x080808); dc.clear();
        if (w == h) {
            dc.setColor(0x101418, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, h / 2, w / 2 - 1);
        }

        // Title + Bitochi attribution
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 8 / 100, Graphics.FONT_SMALL,
                    "HANGMAN", Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 20 / 100, Graphics.FONT_XTINY,
                    "by Bitochi", Graphics.TEXT_JUSTIFY_CENTER);

        // Four rows centred between title and footer. Rows are ~18%
        // shorter than the original 3-row layout so the extra
        // LEADERBOARD row fits without overlapping on small round
        // watches, and the gap shrinks too when vertical space is tight.
        var rowH = (h * 11) / 100; if (rowH < 20) { rowH = 20; } if (rowH > 30) { rowH = 30; }
        var rowW = (w * 78) / 100; if (rowW < 140) { rowW = 140; }
        var rowX = (w - rowW) / 2;
        var gap  = (h * 15) / 1000; if (gap < 3) { gap = 3; }
        var nRows = MENU_ITEMS;
        var total = nRows * rowH + (nRows - 1) * gap;
        // Keep the stack inside the round-safe band: clamp the top so the
        // last row never spills past the footer hint.
        var rowY0 = (h - total) / 2 + (h * 3) / 100;
        var topMin = h * 26 / 100;
        if (rowY0 < topMin) { rowY0 = topMin; }

        var labels = [
            "Category: " + WordList.categoryName(ctrl.category),
            "Diff: "     + WordList.difficultyName(ctrl.difficulty),
            "START"
        ];
        var selRow = ctrl.menuCursor;
        for (var i = 0; i < nRows; i++) {
            var ry  = rowY0 + i * (rowH + gap);
            var sel = (i == selRow);

            if (i == MENU_LB) {
                LbBadge.drawRow(dc, rowX, ry, rowW, rowH, sel);
                continue;
            }

            var isStart = (i == MENU_START);
            dc.setColor(sel ? (isStart ? 0x1A4400 : 0x1A3A6A) : 0x111820,
                        Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(rowX, ry, rowW, rowH, 5);
            dc.setColor(sel ? (isStart ? 0x44BB22 : 0x55AAFF) : 0x2A3A4A,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawRoundedRectangle(rowX, ry, rowW, rowH, 5);

            if (sel) {
                dc.setColor(isStart ? 0x44BB22 : 0x55AAFF,
                            Graphics.COLOR_TRANSPARENT);
                var ay = ry + rowH / 2;
                dc.fillPolygon([[rowX + 5, ay - 4],
                                [rowX + 5, ay + 4],
                                [rowX + 11, ay]]);
            }
            dc.setColor(sel ? (isStart ? 0xAAFF66 : 0xCCEEFF) : 0x778899,
                        Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, ry + (rowH - 14) / 2, Graphics.FONT_XTINY,
                        labels[i], Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Footer hint
        dc.setColor(0x778899, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h - 14, Graphics.FONT_XTINY,
                    "UP=row  DN=letter  tap=guess", Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Decorative notebook horizontal lines
    hidden static function _drawNotebookLines(dc, w, h) {
        dc.setColor(0xE3D6C0, Graphics.COLOR_TRANSPARENT);
        var step = h / 14;
        if (step < 6) { step = 6; }
        for (var y = step; y < h; y += step) {
            dc.drawLine(0, y, w, y);
        }
        // Red margin
        dc.setColor(0xDC6E6E, Graphics.COLOR_TRANSPARENT);
        var margin = w / 10;
        dc.drawLine(margin, 0, margin, h);
    }

    // ── GAME ────────────────────────────────────────────────────────
    // Returns the keyboard layout used so InputHandler/tap routing can
    // look up letter indices for touch input.
    //
    // The entire play layout is shrunk an EXTRA ~10% versus the
    // previous (-20%) version so every element — including the
    // corner letters of the keyboard — stays inside the visible
    // round area on small watches like fenix8solar51mm. Edges are
    // pulled inward symmetrically so the composition still looks
    // centred.
    static function drawGame(dc, ctrl, w, h) {
        dc.setColor(COL_PAPER, COL_PAPER);
        dc.clear();
        _drawNotebookLines(dc, w, h);

        var lives = ctrl.attemptsLeft();
        // Top HUD: lives counter (nudged down so it clears the round bezel).
        dc.setColor(COL_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 7 / 100, Graphics.FONT_XTINY,
                    "Lives " + lives.toString(),
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Gallows — compact, upper-left quadrant, pulled inward 10%.
        var gx = w * 12 / 100;
        var gy = h * 13 / 100;
        var gw = w * 31 / 100;
        var gh = h * 27 / 100;
        HangmanRenderer.draw(dc, gx, gy, gw, gh, ctrl.misses);

        // Category badge — upper-right, pulled inward.
        dc.setColor(COL_INK_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w * 88 / 100, h * 17 / 100, Graphics.FONT_XTINY,
                    WordList.categoryName(ctrl.category),
                    Graphics.TEXT_JUSTIFY_RIGHT);

        // Masked word — center band (above the keyboard)
        var maskedY = h * 45 / 100;
        var maskedFont = (ctrl.word.length() > 9)
            ? Graphics.FONT_TINY : Graphics.FONT_SMALL;
        var mfh = dc.getFontHeight(maskedFont);
        dc.setColor(COL_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, maskedY - mfh / 2, maskedFont,
                    ctrl.maskedWord(), Graphics.TEXT_JUSTIFY_CENTER);

        // Keyboard — middle/lower band, fully inside round-safe zone
        var kb = layoutKeyboard(w, h);
        _drawKeyboard(dc, ctrl, kb);

        return kb;
    }

    // Keyboard rectangle — sized to live entirely inside the visible
    // round-watch area. Horizontal inset is 17% per side and the
    // band height is 30% (top at h*53%, bottom at h*83%), which is
    // ~10% smaller in each dimension than the previous version.
    //
    // Public so MainView can build a fresh layout on demand for
    // touch-routing in the rare case a tap arrives before the first
    // GS_PLAY frame has been drawn (`_kb` cache is still null).
    static function layoutKeyboard(w, h) {
        var kb = new KbLayout();
        var marginX = w * 17 / 100;
        var bandY   = h * 53 / 100;
        var bandH   = h * 30 / 100;       // bottom ends at ~83% of h
        kb.x0   = marginX;
        kb.y0   = bandY;
        kb.cellW = (w - marginX * 2) / KB_COLS;
        kb.cellH = bandH / KB_ROWS;
        return kb;
    }

    hidden static function _drawKeyboard(dc, ctrl, kb) {
        dc.setPenWidth(1);
        for (var i = 0; i < 26; i++) {
            var rect = kb.rectFor(i);
            var x = rect[0]; var y = rect[1];
            var cw = rect[2]; var ch = rect[3];
            var ch_str = GameController._letterChar(i);
            var col;
            if (ctrl.isGuessed(i)) {
                col = ctrl.isCorrect(i) ? COL_HIT : COL_MISS;
            } else {
                col = COL_INK;
            }
            // Cursor highlight ring around current letter
            if (i == ctrl.cursor) {
                dc.setColor(COL_SELECT, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawRoundedRectangle(x + 1, y + 1, cw - 2, ch - 2, 3);
                dc.setPenWidth(1);
            }
            // Strike-through for guessed letters
            if (ctrl.isGuessed(i)) {
                dc.setColor(0xE3D6C0, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + 2, y + 2, cw - 4, ch - 4);
            }
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            var fh = dc.getFontHeight(Graphics.FONT_XTINY);
            dc.drawText(x + cw / 2, y + ch / 2 - fh / 2,
                        Graphics.FONT_XTINY, ch_str,
                        Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // ── OVERLAYS ────────────────────────────────────────────────────
    static function drawOverlay(dc, ctrl, w, h) {
        var isWin = (ctrl.state == GS_WIN);
        // Dim background
        dc.setColor(isWin ? 0xC8EFD1 : 0xF6D4D4, COL_PAPER);
        dc.clear();
        _drawNotebookLines(dc, w, h);

        var titleCol = isWin ? COL_HIT : COL_MISS;
        var title    = isWin ? "YOU WIN!" : "HANGED!";

        dc.setColor(titleCol, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 20 / 100, Graphics.FONT_MEDIUM,
                    title, Graphics.TEXT_JUSTIFY_CENTER);

        // Show full word
        dc.setColor(COL_INK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 40 / 100, Graphics.FONT_XTINY,
                    "Word:", Graphics.TEXT_JUSTIFY_CENTER);
        var wordFont = (ctrl.word.length() > 9)
            ? Graphics.FONT_SMALL : Graphics.FONT_MEDIUM;
        dc.drawText(w / 2, h * 48 / 100, wordFont, ctrl.word,
                    Graphics.TEXT_JUSTIFY_CENTER);

        // Mini gallows (always final pose on lose, empty on win) —
        // shrunk and lifted up so it doesn't clip on round watches.
        var stage = isWin ? 0 : MAX_MISSES;
        HangmanRenderer.draw(dc,
                             w / 2 - w * 14 / 100, h * 62 / 100,
                             w * 28 / 100,        h * 20 / 100,
                             stage);

        dc.setColor(COL_INK_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 88 / 100, Graphics.FONT_XTINY,
                    "Press any key", Graphics.TEXT_JUSTIFY_CENTER);
    }
}
