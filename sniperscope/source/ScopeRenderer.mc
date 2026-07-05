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
    //
    // Brightened revision: the prior palette (sky 0x14181E, ground
    // 0x0A1208, skyline 0x0F1A12) read as "near black" through the
    // scope vignette, so silhouettes had almost no background to
    // contrast against and the player struggled to scan the field.
    // All in-scope colours are now lifted by ~40-60 RGB points so
    // the scene is recognisably "dusk-lit terrain" rather than
    // "scope on opaque mud".
    //
    // Three genuinely distinct maps rotate mission-to-mission
    // (GameController.scene, picked once per mission in
    // _startMission): FIELD (rolling hills + trees), URBAN (the
    // original dense skyline) and ROOFTOP (closer night skyline with
    // chimneys/antennas/water towers + a parapet ledge underfoot).
    static function drawScene(dc, ctrl, ox, oy) {
        var w = ctrl.sw; var h = ctrl.sh;
        var horizonY = ctrl.cy + (ctrl.aim.aimPitch * SS_FOV * 0.45).toNumber() + oy;
        if (horizonY < h * 20 / 100) { horizonY = h * 20 / 100; }
        if (horizonY > h * 80 / 100) { horizonY = h * 80 / 100; }

        // Parallax X based on yaw — scenery slides opposite gaze.
        var px = (-ctrl.aim.aimYaw * SS_FOV * 0.5).toNumber() + ox;
        var ws = (ctrl.wind.strength * 4.0).toNumber();

        if      (ctrl.scene == SS_SCENE_URBAN)   { _sceneUrban(dc, w, h, horizonY, px, ox, ws); }
        else if (ctrl.scene == SS_SCENE_ROOFTOP) { _sceneRooftop(dc, w, h, horizonY, px, ox, ws); }
        else                                       { _sceneField(dc, w, h, horizonY, px, ox, ws); }
    }

    // ── FIELD — open countryside at dusk: rolling hills, lone trees,
    // tall warm grass. No buildings, no windows.
    hidden static function _sceneField(dc, w, h, horizonY, px, ox, ws) {
        dc.setColor(0x2E2A4A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, horizonY - 14);
        dc.setColor(0x5A4A5E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY - 14, w, 8);
        dc.setColor(0xB88858, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY - 6, w, 6);

        dc.setColor(0x3E5A26, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY, w, h - horizonY);

        // Rolling hills — overlapping circle caps poking above the
        // horizon line (cheap way to fake a hill skyline).
        var seed = 55511;
        dc.setColor(0x2C4420, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 6; i++) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var hr = 46 + seed % 40;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var hx = ((seed % (w + 160)) - 80) + px + i * 40;
            dc.fillCircle(hx, horizonY + hr - 16, hr);
        }
        // Lone trees for scale/variety.
        var ts = 71237;
        for (var t = 0; t < 3; t++) {
            ts = (ts * 1103515245 + 12345) & 0x7FFFFFFF;
            var tx = ((ts % (w * 2)) - w / 2) + px + t * 70;
            var th = 14 + (ts >> 8) % 10;
            dc.setColor(0x241E14, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(tx, horizonY, tx, horizonY - th);
            dc.setColor(0x203A18, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(tx, horizonY - th, 6);
        }

        // Foreground — tall grass, denser & warmer than the city lot.
        dc.setColor(0x5C8A2E, Graphics.COLOR_TRANSPARENT);
        var s2 = 90217;
        for (var k = 0; k < 30; k++) {
            s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF;
            var gx = (s2 % w) + (ws * (k & 1)) / 4 + ox;
            var gy = horizonY + 4 + (s2 % (h - horizonY > 0 ? h - horizonY : 1)) * 3 / 4;
            if (gy >= h - 2) { continue; }
            dc.drawLine(gx, gy, gx + ws, gy - 5);
        }
    }

    // ── URBAN — the original dense daytime/dusk skyline treatment.
    hidden static function _sceneUrban(dc, w, h, horizonY, px, ox, ws) {
        // Sky band — deeper top fading to a brighter mid-tone near
        // the horizon.
        dc.setColor(0x2A3848, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, horizonY - 10);
        dc.setColor(0x3F5066, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY - 10, w, 6);
        // Horizon glow — warm dawn band.
        dc.setColor(0x6A6A4A, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY - 4, w, 4);

        // Ground band — olive/green-ish mid-tone so silhouettes pop.
        dc.setColor(0x223A1E, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY, w, h - horizonY);

        // Distant skyline — darker than the sky behind it but still
        // far brighter than before so the buildings actually read.
        var seed = 24061;
        for (var i = 0; i < 18; i++) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bx0 = ((seed % (w * 2)) - w / 2) + px + i * 30;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bw = 18 + seed % 22;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bh = 10 + seed % 32;
            dc.setColor(0x1A2A24, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx0, horizonY - bh, bw, bh);
            if ((seed & 7) == 0 && bh >= 12) {
                dc.setColor(0xAA7733, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx0 + bw / 2 - 1, horizonY - bh / 2, 2, 2);
            }
        }

        // Foreground grass tufts — drift with wind.  Lifted to a
        // brighter olive so the ground texture is visible without
        // demanding the player squint.
        dc.setColor(0x3A5C24, Graphics.COLOR_TRANSPARENT);
        var s2 = 90217;
        for (var k = 0; k < 28; k++) {
            s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF;
            var gx = (s2 % w) + (ws * (k & 1)) / 4 + ox;
            var gy = horizonY + 4 + (s2 % (h - horizonY > 0 ? h - horizonY : 1)) * 3 / 4;
            if (gy >= h - 2) { continue; }
            dc.drawLine(gx, gy, gx + ws, gy - 4);
        }
    }

    // ── ROOFTOP — closer, taller night skyline shot from up high:
    // chimneys / antennas / water towers, gravel + parapet underfoot.
    hidden static function _sceneRooftop(dc, w, h, horizonY, px, ox, ws) {
        dc.setColor(0x151C30, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, 0, w, horizonY - 8);
        dc.setColor(0x263148, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY - 8, w, 8);

        dc.setColor(0x1E2430, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, horizonY, w, h - horizonY);

        var seed = 68131;
        for (var i = 0; i < 14; i++) {
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bx0 = ((seed % (w * 2)) - w / 2) + px + i * 38;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bw = 24 + seed % 26;
            seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
            var bh = 22 + seed % 46;
            dc.setColor(0x11151E, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(bx0, horizonY - bh, bw, bh);
            // Lit windows — cooler, sparser than urban (night city).
            if ((seed & 3) == 0) {
                dc.setColor(0x8899CC, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx0 + bw / 2 - 1, horizonY - bh / 2, 2, 2);
            }
            // Roof furniture, varied deterministically so the skyline
            // reads unmistakably as "rooftops" rather than plain blocks.
            var rf = seed % 3;
            if (rf == 0) {
                dc.setColor(0x0C0E14, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(bx0 + bw / 4, horizonY - bh - 8, 5, 8);
            } else if (rf == 1) {
                dc.setColor(0x0C0E14, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(bx0 + bw / 2, horizonY - bh, bx0 + bw / 2, horizonY - bh - 14);
            } else {
                var wtx = bx0 + bw / 2;
                dc.setColor(0x181C24, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(wtx - 5, horizonY - bh - 10, 10, 8);
                dc.drawLine(wtx - 4, horizonY - bh, wtx - 4, horizonY - bh - 2);
                dc.drawLine(wtx + 4, horizonY - bh, wtx + 4, horizonY - bh - 2);
            }
        }

        // Foreground — rooftop gravel specks + a dark parapet ledge
        // underfoot instead of grass (we're up on a roof here).
        dc.setColor(0x2A303E, Graphics.COLOR_TRANSPARENT);
        var s2 = 40507;
        for (var k = 0; k < 20; k++) {
            s2 = (s2 * 1103515245 + 12345) & 0x7FFFFFFF;
            var gx = (s2 % w) + (ws * (k & 1)) / 4 + ox;
            var gy = horizonY + 6 + (s2 % (h - horizonY > 0 ? h - horizonY : 1)) * 4 / 5;
            if (gy >= h - 2) { continue; }
            dc.fillRectangle(gx, gy, 2, 2);
        }
        dc.setColor(0x0E1118, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(0, h - 10, w, 10);
    }

    // ── Wind streaks across the scope (subtle motion). ───────
    static function drawWindStreaks(dc, ctrl, ox, oy) {
        var w  = ctrl.sw; var h = ctrl.sh;
        var ws = ctrl.wind.strength;
        if (ws > -0.05 && ws < 0.05) { return; }
        // Step the streak phase from the game tick.
        var phase = (ctrl.tick * (ws * 2.0).toNumber()) & 0xFF;
        dc.setColor(0x556644, Graphics.COLOR_TRANSPARENT);
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

        // Tail tip — for an IN-FLIGHT bullet (live == 1) this is the
        // last few ticks of trajectory.  For a FROZEN bullet
        // (live == 2, sitting on the RESULT screen) the head is
        // already at the impact, so we render a LONGER tracer to
        // signal "this is where the shot came from" — the player
        // sees the line connecting their muzzle to the impact.
        var tail = 5;
        var denom = 28;
        if (ctrl.bullet.live == 2) {
            // Static post-shot trace: pull the tail further toward
            // the muzzle so it reads as a sniper's bullet line.
            tail  = 12;
            denom = 16;
        }
        if (ctrl.bullet.ttl < tail) { tail = ctrl.bullet.ttl; }
        if (tail < 1) { tail = 1; }
        var tx = bx + ((mx - bx) * tail) / denom;
        var ty = by + ((my - by) * tail) / denom;

        // Faint orange tail behind the head.
        dc.setColor(0x442200, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tx, ty, bx, by);
        dc.setColor(0xFFAA33, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(tx + 1, ty, bx + 1, by);
        // Bullet head — a hot 3x3 pixel.  Slightly cooler on the
        // frozen post-shot trace so it doesn't compete with the
        // impact splash colour.
        var headCol = (ctrl.bullet.live == 2) ? 0xFFCC66 : 0xFFEE88;
        dc.setColor(headCol, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(bx - 1, by - 1, 3, 3);
    }

    // ── Muzzle flash (fire feedback, first few ticks of SS_FIRED). ──
    // A quick bright starburst at the reticle centre — cheap (4 lines
    // + 1 fill) but adds a lot of "oomph" to the trigger pull.
    static function drawMuzzleFlash(dc, ctrl) {
        if (ctrl.muzzleFlashT <= 0) { return; }
        var sc = scopeCircle(ctrl);
        var cx0 = sc[0]; var cy0 = sc[1];
        var age = 3 - ctrl.muzzleFlashT;         // 0 (fresh) .. 2 (fading)
        var r = 10 + age * 8;
        dc.setPenWidth(2);
        dc.setColor(0xFFEE99, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(cx0 - r, cy0, cx0 - r / 2, cy0);
        dc.drawLine(cx0 + r / 2, cy0, cx0 + r, cy0);
        dc.drawLine(cx0, cy0 - r, cx0, cy0 - r / 2);
        dc.drawLine(cx0, cy0 + r / 2, cx0, cy0 + r);
        dc.setPenWidth(1);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx0, cy0, 4 - age);
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
