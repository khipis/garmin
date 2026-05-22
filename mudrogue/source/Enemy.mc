// ═══════════════════════════════════════════════════════════════
// Enemy.mc — Templates, scaling, AI.
//
// Each template is a flat tuple [name, baseHp, baseAtk, baseDef,
// xp, gold]. Floor scaling multiplies hp and atk by (1 + floor/9)
// rounded up — gentle early, steep at depth.
//
// The "boss" template is special: it gets a bigger base + an extra
// per-floor bump. The AI is the same for all enemies but the random
// chance to defend rises as their HP gets low (smart caution).
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

// Action codes returned by Enemy.pickAction()
const EA_ATTACK = 0;
const EA_DEFEND = 1;

// Index layout for the templates below.
const ET_NAME    = 0;
const ET_HP      = 1;
const ET_ATK     = 2;
const ET_DEF     = 3;
const ET_XP      = 4;
const ET_GOLD    = 5;

class Enemy {
    var name;
    var hp;
    var maxHp;
    var atk;
    var def;
    var xpReward;
    var goldReward;
    var defending;     // 1 if defend chosen this turn

    // The template bank — order matters because EventSystem picks an
    // index biased by floor depth.
    static var TEMPLATES = [
        ["Rat",      8,   2, 0,  4,   5 ],
        ["Goblin",   14,  4, 1,  8,  12 ],
        ["Skeleton", 20,  5, 2, 12,  18 ],
        ["Orc",      28,  7, 2, 18,  25 ],
        ["Troll",    40,  9, 3, 28,  40 ],
        ["Wraith",   32, 12, 1, 35,  50 ]
    ];

    static var BOSS_TEMPLATE =
        ["Dragon",   60, 11, 4, 80, 120];

    function initialize() {
        name = ""; hp = 0; maxHp = 0; atk = 0; def = 0;
        xpReward = 0; goldReward = 0; defending = 0;
    }

    // Build a regular enemy from a template index, scaled to floor.
    function fromTemplate(idx, floor) {
        var t = TEMPLATES[idx];
        // Scale: every 9 floors roughly doubles HP/ATK.
        var scaleNum = 9 + floor;
        var scaleDen = 9;
        name       = t[ET_NAME];
        maxHp      = (t[ET_HP]  * scaleNum) / scaleDen;
        hp         = maxHp;
        atk        = (t[ET_ATK] * scaleNum) / scaleDen;
        def        = t[ET_DEF];
        xpReward   = (t[ET_XP]  * scaleNum) / scaleDen;
        goldReward = (t[ET_GOLD] * scaleNum) / scaleDen;
        defending  = 0;
    }

    function fromBoss(floor) {
        var t = BOSS_TEMPLATE;
        var scaleNum = 6 + floor;
        var scaleDen = 6;
        name       = "Boss " + t[ET_NAME];
        maxHp      = ((t[ET_HP]  * scaleNum) / scaleDen) + floor * 3;
        hp         = maxHp;
        atk        = ((t[ET_ATK] * scaleNum) / scaleDen) + floor / 3;
        def        = t[ET_DEF];
        xpReward   = ((t[ET_XP]  * scaleNum) / scaleDen);
        goldReward = ((t[ET_GOLD] * scaleNum) / scaleDen);
        defending  = 0;
    }

    function isAlive() { return hp > 0; }

    // AI — 20% defend baseline, rising to ~50% when low HP. Bosses
    // are tougher: never defend (always attack) so they feel relentless.
    function pickAction(isBoss) {
        if (isBoss) { return EA_ATTACK; }
        var threshold = 20;
        if (hp * 3 < maxHp) { threshold = 50; }   // < 33% HP
        var roll = Math.rand() % 100;
        return (roll < threshold) ? EA_DEFEND : EA_ATTACK;
    }

    // Compute enemy attack damage delivered to player (random ±2).
    function rollAttack() {
        return atk + (Math.rand() % 3);
    }
}
