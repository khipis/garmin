// ═══════════════════════════════════════════════════════════════════════════
// DungeonMap.mc — The floor grid + procedural DungeonGenerator.
//
// A floor is a flat DM_W×DM_H tile array plus five small entity pools
// (monsters / loot / secrets / traps / features). Generation is driven entirely
// by DmRng, so the same (seed, floor) always rebuilds byte-identical geometry —
// the save system and the daily dungeon both rely on that. Nothing mutable is
// stored in the tiles that cannot be replayed from a handful of flags.
//
// Rooms carry an archetype (crypt, library, treasury, arena, pillared hall)
// which steers what spawns inside them, so a floor reads as a place rather
// than as a bag of rectangles.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class DungeonMap {

    var tiles;        // flat DM_W*DM_H of tile codes
    var visited;      // flat flags: tile already stepped on
    var startX;
    var startY;
    var startDir;
    var stairX;
    var stairY;
    var floorNo;
    var theme;        // DmConst.zoneOf(floor) — cached for the renderer

    // Rooms
    var roomN;
    var roomX;
    var roomY;
    var roomW;
    var roomH;
    var roomArch;

    // Monsters
    var monN;
    var monX;
    var monY;
    var monType;
    var monHp;
    var monAlive;
    var monElite;

    // Loot lying in the open
    var lootN;
    var lootX;
    var lootY;
    var lootKind;
    var lootVal;
    var lootTaken;

    // Secrets hidden in walls
    var secN;
    var secX;
    var secY;
    var secType;      // SEC_STASH / SEC_VAULT / SEC_PASSAGE
    var secKind;      // loot kind revealed (stash/vault)
    var secVal;
    var secFound;

    // Traps
    var trapN;
    var trapX;
    var trapY;
    var trapKind;
    var trapArmed;

    // Shrines / fountains / merchants
    var featN;
    var featX;
    var featY;
    var featKind;
    var featUsed;

    function initialize() {
        tiles = new [DM_W * DM_H];
        visited = new [DM_W * DM_H];
        roomX = new [DM_MAX_ROOM];
        roomY = new [DM_MAX_ROOM];
        roomW = new [DM_MAX_ROOM];
        roomH = new [DM_MAX_ROOM];
        roomArch = new [DM_MAX_ROOM];
        monX = new [DM_MAX_MON];
        monY = new [DM_MAX_MON];
        monType = new [DM_MAX_MON];
        monHp = new [DM_MAX_MON];
        monAlive = new [DM_MAX_MON];
        monElite = new [DM_MAX_MON];
        lootX = new [DM_MAX_LOOT];
        lootY = new [DM_MAX_LOOT];
        lootKind = new [DM_MAX_LOOT];
        lootVal = new [DM_MAX_LOOT];
        lootTaken = new [DM_MAX_LOOT];
        secX = new [DM_MAX_SEC];
        secY = new [DM_MAX_SEC];
        secType = new [DM_MAX_SEC];
        secKind = new [DM_MAX_SEC];
        secVal = new [DM_MAX_SEC];
        secFound = new [DM_MAX_SEC];
        trapX = new [DM_MAX_TRAP];
        trapY = new [DM_MAX_TRAP];
        trapKind = new [DM_MAX_TRAP];
        trapArmed = new [DM_MAX_TRAP];
        featX = new [DM_MAX_FEAT];
        featY = new [DM_MAX_FEAT];
        featKind = new [DM_MAX_FEAT];
        featUsed = new [DM_MAX_FEAT];
        roomN = 0;
        monN = 0;
        lootN = 0;
        secN = 0;
        trapN = 0;
        featN = 0;
        floorNo = 1;
        theme = 0;
        startX = 1;
        startY = 1;
        startDir = DIR_E;
        stairX = 1;
        stairY = 1;
        for (var i = 0; i < DM_W * DM_H; i++) {
            tiles[i] = T_WALL;
            visited[i] = 0;
        }
    }

    function at(x as Lang.Number, y as Lang.Number) as Lang.Number {
        if (x < 0 || y < 0 || x >= DM_W || y >= DM_H) { return T_WALL; }
        return tiles[y * DM_W + x];
    }

    function set(x as Lang.Number, y as Lang.Number, v as Lang.Number) as Void {
        if (x < 0 || y < 0 || x >= DM_W || y >= DM_H) { return; }
        tiles[y * DM_W + x] = v;
    }

    // Blocks movement and blocks rays.
    function isSolid(x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        var t = at(x, y);
        return t == T_WALL || t == T_SECRET || t == T_DOOR || t == T_LOCKED || t == T_PILLAR;
    }

    function isWalkable(x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        var t = at(x, y);
        return t == T_FLOOR || t == T_DOOR_OPEN || t == T_STAIRS;
    }

    function markVisited(x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        if (x < 0 || y < 0 || x >= DM_W || y >= DM_H) { return false; }
        var i = y * DM_W + x;
        if (visited[i] != 0) { return false; }
        visited[i] = 1;
        return true;
    }

    function seen(x as Lang.Number, y as Lang.Number) as Lang.Boolean {
        if (x < 0 || y < 0 || x >= DM_W || y >= DM_H) { return false; }
        return visited[y * DM_W + x] != 0;
    }

    // Reveal the tiles a torch would actually light: the current tile and its
    // immediate ring, so the minimap fills in like a memory rather than a scan.
    // Returns how many tiles were newly revealed (drives exploration XP).
    function markNear(x as Lang.Number, y as Lang.Number) as Lang.Number {
        var fresh = 0;
        for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
                var nx = x + dx;
                var ny = y + dy;
                if (nx < 0 || ny < 0 || nx >= DM_W || ny >= DM_H) { continue; }
                var i = ny * DM_W + nx;
                if (visited[i] == 0) { fresh++; }
                visited[i] = 1;
            }
        }
        return fresh;
    }

    // The explored map packs into one 16-bit mask per row, so a whole floor's
    // memory costs 16 numbers in the save blob instead of 256.
    function visitedRow(y as Lang.Number) as Lang.Number {
        var mask = 0;
        var base = y * DM_W;
        for (var x = 0; x < DM_W; x++) {
            if (visited[base + x] != 0) { mask |= (1 << x); }
        }
        return mask;
    }

    function setVisitedRow(y as Lang.Number, mask as Lang.Number) as Void {
        var base = y * DM_W;
        for (var x = 0; x < DM_W; x++) {
            visited[base + x] = ((mask & (1 << x)) != 0) ? 1 : 0;
        }
    }

    function monsterAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        for (var i = 0; i < monN; i++) {
            if (monAlive[i] && monX[i] == x && monY[i] == y) { return i; }
        }
        return -1;
    }

    function lootAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        for (var i = 0; i < lootN; i++) {
            if (lootTaken[i] == 0 && lootX[i] == x && lootY[i] == y) { return i; }
        }
        return -1;
    }

    function trapAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        for (var i = 0; i < trapN; i++) {
            if (trapArmed[i] != 0 && trapX[i] == x && trapY[i] == y) { return i; }
        }
        return -1;
    }

    function featAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        for (var i = 0; i < featN; i++) {
            if (featX[i] == x && featY[i] == y) { return i; }
        }
        return -1;
    }

    function secretAt(x as Lang.Number, y as Lang.Number) as Lang.Number {
        for (var i = 0; i < secN; i++) {
            if (secFound[i] == 0 && secX[i] == x && secY[i] == y) { return i; }
        }
        return -1;
    }

    // Open a secret wall. Returns the pool index, or -1 if there was none.
    function openSecret(x as Lang.Number, y as Lang.Number) as Lang.Number {
        var i = secretAt(x, y);
        if (i < 0) { return -1; }
        secFound[i] = 1;
        set(x, y, T_FLOOR);
        return i;
    }
}

// ── Generator ──────────────────────────────────────────────────────────────
module DungeonGenerator {

    // Build one floor. Deterministic in (seed, floor, diff).
    function build(seed as Lang.Number, floor as Lang.Number, diff as Lang.Number) as DungeonMap {
        var m = new DungeonMap();
        var rng = new DmRng(seed + floor * 7919);
        m.floorNo = floor;
        m.theme = DmConst.zoneOf(floor);

        _carveRooms(m, rng, floor);
        _linkRooms(m);
        _placeDoors(m, rng, floor);
        _placePillars(m);

        // Start in room 0, stairs in the last room of the chain — always the
        // farthest walk the generator can promise.
        m.startX = m.roomX[0] + m.roomW[0] / 2;
        m.startY = m.roomY[0] + m.roomH[0] / 2;
        m.startDir = _openestDir(m, rng);
        m.stairX = m.roomX[m.roomN - 1] + m.roomW[m.roomN - 1] / 2;
        m.stairY = m.roomY[m.roomN - 1] + m.roomH[m.roomN - 1] / 2;
        m.set(m.stairX, m.stairY, T_STAIRS);
        m.markNear(m.startX, m.startY);

        _spawnMonsters(m, rng, floor, diff);
        _spawnLoot(m, rng, floor);
        _spawnSecrets(m, rng, floor);
        _spawnTraps(m, rng, floor);
        _spawnFeatures(m, rng, floor);

        return m;
    }

    // Face the longest open run from the start tile. Spawning into a wall two
    // feet from your nose is the worst possible first frame of a dungeon: the
    // whole screen is one flat surface and the game reads as broken.
    function _openestDir(m as DungeonMap, rng as DmRng) as Lang.Number {
        // N/E/S/W unit vectors without a lookup table or a branch chain: dx is
        // zero on the vertical axes and ±1 on the horizontal ones, and dy is
        // the same expression rotated a quarter turn.
        var start = rng.range(4);
        for (var k = 0; k < 4; k++) {
            var d = (start + k) % 4;
            var e = (d + 3) % 4;
            if (m.isWalkable(m.startX + (d % 2) * (2 - d),
                             m.startY + (e % 2) * (2 - e))) {
                return d;
            }
        }
        return start;
    }

    // ── Layout ──────────────────────────────────────────────────────────────
    function _carveRooms(m as DungeonMap, rng as DmRng, floor as Lang.Number) as Void {
        var target = rng.between(4, DM_MAX_ROOM);
        var placed = 0;
        for (var attempt = 0; attempt < 48 && placed < target; attempt++) {
            var w = rng.between(3, 5);
            var h = rng.between(3, 5);
            var x = rng.between(1, DM_W - w - 2);
            var y = rng.between(1, DM_H - h - 2);
            var clash = false;
            for (var i = 0; i < placed; i++) {
                if (x - 1 < m.roomX[i] + m.roomW[i] && x + w + 1 > m.roomX[i] &&
                    y - 1 < m.roomY[i] + m.roomH[i] && y + h + 1 > m.roomY[i]) {
                    clash = true;
                    break;
                }
            }
            if (clash) { continue; }
            m.roomX[placed] = x;
            m.roomY[placed] = y;
            m.roomW[placed] = w;
            m.roomH[placed] = h;
            m.roomArch[placed] = _pickArch(rng, floor, placed, w, h);
            for (var cy = y; cy < y + h; cy++) {
                for (var cx = x; cx < x + w; cx++) { m.set(cx, cy, T_FLOOR); }
            }
            placed++;
        }
        if (placed < 2) {
            // Degenerate seed — fall back to one big hall so a run is always playable.
            for (var cy = 1; cy < DM_H - 1; cy++) {
                for (var cx = 1; cx < DM_W - 1; cx++) { m.set(cx, cy, T_FLOOR); }
            }
            m.roomX[0] = 1; m.roomY[0] = 1; m.roomW[0] = 4; m.roomH[0] = 4; m.roomArch[0] = RM_PLAIN;
            m.roomX[1] = DM_W - 6; m.roomY[1] = DM_H - 6; m.roomW[1] = 4; m.roomH[1] = 4;
            m.roomArch[1] = RM_ARENA;
            placed = 2;
        }
        m.roomN = placed;
    }

    // Room 0 is always plain: the room you wake up in should not be a crypt.
    function _pickArch(rng as DmRng, floor as Lang.Number, idx as Lang.Number,
                       w as Lang.Number, h as Lang.Number) as Lang.Number {
        if (idx == 0) { return RM_PLAIN; }
        var r = rng.range(100);
        if (w >= 4 && h >= 4 && r < 18) { return RM_PILLARED; }
        if (floor >= 2 && r < 36) { return RM_CRYPT; }
        if (floor >= 3 && r < 52) { return RM_LIBRARY; }
        if (floor >= 3 && r < 66) { return RM_TREASURY; }
        if (floor >= 4 && r < 82) { return RM_ARENA; }
        return RM_PLAIN;
    }

    function _linkRooms(m as DungeonMap) as Void {
        for (var i = 1; i < m.roomN; i++) {
            var ax = m.roomX[i - 1] + m.roomW[i - 1] / 2;
            var ay = m.roomY[i - 1] + m.roomH[i - 1] / 2;
            var bx = m.roomX[i] + m.roomW[i] / 2;
            var by = m.roomY[i] + m.roomH[i] / 2;
            _carveH(m, ax, bx, ay);
            _carveV(m, ay, by, bx);
        }
    }

    function _placeDoors(m as DungeonMap, rng as DmRng, floor as Lang.Number) as Void {
        var budget = 2 + floor / 3;
        for (var i = 1; i < m.roomN && budget > 0; i++) {
            var dx = m.roomX[i] - 1;
            var dy = m.roomY[i] + m.roomH[i] / 2;
            if (m.at(dx, dy) != T_FLOOR) { continue; }
            if (_neighbourWalls(m, dx, dy) < 2) { continue; }
            // Treasuries lock up; elsewhere locks start on floor 3.
            var lockChance = (m.roomArch[i] == RM_TREASURY) ? 75 : 35;
            var locked = (floor >= 3 && rng.range(100) < lockChance);
            m.set(dx, dy, locked ? T_LOCKED : T_DOOR);
            budget--;
        }
    }

    // Pillars only ever go strictly inside a room, so the surrounding ring
    // stays connected and no pillar can ever wall off the stairs.
    function _placePillars(m as DungeonMap) as Void {
        for (var i = 0; i < m.roomN; i++) {
            if (m.roomArch[i] != RM_PILLARED) { continue; }
            var x = m.roomX[i];
            var y = m.roomY[i];
            var w = m.roomW[i];
            var h = m.roomH[i];
            if (w < 3 || h < 3) { continue; }
            _pillar(m, x + 1, y + 1);
            if (w >= 5 && h >= 5) { _pillar(m, x + w - 2, y + h - 2); }
            else if (w >= 4) { _pillar(m, x + w - 2, y + 1); }
        }
    }

    function _pillar(m as DungeonMap, x as Lang.Number, y as Lang.Number) as Void {
        if (m.at(x, y) != T_FLOOR) { return; }
        m.set(x, y, T_PILLAR);
    }

    // ── Population ──────────────────────────────────────────────────────────
    function _spawnMonsters(m as DungeonMap, rng as DmRng, floor as Lang.Number,
                            diff as Lang.Number) as Void {
        var target = 3 + floor / 2 + diff;
        if (target > DM_MAX_MON - 1) { target = DM_MAX_MON - 1; }
        var isBossFloor = (floor % 5 == 0);
        if (isBossFloor) { target -= 1; }

        var eliteChance = 0;
        if (floor >= 4) {
            eliteChance = 6 + floor * 3 + diff * 5;
            if (eliteChance > 48) { eliteChance = 48; }
        }

        for (var i = 0; i < target; i++) {
            var r = rng.range(m.roomN);
            if (r == 0 && m.roomN > 1) { r = 1; }   // never spawn in the start room
            var mx = rng.between(m.roomX[r], m.roomX[r] + m.roomW[r] - 1);
            var my = rng.between(m.roomY[r], m.roomY[r] + m.roomH[r] - 1);
            if (!m.isWalkable(mx, my)) { continue; }
            if (mx == m.startX && my == m.startY) { continue; }
            if (mx == m.stairX && my == m.stairY) { continue; }
            if (m.monsterAt(mx, my) >= 0) { continue; }

            var t = _pickMonster(rng, floor, m.roomArch[r]);
            var el = EL_NONE;
            if (rng.range(100) < eliteChance) { el = rng.between(EL_SAVAGE, EL_ARCANE); }
            // Arenas earn their name.
            if (m.roomArch[r] == RM_ARENA && el == EL_NONE && rng.range(100) < 25) {
                el = EL_SAVAGE;
            }
            _addMonster(m, mx, my, t, el, floor, diff);
        }

        if (isBossFloor) {
            var bx = m.stairX;
            var by = m.stairY - 1;
            if (!m.isWalkable(bx, by)) { bx = m.stairX + 1; by = m.stairY; }
            if (!m.isWalkable(bx, by)) { bx = m.stairX - 1; by = m.stairY; }
            if (m.isWalkable(bx, by) && m.monsterAt(bx, by) < 0) {
                _addMonster(m, bx, by, DmConst.bossFor(floor), EL_NONE, floor, diff);
            }
        }
    }

    // Depth gates which monsters exist at all; the room archetype then bends
    // the roll toward what belongs there.
    function _pickMonster(rng as DmRng, floor as Lang.Number, arch as Lang.Number) as Lang.Number {
        if (arch == RM_CRYPT && floor >= 2) {
            var rc = rng.range(100);
            if (rc < 55) { return MON_SKELETON; }
            if (rc < 75 && floor >= 7) { return MON_WRAITH; }
            if (rc < 85) { return MON_RAT; }
            return MON_SPIDER;
        }
        if (arch == RM_LIBRARY && floor >= 3) {
            var rl = rng.range(100);
            if (rl < 55) { return MON_CULTIST; }
            if (rl < 75) { return MON_SPIDER; }
            return MON_SKELETON;
        }
        if (arch == RM_ARENA && floor >= 4) {
            var ra = rng.range(100);
            if (ra < 40) { return MON_KNIGHT; }
            if (ra < 70 && floor >= 7) { return MON_OGRE; }
            if (ra < 85 && floor >= 10) { return MON_DEMON; }
            return MON_SKELETON;
        }

        var r = rng.range(100);
        if (floor <= 1) {
            if (r < 55) { return MON_RAT; }
            return MON_GOBLIN;
        }
        if (floor <= 3) {
            if (r < 25) { return MON_RAT; }
            if (r < 55) { return MON_GOBLIN; }
            if (r < 80) { return MON_SKELETON; }
            return MON_SPIDER;
        }
        if (floor <= 6) {
            if (r < 15) { return MON_GOBLIN; }
            if (r < 40) { return MON_SKELETON; }
            if (r < 60) { return MON_SPIDER; }
            if (r < 82) { return MON_CULTIST; }
            return MON_KNIGHT;
        }
        if (floor <= 9) {
            if (r < 15) { return MON_SKELETON; }
            if (r < 32) { return MON_SPIDER; }
            if (r < 50) { return MON_CULTIST; }
            if (r < 70) { return MON_KNIGHT; }
            if (r < 88) { return MON_WRAITH; }
            return MON_OGRE;
        }
        if (r < 14) { return MON_CULTIST; }
        if (r < 34) { return MON_KNIGHT; }
        if (r < 56) { return MON_WRAITH; }
        if (r < 78) { return MON_OGRE; }
        return MON_DEMON;
    }

    function _spawnLoot(m as DungeonMap, rng as DmRng, floor as Lang.Number) as Void {
        var target = 2 + floor / 3;
        if (target > DM_MAX_LOOT - 2) { target = DM_MAX_LOOT - 2; }
        for (var i = 0; i < target; i++) {
            var r = rng.range(m.roomN);
            var lx = rng.between(m.roomX[r], m.roomX[r] + m.roomW[r] - 1);
            var ly = rng.between(m.roomY[r], m.roomY[r] + m.roomH[r] - 1);
            if (!m.isWalkable(lx, ly)) { continue; }
            if (lx == m.stairX && ly == m.stairY) { continue; }
            if (m.lootAt(lx, ly) >= 0 || m.monsterAt(lx, ly) >= 0) { continue; }
            _addLoot(m, lx, ly, _pickLoot(rng, floor, m.roomArch[r]), floor, rng, false);
        }
    }

    function _pickLoot(rng as DmRng, floor as Lang.Number, arch as Lang.Number) as Lang.Number {
        if (arch == RM_TREASURY) {
            var rt = rng.range(100);
            if (rt < 40) { return LOOT_GOLD; }
            if (rt < 58) { return LOOT_WEAPON; }
            if (rt < 74) { return LOOT_ARMOR; }
            if (rt < 88 && floor >= 4) { return LOOT_RING; }
            if (floor >= 6) { return LOOT_AMULET; }
            return LOOT_GOLD;
        }
        if (arch == RM_LIBRARY) {
            var rl = rng.range(100);
            if (rl < 40) { return LOOT_SCROLL; }
            if (rl < 72) { return LOOT_ETHER; }
            if (rl < 86) { return LOOT_KEY; }
            return LOOT_GOLD;
        }
        var r = rng.range(100);
        if (r < 26) { return LOOT_GOLD; }
        if (r < 44) { return LOOT_POTION; }
        if (r < 56) { return LOOT_ETHER; }
        if (r < 64) { return LOOT_SCROLL; }
        if (r < 74) { return LOOT_KEY; }
        if (r < 82) { return LOOT_BOMB; }
        if (r < 92) { return LOOT_WEAPON; }
        return LOOT_ARMOR;
    }

    // Secret walls: a stash or vault behind a dead-end face, or a genuine
    // shortcut connecting two corridors.
    function _spawnSecrets(m as DungeonMap, rng as DmRng, floor as Lang.Number) as Void {
        var want = 1;
        if (floor >= 4) { want = 2; }
        if (floor >= 9) { want = DM_MAX_SEC; }
        for (var k = 0; k < want; k++) {
            var wantPassage = (k == 1);
            var made = false;
            for (var attempt = 0; attempt < 50 && !made; attempt++) {
                var x = rng.between(1, DM_W - 2);
                var y = rng.between(1, DM_H - 2);
                if (m.at(x, y) != T_WALL) { continue; }
                if (m.secretAt(x, y) >= 0) { continue; }
                var wE = m.isWalkable(x + 1, y);
                var wW = m.isWalkable(x - 1, y);
                var wN = m.isWalkable(x, y - 1);
                var wS = m.isWalkable(x, y + 1);
                var touches = 0;
                if (wE) { touches++; }
                if (wW) { touches++; }
                if (wN) { touches++; }
                if (wS) { touches++; }
                if (wantPassage) {
                    // A shortcut has to actually go somewhere: opposite faces.
                    if (!((wE && wW) || (wN && wS))) { continue; }
                    _addSecret(m, x, y, SEC_PASSAGE, LOOT_GOLD, 0);
                    made = true;
                } else {
                    if (touches != 1) { continue; }
                    var vault = (floor >= 5 && rng.range(100) < 35);
                    if (vault) {
                        _addSecret(m, x, y, SEC_VAULT, LOOT_GOLD, 60 + floor * 22);
                    } else {
                        var kind = _pickSecretItem(rng, floor);
                        _addSecret(m, x, y, SEC_STASH, kind, _lootValue(kind, floor, rng, true));
                    }
                    made = true;
                }
                if (made) { m.set(x, y, T_SECRET); }
            }
        }
    }

    function _pickSecretItem(rng as DmRng, floor as Lang.Number) as Lang.Number {
        var r = rng.range(100);
        if (floor >= 6 && r < 18) { return LOOT_AMULET; }
        if (floor >= 4 && r < 40) { return LOOT_RING; }
        if (r < 62) { return LOOT_WEAPON; }
        if (r < 82) { return LOOT_ARMOR; }
        return LOOT_GOLD;
    }

    function _spawnTraps(m as DungeonMap, rng as DmRng, floor as Lang.Number) as Void {
        var target = 1 + floor / 3;
        if (target > DM_MAX_TRAP) { target = DM_MAX_TRAP; }
        for (var i = 0; i < target; i++) {
            var tx = rng.between(1, DM_W - 2);
            var ty = rng.between(1, DM_H - 2);
            if (m.at(tx, ty) != T_FLOOR) { continue; }
            if (tx == m.startX && ty == m.startY) { continue; }
            if (m.monsterAt(tx, ty) >= 0 || m.lootAt(tx, ty) >= 0) { continue; }
            if (m.trapAt(tx, ty) >= 0) { continue; }
            if (m.trapN >= DM_MAX_TRAP) { break; }
            var k = TRAP_SPIKE;
            var r = rng.range(100);
            if (r < 30) { k = TRAP_DART; }
            else if (r < 50 && floor >= 3) { k = TRAP_PIT; }
            else if (r < 68 && floor >= 5) { k = TRAP_RUNE; }
            var idx = m.trapN;
            m.trapX[idx] = tx;
            m.trapY[idx] = ty;
            m.trapKind[idx] = k;
            m.trapArmed[idx] = 1;
            m.trapN++;
        }
    }

    // At most two per floor — a shrine you can count on stops being a gamble.
    function _spawnFeatures(m as DungeonMap, rng as DmRng, floor as Lang.Number) as Void {
        var want = 1;
        if (floor >= 4) { want = 2; }
        for (var k = 0; k < want; k++) {
            var kind = FEAT_SHRINE;
            var r = rng.range(100);
            if (r < 34) { kind = FEAT_FOUNTAIN; }
            else if (r < 62 && floor >= 3) { kind = FEAT_MERCHANT; }
            for (var attempt = 0; attempt < 30; attempt++) {
                var ri = rng.range(m.roomN);
                if (ri == 0 && m.roomN > 1) { ri = 1; }
                var fx = rng.between(m.roomX[ri], m.roomX[ri] + m.roomW[ri] - 1);
                var fy = rng.between(m.roomY[ri], m.roomY[ri] + m.roomH[ri] - 1);
                if (!m.isWalkable(fx, fy)) { continue; }
                if (fx == m.stairX && fy == m.stairY) { continue; }
                if (m.lootAt(fx, fy) >= 0 || m.monsterAt(fx, fy) >= 0) { continue; }
                if (m.featAt(fx, fy) >= 0 || m.trapAt(fx, fy) >= 0) { continue; }
                if (m.featN >= DM_MAX_FEAT) { return; }
                var i = m.featN;
                m.featX[i] = fx;
                m.featY[i] = fy;
                m.featKind[i] = kind;
                m.featUsed[i] = 0;
                m.featN++;
                break;
            }
        }
    }

    // ── Pool helpers ────────────────────────────────────────────────────────
    function _addMonster(m as DungeonMap, x as Lang.Number, y as Lang.Number,
                         t as Lang.Number, elite as Lang.Number,
                         floor as Lang.Number, diff as Lang.Number) as Void {
        if (m.monN >= DM_MAX_MON) { return; }
        var i = m.monN;
        m.monX[i] = x;
        m.monY[i] = y;
        m.monType[i] = t;
        m.monElite[i] = elite;
        m.monHp[i] = eliteHp(DmConst.monHp(t, floor, diff), elite);
        m.monAlive[i] = true;
        m.monN++;
    }

    function eliteHp(base as Lang.Number, elite as Lang.Number) as Lang.Number {
        if (elite == EL_NONE) { return base; }
        if (elite == EL_ARMORED) { return base * 9 / 5; }
        return base * 7 / 5;
    }

    function _lootValue(kind as Lang.Number, floor as Lang.Number, rng as DmRng,
                        rich as Lang.Boolean) as Lang.Number {
        if (kind == LOOT_GOLD) {
            var g = rng.between(10, 24) + floor * 5;
            if (rich) { g = g * 3; }
            return g;
        }
        if (kind == LOOT_WEAPON) {
            var w = 1 + floor / 3;
            if (rich) { w += 1; }
            if (w > 5) { w = 5; }
            return w;
        }
        if (kind == LOOT_ARMOR) {
            var a = 1 + floor / 4;
            if (rich) { a += 1; }
            if (a > 5) { a = 5; }
            return a;
        }
        if (kind == LOOT_RING)   { return rng.between(1, 4); }
        if (kind == LOOT_AMULET) { return rng.between(1, 3); }
        return 1;
    }

    function _addLoot(m as DungeonMap, x as Lang.Number, y as Lang.Number, kind as Lang.Number,
                      floor as Lang.Number, rng as DmRng, rich as Lang.Boolean) as Void {
        if (m.lootN >= DM_MAX_LOOT) { return; }
        var i = m.lootN;
        m.lootX[i] = x;
        m.lootY[i] = y;
        m.lootKind[i] = kind;
        m.lootVal[i] = _lootValue(kind, floor, rng, rich);
        m.lootTaken[i] = 0;
        m.lootN++;
    }

    function _addSecret(m as DungeonMap, x as Lang.Number, y as Lang.Number, type as Lang.Number,
                        kind as Lang.Number, val as Lang.Number) as Void {
        if (m.secN >= DM_MAX_SEC) { return; }
        var i = m.secN;
        m.secX[i] = x;
        m.secY[i] = y;
        m.secType[i] = type;
        m.secKind[i] = kind;
        m.secVal[i] = val;
        m.secFound[i] = 0;
        m.secN++;
    }

    function _carveH(m as DungeonMap, x1 as Lang.Number, x2 as Lang.Number, y as Lang.Number) as Void {
        var a = (x1 < x2) ? x1 : x2;
        var b = (x1 < x2) ? x2 : x1;
        for (var x = a; x <= b; x++) {
            if (m.at(x, y) == T_WALL) { m.set(x, y, T_FLOOR); }
        }
    }

    function _carveV(m as DungeonMap, y1 as Lang.Number, y2 as Lang.Number, x as Lang.Number) as Void {
        var a = (y1 < y2) ? y1 : y2;
        var b = (y1 < y2) ? y2 : y1;
        for (var y = a; y <= b; y++) {
            if (m.at(x, y) == T_WALL) { m.set(x, y, T_FLOOR); }
        }
    }

    function _neighbourWalls(m as DungeonMap, x as Lang.Number, y as Lang.Number) as Lang.Number {
        var n = 0;
        if (m.at(x, y - 1) == T_WALL) { n++; }
        if (m.at(x, y + 1) == T_WALL) { n++; }
        if (m.at(x - 1, y) == T_WALL) { n++; }
        if (m.at(x + 1, y) == T_WALL) { n++; }
        return n;
    }
}
