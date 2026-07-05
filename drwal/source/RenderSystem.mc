// ═══════════════════════════════════════════════════════════════
// RenderSystem.mc — Pure drawing helpers for the game world (sky,
// trunk, branches, lumberjack). Stateless: reads GameController +
// layout numbers cached by MainView. High-contrast, flat pixel-art
// shapes only — no gradients, no per-frame allocation, no blocking
// animation. The only "animation" is a short cosmetic tween driven
// by countdown fields the controller already owns.
// ═══════════════════════════════════════════════════════════════
using Toybox.Graphics;

class RenderSystem {

    static function drawBackground(dc, sw, sh, groundY) {
        dc.setColor(0x0B1418, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, sw, groundY);
        dc.setColor(0x2A3A1E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, sw, sh - groundY);
        dc.setColor(0x527A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, sw, 3);
    }

    // Trunk + the stack of visible segments (branch or bare bark).
    static function drawTree(dc, ctrl, cx, trunkW, chopLineY, segH, shx) {
        var half = trunkW / 2;
        var topY = chopLineY - segH * TG_VISIBLE;

        dc.setColor(0x8A5A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx - half + shx, topY, trunkW, chopLineY - topY);
        dc.setColor(0x6B421F, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - half / 2 + shx, topY, cx - half / 2 + shx, chopLineY);
        dc.drawLine(cx + shx,            topY, cx + shx,            chopLineY);
        dc.drawLine(cx + half / 2 + shx, topY, cx + half / 2 + shx, chopLineY);

        // Slide-down tween for the window that just shifted — purely
        // cosmetic; the underlying segment data already advanced.
        var offsetY = 0;
        if (ctrl.scrollT > 0) { offsetY = (segH * ctrl.scrollT) / SCROLL_FRAMES; }

        for (var i = 0; i < TG_VISIBLE; i++) {
            var segBottom = chopLineY - i * segH - offsetY;
            var segTop    = segBottom - segH;
            var segType   = ctrl.tree.seg[i];
            if (segType == SEG_NONE) { continue; }
            _drawBranch(dc, cx, half, segTop, segBottom, segType, shx);
        }

        // Bright chop-line marker — makes the "danger row" unmistakable.
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - half - 10 + shx, chopLineY, cx + half + 10 + shx, chopLineY);
    }

    hidden static function _drawBranch(dc, cx, half, segTop, segBottom, segType, shx) {
        var midY = (segTop + segBottom) / 2;
        var len  = half + 16;
        var dir  = (segType == SEG_LEFT) ? -1 : 1;
        var bh   = (segBottom - segTop) * 55 / 100;

        var trunkEdgeX = cx + shx + dir * half;
        var tipX       = cx + shx + dir * (half + len);
        var stubX      = (dir < 0) ? tipX : trunkEdgeX;

        dc.setColor(0xB07A3E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stubX, midY - bh / 2, len, bh);
        dc.setColor(0x6B421F, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(stubX, midY - bh / 2, len, bh);

        // Leaf clump at the tip — unmistakably a hazard against the
        // dark sky / bare bark.
        dc.setColor(0x3FA13F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX, midY - bh / 2, bh * 60 / 100);
        dc.fillCircle(tipX + dir * (bh / 3), midY + bh / 3, bh * 45 / 100);
    }

    // Lumberjack: head + body + axe, snapped instantly to whichever
    // side is current. The "swing" is a single 2-pose flip driven by
    // swingT — no interpolation, no blocking.
    static function drawPlayer(dc, ctrl, cx, trunkW, chopLineY, shx) {
        var side  = ctrl.player.side;
        var half  = trunkW / 2;
        var px    = cx + shx + side * (half + 14);
        var feetY = chopLineY + 4;
        var swinging = (ctrl.player.swingT > SWING_FRAMES / 2);

        dc.setColor(0x2A2A2A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 6, feetY - 8, 5, 8);
        dc.fillRectangle(px + 1, feetY - 8, 5, 8);

        dc.setColor(0xCC3333, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px - 8, feetY - 24, 16, 18, 3);

        dc.setColor(0xE8B888, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, feetY - 30, 7);
        dc.setColor(0x3355AA, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 7, feetY - 36, 14, 6);

        var axeX = px - side * 6;
        var axeY = swinging ? feetY - 20 : feetY - 28;
        dc.setColor(0xCCCCCC, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(axeX - side * 2, axeY, 4, 12);
        dc.setColor(0x999999, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(axeX - side * 8, axeY - 4, 8, 8);

        // Wood-chip particles — a few fixed offsets that fly outward
        // for the first half of the swing, then vanish.
        if (ctrl.player.swingT > 0) {
            var spread = SWING_FRAMES - ctrl.player.swingT + 1;
            dc.setColor(0xD8B060, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(cx + shx + side * half - side * 2, chopLineY - 6 - spread, 3, 3);
            dc.fillRectangle(cx + shx + side * half + side * 4, chopLineY - 2 - spread * 2, 3, 3);
            dc.fillRectangle(cx + shx + side * half + side,     chopLineY + 3 - spread, 2, 2);
        }
    }
}
