// ═══════════════════════════════════════════════════════════════
// DungeonGenerator.mc — Build a single floor's event sequence.
//
// On every floor entry we roll N events (5..7) and the player walks
// through them in order. The last event on a "boss floor" (every
// BOSS_INTERVAL floors) is always the boss. Weighted rolls give the
// dungeon variety while keeping the flow predictable:
//
//   Floor 1-2  : 60% enemy, 20% treasure, 10% trap,  0% merch, 10% rest
//   Floor 3-9  : 55% enemy, 15% treasure, 15% trap, 10% merch,  5% rest
//   Floor 10+  : 60% enemy, 15% treasure, 15% trap,  5% merch,  5% rest
//
// Enemy template index is biased by floor — higher floor → tougher
// monsters dominate the pool.
//
// All randomness uses Math.rand() which is seeded by the runtime's
// system clock — each new game gets a fresh sequence.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

const BOSS_INTERVAL = 5;

class DungeonGenerator {
    // Returns a list (Array) of GameEvent instances for the given floor.
    static function buildFloor(floor) {
        var events = [];
        var nEvents = 4 + (Math.rand() % 3);    // 4..6 non-boss events
        var isBossFloor = (floor % BOSS_INTERVAL == 0);
        if (isBossFloor) { nEvents = 3 + (Math.rand() % 2); } // 3..4 + boss

        for (var i = 0; i < nEvents; i++) {
            events.add(_rollEvent(floor));
        }
        if (isBossFloor) {
            var b = new GameEvent(EV_BOSS);
            b.enemy = new Enemy();
            b.enemy.fromBoss(floor);
            b.label = b.enemy.name + " appears!";
            events.add(b);
        }
        return events;
    }

    // ── Internals ───────────────────────────────────────────────────
    hidden static function _rollEvent(floor) {
        var roll = Math.rand() % 100;
        var w_enemy; var w_treasure; var w_trap; var w_merch; var w_rest;
        if (floor <= 2) {
            w_enemy = 60; w_treasure = 80; w_trap = 90;
            w_merch = 90; w_rest = 100;
        } else if (floor <= 9) {
            w_enemy = 55; w_treasure = 70; w_trap = 85;
            w_merch = 95; w_rest = 100;
        } else {
            w_enemy = 60; w_treasure = 75; w_trap = 90;
            w_merch = 95; w_rest = 100;
        }
        if (roll < w_enemy)      { return _makeEnemy(floor);    }
        if (roll < w_treasure)   { return _makeTreasure(floor); }
        if (roll < w_trap)       { return _makeTrap(floor);     }
        if (roll < w_merch)      { return _makeMerchant(floor); }
        return _makeRest(floor);
    }

    hidden static function _makeEnemy(floor) {
        var e = new GameEvent(EV_ENEMY);
        e.enemy = new Enemy();
        // Pick template biased by floor depth.
        var poolMax;
        if (floor <= 2)       { poolMax = 2; }      // Rat / Goblin / Skel
        else if (floor <= 5)  { poolMax = 4; }
        else                  { poolMax = Enemy.TEMPLATES.size() - 1; }
        var poolMin = 0;
        if (floor >= 4)       { poolMin = 1; }      // no rats past F3
        if (floor >= 8)       { poolMin = 2; }
        var span = poolMax - poolMin + 1;
        if (span < 1) { span = 1; }
        var idx = poolMin + (Math.rand() % span);
        if (idx > Enemy.TEMPLATES.size() - 1) { idx = Enemy.TEMPLATES.size() - 1; }
        e.enemy.fromTemplate(idx, floor);
        e.label = "A " + e.enemy.name + " blocks the path!";
        return e;
    }

    hidden static function _makeTreasure(floor) {
        var e = new GameEvent(EV_TREASURE);
        // 70% gold, 30% item
        if ((Math.rand() % 10) < 7) {
            e.goldAmt = 6 + (Math.rand() % 12) + floor;
            e.label   = "Chest! +" + e.goldAmt.format("%d") + " gold.";
        } else {
            e.itemKind = Math.rand() % 3;
            var itemName = _itemName(e.itemKind);
            e.label    = "Chest! +1 " + itemName + ".";
        }
        return e;
    }

    hidden static function _makeTrap(floor) {
        var e = new GameEvent(EV_TRAP);
        e.damage = 3 + (Math.rand() % 5) + (floor / 3);
        e.label  = "A trap! -" + e.damage.format("%d") + " HP.";
        return e;
    }

    hidden static function _makeMerchant(floor) {
        var e = new GameEvent(EV_MERCHANT);
        // Merchant offers all three items at fixed prices that scale.
        // Prices live in goldAmt as a single packed value for compactness:
        //   potionPrice  = base
        //   bombPrice    = base + 4
        //   shieldPrice  = base + 8
        e.goldAmt = 8 + floor;
        e.label   = "A wandering merchant.";
        return e;
    }

    hidden static function _makeRest(floor) {
        var e = new GameEvent(EV_REST);
        e.goldAmt = 6 + floor;        // cost to rest
        e.label   = "A quiet sanctuary.";
        return e;
    }

    static function _itemName(k) {
        if (k == 0) { return "potion"; }
        if (k == 1) { return "bomb";   }
        return "shield";
    }
}
