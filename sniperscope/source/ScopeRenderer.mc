// ═══════════════════════════════════════════════════════════════
// ScopeRenderer.mc — Scope tube + reticle + scene background.
//
// Pure rendering helpers — no game-state mutation.  Called from
// UIManager.draw().
//
// Visual hierarchy (back → front):
//   • Dark off-scope letterbox          (everything outside circle)
//   • Sky/ground gradient inside scope
//   • Static scene silhouettes (buildings, hills, windows…)
//   • Wind streaks (grass / dust)
//   • Targets (TargetManager.drawAll)
//   • Bullet trace + impact glow
//   • Scope ring + reticle (mil-dot crosshair)
//   • Slow-mo overlay (faint red ring on a kill)
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;
using Toybox.Math;

class ScopeRenderer {

    // ── Compute the scope circle parameters once per frame. ──
    // Returns [cx, cy, r].
    static function scopeCircle(ctrl) {
        var rmin = (ctrl.sw < ctrl.sh) ? ctrl.sw : ctrl.sh;
        var r    = rmin * SS_SCOPE_PCT / 200;     // half-diam → radius
        return [ctrl.cx, ctrl.cy, r];
    }

    // ── Sky / ground + scenery (depends on aim yaw for parallax). ──
    static function drawScene(dc, ctrl, ox, oy) {
        var w = ctrl.sw; var h = ctrl.sh;
        // Horizon Y is pulled down by the player's pitch — looking
        // UP raises the horizon, looking DOWN lowers it.
        var horizonY = ctrl.cy + (ctrl.aim.aimPitch * SS_FOV * 0.45).toNumber() + oy;
        if (horizonY < h * 20 / 100) { horizonY = h * 20 / 100; }
        if (horizonY > h * 80 / 100) { horizonY = h * 80 / 100; }

        // Sky band — soft dawn-ish hue, just barely lighter near the
        // horizon for a sense of depth.
        dc.setColor(0x14181E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, horizonY);
        // Faint horizon glow.
        dc.setColor(0x232B22, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY - 6, w, 6);

        // Ground band.
        dc.setColor(0x0A1208, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY, w, h - horizonY);

        // Parallax X based on yaw — buildings slide opposite gaze.
        var px = (-ctrl.aim.aimYaw * SS_FOV * 0.5).toNumber() + ox;

        // Distant skyline — a few rectangular shapes seeded by an LCG
        // for visual variety.  Cheap (12 buildings, fixed seed).
        var seed = 24061;
        for (var i = 0; i < 18; i++) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bx0 = ((seed % (w * 2)) - w / 2) + px + i * 30;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bw = 18 + seed % 22;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bh = 10 + seed % 32;
            dc.setColor(0x0F1A12, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx0, horizonY - bh, bw, bh);
            // Lit window dot.
            if ((seed & 7) == 0 && bh >= 12) {
                dc.setColor(0x554422, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx0 + bw / 2 - 1, horizonY - bh / 2, 2, 2);
            }
        }

        // Foreground grass tufts — drift with wind.
        var ws = (ctrl.wind.strength * 4.0).toNumber();
        dc.setColor(0x182A12, Graphics.COLOR_TRANSPARENT);
        var s2 = 90217;
        for (var k = 0; k < 28; k++) {
            s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF;
            var gx = (s2 % w) + (ws * (k & 1)) / 4 + ox;
            var gy = horizonY + 4 + (s2 % (h - horizonY > 0 ? h - horizonY : 1)) * 3 / 4;
            if (gy >= h - 2) { continue; }
            dc.drawLine(gx, gy, gx + ws, gy - 4);
        }
    }

    // ── Wind streaks across the scope (subtle motion). ───────
    static function drawWindStreaks(dc, ctrl, ox, oy) {
        var w  = ctrl.sw; var h = ctrl.sh;
        var ws = ctrl.wind.strength;
        if (ws > -0.05 && ws < 0.05) { return; }
        // Step the streak phase from the game tick.
        var phase = (ctrl.tick * (ws * 2.0).toNumber()) & 0xFF;
        dc.setColor(0x2C3429, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 7; i++) {
            var y = (h * (15 + i * 11)) / 100 + oy;
            var len = (ws > 0 ? 1 : -1) * (5 + i);
            var x  = ((phase * 11 + i * 73) % w) + ox;
            dc.drawLine(x, y, x + len, y);
        }
    }

    // ── Off-scope letterbox (the dark mask around the scope). ──
    static function drawScopeMask(dc, ctrl) {
        var sc = scopeCircle(ctrl);
        var cx0 = sc[0]; var cy0 = sc[1]; var r = sc[2];
        // Outer dark ring (thick) — gives the lens its tube feel.
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        // Four black corner rectangles around the scope circle.
        var outR = r + 24;
        dc.fillRectangle(0, 0, ctrl.sw, cy0 - outR);
        dc.fillRectangle(0, cy0 + outR, ctrl.sw, ctrl.sh - (cy0 + outR));
        dc.fillRectangle(0, cy0 - outR, cx0 - outR, 2 * outR);
        dc.fillRectangle(cx0 + outR, cy0 - outR, ctrl.sw - (cx0 + outR), 2 * outR);
        // Dark vignette ring just outside the scope.
        dc.setPenWidth(20);
        dc.setColor(0x0A0E0A, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx0, cy0, r + 12);
        dc.setPenWidth(8);
        dc.setColor(0x040604, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx0, cy0, r + 4);
        // Bright glass ring (the polished metal lip).
        dc.setPenWidth(2);
        dc.setColor(0x5A6850, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx0, cy0, r);
        dc.setPenWidth(1);
        dc.setColor(0xA5BD92, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx0, cy0, r - 1);
    }

    // ── Reticle (crosshair + mil dots + breathing wobble). ───
    static function drawReticle(dc, ctrl) {
        var sc = scopeCircle(ctrl);
        var cx0 = sc[0]; var cy0 = sc[1]; var r = sc[2];

        // Recoil pushes the reticle UP for `recoilT` ticks.
        var recoilY = (ctrl.recoilT > 0) ? -ctrl.recoilT * 2 : 0;

        // Reticle colour reflects the breathing state.
        var col;
        if      (ctrl.breath.steady == 1)    { col = 0xC8FFC8; }
        else if (ctrl.breath.fatigue > 1.4)  { col = 0xFFC080; }
        else                                  { col = 0xE0F0DC; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);

        // Horizontal & vertical hairs with a 6-px gap around centre.
        var gap = 6;
        var armX = r - 6;
        var armY = r - 6;
        dc.drawLine(cx0 - armX, cy0 + recoilY, cx0 - gap, cy0 + recoilY);
        dc.drawLine(cx0 + gap,  cy0 + recoilY, cx0 + armX, cy0 + recoilY);
        dc.drawLine(cx0, cy0 - armY + recoilY, cx0, cy0 - gap + recoilY);
        dc.drawLine(cx0, cy0 + gap + recoilY, cx0, cy0 + armY + recoilY);

        // Mil dots below centre (range estimation aid).
        for (var k = 1; k <= 4; k++) {
            var dy = k * 8;
            if (dy + gap >= armY) { break; }
            dc.drawLine(cx0 - 3, cy0 + gap + dy + recoilY,
                        cx0 + 3, cy0 + gap + dy + recoilY);
        }

        // Centre pip.
        dc.setColor(0xFF6633, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(cx0, cy0 + recoilY, 1, 1);

        // Steady-window glow ring.
        if (ctrl.breath.steady == 1) {
            dc.setPenWidth(1);
            dc.setColor(0x66FF66, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx0, cy0, 18);
        }
    }

    // ── Bullet trace (visible during SS_FIRED). ──────────────
    //
    // Two stages, world-anchored:
    //   1. Project the FIRE-TIME aim direction through the CURRENT
    //      gaze to get the muzzle's on-screen position.  This is
    //      where the bullet entered the world — when the player
    //      moves the reticle, this point slides too, so the trace
    //      stays planted in world space.
    //   2. Draw a short comet-tail tracer from a few ticks back of
    //      the bullet head to the bullet head itself.  Compared
    //      to drawing the entire flight as one stretched line,
    //      this reads as motion and doesn't fight the gentle
    //      ballistic curve.
    static function drawBullet(dc, ctrl, ox, oy) {
        if (ctrl.bullet.live == 0) { return; }
        var ba = ctrl.bullet.screenAt(ctrl.cx, ctrl.cy,
                                       ctrl.aim.gazeYaw,
                                       ctrl.aim.gazePitch);
        var bx = ba[0] + ox; var by = ba[1] + oy;
        var mx = ba[2] + ox; var my = ba[3] + oy;

        // Tail tip — bullet position a few ticks ago, on the same
        // ballistic curve we just integrated.  We don't store a
        // history so we back-solve approximately: the average
        // velocity over the last `tail` ticks is the current
        // velocity minus half of (tail-1) accelerations.  For
        // visual purposes a simple lerp toward the muzzle is more
        // than good enough.
        var tail = 5;
        if (ctrl.bullet.ttl < tail) { tail = ctrl.bullet.ttl; }
        if (tail < 1) { tail = 1; }
        var tx = bx + ((mx - bx) * tail) / 28;     // ~18 % toward muzzle
        var ty = by + ((my - by) * tail) / 28;

        // Faint orange tail behind the head.
        dc.setColor(0x442200, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tx, ty, bx, by);
        dc.setColor(0xFFAA33, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tx + 1, ty, bx + 1, by);
        // Bullet head — a hot 3x3 pixel.
        dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - 1, by - 1, 3, 3);
    }

    // ── Impact splash (RESULT screen). ───────────────────────
    static function drawImpact(dc, ctrl) {
        if (ctrl.state != SS_RESULT) { return; }
        var x = ctrl.lastImpactX;
        var y = ctrl.lastImpactY;
        var age = SS_RESULT_TICKS - ctrl.resultT;
        if (age < 0) { age = 0; }
        if (ctrl.lastZone == SS_ZONE_MISS) {
            // Dust puff.
            dc.setColor(0x6E6450, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, age * 2 + 3);
            dc.setColor(0x382E22, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(x, y, age + 2);
            return;
        }
        // Hit — red shockwave.
        var col;
        if      (ctrl.lastZone == SS_ZONE_HEAD)  { col = 0xFF3344; }
        else if (ctrl.lastZone == SS_ZONE_CHEST) { col = 0xFF7733; }
        else                                      { col = 0xCC8844; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(x, y, age * 3 + 4);
        dc.drawCircle(x, y, age * 2 + 2);
        // Bright core for first few ticks.
        if (age < 4) {
            dc.setColor(0xFFEE88, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y, 3);
        }
    }
}
