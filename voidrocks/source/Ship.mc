// ═══════════════════════════════════════════════════════════════
// Ship.mc — The player's spaceship.
//
// Geometry:
//   • x, y       — position in pixels (continuous Float)
//   • vx, vy     — velocity per tick (Float, capped)
//   • angle      — heading in radians; 0 = pointing UP, increases
//                  CLOCKWISE on the screen (matches +X = right /
//                  +Y = down).  Thrust adds  (+sin a, -cos a).
//   • radius     — collision radius in pixels (re-computed every
//                  resize based on min(sw, sh)).
//   • invul      — invulnerability countdown (ticks).  While > 0
//                  asteroids pass through harmlessly and the ship
//                  is rendered blinking.
//
// The Ship is intentionally "dumb": it exposes mutating helpers
// (rotateLeft/Right, thrust, friction, integrate) and lets the
// GameController orchestrate them.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const VR_TWO_PI = 6.28319;
const VR_ROT_STEP    = 0.22;     // radians per button press
const VR_THRUST_ACC  = 0.42;     // pixels/tick² added on thrust
const VR_FRICTION    = 0.985;    // velocity decay per tick
const VR_MAX_V       = 5.5;      // ship max speed (px/tick)

class Ship {
    var x;
    var y;
    var vx;
    var vy;
    var angle;
    var radius;
    var alive;
    var invul;
    var thrustOn;      // visual flag — was thrust applied this tick?

    function initialize() {
        x = 0.0; y = 0.0; vx = 0.0; vy = 0.0;
        angle    = 0.0;
        radius   = 8;
        alive    = true;
        invul    = 0;
        thrustOn = false;
    }

    function respawn(sw, sh, r) {
        x = sw / 2.0; y = sh / 2.0;
        vx = 0.0;     vy = 0.0;
        angle  = 0.0;
        radius = r;
        alive  = true;
        invul  = 60;        // ~4.8 s grace at 80 ms tick
        thrustOn = false;
    }

    function rotateLeft()  { angle = angle - VR_ROT_STEP; if (angle < 0) { angle = angle + VR_TWO_PI; } }
    function rotateRight() { angle = angle + VR_ROT_STEP; if (angle >= VR_TWO_PI) { angle = angle - VR_TWO_PI; } }

    function applyThrust() {
        vx = vx + VR_THRUST_ACC *  Math.sin(angle);
        vy = vy + VR_THRUST_ACC * -Math.cos(angle);
        var c = PhysicsEngine.capV(vx, vy, VR_MAX_V);
        vx = c[0]; vy = c[1];
        thrustOn = true;
    }

    // Integrate one tick of motion + friction + invul countdown.
    function integrate(sw, sh) {
        // Friction first so a ship that just thrusted still moves.
        vx = vx * VR_FRICTION;
        vy = vy * VR_FRICTION;
        if (vx < 0.02 && vx > -0.02) { vx = 0.0; }
        if (vy < 0.02 && vy > -0.02) { vy = 0.0; }
        var p = PhysicsEngine.step(x, y, vx, vy, sw, sh);
        x = p[0]; y = p[1];
        if (invul > 0) { invul = invul - 1; }
        // Reset thrust flag for next frame (UI sets each tick).
        thrustOn = false;
    }

    // Forward unit-vector (used to spawn bullets at nose).
    function noseDx() { return  Math.sin(angle); }
    function noseDy() { return -Math.cos(angle); }
}
