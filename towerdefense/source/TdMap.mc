// ═══════════════════════════════════════════════════════════════════════════
// TdMap.mc — Four hand-tuned layouts + their buildable pads.
//
// Coordinates are 0..100 inside the playfield square; the View scales them, so
// nothing here is pixel-bound. Everything stays inside a radius of ~45 from
// (50,50) so the layouts survive the bezel on round watches.
//
// The four maps ask genuinely different questions:
//   BEND  long straights — range and travel time, easy to learn
//   SNAKE stacked switchbacks — one pad can cover two lanes, reward placement
//   RING  a spiral of corners into a central base — everything is a corner
//   GATE  an hourglass that pinches twice — a single centre pad hits twice
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

module TdMap {

    const COUNT = 4;

    // Path waypoints, flat [x0,y0, x1,y1, ...]. First point is the spawn
    // portal, last is the base.
    function path(mapIdx as Lang.Number) as Lang.Array {
        if (mapIdx == 1) {
            return [16, 22,  84, 22,  84, 38,  16, 38,  16, 54,
                    84, 54,  84, 70,  26, 70,  26, 84,  58, 84];
        }
        if (mapIdx == 2) {
            return [50, 10,  82, 26,  88, 58,  62, 84,  30, 84,
                    12, 58,  20, 32,  44, 26,  56, 42,  50, 54];
        }
        if (mapIdx == 3) {
            return [14, 26,  44, 26,  50, 44,  56, 26,  86, 26,
                    86, 60,  56, 60,  50, 78,  44, 60,  14, 60];
        }
        return [14, 30,  80, 30,  80, 54,  22, 54,  22, 76,  76, 76];
    }

    // Build pads, flat [x,y, ...]. Ordered roughly along the path so that
    // walking the cursor with UP/DOWN feels spatially sensible.
    function pads(mapIdx as Lang.Number) as Lang.Array {
        if (mapIdx == 1) {
            return [50, 30,  24, 30,  76, 30,  50, 46,  24, 46,
                    76, 46,  50, 62,  76, 62,  14, 62,  44, 76];
        }
        if (mapIdx == 2) {
            return [66, 14,  34, 14,  92, 42,  76, 68,  46, 92,
                    20, 74,   8, 44,  30, 50,  68, 52,  50, 70];
        }
        if (mapIdx == 3) {
            return [50, 34,  50, 52,  30, 18,  70, 18,  28, 42,
                    72, 42,  36, 72,  64, 72,  50, 88,  20, 44];
        }
        return [46, 18,  80, 16,  92, 42,  50, 42,  12, 44,
                50, 66,  12, 66,  86, 62,  48, 90,  66, 90];
    }

    function mapName(mapIdx as Lang.Number) as Lang.String {
        if (mapIdx == 1) { return "SNAKE"; }
        if (mapIdx == 2) { return "RING"; }
        if (mapIdx == 3) { return "GATE"; }
        return "BEND";
    }
}
