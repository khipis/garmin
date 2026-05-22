// ═══════════════════════════════════════════════════════════════
// HangmanRenderer.mc — Stick-figure gallows that grows each miss.
//
// 7 stages mirror the classic schoolroom progression:
//
//   0  empty           — no misses yet
//   1  base + post     — first miss
//   2  + crossbeam     — second
//   3  + rope          — third
//   4  + head          — fourth
//   5  + torso         — fifth
//   6  + arms          — sixth
//   7  + legs (DEAD)   — seventh & final miss
//
// MAX_MISSES is 7. Drawing scales relative to the caller-supplied
// bounding box (x, y, w, h) so the figure fits any watch size.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

const MAX_MISSES = 7;

class HangmanRenderer {
    // Draw stage `s` (0..MAX_MISSES) inside [x, y, w, h]. `dead` flag
    // tints the body red on the final stage.
    static function draw(dc, x, y, w, h, s) {
        // Anchor key points so the geometry is consistent.
        var baseY  = y + h - 2;                  // ground line
        var postX  = x + w / 4;
        var topY   = y + 4;
        var beamEndX = postX + w / 2;
        var ropeLen  = h / 5; if (ropeLen < 7) { ropeLen = 7; }
        var headR    = h / 12; if (headR  < 3) { headR  = 3; }
        var torsoLen = h / 4;  if (torsoLen < 8) { torsoLen = 8; }
        var armLen   = h / 7;  if (armLen   < 5) { armLen = 5; }
        var legLen   = h / 6;  if (legLen   < 6) { legLen = 6; }
        var headCx   = beamEndX;
        var headCy   = topY + ropeLen + headR;

        var ink = (s >= MAX_MISSES) ? 0xFF4466 : 0x000000;
        dc.setPenWidth(2);

        if (s >= 1) {
            // Base + vertical post
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(x + 4, baseY, x + w - 4, baseY);
            dc.drawLine(postX, baseY, postX, topY);
        }
        if (s >= 2) {
            // Crossbeam + diagonal brace
            dc.drawLine(postX, topY, beamEndX, topY);
            dc.drawLine(postX, topY + 8, postX + 8, topY);
        }
        if (s >= 3) {
            // Rope
            dc.drawLine(beamEndX, topY, beamEndX, topY + ropeLen);
        }
        // Body parts use the death tint if stage = MAX
        dc.setColor(ink, Graphics.COLOR_TRANSPARENT);
        if (s >= 4) {
            // Head
            dc.drawCircle(headCx, headCy, headR);
        }
        if (s >= 5) {
            // Torso
            dc.drawLine(headCx, headCy + headR,
                        headCx, headCy + headR + torsoLen);
        }
        if (s >= 6) {
            // Arms
            var armY = headCy + headR + torsoLen / 3;
            dc.drawLine(headCx, armY, headCx - armLen, armY + armLen);
            dc.drawLine(headCx, armY, headCx + armLen, armY + armLen);
        }
        if (s >= 7) {
            // Legs
            var legY = headCy + headR + torsoLen;
            dc.drawLine(headCx, legY, headCx - legLen, legY + legLen);
            dc.drawLine(headCx, legY, headCx + legLen, legY + legLen);
        }
        dc.setPenWidth(1);
    }
}
