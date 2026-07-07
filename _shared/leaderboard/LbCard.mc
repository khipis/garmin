// ═══════════════════════════════════════════════════════════════════════════
// LbCard.mc — Shared "game over / summary" card renderer.
//
// WHY
//   Every game drew its own end-of-run card with HARD-CODED pixel offsets
//   (title at by+6, stat lines every ~16 px, footer at by+bh-14). Those
//   offsets assume small fonts, but font pixel-height scales with the device
//   DPI — on high-resolution watches (e.g. the 416×416 fenix 8) FONT_XTINY is
//   ~28 px tall, so 16-px spacing makes the lines visibly overlap and the card
//   becomes unreadable.
//
// FIX
//   One renderer that measures the real font heights with dc.getFontHeight()
//   and lays the card out from those measurements: the box auto-sizes to its
//   content, every line is vertically centred with guaranteed non-overlapping
//   spacing, and the whole card is centred on screen and clamped so it never
//   spills past the round chords.
//
// USAGE (from a game's game-over draw)
//   GameOverCard.draw(dc, sw, sh,
//       "GAME OVER", 0xFF4466,                    // title + colour
//       [ ["Score " + score, 0xFFFFFF],           // stat lines: [text, colour]
//         [bestLine, bestColor] ],
//       "Tap to retry", 0xAABBCC);                 // footer + colour
//
//   Pass an empty footer ("" or null) to omit it. `lines` may be empty.
// ═══════════════════════════════════════════════════════════════════════════

using Toybox.Graphics;

module GameOverCard {

    // Draw a centred summary card. Returns the card's [x, y, w, h] in case the
    // caller wants to place something relative to it.
    function draw(dc, sw, sh, title, titleColor, lines, footer, accent) {
        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var titleFont = Graphics.FONT_SMALL;
        var lineFont  = Graphics.FONT_XTINY;

        var th = dc.getFontHeight(titleFont);
        var lh = dc.getFontHeight(lineFont);
        var gap = lh / 4; if (gap < 3) { gap = 3; }
        var padY = lh / 2; if (padY < 6) { padY = 6; }

        var n = (lines != null) ? lines.size() : 0;
        var hasFooter = (footer != null && footer.length() > 0);

        // Total content height (top pad, title, gap, stat lines with gaps,
        // extra gap + footer, bottom pad).
        var bh = padY + th;
        if (n > 0) { bh = bh + gap + n * lh + (n - 1) * gap; }
        if (hasFooter) { bh = bh + gap * 2 + lh; }
        bh = bh + padY;

        // Width: comfortably wide for centred text but inside the round chords.
        var bw = sw * 78 / 100;
        if (bw < 150) { bw = 150; }
        if (bw > sw - 8) { bw = sw - 8; }

        // Clamp height to the screen (leave a small vertical margin).
        var maxBh = sh - (sh * 8 / 100);
        if (bh > maxBh) { bh = maxBh; }

        var bx = (sw - bw) / 2;
        var by = (sh - bh) / 2;
        var cx = sw / 2;

        // Card body + double accent border (matches the previous house style).
        dc.setColor(0x060A14, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(bx, by, bw, bh, 10);
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(bx, by, bw, bh, 10);
        dc.drawRoundedRectangle(bx + 1, by + 1, bw - 2, bh - 2, 9);

        // Title (vertically centred at its own band).
        var y = by + padY + th / 2;
        dc.setColor(titleColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y, titleFont, title, VC);

        // Stat lines.
        y = by + padY + th + gap + lh / 2;
        for (var i = 0; i < n; i++) {
            var ln = lines[i];
            dc.setColor(ln[1], Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, lineFont, ln[0], VC);
            y = y + lh + gap;
        }

        // Footer pinned to the bottom band.
        if (hasFooter) {
            var fy = by + bh - padY - lh / 2;
            dc.setColor(0xAABBCC, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, fy, lineFont, footer, VC);
        }

        return [bx, by, bw, bh];
    }
}
