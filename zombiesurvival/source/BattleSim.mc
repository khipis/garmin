// ═══════════════════════════════════════════════════════════════════════════
// BattleSim.mc — One night, resolved.
//
// This is the only combat code in the game and it runs identically whether
// anybody is looking. `tick()` advances the night by one step; the view calls
// it a few times a frame to animate the wave, and `runHeadless()` calls it in
// a tight loop to settle a wave that happened while the watch was in a drawer.
// Two code paths would drift, and a player who watched would be playing a
// different game from one who slept.
//
// Nothing here reads input. The single exception is `assist()`: if you are
// actually present you may fire your own rifle, which is the reward for
// turning up rather than a way to play. Everything else — turrets, traps,
// walls — fights on its own.
//
// The outcome is defence against horde with a per-shot wobble of about ±12%,
// so two identical nights are not identical, and a base that is only just
// strong enough is genuinely uncertain.
//
// World X is fixed point: Zs.WX_SPAWN at the far end of the street down to
// Zs.WX_WALL at the wall.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;
using Toybox.Math;

// What a finished night leaves behind. The model folds this into the save.
class WaveResult {
    var win;
    var kills;
    var total;
    var wallPct;
    var scrap;
    function initialize() {
        win = false; kills = 0; total = 0; wallPct = 0; scrap = 0;
    }
}

class BattleSim {

    // ── Capacities ──────────────────────────────────────────────────────────
    // Deliberately small. Everything is a parallel array allocated once, so a
    // night costs a fixed handful of objects no matter how many dead walk in.
    const ZMAX = 16;         // zombies on the street at once
    const PMAX = 24;         // blood / spark particles
    const TMAX = 6;          // tracer lines

    // ── Run state ───────────────────────────────────────────────────────────
    const ST_FIGHT = 0;
    const ST_WON   = 1;
    const ST_LOST  = 2;

    // ── Events, drained by the view for haptics and screen shake ────────────
    const EV_SHOT   = 0;
    const EV_KILL   = 1;
    const EV_WALL   = 2;
    const EV_BREACH = 3;
    const EV_BOSS   = 4;
    const EV_END    = 5;
    const EVMAX     = 8;

    // Turrets stop acquiring past this in fog.
    const FOG_RANGE = 5200;
    // A zombie that has reached the wall sits at this world X; spitters stop
    // short and work at range.
    const WX_SPIT   = 2600;

    var state;
    var tickN;

    // Night definition
    var night; var wv; var sched; var si;
    var total; var mod; var hpPct; var spPct; var bossDue; var bossSpawned;

    // Wall — three segments, and the base falls only when all three are gone.
    var wall; var wallMax; var breach;

    // Zombies
    var zAlive; var zX; var zLane; var zType; var zHp; var zMax;
    var zBite; var zAnim; var zFlash; var zSpiked;

    // Defences
    var lvl;                                   // [Zs.D_N] levels, copied in
    var mgT; var morT; var tesT; var rifT;
    var mgDmg; var mgRate; var morDmg; var morRate;
    var tesDmg; var tesRate; var tesChain;
    var spikeDmg; var wirePct; var plating;
    var rifDmg; var rifRate; var hasRifle; var salvageMul;

    // Feel / visuals (ignored entirely by the headless path)
    var pAlive; var pX; var pY; var pVX; var pVY; var pLife; var pKind; var pCol;
    var tLife; var tLane; var tX;
    var shake; var flashW; var muzzle;
    var evt; var evtN;
    // Cleared for the offline resolve. Blood and tracers cost real time when
    // a whole night is being settled in one go at app start.
    var visual;

    // Tally
    var kills; var scrap; var assists;

    hidden var _seed;
    hidden var _w; hidden var _h;

    // ────────────────────────────────────────────────────────────────────────
    function initialize(model, nightNo) {
        night = nightNo < 1 ? 1 : nightNo;
        wv = WaveGen.forNight(night);
        sched = wv["sched"];
        total = wv["count"];
        mod = wv["mod"];
        hpPct = wv["hpPct"];
        spPct = wv["spPct"];
        bossDue = wv["boss"];
        bossSpawned = false;
        si = 0;
        tickN = 0;
        state = ST_FIGHT;
        kills = 0; scrap = 0; assists = 0;
        shake = 0; flashW = 0; muzzle = 0; visual = true;
        _seed = (WaveGen.seedFor(night) ^ 0x5D3F) & 0x7FFFFFFF;
        _w = 240; _h = 240;

        zAlive = new [ZMAX]; zX = new [ZMAX]; zLane = new [ZMAX];
        zType = new [ZMAX]; zHp = new [ZMAX]; zMax = new [ZMAX];
        zBite = new [ZMAX]; zAnim = new [ZMAX]; zFlash = new [ZMAX];
        zSpiked = new [ZMAX];
        for (var i = 0; i < ZMAX; i++) {
            zAlive[i] = false; zX[i] = 0; zLane[i] = 0; zType[i] = 0;
            zHp[i] = 0; zMax[i] = 1; zBite[i] = 0; zAnim[i] = 0;
            zFlash[i] = 0; zSpiked[i] = false;
        }

        pAlive = new [PMAX]; pX = new [PMAX]; pY = new [PMAX];
        pVX = new [PMAX]; pVY = new [PMAX]; pLife = new [PMAX];
        pKind = new [PMAX]; pCol = new [PMAX];
        for (var p = 0; p < PMAX; p++) { pAlive[p] = false; pLife[p] = 0; }

        tLife = new [TMAX]; tLane = new [TMAX]; tX = new [TMAX];
        for (var t = 0; t < TMAX; t++) { tLife[t] = 0; tLane[t] = 0; tX[t] = 0; }

        evt = new [EVMAX]; evtN = 0;

        _setupDefences(model);
        _setupWall(model);
    }

    hidden function _setupDefences(model) {
        lvl = new [Zs.D_N];
        for (var i = 0; i < Zs.D_N; i++) { lvl[i] = model.dLevel[i]; }

        // Salvage off the shelf, folded in once here so nothing downstream has
        // to know the shelf exists. Every item is worth a few percent; the
        // full set is about two levels of a good turret.
        var tur = 100 + model.itemBonus(Zs.EF_TURRET);
        var rif = 100 + model.itemBonus(Zs.EF_RIFLE);

        mgDmg   = Zs.mgDmg(lvl[Zs.D_MG]) * tur / 100;
        mgRate  = Zs.mgRate(lvl[Zs.D_MG]);
        morDmg  = Zs.mortarDmg(lvl[Zs.D_MORTAR]) * tur / 100;
        morRate = Zs.mortarRate(lvl[Zs.D_MORTAR]);
        tesDmg  = Zs.teslaDmg(lvl[Zs.D_TESLA]) * tur / 100;
        tesRate = Zs.teslaRate(lvl[Zs.D_TESLA]);
        tesChain= Zs.teslaChain(lvl[Zs.D_TESLA]);
        spikeDmg= Zs.spikeDmg(lvl[Zs.D_SPIKES]);
        wirePct = Zs.wireSlowPct(lvl[Zs.D_WIRE]);
        plating = Zs.platingCut(lvl[Zs.D_PLATING])
                  + model.itemBonus(Zs.EF_PLATING);
        rifDmg  = Zs.rifleDmg(lvl[Zs.D_RIFLE]) * rif / 100;
        rifRate = Zs.rifleRate(lvl[Zs.D_RIFLE]);
        salvageMul = Zs.salvagePct(lvl[Zs.D_SALVAGE])
                     + model.itemBonus(Zs.EF_SALVAGE);
        hasRifle = true;
        mgT = 0; morT = 0; tesT = 0; rifT = 0;
    }

    // The gate is spent first: it is a buffer in front of the wall proper, so
    // buying one gives every turret more seconds on target before anything
    // starts chewing structure.
    hidden function _setupWall(model) {
        var seg = (Zs.wallHp(lvl[Zs.D_WALL]) + Zs.gateHp(lvl[Zs.D_GATE]))
                  * (100 + model.itemBonus(Zs.EF_WALL)) / 100;
        var pct = model.wallPct;
        if (pct < 5) { pct = 5; }
        wall = new [Zs.LANES];
        wallMax = new [Zs.LANES];
        breach = new [Zs.LANES];
        for (var l = 0; l < Zs.LANES; l++) {
            wallMax[l] = seg;
            wall[l] = seg * pct / 100;
            if (wall[l] < 1) { wall[l] = 1; }
            breach[l] = false;
        }
    }

    // Screen geometry, handed in by the view so world X can be drawn. The
    // headless path never calls this and never needs it.
    function setGeometry(w, h) { _w = w; _h = h; }
    function screenX(wx, lane) {
        var t = wx;
        if (t < 0) { t = 0; }
        if (t > Zs.WX_SPAWN) { t = Zs.WX_SPAWN; }
        var wallX = ZsArt.wallXs(_w)[lane];
        var spawnX = ZsArt.spawnXs(_w)[lane];
        return wallX + (spawnX - wallX) * t / Zs.WX_SPAWN;
    }

    // ── Random ──────────────────────────────────────────────────────────────
    hidden function _rnd(n) {
        _seed = (_seed * 1103515245 + 12345) & 0x7FFFFFFF;
        if (n <= 0) { return 0; }
        return (_seed / 65536) % n;
    }
    // The uncertainty the whole game hangs on. Every point of damage is worth
    // between 88% and 112% of itself, so a base that beats the horde on paper
    // by a hair does not beat it reliably.
    hidden function _jitter(d) {
        if (d <= 0) { return 0; }
        var v = d * (88 + _rnd(25)) / 100;
        return v < 1 ? 1 : v;
    }

    hidden function _push(e) {
        if (evtN < EVMAX) { evt[evtN] = e; evtN += 1; }
    }
    function events() { return evtN; }
    function eventAt(i) { return evt[i]; }
    function clearEvents() { evtN = 0; }

    // ── Advance one step ────────────────────────────────────────────────────
    function tick() {
        if (state != ST_FIGHT) { return state; }
        tickN += 1;

        if (shake > 0) { shake -= 1; }
        if (flashW > 0) { flashW -= 1; }
        if (muzzle > 0) { muzzle -= 1; }
        for (var t = 0; t < TMAX; t++) {
            if (tLife[t] > 0) { tLife[t] -= 1; }
        }

        _spawns();
        _zombies();
        _turrets();
        if (visual) { _particles(); }

        // Won: the schedule is exhausted and nothing is left standing.
        if (_aliveCount() == 0 && si >= sched.size() && (!bossDue || bossSpawned)) {
            state = ST_WON;
            _push(EV_END);
        }
        // A night that will not resolve inside the cap is a night the guns
        // could not finish, and the dead are still out there at dawn. Calling
        // that a win would reward building nothing at all.
        if (state == ST_FIGHT && tickN > Zs.SIM_MAX_TICKS) {
            state = ST_LOST;
            _push(EV_END);
        }
        return state;
    }

    // Settle the rest of the night immediately. Used for a wave that landed
    // while the app was closed, and for the player who skips the replay.
    function runHeadless() {
        visual = false;
        var guard = 0;
        while (state == ST_FIGHT && guard < Zs.SIM_MAX_TICKS + 8) {
            tick();
            guard += 1;
        }
        evtN = 0;
        return result();
    }

    function result() {
        var r = new WaveResult();
        r.win = (state == ST_WON);
        r.kills = kills;
        r.total = total + (bossSpawned ? 1 : 0);
        r.wallPct = totalWallPct();
        // Salvage from the corpses. A lost night still pays: the point of a
        // loss is to cost you the night, not the day's walking.
        r.scrap = scrap * salvageMul / 100;
        if (!r.win) { r.scrap = r.scrap * 60 / 100; }
        return r;
    }

    // ── Spawning ────────────────────────────────────────────────────────────
    hidden function _spawns() {
        while (si + 2 < sched.size() && sched[si] <= tickN) {
            var type = sched[si + 1];
            var lane = sched[si + 2];
            if (!_spawn(type, lane, hpPct)) { return; }   // no slot, try later
            si += 3;
        }
        // The abomination arrives a third of the way in, once the street is
        // already busy and the turrets are committed.
        if (bossDue && !bossSpawned && si >= sched.size() / 3) {
            if (_spawn(Zs.Z_BOSS, 1, 100)) {
                bossSpawned = true;
                shake = 8;
                _push(EV_BOSS);
            }
        }
    }

    hidden function _spawn(type, lane, pct) {
        for (var i = 0; i < ZMAX; i++) {
            if (zAlive[i]) { continue; }
            var hp = (type == Zs.Z_BOSS) ? wv["bossHp"] : Zs.zHp(type) * pct / 100;
            if (hp < 1) { hp = 1; }
            zAlive[i] = true;
            zX[i] = Zs.WX_SPAWN + _rnd(600);
            zLane[i] = lane;
            zType[i] = type;
            zHp[i] = hp;
            zMax[i] = hp;
            zBite[i] = 0;
            zAnim[i] = _rnd(4);
            zFlash[i] = 0;
            zSpiked[i] = false;
            return true;
        }
        return false;
    }

    hidden function _aliveCount() {
        var n = 0;
        for (var i = 0; i < ZMAX; i++) { if (zAlive[i]) { n += 1; } }
        return n;
    }

    // ── Zombies ─────────────────────────────────────────────────────────────
    hidden function _zombies() {
        for (var i = 0; i < ZMAX; i++) {
            if (!zAlive[i]) { continue; }
            if (zFlash[i] > 0) { zFlash[i] -= 1; }

            var type = zType[i];
            var stop = (type == Zs.Z_SPITTER) ? WX_SPIT : Zs.WX_WALL;

            if (zX[i] > stop) {
                var sp = Zs.zSpeed(type) * spPct / 100;
                // Razor wire only covers the last stretch of street, which is
                // exactly the stretch the turrets are already pointed at.
                if (zX[i] < Zs.WX_WIRE) { sp = sp * wirePct / 100; }
                if (sp < 4) { sp = 4; }
                zX[i] -= sp;
                zAnim[i] += 1;

                // The spike pit bites once, on the way through.
                if (!zSpiked[i] && spikeDmg > 0 && zX[i] <= Zs.WX_SPIKES) {
                    zSpiked[i] = true;
                    _damage(i, _jitter(spikeDmg));
                    if (!zAlive[i]) { continue; }
                }
                if (zX[i] < stop) { zX[i] = stop; }
                continue;
            }

            // At the wall. Bite whatever structure is still standing.
            zBite[i] -= 1;
            if (zBite[i] > 0) { continue; }
            zBite[i] = Zs.zBite(type);

            var target = _biteTarget(zLane[i]);
            if (target < 0) { continue; }          // nothing left; base is gone
            var dmg = Zs.zDmg(type) - plating;
            if (dmg < 1) { dmg = 1; }
            _hitWall(target, _jitter(dmg));
        }
    }

    // The segment this zombie can actually reach: its own if it stands, else
    // the weakest one still up, because a breach lets them flank.
    hidden function _biteTarget(lane) {
        if (wall[lane] > 0) { return lane; }
        var best = -1;
        for (var l = 0; l < Zs.LANES; l++) {
            if (wall[l] <= 0) { continue; }
            if (best < 0 || wall[l] < wall[best]) { best = l; }
        }
        return best;
    }

    hidden function _hitWall(lane, dmg) {
        wall[lane] -= dmg;
        if (shake < 3) { shake = 3; }
        _push(EV_WALL);
        if (wall[lane] <= 0) {
            wall[lane] = 0;
            if (!breach[lane]) {
                breach[lane] = true;
                shake = 10;
                _push(EV_BREACH);
            }
            if (_allBreached()) {
                state = ST_LOST;
                _push(EV_END);
            }
        }
    }

    hidden function _allBreached() {
        for (var l = 0; l < Zs.LANES; l++) {
            if (wall[l] > 0) { return false; }
        }
        return true;
    }

    function totalWallPct() {
        var cur = 0; var max = 0;
        for (var l = 0; l < Zs.LANES; l++) { cur += wall[l]; max += wallMax[l]; }
        if (max <= 0) { return 0; }
        return cur * 100 / max;
    }
    function wallPctAt(lane) {
        if (wallMax[lane] <= 0) { return 0; }
        return wall[lane] * 100 / wallMax[lane];
    }
    function anyBreach() {
        for (var l = 0; l < Zs.LANES; l++) { if (breach[l]) { return true; } }
        return false;
    }

    // ── Turrets ─────────────────────────────────────────────────────────────
    hidden function _turrets() {
        var reach = (mod == Zs.MOD_FOG) ? FOG_RANGE : Zs.WX_SPAWN + 1000;

        if (mgDmg > 0) {
            mgT -= 1;
            if (mgT <= 0) {
                var m = _nearest(reach);
                if (m >= 0) {
                    mgT = mgRate;
                    _shoot(m, _jitter(mgDmg), 0xFFAA00);
                }
            }
        }
        if (morDmg > 0) {
            morT -= 1;
            if (morT <= 0) {
                // Shells go to whatever is toughest, not whatever is closest:
                // a mortar exists to answer brutes.
                var b = _toughest(reach);
                if (b >= 0) {
                    morT = morRate;
                    var lane = zLane[b];
                    _shoot(b, _jitter(morDmg), 0xFF5500);
                    // Splash on the rest of that lane.
                    for (var i = 0; i < ZMAX; i++) {
                        if (!zAlive[i] || i == b || zLane[i] != lane) { continue; }
                        _damage(i, _jitter(morDmg / 2));
                    }
                    shake = 5;
                }
            }
        }
        if (tesDmg > 0) {
            tesT -= 1;
            if (tesT <= 0) {
                var hit = 0;
                for (var c = 0; c < ZMAX && hit < tesChain; c++) {
                    var n = _nearestUnflashed(reach);
                    if (n < 0) { break; }
                    _shoot(n, _jitter(tesDmg), 0x55AAFF);
                    hit += 1;
                }
                if (hit > 0) { tesT = tesRate; }
            }
        }
        if (rifT > 0) { rifT -= 1; }
    }

    // The one thing a present player can do. It is a bonus for being there,
    // not a skill check: there is no aiming, the shot goes to whatever is
    // closest, and holding the button just fires at the rifle's own rate.
    function assist() {
        if (state != ST_FIGHT || !hasRifle || rifT > 0) { return false; }
        var n = _nearest(Zs.WX_SPAWN + 1000);
        if (n < 0) { return false; }
        rifT = rifRate;
        assists += 1;
        muzzle = 3;
        _shoot(n, _jitter(rifDmg), 0xFFFFFF);
        return true;
    }

    hidden function _shoot(i, dmg, col) {
        if (visual) {
            _tracer(zLane[i], zX[i]);
            _spark(i, col);
            _push(EV_SHOT);
        }
        _damage(i, dmg);
    }

    hidden function _nearest(reach) {
        var best = -1;
        for (var i = 0; i < ZMAX; i++) {
            if (!zAlive[i] || zX[i] > reach) { continue; }
            if (best < 0 || zX[i] < zX[best]) { best = i; }
        }
        return best;
    }
    // Tesla arcs skip anything it just hit this tick, so a chain spreads.
    hidden function _nearestUnflashed(reach) {
        var best = -1;
        for (var i = 0; i < ZMAX; i++) {
            if (!zAlive[i] || zX[i] > reach || zFlash[i] > 0) { continue; }
            if (best < 0 || zX[i] < zX[best]) { best = i; }
        }
        return best;
    }
    hidden function _toughest(reach) {
        var best = -1;
        for (var i = 0; i < ZMAX; i++) {
            if (!zAlive[i] || zX[i] > reach) { continue; }
            if (best < 0 || zHp[i] > zHp[best]) { best = i; }
        }
        return best;
    }

    hidden function _damage(i, dmg) {
        var d = dmg - Zs.zArmor(zType[i]);
        if (d < 1) { d = 1; }
        zHp[i] -= d;
        zFlash[i] = 2;
        if (zHp[i] <= 0) { _kill(i); }
    }

    hidden function _kill(i) {
        zAlive[i] = false;
        kills += 1;
        var s = Zs.zScrap(zType[i]);
        if (mod == Zs.MOD_BLOOD) { s = s * 130 / 100; }
        scrap += s;
        if (visual) { _push(EV_KILL); _gore(i); }
    }

    // ── Particles (skipped entirely when nobody is watching) ────────────────
    hidden function _slot() {
        for (var i = 0; i < PMAX; i++) {
            if (!pAlive[i]) { return i; }
        }
        return -1;
    }

    hidden function _spark(i, col) {
        var s = _slot();
        if (s < 0) { return; }
        var y = ZsArt.laneYs(_h)[zLane[i]];
        pAlive[s] = true;
        pX[s] = screenX(zX[i], zLane[i]) * 16;
        pY[s] = (y - 10) * 16;
        pVX[s] = 8 - _rnd(16);
        pVY[s] = -8 - _rnd(10);
        pLife[s] = 5 + _rnd(4);
        pKind[s] = 2;
        pCol[s] = col;
    }

    hidden function _gore(i) {
        var y = ZsArt.laneYs(_h)[zLane[i]];
        var sx = screenX(zX[i], zLane[i]);
        var n = (zType[i] == Zs.Z_BOSS) ? 8 : 4;
        for (var k = 0; k < n; k++) {
            var s = _slot();
            if (s < 0) { return; }
            pAlive[s] = true;
            pX[s] = sx * 16;
            pY[s] = (y - 8 - _rnd(10)) * 16;
            pVX[s] = 18 - _rnd(36);
            pVY[s] = -14 - _rnd(16);
            pLife[s] = 9 + _rnd(8);
            pKind[s] = (k == 0) ? 1 : 0;
            pCol[s] = (k & 1) == 0 ? Zs.BLOOD2 : Zs.BLOOD;
        }
    }

    hidden function _particles() {
        for (var i = 0; i < PMAX; i++) {
            if (!pAlive[i]) { continue; }
            pLife[i] -= 1;
            if (pLife[i] <= 0) { pAlive[i] = false; continue; }
            pX[i] += pVX[i];
            pY[i] += pVY[i];
            pVY[i] += 3;
        }
    }

    hidden function _tracer(lane, wx) {
        for (var t = 0; t < TMAX; t++) {
            if (tLife[t] > 0) { continue; }
            tLife[t] = 2;
            tLane[t] = lane;
            tX[t] = wx;
            return;
        }
    }
}
