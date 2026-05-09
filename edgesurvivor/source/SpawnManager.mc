using Toybox.Math;

// SpawnManager — decides what to spawn and when, based on current score.
//
// Phases unlock progressively harder enemy types:
//   Phase 0 (  0–199): bullets only
//   Phase 1 (200–599): + arc walls + lasers
//   Phase 2 (600–1199): + rings, faster
//   Phase 3 (1200+):  all types, fastest

class SpawnManager {
    hidden var _nextSpawn;
    hidden var _phase;

    function initialize() { reset(); }

    function reset() {
        _nextSpawn = 90;
        _phase     = 0;
    }

    function getPhase() { return _phase; }

    // Call every game tick. Spawns enemies when the countdown expires.
    // playerAngle: used to avoid spawning lasers directly on the player.
    function update(score, pool, edgeRadius, playerAngle) {
        _phase = _scoreToPhase(score);
        _nextSpawn = _nextSpawn - 1;
        if (_nextSpawn > 0) { return; }

        _doSpawn(score, pool, edgeRadius, playerAngle);

        // spawn interval shrinks with score, minimum ~32 ticks (~1 s)
        var iv = 110 - score / 28;
        if (iv < 32) { iv = 32; }
        _nextSpawn = iv + Math.rand() % 28;
    }

    hidden function _scoreToPhase(score) {
        if (score < 200)  { return 0; }
        if (score < 600)  { return 1; }
        if (score < 1200) { return 2; }
        return 3;
    }

    hidden function _doSpawn(score, pool, edgeRadius, playerAngle) {
        var type = ET_BULLET;
        var r    = Math.rand() % 100;

        if (_phase == 0) {
            type = ET_BULLET;
        } else if (_phase == 1) {
            if      (r < 55) { type = ET_BULLET;  }
            else if (r < 82) { type = ET_ARCWALL; }
            else             { type = ET_LASER;   }
        } else if (_phase == 2) {
            if      (r < 38) { type = ET_BULLET;  }
            else if (r < 58) { type = ET_ARCWALL; }
            else if (r < 78) { type = ET_LASER;   }
            else             { type = ET_RING;    }
        } else {
            if      (r < 25) { type = ET_BULLET;  }
            else if (r < 48) { type = ET_ARCWALL; }
            else if (r < 72) { type = ET_LASER;   }
            else             { type = ET_RING;    }
        }

        // outward speed: grows with score, capped
        var spd = 2 + score / 400;
        if (spd > 5) { spd = 5; }

        if (type == ET_BULLET) {
            pool.spawn(ET_BULLET, Math.rand() % 360, 12, spd, 0);

        } else if (type == ET_ARCWALL) {
            // gap half-width shrinks with score (harder to fit through)
            var gapHalf = 44 - score / 60;
            if (gapHalf < 22) { gapHalf = 22; }
            pool.spawn(ET_ARCWALL, Math.rand() % 360, 12, spd, gapHalf);

        } else if (type == ET_LASER) {
            // Spawn at ~180° from player so there is reaction time
            var laserAng = (playerAngle + 150 + Math.rand() % 60) % 360;
            var lspd     = 1 + score / 700;
            if (lspd > 3) { lspd = 3; }
            var dir = (Math.rand() % 2 == 0) ? 1 : -1;
            pool.spawn(ET_LASER, laserAng, 300, lspd, dir);  // radius = lifetime

        } else {  // ET_RING
            var rgHalf = 42 - score / 65;
            if (rgHalf < 20) { rgHalf = 20; }
            pool.spawn(ET_RING, Math.rand() % 360, 12, spd, rgHalf);
        }
    }
}
