// ═══════════════════════════════════════════════════════════════════════════
// EventManager.mc — The floor's mood.
//
// Most of the horror budget goes here rather than into entities: the player
// should spend the run unable to tell whether anything is actually happening.
// Events are cheap flags the renderer reads (darkness, glitch, shake, wall
// stretch) plus the occasional real change to the world.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class EventManager {
    var cur; var left; var cd;
    var seed;
    var darkOn;      // lights are out floor-wide
    var glitch;      // 0..100 scanline / tear intensity
    var shake;       // camera shake in px
    var stretch;     // extra wall height, % (the corridor "grows")
    var msg; var msgLeft;
    var tone;        // 0 none, 1 soft cue, 2 harsh cue — consumed by the view
    var fired;       // events triggered this run (score flavour)

    function initialize(s) {
        cur = Br.EV_NONE; left = 0; cd = 90;
        seed = (s == 0) ? 777 : s;
        darkOn = false; glitch = 0; shake = 0; stretch = 0;
        msg = null; msgLeft = 0; tone = 0; fired = 0;
    }

    function _rand(n) {
        seed = MapGen.nextRand(seed);
        if (n <= 1) { return 0; }
        return seed % n;
    }

    function takeTone() {
        var t = tone;
        tone = 0;
        return t;
    }

    function update(map, p, ents, level, freqPct) {
        // Effects always relax back toward calm.
        if (glitch > 0) { glitch -= 4; if (glitch < 0) { glitch = 0; } }
        if (shake > 0) { shake -= 1; }
        if (msgLeft > 0) { msgLeft -= 1; if (msgLeft == 0) { msg = null; } }

        if (left > 0) {
            left -= 1;
            _sustain();
            if (left == 0) { _end(); }
            return;
        }

        if (cd > 0) {
            cd -= 1;
            return;
        }
        _roll(map, p, ents, level, freqPct);
    }

    hidden function _sustain() {
        if (cur == Br.EV_DISTORT) {
            if (glitch < 60) { glitch = 60; }
        } else if (cur == Br.EV_LIGHTSOUT) {
            darkOn = true;
            if (_rand(100) < 6) { glitch = 40; }
        } else if (cur == Br.EV_FOLLOWED) {
            if (_rand(100) < 8) { shake = 2; }
        }
    }

    hidden function _end() {
        if (cur == Br.EV_LIGHTSOUT) {
            darkOn = false;
            tone = 1;
        } else if (cur == Br.EV_STRETCH) {
            stretch = 0;
        }
        cur = Br.EV_NONE;
        // Quiet stretches matter as much as the events do.
        cd = 70 + _rand(150);
    }

    hidden function _roll(map, p, ents, level, freqPct) {
        // Not every window produces an event — dead air is the point.
        var chance = 45 * freqPct / 100 + level * 4;
        if (chance > 88) { chance = 88; }
        if (_rand(100) >= chance) {
            cd = 45 + _rand(90);
            return;
        }

        var pick = _rand(100);
        var e;
        if (pick < 14)      { e = Br.EV_FOOTSTEPS; }
        else if (pick < 26) { e = Br.EV_WHISPER; }
        else if (pick < 38) { e = Br.EV_DISTORT; }
        else if (pick < 50) { e = Br.EV_GLIMPSE; }
        else if (pick < 61) { e = Br.EV_LIGHTSOUT; }
        else if (pick < 71) { e = Br.EV_SHIFT; }
        else if (pick < 81) { e = Br.EV_STRETCH; }
        else if (pick < 92) { e = Br.EV_FOLLOWED; }
        else                { e = Br.EV_FAKEEXIT; }

        // The lobby stays merciful.
        if (level == 0 && (e == Br.EV_LIGHTSOUT || e == Br.EV_FAKEEXIT)) {
            e = Br.EV_FOOTSTEPS;
        }

        cur = e;
        left = Br.evFrames(e);
        fired += 1;
        _begin(map, p, ents, level);

        var t = Br.evText(e);
        if (t != null && t.length() > 0) {
            msg = t;
            msgLeft = 34;
        }
    }

    hidden function _begin(map, p, ents, level) {
        var maxE = 4;
        if (cur == Br.EV_LIGHTSOUT) {
            darkOn = true;
            glitch = 70;
            shake = 3;
            tone = 2;
            ents.trySpawn(Br.E_SHADOW, map, p, level, maxE);

        } else if (cur == Br.EV_FOOTSTEPS) {
            tone = 1;

        } else if (cur == Br.EV_WHISPER) {
            glitch = 30;
            tone = 1;

        } else if (cur == Br.EV_DISTORT) {
            glitch = 80;

        } else if (cur == Br.EV_SHIFT) {
            seed = MapGen.shiftWalls(map, p.cellX(), p.cellY(), seed);
            shake = 4;
            tone = 2;

        } else if (cur == Br.EV_STRETCH) {
            stretch = 45;

        } else if (cur == Br.EV_GLIMPSE) {
            ents.trySpawn(Br.E_STALKER, map, p, level, maxE);
            ents.lastGlimpse = 10;

        } else if (cur == Br.EV_FOLLOWED) {
            tone = 1;
            shake = 2;
            // Put it behind you, so the only way to check is to turn around.
            var bx = (p.x - p.dirX * 3.0).toNumber();
            var by = (p.y - p.dirY * 3.0).toNumber();
            if (!map.isWall(bx, by)) {
                ents.list.add(new BrEntity(Br.E_STALKER, bx + 0.5, by + 0.5, 60));
            } else {
                ents.trySpawn(Br.E_STALKER, map, p, level, maxE);
            }

        } else if (cur == Br.EV_FAKEEXIT) {
            for (var i = 0; i < map.sp.size(); i++) {
                var s = map.sp[i];
                if (s[2] == Br.SP_MIMIC && s[3] == 0) {
                    ents.spawnMimicAt(s[0], s[1]);
                    break;
                }
            }
            glitch = 45;
        }
    }
}
