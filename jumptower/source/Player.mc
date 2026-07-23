// ═══════════════════════════════════════════════════════════════
// Player.mc — The hopping frog avatar.
//
// Movement model
//   • vx is driven by two sources: a "held" direction (KEY_UP /
//     KEY_DOWN held → constant ±MOVE_VX) and short impulse pulses
//     from taps that decay through friction. This unifies button
//     and touch input without timing magic.
//   • vy is updated by gravity every tick and reset to JUMP_VY each
//     time the platform manager reports a landing.
//   • Horizontal wrap: walking off the right edge teleports back
//     to the left and vice versa (classic Doodle-Jump style).
//
// The character is drawn procedurally so it renders at any size and
// stays sharp on hi-DPI Edge units without an asset.
// ═══════════════════════════════════════════════════════════════

using Toybox.Graphics;

class Player {
    var x;          // world-x in screen pixels (0..screenW-1)
    var y;          // world-y, increases upward
    var vx;
    var vy;
    var w;          // collision/render half-width
    var h;          // collision/render half-height
    var alive;

    // Animation
    var legPhase;   // 0..7 used to bob the legs
    var squashT;    // ticks remaining of a landing squash

    // Cosmetic skin tier, unlocked by lifetime coins collected — see
    // GameController.skinTier(). 0 = default green frog.
    var skin;

    // Selectable, shop-ready character skin from the shared Progress layer:
    // 0 = CLASSIC (use the coin-tier look above), 1 = NEON, 2 = GOLD. When
    // the player picks (and owns) NEON/GOLD it overrides the body palette.
    var skinSel;

    // Continuous input flags (mutated by InputHandler/MainView via
    // GameController.setHold). Tap pulses live in vx directly.
    var holdLeft;
    var holdRight;

    function initialize() {
        x = 0; y = 0; vx = 0.0; vy = 0.0; w = 8; h = 10;
        alive = true; legPhase = 0; skin = 0; skinSel = 0; squashT = 0;
        holdLeft = false; holdRight = false;
    }

    function reset(startX, startY, halfW, halfH) {
        x = startX; y = startY;
        vx = 0.0; vy = 0.0;
        w  = halfW; h = halfH;
        alive = true; legPhase = 0; squashT = 0;
        holdLeft = false; holdRight = false;
    }

    // Decay animation-only timers (kept out of step() so the physics
    // integration stays untouched).
    function stepFx() {
        if (squashT > 0) { squashT = squashT - 1; }
    }

    function bounce() {
        if (!alive) { return; }
        vy = Physics.JUMP_VY;
        legPhase = 0;
    }

    // Tap impulse — short kick that decays via friction.
    function tapImpulse(dir) {
        if (!alive) { return; }
        vx = dir * (Physics.MOVE_VX + 1.0);
    }

    function step(screenW) {
        // Horizontal velocity composition
        if (holdLeft && !holdRight) {
            vx = -Physics.MOVE_VX;
        } else if (holdRight && !holdLeft) {
            vx =  Physics.MOVE_VX;
        } else {
            vx = vx * Physics.FRICTION;
            if (vx > -0.05 && vx < 0.05) { vx = 0.0; }
        }
        x = x + vx;
        // Horizontal wrap
        if (x < -w)              { x = screenW + w - 1; }
        if (x > screenW + w - 1) { x = -w + 1;          }

        // Vertical — screen convention: positive vy means falling (y down).
        // JUMP_VY is negative so a jump pushes y upward (smaller y).
        vy = Physics.applyGravity(vy);
        y  = y + vy;

        legPhase = (legPhase + 1) % 8;
    }

    // AABB used by PlatformManager.
    function bbox() {
        return [x - w, y - h, x + w, y + h];
    }

    // Render at (sx, sy) — caller supplies the screen-space top centre
    // because the world→screen projection lives in MainView.
    function draw(dc, sx, sy) {
        // Skin palette — unlocked by lifetime coins (see
        // GameController.skinTier()). Purely cosmetic; hitbox/physics
        // are identical across tiers.
        var bodyC = 0x44CC44; var bellyC = 0xCCFFCC; var legC = 0x33AA33;
        // Selectable shop-ready skin takes priority when picked & owned.
        if (skinSel == 1) {         // NEON frog
            bodyC = 0x22FF99; bellyC = 0xCCFFEE; legC = 0x00CC88;
        } else if (skinSel == 2) {  // GOLD frog
            bodyC = 0xFFD21A; bellyC = 0xFFF3C4; legC = 0xC79300;
        } else if (skin == 1) {     // Ice Frog (coin tier)
            bodyC = 0x55CCEE; bellyC = 0xEAFBFF; legC = 0x2E9BC0;
        } else if (skin == 2) {     // Gold Frog (coin tier)
            bodyC = 0xE8B923; bellyC = 0xFFF3C4; legC = 0xB4880F;
        } else if (skin >= 3) {     // Diamond Frog (coin tier)
            bodyC = 0xB06CFF; bellyC = 0xE9D6FF; legC = 0x7A3FCC;
        }

        // Squash & stretch — the body fattens on a landing and slims
        // when rocketing upward. Purely cosmetic; hitbox is unchanged.
        var bw = w;
        if (squashT > 0)        { bw = (w * 5) / 4; }   // splat wide on landing
        else if (vy < -3.0)     { bw = (w * 3) / 4; }   // stretch thin on ascent

        // Body — coloured oval (drawn as two circles + rectangle for round-rect feel)
        dc.setColor(bodyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy, bw);
        dc.fillRectangle(sx - bw, sy - 2, bw * 2, 4);
        // Belly
        dc.setColor(bellyC, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx, sy + 2, (w * 2) / 3);
        // Eyes — two white circles on the head
        var eyeR = (w / 3 < 2) ? 2 : w / 3;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx - w / 2, sy - h / 2, eyeR);
        dc.fillCircle(sx + w / 2, sy - h / 2, eyeR);
        // Pupils — look in direction of motion
        var pupOff = (vx > 0.5) ? 1 : ((vx < -0.5) ? -1 : 0);
        dc.setColor(0x000000, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(sx - w / 2 + pupOff, sy - h / 2, eyeR / 2);
        dc.fillCircle(sx + w / 2 + pupOff, sy - h / 2, eyeR / 2);
        // Legs — small triangles below when falling, tucked when rising
        var legY = sy + h - 1;
        dc.setColor(legC, Graphics.COLOR_TRANSPARENT);
        var spread = (vy > 0) ? (w - 2) : (w / 2);
        dc.fillPolygon([[sx - spread, legY],
                        [sx - 1,      legY - 3],
                        [sx - 1,      legY]]);
        dc.fillPolygon([[sx + spread, legY],
                        [sx + 1,      legY - 3],
                        [sx + 1,      legY]]);
        // Diamond tier sparkle — a tiny glint on the head.
        if (skin >= 3) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(sx - w / 4, sy - h / 2 - 2, 1);
        }
    }
}
