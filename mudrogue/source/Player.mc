// ═══════════════════════════════════════════════════════════════
// Player.mc — Hero stats, inventory, level-up curve.
//
// Inventory is intentionally a flat trio of consumable counts rather
// than a generic item list — keeps things light on memory and the
// inventory UI trivial:
//   potion : restores 25 HP
//   bomb   : deals 22 damage to the current enemy
//   shield : grants +5 DEF for the remainder of the current combat
//            (stacking, up to 3 uses per fight)
//
// XP curve: level N needs (15 + 10*(N-1)) XP. Reaching the next level
// awards +6 MaxHP, +1 ATK and (every other level) +1 DEF.
// ═══════════════════════════════════════════════════════════════

class Player {
    var hp;
    var maxHp;
    var atk;
    var def;
    var level;
    var xp;
    var xpToNext;
    var gold;

    // Inventory
    var potions;
    var bombs;
    var shields;

    // Combat-scoped buffs (cleared between fights)
    var defBonus;

    function initialize() {
        hp        = 30;
        maxHp     = 30;
        atk       = 4;
        def       = 1;
        level     = 1;
        xp        = 0;
        xpToNext  = 15;
        gold      = 10;
        potions   = 2;
        bombs     = 0;
        shields   = 1;
        defBonus  = 0;
    }

    // Wipe combat-only state at the end of every fight.
    function resetCombatBuffs() { defBonus = 0; }

    function isAlive() { return hp > 0; }

    // Apply damage (defending halves it after DEF reduction).
    function takeDamage(amount, defending) {
        var d = amount - def - defBonus;
        if (defending) { d = d - 3; }
        if (d < 1) { d = 1; }
        hp = hp - d;
        if (hp < 0) { hp = 0; }
        return d;
    }

    function heal(amount) {
        var before = hp;
        hp = hp + amount;
        if (hp > maxHp) { hp = maxHp; }
        return hp - before;
    }

    // Award XP. Returns the number of level-ups triggered so the UI
    // can show one "LEVEL UP!" screen per gain. (We cap at one per
    // call in practice — XP awards are small.)
    function gainXp(amount) {
        xp = xp + amount;
        var ups = 0;
        while (xp >= xpToNext) {
            xp = xp - xpToNext;
            level    = level + 1;
            xpToNext = 15 + 10 * (level - 1);
            maxHp    = maxHp + 6;
            hp       = hp + 6;
            atk      = atk + 1;
            if (level % 2 == 0) { def = def + 1; }
            ups = ups + 1;
        }
        return ups;
    }

    function addGold(g)   { gold = gold + g; }
    function spendGold(g) {
        if (gold < g) { return false; }
        gold = gold - g;
        return true;
    }

    // ── Item use ────────────────────────────────────────────────────
    function usePotion() {
        if (potions <= 0) { return 0; }
        potions = potions - 1;
        return heal(25);
    }

    // Bomb deals fixed damage to an enemy (returns dmg or 0 if none).
    function useBomb(enemy) {
        if (bombs <= 0 || enemy == null) { return 0; }
        bombs = bombs - 1;
        var d = 22;
        enemy.hp = enemy.hp - d;
        if (enemy.hp < 0) { enemy.hp = 0; }
        return d;
    }

    function useShield() {
        if (shields <= 0) { return 0; }
        shields = shields - 1;
        defBonus = defBonus + 5;
        return 5;
    }

    function hasAnyItem() { return potions + bombs + shields > 0; }
}
