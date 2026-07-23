// ═══════════════════════════════════════════════════════════════
// RenderSystem.mc — Pure drawing helpers for the game world.
//
// Stateless: reads GameController + layout numbers cached by MainView.
// Flat pixel-art shapes only — no per-frame allocation, no blocking
// animation. The world visibly evolves with the score (day → sunset →
// dusk → starry night) and every chop throws chips + a floating "+N",
// so runs feel alive without any of it ever gating input.
// ═══════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;

class RenderSystem {

    // ── Sky / parallax backdrop, driven by the day phase ─────────────
    static function drawBackground(dc, sw, sh, groundY, ctrl) {
        var ph    = ctrl.dayPhase();
        var frame = ctrl.frame;

        // Three-band sky gradient per phase.
        var top; var mid; var low;
        if (ph == 0)      { top = 0x2E6FB0; mid = 0x4E9AD0; low = 0x9AD0EC; }  // day
        else if (ph == 1) { top = 0x274066; mid = 0xB0603A; low = 0xF0A85A; }  // sunset
        else if (ph == 2) { top = 0x0E1730; mid = 0x38265A; low = 0x7A466E; }  // dusk
        else              { top = 0x05080E; mid = 0x0A1222; low = 0x142038; }  // night

        var b1 = groundY * 38 / 100;
        var b2 = groundY * 70 / 100;
        dc.setColor(top, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, 0, sw, b1);
        dc.setColor(mid, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, b1, sw, b2 - b1);
        dc.setColor(low, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(0, b2, sw, groundY - b2 + 2);

        // Celestial body: sun (day/sunset) or moon + stars (dusk/night).
        if (ph <= 1) {
            var sunY = (ph == 0) ? groundY * 24 / 100 : groundY * 60 / 100;
            var sunX = sw * 22 / 100;
            dc.setColor((ph == 0) ? 0xFFE24A : 0xFFC94A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sunX, sunY, 13);
            dc.setColor((ph == 0) ? 0xFFF0A0 : 0xFFE39A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sunX, sunY, 8);
        } else {
            // Stars — deterministic positions, gentle twinkle from the frame.
            dc.setColor(0xCFE0F0, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < 14; s++) {
                var stx = (s * 53 + 11) % sw;
                var sty = (s * 37 + 7) % (groundY * 62 / 100);
                if (((s + frame / 8) % 5) < 4) { dc.fillRectangle(stx, sty, 1, 1); }
            }
            // Moon with a couple of craters.
            var mX = sw * 76 / 100; var mY = groundY * 24 / 100;
            dc.setColor(0xE8ECF4, Graphics.COLOR_TRANSPARENT); dc.fillCircle(mX, mY, 11);
            dc.setColor(0xC4CCDC, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(mX - 3, mY - 2, 2); dc.fillCircle(mX + 4, mY + 3, 2); dc.fillCircle(mX + 1, mY - 5, 1);
        }

        // Rolling hills (two layers) — gentle mounds peeking over the horizon.
        var hillFar  = (ph <= 1) ? 0x2E5A2A : ((ph == 2) ? 0x24304A : 0x101A2A);
        var hillNear = (ph <= 1) ? 0x24501F : ((ph == 2) ? 0x1A2740 : 0x0C1622);
        var r1 = sw * 24 / 100;
        var r2 = sw * 28 / 100;
        dc.setColor(hillFar, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sw * 20 / 100, groundY + r1 * 6 / 10, r1);
        dc.fillCircle(sw * 82 / 100, groundY + r1 * 7 / 10, r1);
        dc.setColor(hillNear, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sw * 55 / 100, groundY + r2 * 6 / 10, r2);

        // Pine silhouettes along the horizon (skip the centre where the trunk is).
        var pineC = (ph <= 1) ? 0x18401A : ((ph == 2) ? 0x141E30 : 0x0A1220);
        var pineXs = [sw * 8 / 100, sw * 24 / 100, sw * 74 / 100, sw * 90 / 100];
        for (var p = 0; p < pineXs.size(); p++) {
            _pine(dc, pineXs[p], groundY, 9 + (p * 3) % 6, pineC);
        }

        // Ground.
        var gTop; var gBody;
        if (ph <= 1)      { gTop = 0x5A9A34; gBody = 0x2E6A1E; }
        else if (ph == 2) { gTop = 0x2E4A28; gBody = 0x1C3418; }
        else              { gTop = 0x1E3A20; gBody = 0x142614; }
        dc.setColor(gBody, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, sw, sh - groundY);
        dc.setColor(gTop, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, groundY, sw, 3);
        // Grass tufts.
        dc.setColor(gTop, Graphics.COLOR_TRANSPARENT);
        for (var gx = 6; gx < sw; gx += 22) {
            var jy = groundY + 4 + ((gx / 22) % 2) * 2;
            dc.drawLine(gx, jy, gx, jy - 4);
            dc.drawLine(gx + 2, jy, gx + 2, jy - 3);
        }
    }

    hidden static function _pine(dc, x, baseY, sz, col) {
        dc.setColor(0x3A2A16, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x - 1, baseY - 2, 2, 4);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, baseY - sz * 3],       [x - sz, baseY],       [x + sz, baseY]]);
        dc.fillPolygon([[x, baseY - sz * 4],       [x - sz * 3 / 4, baseY - sz], [x + sz * 3 / 4, baseY - sz]]);
    }

    // ── Trunk + stack of visible segments (branch or bare bark) ─────
    static function drawTree(dc, ctrl, cx, trunkW, chopLineY, segH, shx) {
        var half = trunkW / 2;
        var topY = chopLineY - segH * TG_VISIBLE;
        var lx   = cx - half + shx;

        // Body with a lit left edge and a shadowed right edge for roundness.
        dc.setColor(0x7A4A24, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx, topY, trunkW, chopLineY - topY);
        dc.setColor(0x9A6636, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx, topY, trunkW * 26 / 100, chopLineY - topY);
        dc.setColor(0x5A3418, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx + trunkW * 78 / 100, topY, trunkW * 22 / 100, chopLineY - topY);

        // Bark grain — short vertical ticks staggered down the trunk.
        dc.setColor(0x6B421F, Graphics.COLOR_TRANSPARENT);
        for (var by = topY + 4; by < chopLineY; by += 11) {
            dc.drawLine(cx - half / 3 + shx, by, cx - half / 3 + shx, by + 6);
            dc.drawLine(cx + half / 3 + shx, by + 5, cx + half / 3 + shx, by + 10);
        }

        // Cosmetic slide-down tween for the window that just shifted.
        var offsetY = 0;
        if (ctrl.scrollT > 0) { offsetY = (segH * ctrl.scrollT) / SCROLL_FRAMES; }

        for (var i = 0; i < TG_VISIBLE; i++) {
            var segBottom = chopLineY - i * segH - offsetY;
            var segTop    = segBottom - segH;
            var segType   = ctrl.tree.seg[i];
            if (segType == SEG_NONE) { continue; }
            _drawBranch(dc, cx, half, segTop, segBottom, segType, shx);
            // Danger telegraph: pulse a warning ring on the LIVE branch
            // (row 0, the one at the chop line you must dodge right now).
            if (i == 0 && (ctrl.frame % 8 < 5)) {
                var dir  = (segType == SEG_LEFT) ? -1 : 1;
                var midY = (segTop + segBottom) / 2;
                var tipX = cx + shx + dir * (half + 16 + half);
                dc.setColor(0xFF5533, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawCircle(tipX, midY - (segBottom - segTop) * 55 / 200, (segBottom - segTop) * 62 / 100 + 3);
                dc.setPenWidth(1);
            }
        }

        // Cut rings at the very top (the fresh saw-cut).
        dc.setColor(0xB98A54, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(lx + 1, topY, trunkW - 2, 3);
        dc.setColor(0x8A5A2E, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx + shx - half / 2, topY + 1, cx + shx + half / 2, topY + 1);

        // Bright chop-line marker — makes the "danger row" unmistakable.
        dc.setColor(0xFFF2C0, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - half - 10 + shx, chopLineY, cx + half + 10 + shx, chopLineY);
        dc.setColor(0xFFAA33, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx - half - 6 + shx, chopLineY + 1, cx + half + 6 + shx, chopLineY + 1);
    }

    hidden static function _drawBranch(dc, cx, half, segTop, segBottom, segType, shx) {
        var midY = (segTop + segBottom) / 2;
        var len  = half + 16;
        var dir  = (segType == SEG_LEFT) ? -1 : 1;
        var bh   = (segBottom - segTop) * 55 / 100;

        var trunkEdgeX = cx + shx + dir * half;
        var tipX       = cx + shx + dir * (half + len);
        var stubX      = (dir < 0) ? tipX : trunkEdgeX;

        // Branch limb with a lit top edge.
        dc.setColor(0x8A5A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stubX, midY - bh / 2, len, bh);
        dc.setColor(0xB07A3E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(stubX, midY - bh / 2, len, bh * 40 / 100);
        dc.setColor(0x5A3418, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(stubX, midY - bh / 2, len, bh);

        // Layered leaf clump at the tip — clearly a hazard.
        var lr = bh * 62 / 100; if (lr < 5) { lr = 5; }
        dc.setColor(0x1F5A1F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX, midY - bh / 2, lr);
        dc.fillCircle(tipX + dir * (bh / 3), midY + bh / 3, lr * 80 / 100);
        dc.setColor(0x3FA13F, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX - dir * 2, midY - bh / 2 - 1, lr * 72 / 100);
        dc.fillCircle(tipX + dir * (bh / 3), midY + bh / 4, lr * 60 / 100);
        dc.setColor(0x66C866, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(tipX - dir * 3, midY - bh / 2 - 3, lr * 34 / 100);
    }

    // ── Lumberjack — plaid shirt, beanie, beard, swinging axe ────────
    static function drawPlayer(dc, ctrl, cx, trunkW, chopLineY, shx) {
        var side  = ctrl.player.side;
        var half  = trunkW / 2;
        var swinging = (ctrl.player.swingT > SWING_FRAMES / 2);
        var dead  = (ctrl.player.shakeT > 0);
        // Lean into the trunk on the swing for a bit of body english.
        var lean  = swinging ? -side * 3 : 0;
        var px    = cx + shx + side * (half + 15) + lean;
        var feetY = chopLineY + 4;

        // Boots.
        dc.setColor(0x2A1E12, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 7, feetY - 7, 6, 7);
        dc.fillRectangle(px + 1, feetY - 7, 6, 7);
        dc.setColor(0x503A22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 7, feetY - 2, 6, 2);
        dc.fillRectangle(px + 1, feetY - 2, 6, 2);

        // Plaid shirt (red body + darker checks).
        dc.setColor(0xC0362E, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(px - 9, feetY - 25, 18, 19, 3);
        dc.setColor(0x8A241E, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(px - 3, feetY - 25, px - 3, feetY - 6);
        dc.drawLine(px + 3, feetY - 25, px + 3, feetY - 6);
        dc.drawLine(px - 9, feetY - 18, px + 9, feetY - 18);
        dc.drawLine(px - 9, feetY - 12, px + 9, feetY - 12);

        // Head + beard + beanie.
        dc.setColor(0xE8B888, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(px, feetY - 31, 7);
        dc.setColor(0x7A4A22, Graphics.COLOR_TRANSPARENT);      // beard
        dc.fillRectangle(px - 6, feetY - 30, 12, 5);
        dc.setColor(0x2E6A44, Graphics.COLOR_TRANSPARENT);      // beanie
        dc.fillRectangle(px - 8, feetY - 39, 16, 6);
        dc.fillRectangle(px - 6, feetY - 42, 12, 4);
        dc.setColor(0x9EE0B4, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(px - 2, feetY - 45, 4, 4);            // pom-pom
        // Eyes (X when dead).
        if (dead) {
            dc.setColor(0x201008, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(px - 4, feetY - 34, px - 1, feetY - 31);
            dc.drawLine(px - 1, feetY - 34, px - 4, feetY - 31);
            dc.drawLine(px + 1, feetY - 34, px + 4, feetY - 31);
            dc.drawLine(px + 4, feetY - 34, px + 1, feetY - 31);
        } else {
            dc.setColor(0x201008, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(px - 2, feetY - 32, 1); dc.fillCircle(px + 2, feetY - 32, 1);
        }

        // Axe — wooden handle + metal head, raised/lowered by the swing. The
        // head colour reflects the equipped cosmetic tier (Oak steel / bright
        // Iron / Golden) — purely visual, matches the escalating chop FX.
        var tier = ctrl.axeTier();
        var headCol; var edgeCol;
        if      (tier >= 2) { headCol = 0xFFC020; edgeCol = 0xFFF0A0; }  // Golden
        else if (tier >= 1) { headCol = 0xD8DCE8; edgeCol = 0xFFFFFF; }  // Iron
        else                { headCol = 0xC8C8D0; edgeCol = 0xEDEDF4; }  // Oak
        var axeX = px - side * 7;
        var headY = swinging ? feetY - 19 : feetY - 31;
        dc.setColor(0x8A5A2E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(axeX - side * 2, headY, 3, 16);
        var hx = axeX - side * 9;
        dc.setColor(headCol, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[hx, headY - 3], [hx + side * 10, headY - 5],
                        [hx + side * 10, headY + 6], [hx, headY + 4]]);
        dc.setColor(edgeCol, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(hx + side * 10, headY - 5, hx + side * 10, headY + 6);
    }

    // ── Chop effects: extra wood chips + floating "+N" popup ─────────
    static function drawEffects(dc, ctrl, cx, trunkW, chopLineY, shx) {
        var half = trunkW / 2;
        var side = ctrl.player.side;
        var tier = ctrl.axeTier();   // 0=Oak, 1=Iron, 2=Golden (visual only)

        // Wood-chip burst on the swing (a few fixed offsets flying out).
        if (ctrl.player.swingT > 0) {
            var spread = SWING_FRAMES - ctrl.player.swingT + 1;
            var ex = cx + shx + side * half;

            // Impact flash at the chop point — bigger/brighter with the axe tier.
            // A short-lived bloom over the very first swing frames.
            if (tier >= 1 && ctrl.player.swingT > SWING_FRAMES / 2) {
                var flR = 5 + tier * 4;
                dc.setColor((tier >= 2) ? 0xFFF0A0 : 0xFFE0A0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex, chopLineY - 2, flR);
                dc.setColor((tier >= 2) ? 0xFFFFFF : 0xFFF2D0, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(ex, chopLineY - 2, flR / 2);
            }

            dc.setColor(0xE0C070, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ex - side * 2, chopLineY - 6 - spread * 2, 3, 3);
            dc.fillRectangle(ex + side * 5, chopLineY - 2 - spread * 3, 3, 3);
            dc.fillRectangle(ex + side * 2, chopLineY + 3 - spread, 2, 2);
            dc.setColor(0xB88A40, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(ex + side * 8, chopLineY - 4 - spread * 2, 2, 2);
            dc.fillRectangle(ex - side * 6, chopLineY - spread, 2, 2);
            // Extra chips for higher tiers — more debris, further out.
            if (tier >= 1) {
                dc.setColor(0xE0C070, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - side * 9, chopLineY - 8 - spread * 2, 3, 3);
                dc.fillRectangle(ex + side * 11, chopLineY + 1 - spread * 2, 2, 2);
            }
            if (tier >= 2) {
                dc.setColor(0xFFE58A, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ex - side * 4, chopLineY - 12 - spread * 3, 3, 3);
                dc.fillRectangle(ex + side * 14, chopLineY - 6 - spread * 3, 3, 3);
            }

            // Expanding impact ring — the Golden Axe's signature big hit.
            if (tier >= 2) {
                var rr = spread * 5;
                dc.setColor(0xFFD24A, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(2);
                dc.drawCircle(ex, chopLineY - 2, rr);
                dc.setPenWidth(1);
            }
        }

        // Floating "+N" — rises and fades from the chop point, coloured by combo.
        if (ctrl.popT > 0 && ctrl.popPts > 0) {
            var rise = (POP_FRAMES - ctrl.popT) * 2;
            var py   = chopLineY - 14 - rise;
            var pxp  = cx + shx + ctrl.popSide * (half + 20);
            var combo = ctrl.scoreSys.combo;
            var col;
            if      (combo >= 5) { col = 0xFF7A2A; }
            else if (combo >= 2) { col = 0x66DDFF; }
            else                 { col = 0xEAF2F0; }
            dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pxp + 1, py + 1, Graphics.FONT_XTINY, "+" + ctrl.popPts.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawText(pxp, py, Graphics.FONT_XTINY, "+" + ctrl.popPts.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }
}
