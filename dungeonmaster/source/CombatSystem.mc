// ═══════════════════════════════════════════════════════════════════════════
// CombatSystem.mc — Turn based encounter resolution.
//
// Damage is dominated by stats, not dice: the random term is a small ±band on
// top of (weapon + strength − effective defense), so gear, spells and upgrade
// choices are what decide a fight. Every monster has one readable habit, and
// every boss has a two-beat pattern you can learn and play around.
//
// The class also owns the *presentation* state the view animates: which effect
// to draw, how much damage to float, how hard to shake. It never touches the
// screen itself.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Lang;
using Toybox.Math;

// Effects the view renders on top of the fight.
const FX_NONE   = 0;
const FX_SLASH  = 1;
const FX_HEAVY  = 2;
const FX_FIRE   = 3;
const FX_FROST  = 4;
const FX_HEAL   = 5;
const FX_WARD   = 6;
const FX_BOMB   = 7;
const FX_ENEMY  = 8;
const FX_MISS   = 9;

class CombatSystem {

    var active;
    var monIdx;
    var monType;
    var monElite;
    var monHp;
    var monMaxHp;
    var monAtk;
    var monDef;
    var isBoss;

    var mode;          // CS_ACTIONS / CS_SPELLS / CS_ITEMS
    var sel;           // highlighted action
    var spellSel;
    var itemSel;

    var powerCd;
    var guarding;
    var exposed;       // a power swing leaves you open for one reply
    var windup;        // skeleton charge state
    var frozen;        // monster loses its next turn
    var monShield;     // bone armour / stone form turns
    var bossBeat;      // boss pattern counter
    var enraged;

    var msg;
    var msg2;
    var flashPlayer;
    var flashMon;
    var turns;

    // Presentation hand-off — the view reads these once and clears them.
    var fx;
    var fxTick;
    var lastMonDmg;
    var lastHeroDmg;
    var lastCrit;
    var shakeMag;
    var lunge;         // monster lunges toward the camera when it strikes

    function initialize() {
        active = false;
        monIdx = -1;
        monType = MON_RAT;
        monElite = EL_NONE;
        monHp = 1;
        monMaxHp = 1;
        monAtk = 1;
        monDef = 0;
        isBoss = false;
        mode = CS_ACTIONS;
        sel = ACT_ATTACK;
        spellSel = 0;
        itemSel = 0;
        powerCd = 0;
        guarding = false;
        exposed = false;
        windup = false;
        frozen = false;
        monShield = 0;
        bossBeat = 0;
        enraged = false;
        msg = "";
        msg2 = "";
        flashPlayer = 0;
        flashMon = 0;
        turns = 0;
        fx = FX_NONE;
        fxTick = 0;
        lastMonDmg = -1;
        lastHeroDmg = -1;
        lastCrit = false;
        shakeMag = 0;
        lunge = 0;
    }

    function begin(map as DungeonMap, idx as Lang.Number, floor as Lang.Number,
                   diff as Lang.Number) as Void {
        active = true;
        monIdx = idx;
        monType = map.monType[idx];
        monElite = map.monElite[idx];
        monHp = map.monHp[idx];
        monMaxHp = DungeonGenerator.eliteHp(DmConst.monHp(monType, floor, diff), monElite);
        if (monHp > monMaxHp) { monMaxHp = monHp; }
        monAtk = DmConst.monAtk(monType, floor, diff);
        if (monElite == EL_SAVAGE) { monAtk = monAtk * 5 / 4; }
        monDef = DmConst.monDef(monType, floor);
        if (monElite == EL_ARMORED) { monDef += 4; }
        isBoss = DmConst.isBossType(monType);
        mode = CS_ACTIONS;
        sel = ACT_ATTACK;
        spellSel = 0;
        itemSel = 0;
        powerCd = 0;
        guarding = false;
        exposed = false;
        windup = false;
        frozen = false;
        monShield = 0;
        bossBeat = 0;
        enraged = false;
        turns = 0;
        flashPlayer = 0;
        flashMon = 0;
        fx = FX_NONE;
        fxTick = 0;
        lastMonDmg = -1;
        lastHeroDmg = -1;
        shakeMag = 0;
        lunge = 0;
        if (isBoss) {
            msg = fullName() + " AWAKENS";
        } else {
            msg = fullName() + " BLOCKS THE WAY";
        }
        msg2 = DmConst.monTell(monType);
    }

    function fullName() as Lang.String {
        return DmConst.eliteName(monElite) + DmConst.monName(monType);
    }

    // ── Menu navigation (UP / DOWN reach everything, no touch required) ─────
    function navigate(delta as Lang.Number) as Void {
        if (mode == CS_SPELLS) {
            var n = SP_COUNT + 1;
            spellSel = ((spellSel + delta) % n + n) % n;
            return;
        }
        if (mode == CS_ITEMS) {
            itemSel = ((itemSel + delta) % 4 + 4) % 4;
            return;
        }
        sel = ((sel + delta) % ACT_COUNT + ACT_COUNT) % ACT_COUNT;
    }

    // BACK inside a submenu returns to the action list rather than the dungeon.
    function cancel() as Lang.Boolean {
        if (mode != CS_ACTIONS) {
            mode = CS_ACTIONS;
            return true;
        }
        return false;
    }

    function actionLabel(a as Lang.Number, hero as Character) as Lang.String {
        if (a == ACT_ATTACK) { return "ATTACK  " + hero.attackPower().format("%d"); }
        if (a == ACT_POWER)  {
            if (powerCd > 0) { return "POWER (" + powerCd.format("%d") + ")"; }
            return "POWER SWING";
        }
        if (a == ACT_SPELL)  { return "CAST  " + hero.mana.format("%d") + "mp"; }
        if (a == ACT_GUARD)  { return "GUARD"; }
        return "USE ITEM";
    }

    function spellLabel(i as Lang.Number, hero as Character) as Lang.String {
        if (i >= SP_COUNT) { return "BACK"; }
        return DmConst.spellName(i) + "  " + hero.spellCost(i).format("%d") + "mp";
    }

    function itemLabel(i as Lang.Number, hero as Character) as Lang.String {
        if (i == 0) { return "POTION x" + hero.potions.format("%d"); }
        if (i == 1) { return "ETHER x" + hero.ethers.format("%d"); }
        if (i == 2) { return "BOMB x" + hero.bombs.format("%d"); }
        return "BACK";
    }

    // ── Turn ────────────────────────────────────────────────────────────────
    // Returns "win", "dead", "menu" (submenu opened, no turn spent) or "".
    function confirm(hero as Character, map as DungeonMap, floor as Lang.Number) as Lang.String {
        if (!active) { return ""; }

        if (mode == CS_ACTIONS) {
            if (sel == ACT_SPELL) {
                mode = CS_SPELLS;
                spellSel = 0;
                return "menu";
            }
            if (sel == ACT_ITEM) {
                mode = CS_ITEMS;
                itemSel = 0;
                return "menu";
            }
            return _round(hero, map, floor, sel, 0);
        }
        if (mode == CS_SPELLS) {
            if (spellSel >= SP_COUNT) { mode = CS_ACTIONS; return "menu"; }
            if (!hero.canCast(spellSel)) {
                msg = "NOT ENOUGH MANA";
                return "menu";
            }
            mode = CS_ACTIONS;
            return _round(hero, map, floor, ACT_SPELL, spellSel);
        }
        if (itemSel >= 3) { mode = CS_ACTIONS; return "menu"; }
        if (itemSel == 0 && hero.potions <= 0) { msg = "NO POTIONS"; return "menu"; }
        if (itemSel == 1 && hero.ethers <= 0) { msg = "NO ETHER"; return "menu"; }
        if (itemSel == 2 && hero.bombs <= 0) { msg = "NO BOMBS"; return "menu"; }
        mode = CS_ACTIONS;
        return _round(hero, map, floor, ACT_ITEM, itemSel);
    }

    hidden function _round(hero as Character, map as DungeonMap, floor as Lang.Number,
                           action as Lang.Number, param as Lang.Number) as Lang.String {
        turns++;
        guarding = false;
        msg2 = "";
        lastMonDmg = -1;
        lastHeroDmg = -1;
        lastCrit = false;
        shakeMag = 0;
        lunge = 0;

        if (hero.stun > 0) {
            hero.stun--;
            msg = "STAGGERED - NO ACTION";
            fx = FX_MISS;
            fxTick = 4;
        } else if (action == ACT_ATTACK) {
            _physical(hero, 100, "STRIKE", FX_SLASH);
        } else if (action == ACT_POWER) {
            if (powerCd > 0) {
                msg = "POWER NOT READY";
                return "";
            }
            _physical(hero, 190, "POWER", FX_HEAVY);
            powerCd = 3;
            exposed = true;          // committing to the big swing costs cover
        } else if (action == ACT_GUARD) {
            guarding = true;
            var back = 2 + hero.def / 2;
            hero.heal(back);
            hero.restoreMana(2);
            msg = "YOU BRACE  +" + back.format("%d") + "HP";
            fx = FX_WARD;
            fxTick = 4;
        } else if (action == ACT_SPELL) {
            _cast(hero, param);
        } else {
            _useItem(hero, param, floor);
        }

        if (powerCd > 0 && action != ACT_POWER) { powerCd--; }

        if (monShield > 0) { monShield--; }

        if (monHp <= 0) {
            map.monAlive[monIdx] = false;
            active = false;
            msg2 = "";
            return "win";
        }

        if (frozen) {
            frozen = false;
            msg2 = fullName() + " IS FROZEN SOLID";
        } else {
            _monsterTurn(hero, floor);
        }

        if (hero.poison > 0) {
            hero.poison--;
            var pd = 2 + floor / 4;
            hero.hurt(pd);
            msg2 = "POISON -" + pd.format("%d") + "HP";
        }

        exposed = false;
        map.monHp[monIdx] = monHp;

        if (!hero.isAlive()) {
            active = false;
            return "dead";
        }
        return "";
    }

    // ── Player offence ──────────────────────────────────────────────────────
    hidden function _effDef() as Lang.Number {
        var d = monDef;
        if (monShield > 0) { d += 6; }
        return d;
    }

    hidden function _physical(hero as Character, pct as Lang.Number, label as Lang.String,
                              effect as Lang.Number) as Void {
        // Wraiths are half in this world; steel sometimes finds nothing to bite.
        if (monType == MON_WRAITH && _rand(100) < 38) {
            msg = "YOUR BLADE PASSES THROUGH";
            fx = FX_MISS;
            fxTick = 4;
            return;
        }
        var raw = hero.attackPower() * pct / 100;
        var swing = _rand(3) + hero.totalMagic() / 4;
        var dmg = raw + swing - _effDef();
        var crit = _rand(100) < (5 + hero.totalLuck() * 2);
        if (crit) { dmg = dmg * 3 / 2; }
        if (monElite == EL_ARMORED && !crit) { dmg = dmg * 8 / 10; }
        if (monType == MON_KNIGHT && !crit) { dmg = dmg * 8 / 10; }
        if (dmg < 1) { dmg = 1; }
        monHp -= dmg;
        flashMon = 3;
        lastMonDmg = dmg;
        lastCrit = crit;
        fx = effect;
        fxTick = 5;
        shakeMag = crit ? 4 : 2;
        if (pct > 150) { shakeMag += 2; }
        if (crit) {
            msg = "CRIT! " + dmg.format("%d");
            // The Amulet of Shadow turns a lucky hit into a lasting wound.
            if (hero.amulet == 3) { monShield = 0; }
        } else {
            msg = label + " " + dmg.format("%d");
        }
    }

    hidden function _cast(hero as Character, s as Lang.Number) as Void {
        var cost = hero.spellCost(s);
        if (hero.mana < cost) {
            msg = "NOT ENOUGH MANA";
            return;
        }
        hero.spendMana(cost);
        var mg = hero.totalMagic();

        if (s == SP_FIRE) {
            var d = 9 + mg * 2 + _rand(4) - _effDef() / 2;
            if (d < 2) { d = 2; }
            monHp -= d;
            flashMon = 4;
            lastMonDmg = d;
            fx = FX_FIRE;
            fxTick = 6;
            shakeMag = 3;
            msg = "FIREBALL " + d.format("%d");
            return;
        }
        if (s == SP_FROST) {
            var d2 = 5 + mg + _rand(3) - _effDef() / 3;
            if (d2 < 1) { d2 = 1; }
            monHp -= d2;
            flashMon = 3;
            lastMonDmg = d2;
            frozen = true;
            windup = false;
            fx = FX_FROST;
            fxTick = 6;
            msg = "FROST NOVA " + d2.format("%d");
            return;
        }
        if (s == SP_HEAL) {
            var h = hero.heal(16 + mg * 2);
            if (hero.poison > 0) { hero.poison = 0; }
            fx = FX_HEAL;
            fxTick = 6;
            msg = "MEND +" + h.format("%d") + "HP";
            return;
        }
        hero.ward = 3;
        fx = FX_WARD;
        fxTick = 6;
        msg = "WARD RAISED";
    }

    hidden function _useItem(hero as Character, which as Lang.Number, floor as Lang.Number) as Void {
        if (which == 0) {
            hero.potions--;
            var h = hero.heal(26 + hero.totalMagic());
            fx = FX_HEAL;
            fxTick = 5;
            msg = "POTION +" + h.format("%d") + "HP";
            return;
        }
        if (which == 1) {
            hero.ethers--;
            var m = hero.restoreMana(16 + hero.totalMagic());
            fx = FX_WARD;
            fxTick = 5;
            msg = "ETHER +" + m.format("%d") + "MP";
            return;
        }
        hero.bombs--;
        // Bombs care nothing for armour — the answer to a plated knight.
        var d = 22 + floor * 2 + _rand(6);
        monHp -= d;
        flashMon = 5;
        lastMonDmg = d;
        fx = FX_BOMB;
        fxTick = 7;
        shakeMag = 6;
        msg = "BOMB! " + d.format("%d");
    }

    // ── Monster turn ────────────────────────────────────────────────────────
    hidden function _monsterTurn(hero as Character, floor as Lang.Number) as Void {
        var hits = 1;
        var mult = 100;
        var pierce = false;
        var note = "";

        if (isBoss) {
            bossBeat++;
            if (monType == MON_KING) {
                if (bossBeat % 3 == 0) {
                    monShield = 2;
                    msg2 = "BONE ARMOUR RISES";
                    fx = FX_WARD;
                    fxTick = 5;
                    return;
                }
                hits = 2;
                note = "x2";
            } else if (monType == MON_GUARDIAN) {
                if (bossBeat % 2 == 1) {
                    monShield = 1;
                    msg2 = "IT SETTLES INTO STONE";
                    return;
                }
                mult = 220;
                note = "QUAKE";
            } else {
                if (!enraged && monHp * 2 <= monMaxHp) {
                    enraged = true;
                    msg2 = "THE BEAST ENRAGES";
                    return;
                }
                if (enraged) { mult = 150; }
                if (_rand(100) < 30) {
                    mult += 60;
                    note = "DEVOUR";
                }
            }
        } else if (monType == MON_SKELETON) {
            if (!windup) {
                windup = true;
                msg2 = "IT WINDS UP";
                return;
            }
            windup = false;
            mult = 165;
        } else if (monType == MON_RAT) {
            hits = 2 + _rand(2);
            mult = 62;
            note = "swarm";
        } else if (monType == MON_GOBLIN) {
            if (_rand(100) < 35) { hits = 2; note = "x2"; }
        } else if (monType == MON_OGRE) {
            if (turns % 2 == 0) {
                mult = 190;
                note = "SLAM";
            }
        } else if (monType == MON_GUARDIAN) {
            mult = 150;
        }

        var total = 0;
        for (var i = 0; i < hits; i++) {
            var dmg = monAtk * mult / 100 + _rand(3);
            if (enraged) { dmg = dmg * 3 / 2; }
            var armour = hero.totalDefense();
            if (monType == MON_DEMON && _rand(100) < 35) { pierce = true; }
            if (monElite == EL_ARCANE) { armour = armour / 2; }
            if (pierce) { armour = 0; }
            dmg -= armour;
            if (guarding) { dmg = dmg / 2; }
            if (exposed) { dmg = dmg * 5 / 4; }
            if (dmg < 1) { dmg = 1; }
            total += hero.hurt(dmg);
        }
        flashPlayer = 3;
        lastHeroDmg = total;
        fx = FX_ENEMY;
        fxTick = 5;
        lunge = 6;
        shakeMag = (mult > 150) ? 6 : 3;

        // Signature riders.
        if (monElite == EL_VENOM && hero.poison <= 0) { hero.poison = 3; }
        if (monType == MON_SPIDER && hero.poison <= 0 && _rand(100) < 55) { hero.poison = 3; }
        if (monElite == EL_ARCANE) { hero.spendMana(3); }
        if (monType == MON_WRAITH) { hero.spendMana(2 + floor / 4); }
        if (monType == MON_CULTIST && _rand(100) < 45) {
            var drain = total / 2 + 1;
            monHp += drain;
            if (monHp > monMaxHp) { monHp = monMaxHp; }
            note = "DRAINS " + drain.format("%d");
        }
        if (monType == MON_KNIGHT && _rand(100) < 28) {
            hero.stun = 1;
            note = "SHIELD BASH";
        }
        if (monType == MON_OGRE && mult > 150 && _rand(100) < 35) {
            hero.stun = 1;
            note = "STUNNED";
        }
        if (pierce) { note = "HELLFIRE"; }

        var who = DmConst.monName(monType);
        if (note.equals("")) {
            msg2 = who + " -" + total.format("%d") + "HP";
        } else {
            msg2 = note + " -" + total.format("%d") + "HP";
        }
        if (hero.poison > 0 && hero.poison == 3) { msg2 = "POISONED! -" + total.format("%d") + "HP"; }
    }

    function tickFlash() as Void {
        if (flashPlayer > 0) { flashPlayer--; }
        if (flashMon > 0) { flashMon--; }
        if (fxTick > 0) {
            fxTick--;
            if (fxTick == 0) { fx = FX_NONE; }
        }
        if (lunge > 0) { lunge -= 2; if (lunge < 0) { lunge = 0; } }
    }

    hidden function _rand(n as Lang.Number) as Lang.Number {
        if (n <= 1) { return 0; }
        var r = 0;
        try { r = Math.rand(); } catch (e) { r = turns * 7 + 13; }
        if (r < 0) { r = -r; }
        return r % n;
    }
}
