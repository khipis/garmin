// ═══════════════════════════════════════════════════════════════════════════
// CharacterSystem.mc — The hero: stats, XP/levelling, mana, inventory, gear.
//
// Kept deliberately flat (plain numbers, no nested objects) so the whole hero
// serialises into a handful of save keys. Gear bonuses are *derived* rather
// than baked into the base stats, so swapping a ring can never corrupt a save.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;

class Character {

    var cls;
    var level;
    var xp;
    var hp;
    var maxHp;       // base — see maxHpTotal() for the equipped value
    var mana;
    var maxMana;
    var str;
    var def;
    var mag;
    var luck;
    var gold;

    var weapon;      // tier 0..5
    var armor;       // tier 0..5
    var ring;        // 0 = none, 1..4
    var amulet;      // 0 = none, 1..3

    var potions;
    var ethers;
    var scrolls;
    var keys;
    var bombs;

    var poison;      // remaining poisoned turns
    var ward;        // remaining turns of magical shield
    var stun;        // hero loses the next combat action

    function initialize(c as Lang.Number) {
        cls = c;
        level = 1;
        xp = 0;
        gold = 0;
        weapon = 0;
        armor = 0;
        ring = 0;
        amulet = 0;
        potions = 2;
        ethers = 0;
        scrolls = 1;
        keys = 0;
        bombs = 0;
        poison = 0;
        ward = 0;
        stun = 0;

        if (c == CLS_ROGUE) {
            maxHp = 34; str = 6; def = 2; mag = 2; luck = 6; maxMana = 14;
            bombs = 1;
        } else if (c == CLS_MAGE) {
            maxHp = 28; str = 3; def = 2; mag = 7; luck = 3; maxMana = 30;
            potions = 1; ethers = 2; scrolls = 2;
        } else if (c == CLS_PALADIN) {
            maxHp = 42; str = 5; def = 5; mag = 4; luck = 2; maxMana = 20;
        } else {
            maxHp = 46; str = 7; def = 4; mag = 0; luck = 2; maxMana = 8;
        }
        hp = maxHpTotal();
        mana = maxManaTotal();
    }

    // ── Derived stats (base + equipment) ────────────────────────────────────
    function maxHpTotal() as Lang.Number {
        var v = maxHp;
        if (amulet == 1) { v += 25; }
        return v;
    }

    function maxManaTotal() as Lang.Number {
        var v = maxMana;
        if (ring == 3) { v += 12; }
        return v;
    }

    function totalStr() as Lang.Number {
        var v = str;
        if (ring == 1) { v += 4; }
        return v;
    }

    function totalDefense() as Lang.Number {
        var v = def + DmConst.armorDef(armor);
        if (ring == 2) { v += 3; }
        return v;
    }

    function totalMagic() as Lang.Number {
        var v = mag;
        if (amulet == 3) { v += 3; }
        return v;
    }

    function totalLuck() as Lang.Number {
        var v = luck;
        if (ring == 4) { v += 4; }
        return v;
    }

    function attackPower() as Lang.Number {
        return DmConst.weaponDmg(weapon) + totalStr();
    }

    // Paladins and mages get a small class discount on top of the amulet.
    function spellCost(s as Lang.Number) as Lang.Number {
        var c = DmConst.spellBaseCost(s);
        if (amulet == 2) { c -= 2; }
        if (cls == CLS_MAGE) { c -= 1; }
        if (c < 2) { c = 2; }
        return c;
    }

    function canCast(s as Lang.Number) as Lang.Boolean {
        return mana >= spellCost(s);
    }

    function isAlive() as Lang.Boolean { return hp > 0; }

    function heal(n as Lang.Number) as Lang.Number {
        var cap = maxHpTotal();
        var before = hp;
        hp += n;
        if (hp > cap) { hp = cap; }
        if (hp < 0) { hp = 0; }
        return hp - before;
    }

    function hurt(n as Lang.Number) as Lang.Number {
        if (n < 0) { n = 0; }
        // A ward eats the blow before flesh does.
        if (ward > 0 && n > 0) {
            var soak = 3 + totalMagic();
            if (soak > n) { soak = n; }
            n -= soak;
            ward--;
        }
        hp -= n;
        if (hp < 0) { hp = 0; }
        return n;
    }

    function restoreMana(n as Lang.Number) as Lang.Number {
        var cap = maxManaTotal();
        var before = mana;
        mana += n;
        if (mana > cap) { mana = cap; }
        return mana - before;
    }

    function spendMana(n as Lang.Number) as Void {
        mana -= n;
        if (mana < 0) { mana = 0; }
    }

    // Walking the halls trickles mana back — exploring is never wasted time.
    function stepRegen(steps as Lang.Number) as Void {
        if (steps % 2 == 0) { restoreMana(1); }
    }

    // Returns true when the hero gained a level (caller opens the choice screen).
    function addXp(n as Lang.Number) as Lang.Boolean {
        xp += n;
        var leveled = false;
        while (xp >= DmConst.xpForLevel(level)) {
            xp -= DmConst.xpForLevel(level);
            level++;
            leveled = true;
        }
        return leveled;
    }

    function applyUpgrade(choice as Lang.Number) as Lang.String {
        if (choice == UP_STR) {
            str += 2;
            return "+2 STRENGTH";
        }
        if (choice == UP_DEF) {
            def += 2;
            return "+2 DEFENSE";
        }
        if (choice == UP_MAGIC) {
            mag += 2;
            maxMana += 8;
            restoreMana(8);
            return "+2 MAGIC  +8 MANA";
        }
        if (choice == UP_LUCK) {
            luck += 2;
            return "+2 LUCK";
        }
        maxHp += 12;
        heal(12);
        return "+12 MAX HP";
    }

    function upgradeLabel(choice as Lang.Number) as Lang.String {
        if (choice == UP_STR)   { return "+2 STR   dmg " + attackPower().format("%d"); }
        if (choice == UP_DEF)   { return "+2 DEF   now " + totalDefense().format("%d"); }
        if (choice == UP_MAGIC) { return "+2 MAG +8 MANA"; }
        if (choice == UP_LUCK)  { return "+2 LUCK  more crits"; }
        return "+12 HP   max " + maxHpTotal().format("%d");
    }

    // ── Loot ────────────────────────────────────────────────────────────────
    // Returns the message shown on the loot card.
    function takeLoot(kind as Lang.Number, val as Lang.Number) as Lang.String {
        if (kind == LOOT_GOLD) {
            gold += val;
            return "+" + val.format("%d") + " GOLD";
        }
        if (kind == LOOT_POTION) {
            potions += 1;
            return "POTIONS x" + potions.format("%d");
        }
        if (kind == LOOT_ETHER) {
            ethers += 1;
            return "ETHER x" + ethers.format("%d");
        }
        if (kind == LOOT_SCROLL) {
            scrolls += 1;
            return "SCROLLS x" + scrolls.format("%d");
        }
        if (kind == LOOT_KEY) {
            keys += 1;
            return "KEYS x" + keys.format("%d");
        }
        if (kind == LOOT_BOMB) {
            bombs += 1;
            return "BOMBS x" + bombs.format("%d");
        }
        if (kind == LOOT_WEAPON) {
            if (val > weapon) {
                weapon = val;
                return DmConst.weaponName(weapon) + "  DMG " + attackPower().format("%d");
            }
            gold += 20;
            return "ALREADY BETTER  +20g";
        }
        if (kind == LOOT_ARMOR) {
            if (val > armor) {
                armor = val;
                return DmConst.armorName(armor) + "  DEF " + totalDefense().format("%d");
            }
            gold += 20;
            return "ALREADY BETTER  +20g";
        }
        if (kind == LOOT_RING) {
            if (ring == 0 || val != ring) {
                var old = ring;
                ring = val;
                if (hp > maxHpTotal()) { hp = maxHpTotal(); }
                if (mana > maxManaTotal()) { mana = maxManaTotal(); }
                if (old != 0) { gold += 25; }
                return DmConst.ringName(ring) + "  " + DmConst.ringEffect(ring);
            }
            gold += 25;
            return "A TWIN RING  +25g";
        }
        if (kind == LOOT_AMULET) {
            if (amulet == 0 || val != amulet) {
                var old2 = amulet;
                amulet = val;
                if (hp > maxHpTotal()) { hp = maxHpTotal(); }
                if (old2 != 0) { gold += 25; }
                return DmConst.amuletName(amulet) + "  " + DmConst.amuletEffect(amulet);
            }
            gold += 25;
            return "A TWIN AMULET  +25g";
        }
        return "NOTHING";
    }

    // ── Fitness bonus ───────────────────────────────────────────────────────
    // Steps become "Adventure Energy": a small head start, never a substitute
    // for playing well (hard capped).
    function applyAdventureEnergy(steps as Lang.Number, activeMinutes as Lang.Number) as Lang.String or Null {
        if (steps <= 0 && activeMinutes <= 0) { return null; }
        var bonusPotions = steps / 4000;
        if (bonusPotions > 2) { bonusPotions = 2; }
        var bonusGold = steps / 200;
        if (bonusGold > 60) { bonusGold = 60; }
        var extraHp = activeMinutes / 10;
        if (extraHp > 10) { extraHp = 10; }

        potions += bonusPotions;
        gold += bonusGold;
        maxHp += extraHp;
        heal(extraHp);

        if (bonusPotions <= 0 && bonusGold <= 0 && extraHp <= 0) { return null; }
        return "ENERGY +" + bonusGold.format("%d") + "g +" + bonusPotions.format("%d") + "pot";
    }

    // ── Save / load ─────────────────────────────────────────────────────────
    function toDict() as Lang.Dictionary {
        return {
            "cl" => cls, "lv" => level, "xp" => xp, "hp" => hp, "mhp" => maxHp,
            "mn" => mana, "mmn" => maxMana,
            "st" => str, "df" => def, "mg" => mag, "lk" => luck,
            "gd" => gold, "wp" => weapon, "ar" => armor, "rg" => ring, "am" => amulet,
            "po" => potions, "et" => ethers, "sc" => scrolls, "ky" => keys, "bo" => bombs,
            "ps" => poison, "wd" => ward
        };
    }

    function fromDict(d as Lang.Dictionary) as Void {
        if (d == null) { return; }
        cls     = _n(d["cl"], cls);
        level   = _n(d["lv"], level);
        xp      = _n(d["xp"], xp);
        maxHp   = _n(d["mhp"], maxHp);
        maxMana = _n(d["mmn"], maxMana);
        str     = _n(d["st"], str);
        def     = _n(d["df"], def);
        mag     = _n(d["mg"], mag);
        luck    = _n(d["lk"], luck);
        gold    = _n(d["gd"], gold);
        weapon  = _n(d["wp"], weapon);
        armor   = _n(d["ar"], armor);
        ring    = _n(d["rg"], 0);
        amulet  = _n(d["am"], 0);
        potions = _n(d["po"], potions);
        ethers  = _n(d["et"], 0);
        scrolls = _n(d["sc"], scrolls);
        keys    = _n(d["ky"], keys);
        bombs   = _n(d["bo"], 0);
        poison  = _n(d["ps"], 0);
        ward    = _n(d["wd"], 0);
        stun    = 0;
        hp      = _n(d["hp"], hp);
        mana    = _n(d["mn"], mana);
        if (hp > maxHpTotal()) { hp = maxHpTotal(); }
        if (mana > maxManaTotal()) { mana = maxManaTotal(); }
    }

    hidden function _n(v, def2 as Lang.Number) as Lang.Number {
        if (v instanceof Lang.Number) { return v; }
        return def2;
    }
}
