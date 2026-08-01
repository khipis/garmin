// ═══════════════════════════════════════════════════════════════════════════
// EntityManager.mc — The three things that share the floor with you.
//
// None of them fight. They cost sanity, and each one punishes a different
// instinct:
//   Stalker  watches from the far end of a corridor and is gone the moment you
//            walk up to it — then comes back a little closer.
//   Shadow   only exists in the dark. Meeting its eye holds it still but eats
//            your sanity; turning away is safe and lets it close the distance.
//   Mimic    wears the exit sign. You only learn which one it was by touching
//            it.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class BrEntity {
    var kind;
    var x; var y;
    var life;      // frames until it leaves on its own
    var fade;      // 0..100 visibility, drives the silhouette alpha
    var state;     // per-kind flag (Shadow: 1 = held by your gaze)

    function initialize(k, ex, ey, l) {
        kind = k; x = ex; y = ey; life = l; fade = 0; state = 0;
    }
}

class EntityManager {
    var list;
    var seed;
    var stalkerBias;   // grows every run — it learns where you look
    var lastGlimpse;   // frames since something was briefly visible
    var contact;       // set when an entity reached the player this frame

    function initialize(s, bias) {
        list = [];
        seed = (s == 0) ? 12345 : s;
        stalkerBias = bias;
        lastGlimpse = 0;
        contact = 0;
    }

    function _rand(n) {
        seed = MapGen.nextRand(seed);
        if (n <= 1) { return 0; }
        return seed % n;
    }

    function clear() { list = []; }
    function count() { return list.size(); }

    // Find an open cell roughly `want` cells away from the player.
    function _openCellNear(map, p, want) {
        for (var t = 0; t < 14; t++) {
            var gx = 1 + _rand(map.w - 2);
            var gy = 1 + _rand(map.h - 2);
            if (map.isWall(gx, gy)) { continue; }
            var d2 = p.dist2To(gx, gy);
            var lo = (want - 2) * (want - 2);
            var hi = (want + 3) * (want + 3);
            if (d2 >= lo && d2 <= hi) { return [gx, gy]; }
        }
        return null;
    }

    // Spawn attempt. Returns true if something arrived.
    function trySpawn(kind, map, p, level, maxEntities) {
        if (list.size() >= maxEntities) { return false; }
        for (var i = 0; i < list.size(); i++) {
            if (list[i].kind == kind) { return false; }   // one of each at a time
        }
        var want = 8;
        if (kind == Br.E_STALKER) {
            want = 9 - stalkerBias;      // every run it starts a step closer
            if (want < 4) { want = 4; }
        } else if (kind == Br.E_SHADOW) {
            want = 6;
        }
        var c = _openCellNear(map, p, want);
        if (c == null) { return false; }
        var life = 150;
        if (kind == Br.E_STALKER) { life = 110 + level * 8; }
        if (kind == Br.E_SHADOW) { life = 220; }
        list.add(new BrEntity(kind, c[0] + 0.5, c[1] + 0.5, life));
        return true;
    }

    // Wake a mimic at a known cell (used by the fake-exit event).
    function spawnMimicAt(gx, gy) {
        list.add(new BrEntity(Br.E_MIMIC, gx + 0.5, gy + 0.5, 260));
    }

    // Per-frame behaviour. `darkNow` is true while the floor is unlit (event or
    // dark zone), `beam` while the torch is lit — the beam is the only thing on
    // this floor that pushes back. Returns the sanity cost this frame, in
    // hundredths of a point.
    function update(map, p, darkNow, level, beam) {
        contact = 0;
        if (lastGlimpse > 0) { lastGlimpse -= 1; }
        var drain = 0;

        for (var i = list.size() - 1; i >= 0; i--) {
            var e = list[i];
            e.life -= 1;
            if (e.life <= 0) { list.remove(e); continue; }

            var gx = e.x.toNumber();
            var gy = e.y.toNumber();
            var d2 = p.dist2To(gx, gy);
            var inView = p.looksAt(gx, gy, 0.80);

            if (e.kind == Br.E_STALKER) {
                // Visible only head-on, and never for long.
                e.fade = inView ? 100 : 0;
                if (d2 < 12.25) { drain += 3; }
                // Under the beam it stops pretending it has not noticed you.
                if (beam && inView && d2 < 49.0) { e.life -= 2; drain += 2; }
                if (d2 < 3.5) {
                    // You closed the distance. It was never there.
                    list.remove(e);
                    lastGlimpse = 14;
                    drain += 500;
                    continue;
                }
                // Drifts toward you only while unobserved.
                if (!inView) { _stepToward(e, map, p, 0.020); }

            } else if (e.kind == Br.E_SHADOW) {
                if (!darkNow) {
                    // Light dissolves it.
                    e.fade -= 12;
                    if (e.fade <= 0) { list.remove(e); continue; }
                } else if (beam && inView && d2 < 49.0) {
                    // The beam is the one thing it cannot stand in. Burning it
                    // off costs battery instead of sanity — which is the whole
                    // trade the torch exists to offer.
                    e.state = 1;
                    e.fade -= 9;
                    drain += 3;
                    _stepToward(e, map, p, -0.045);
                    if (e.fade <= 0) { list.remove(e); continue; }
                } else {
                    if (e.fade < 100) { e.fade += 8; }
                    if (inView && d2 < 64.0) {
                        // Held by your gaze — and feeding on it.
                        e.state = 1;
                        drain += 12 + level;
                    } else {
                        e.state = 0;
                        _stepToward(e, map, p, 0.055);
                        if (d2 < 0.9) {
                            contact = 1;
                            drain += 2500;
                            list.remove(e);
                            continue;
                        }
                    }
                }

            } else if (e.kind == Br.E_MIMIC) {
                e.fade = 100;
                if (d2 < 25.0) { drain += 2; }
            }
        }
        return drain;
    }

    hidden function _stepToward(e, map, p, speed) {
        var dx = p.x - e.x;
        var dy = p.y - e.y;
        var ax = (dx < 0) ? -dx : dx;
        var ay = (dy < 0) ? -dy : dy;
        var len = ax + ay;
        if (len < 0.001) { return; }
        var nx = e.x + (dx / len) * speed;
        var ny = e.y + (dy / len) * speed;
        if (!map.isWall(nx.toNumber(), e.y.toNumber())) { e.x = nx; }
        if (!map.isWall(e.x.toNumber(), ny.toNumber())) { e.y = ny; }
    }

    // True while anything at all has line of sight on the player — the HUD
    // pulse that tells you something is wrong without saying what.
    function watched(p) {
        for (var i = 0; i < list.size(); i++) {
            var e = list[i];
            if (e.fade <= 0) { continue; }
            if (p.looksAt(e.x.toNumber(), e.y.toNumber(), 0.60)) { return true; }
        }
        return false;
    }
}
