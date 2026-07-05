// ═══════════════════════════════════════════════════════════════
// RenderSystem.mc — The game world: casino play background, a brass
// slot cabinet with gradient trim + rivets, glossy reel wells with
// motion streaks + a glass sheen, a glowing payline, the one-armed
// lever, and celebratory win/jackpot FX (pulsing frame + flying
// coins & sparkles). Stateless; reads GameController + layout ints.
// ═══════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Math;
using Toybox.System;

class RenderSystem {

    // ── Play background — deep casino gradient + round-watch vignette ──
    static function drawPlayBackground(dc, sw, sh) {
        GfxUtil.vGradient(dc, 0, 0, sw, sh, 0x2A0813, 0x08040E, 10);
        // faint radial vignette on round watches
        if (sw == sh) {
            dc.setColor(0x05030A, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sw / 2, sh / 2, sw / 2 + 4);
            GfxUtil.vGradient(dc, sw / 6, sh / 8, sw * 4 / 6, sh * 6 / 8, 0x3A0A18, 0x0A0410, 8);
        }
    }

    // ── Brass cabinet frame around the reel window ────────────────────
    static function drawCabinet(dc, sw, sh, cabX, cabY, cabW, cabH) {
        var fx = cabX - 12; var fy = cabY - 12;
        var fw = cabW + 24; var fh = cabH + 24;

        // drop shadow
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(fx + 3, fy + 4, fw, fh, 14);

        // brass frame with a vertical gradient (bright top -> dark bottom)
        GfxUtil.vGradientRounded(dc, fx, fy, fw, fh, 0xF2C94C, 0x6E4E12, 10, 14);
        // inner bevel highlight
        dc.setColor(0xFFE9A0, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(fx + 2, fy + 2, fw - 4, fh - 4, 12);
        dc.setColor(0x5A3E0E, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(fx, fy, fw, fh, 14);

        // corner rivets
        var rv = 3;
        _rivet(dc, fx + 8,        fy + 8,        rv);
        _rivet(dc, fx + fw - 8,   fy + 8,        rv);
        _rivet(dc, fx + 8,        fy + fh - 8,   rv);
        _rivet(dc, fx + fw - 8,   fy + fh - 8,   rv);

        // dark reel-window recess
        dc.setColor(0x07040C, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(cabX - 3, cabY - 3, cabW + 6, cabH + 6, 6);
    }

    static function _rivet(dc, cx, cy, r) {
        dc.setColor(0x8A6508, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r + 1);
        dc.setColor(0xFFE9A0, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r);
        dc.setColor(0x8A6508, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, r - 2 < 1 ? 1 : r - 2);
    }

    // ── Reel columns + payline ────────────────────────────────────────
    static function drawReels(dc, ctrl, cabX, cabY, colW, rowH, gap) {
        for (var i = 0; i < 3; i++) {
            var colX = cabX + i * (colW + gap);
            _drawColumn(dc, ctrl, i, colX, cabY, colW, rowH);
        }
        dc.clearClip();

        // brass dividers between reels
        for (var d = 1; d < 3; d++) {
            var dxp = cabX + d * (colW + gap) - gap;
            GfxUtil.vGradient(dc, dxp, cabY, gap, rowH * 3, 0xF2C94C, 0x6E4E12, 6);
        }

        _drawPayline(dc, cabX, cabY, colW, rowH, gap);
    }

    hidden static function _drawColumn(dc, ctrl, i, colX, cabY, colW, rowH) {
        var reel = ctrl.reels.reels[i];
        var winH = rowH * 3;
        dc.setClip(colX, cabY, colW, winH);

        // reel well: subtle vertical gradient so it looks recessed/curved
        GfxUtil.vGradient(dc, colX, cabY, colW, winH, 0x241A22, 0x0D0910, 8);
        // top & bottom inner shading (cylinder curvature illusion)
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(colX, cabY, colW, rowH / 3);
        dc.fillRectangle(colX, cabY + winH - rowH / 3, colW, rowH / 3);

        var frac = reel.scrollFrac();
        var cx = colX + colW / 2;
        var size = (colW < rowH) ? colW : rowH;
        size = size * 76 / 100;

        // motion streaks while spinning fast — faint vertical blur lines
        if (reel.state == REEL_SPINNING) {
            dc.setColor(0x3A2E38, Graphics.COLOR_TRANSPARENT);
            for (var s = 0; s < 4; s++) {
                var lx = colX + colW * (s + 1) / 5;
                dc.drawLine(lx, cabY + 2, lx, cabY + winH - 2);
            }
        }

        for (var r = -1; r <= 2; r++) {
            var sym = reel.symbolAt(r);
            var y = cabY + (r + 1) * rowH + rowH / 2 - (frac * rowH).toNumber();
            var dim = (r == 0) ? 100 : 52;
            SymbolManager.drawDim(dc, sym, cx, y, size, dim);
        }

        // glass glint — a thin diagonal light streak near the top-left,
        // drawn as slim lines so it reads as reflection without hiding
        // the symbols underneath.
        dc.setColor(0x4A4252, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(colX + 2, cabY + winH * 30 / 100, colX + colW * 40 / 100, cabY + 2);
        dc.drawLine(colX + 5, cabY + winH * 30 / 100, colX + colW * 40 / 100 + 3, cabY + 2);

        dc.clearClip();
    }

    hidden static function _drawPayline(dc, cabX, cabY, colW, rowH, gap) {
        var totalW = colW * 3 + gap * 2;
        var midTop = cabY + rowH;
        var midBot = cabY + rowH * 2;

        // gold guide lines bracketing the centre (payline) row
        dc.setColor(0xFFCC22, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cabX - 4, midTop, cabX + totalW + 4, midTop);
        dc.drawLine(cabX - 4, midBot, cabX + totalW + 4, midBot);
        dc.setColor(0x7A5A10, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cabX - 4, midTop + 1, cabX + totalW + 4, midTop + 1);
        dc.drawLine(cabX - 4, midBot - 1, cabX + totalW + 4, midBot - 1);

        // glowing arrow markers pointing at the payline on both sides
        var my = (midTop + midBot) / 2;
        _payArrow(dc, cabX - 8, my, 1);
        _payArrow(dc, cabX + totalW + 8, my, -1);
    }

    hidden static function _payArrow(dc, x, y, dir) {
        dc.setColor(0x7A2A00, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, y - 7], [x, y + 7], [x + dir * 11, y]]);
        dc.setColor(0xFF5522, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[x, y - 5], [x, y + 5], [x + dir * 8, y]]);
    }

    // Small downward chevron over the reel that's next to be stopped.
    static function drawNextHint(dc, ctrl, cabX, cabY, colW, gap) {
        var idx = ctrl.reels.nextSpinningIndex();
        if (idx < 0) { return; }
        var cx = cabX + idx * (colW + gap) + colW / 2;
        var y  = cabY - 15;
        var bob = ((System.getTimer() / 150) % 2 == 0) ? 0 : 2;
        dc.setColor(0x66DDFF, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[cx - 7, y - 6 + bob], [cx + 7, y - 6 + bob], [cx, y + 3 + bob]]);
    }

    // One-armed-bandit lever on the cabinet's right edge.
    static function drawLever(dc, ctrl, cabX, cabW, cabY, cabH) {
        var baseX = cabX + cabW + 20;
        var baseY = cabY + 8;
        var travel = cabH * 52 / 100;
        var pull = 0;
        if (ctrl.leverT > 0) {
            var t = ctrl.leverT.toFloat() / LEVER_FRAMES;
            pull = (Math.sin(t * Math.PI) * travel).toNumber();
        }
        // mount
        dc.setColor(0x5A3E0E, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(baseX - 5, baseY + cabH - 18, 10, 14, 3);
        // shaft (gradient)
        GfxUtil.vGradient(dc, baseX - 3, baseY + pull, 6, cabH - 22 - pull, 0xE8E8E8, 0x707070, 6);
        // knob
        dc.setColor(0x7A0A12, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(baseX, baseY + pull, 10);
        dc.setColor(0xE23140, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(baseX, baseY + pull, 8);
        dc.setColor(0xFF9AA2, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(baseX - 3, baseY + pull - 3, 3);
    }

    // ── Win / jackpot FX ──────────────────────────────────────────────
    static function drawResultFlash(dc, ctrl, cabX, cabY, cabW, cabH) {
        var r = ctrl.lastResult;
        if (r == null) { return; }
        var kind = r["kind"];
        if (kind == "NONE") { return; }

        var pulse = (ctrl.resultT % 8 < 4);
        var col = 0xFFCC22;
        if (kind == "JACKPOT") { col = pulse ? 0xFF33AA : 0xFFDD33; }
        else if (kind == "TRIPLE") { col = pulse ? 0x33CC55 : 0xAAFF66; }

        // pulsing thick frame around the whole cabinet
        var fx = cabX - 14; var fy = cabY - 14;
        var fw = cabW + 28; var fh = cabH + 28;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRoundedRectangle(fx, fy, fw, fh, 14);
        dc.drawRoundedRectangle(fx + 1, fy + 1, fw - 2, fh - 2, 13);
        dc.drawRoundedRectangle(fx + 2, fy + 2, fw - 4, fh - 4, 12);

        // TRIPLE / JACKPOT get flying coins + sparkles animating outward
        if (kind == "TRIPLE" || kind == "JACKPOT") {
            var age = SLOT_RESULT_TICKS - ctrl.resultT;   // grows 0..N
            _burst(dc, cabX + cabW / 2, cabY + cabH / 2, cabW, cabH, age, kind == "JACKPOT");
        }
    }

    hidden static function _burst(dc, cx, cy, cabW, cabH, age, big) {
        var n = big ? 10 : 6;
        var spread = cabW * 60 / 100;
        for (var i = 0; i < n; i++) {
            // deterministic pseudo-random angle per index
            var ang = (i * 2617) % 360;
            var rad = ang * Math.PI / 180;
            var dist = (age * 5) + (i * 3);
            if (dist > spread) { dist = spread; }
            var px = cx + (Math.cos(rad) * dist).toNumber();
            var py = cy + (Math.sin(rad) * dist).toNumber() - age;   // slight upward drift
            if (i % 2 == 0 || big) {
                // gold coin
                dc.setColor(0xB8860B, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 5);
                dc.setColor(0xFFDD44, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(px, py, 4);
                dc.setColor(0x8A6508, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(px - 1, py - 2, px - 1, py + 2);
            } else {
                GfxUtil.sparkle(dc, px, py, 5, 0xFFF3B0);
            }
        }
    }
}
