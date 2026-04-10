using Toybox.Math;
using Toybox.Application;

// ─────────────────────────────────────────────────────────────────────────────
//  DungeonGame  –  complete game logic for Bitochi Dungeon
//
//  STATE MACHINE:
//    DS_MENU    → class select (UP/DOWN), tap to start run
//    DS_RUN     → auto-running, events fire on timer
//    DS_CHOICE  → path fork LEFT/RIGHT, 2-second countdown
//    DS_COMBAT  → auto-fight with danger windows
//    DS_DANGER  → quick-time "DODGE!" or "STRIKE!" window (1.2s)
//    DS_POWERUP → pick 1 of 2 upgrades
//    DS_DEAD    → death screen, best depth shown
//
//  All timing is in ticks (100ms each from timer).
// ─────────────────────────────────────────────────────────────────────────────

// Game states
const DS_MENU    = 0;
const DS_RUN     = 1;
const DS_CHOICE  = 2;
const DS_COMBAT  = 3;
const DS_DANGER  = 4;
const DS_POWERUP = 5;
const DS_DEAD    = 6;

// Classes
const CLS_WARRIOR = 0;   // tank: high HP/DEF, moderate DMG
const CLS_ROGUE   = 1;   // glass cannon: high CRIT/DMG, low HP
const CLS_MAGE    = 2;   // burst: highest DMG, no DEF, magic bonus

// Enemy types
const EN_GOBLIN   = 0;
const EN_SKELETON = 1;
const EN_DEMON    = 2;
const EN_ELITE    = 3;
const EN_BOSS     = 4;

// Power-up types (12 total)
const PU_DMG2    = 0;   // +60% damage
const PU_CRIT    = 1;   // +20% crit chance
const PU_SHIELD  = 2;   // absorb next hit
const PU_MAXHP   = 3;   // +25 max HP + heal
const PU_SPEED   = 4;   // attack every 7 ticks (was 10)
const PU_STEAL   = 5;   // life steal: heal 5 on kill
const PU_DOUBLE  = 6;   // strike twice per attack
const PU_ARMOR   = 7;   // +3 defense
const PU_BERSERK = 8;   // +80% dmg when HP < 40%
const PU_POISON  = 9;   // enemies take 2 dmg/sec (dot)
const PU_EXPLODE = 10;  // 35% chance of AOE (hit all enemies)
const PU_REGEN   = 11;  // regenerate 1 HP per 5 ticks

// Danger event types
const DNG_DODGE  = 0;   // press A to dodge (reduce incoming dmg)
const DNG_STRIKE = 1;   // press A for crit bonus hit

// Max enemies per encounter
const MAX_EN = 4;
// Max power-ups a player can hold
const MAX_PU = 8;

class DungeonGame {

    // ── State ─────────────────────────────────────────────────────────────────
    var state;
    var gameTick;

    // ── Player ────────────────────────────────────────────────────────────────
    var cls;           // character class
    var hp;  var maxHp;
    var dmg;           // base damage
    var def;           // defense (flat damage reduction)
    var critChance;    // 0-100
    var attackInterval; // ticks per auto-attack

    // Buff flags (from power-ups)
    var shieldCharges;
    var hasStealing;
    var hasDouble;
    var hasExplode;
    var poisonDmg;     // 0 or 2
    var hasBerserk;
    var hasRegen;
    var regenTimer;

    // Collected power-ups list (for HUD display, max MAX_PU)
    var puList;
    var puCount;

    // ── Run state ─────────────────────────────────────────────────────────────
    var depth;         // rooms cleared (also difficulty scale)
    var runTick;       // ticks since run started
    var nextEventTick; // tick when next event fires
    var lastDmgTaken;  // show damage flash
    var lastDmgDealt;
    var dmgTick;       // countdown for damage number display
    var killedCount;   // enemies killed this run

    // ── Enemies ───────────────────────────────────────────────────────────────
    var enType;   var enHp;    var enMaxHp;
    var enCount;
    var enAttackTimer; // ticks until enemy next attacks
    var playerAttackTimer; // ticks until player next attacks

    // ── Event state ───────────────────────────────────────────────────────────
    var choiceTimer;       // countdown for path choice
    var choiceLeft;        // description string for left path
    var choiceRight;       // description string for right path
    var choiceLeftRisk;    // 0=safe 1=risky

    var dangerType;        // DNG_DODGE or DNG_STRIKE
    var dangerTimer;       // countdown for QTE window
    var dangerResolved;    // true if player pressed in time

    var puOpts;            // [type0, type1] power-up choices
    var puTimer;           // countdown for power-up selection

    // ── Meta ─────────────────────────────────────────────────────────────────
    var bestDepth;
    var classesMet;   // [W,R,M] booleans — unlocked by reaching depths 5, 10
    var selectedClass;

    function initialize() {
        state    = DS_MENU;
        gameTick = 0;
        selectedClass = CLS_WARRIOR;

        enType   = new [MAX_EN]; enHp = new [MAX_EN]; enMaxHp = new [MAX_EN];
        puList   = new [MAX_PU];
        puOpts   = [0, 1];
        for (var i = 0; i < MAX_EN; i++) { enType[i] = 0; enHp[i] = 0; enMaxHp[i] = 0; }
        for (var i2 = 0; i2 < MAX_PU; i2++) { puList[i2] = -1; }

        bestDepth  = Application.Storage.getValue("dg_best");
        if (bestDepth == null) { bestDepth = 0; }
        classesMet = Application.Storage.getValue("dg_cls");
        if (classesMet == null) { classesMet = 0; }

        resetRun();
    }

    // ── Run initialization ────────────────────────────────────────────────────

    function resetRun() {
        depth         = 0;
        runTick       = 0;
        killedCount   = 0;
        lastDmgTaken  = 0;
        lastDmgDealt  = 0;
        dmgTick       = 0;
        enCount       = 0;
        choiceTimer   = 0;
        dangerTimer   = 0;
        dangerResolved = false;
        puTimer       = 0;
        puCount       = 0;
        shieldCharges = 0;
        hasStealing   = false;
        hasDouble     = false;
        hasExplode    = false;
        poisonDmg     = 0;
        hasBerserk    = false;
        hasRegen      = false;
        regenTimer    = 0;
        for (var i = 0; i < MAX_PU; i++) { puList[i] = -1; }

        applyClassStats(selectedClass);
        nextEventTick = 30;   // first event after 3s
    }

    hidden function applyClassStats(c) {
        cls = c;
        if (c == CLS_WARRIOR) {
            maxHp = 100; hp = 100; dmg = 8;  def = 3; critChance = 10; attackInterval = 10;
        } else if (c == CLS_ROGUE) {
            maxHp = 70;  hp = 70;  dmg = 12; def = 1; critChance = 25; attackInterval = 9;
        } else {
            maxHp = 60;  hp = 60;  dmg = 18; def = 0; critChance = 15; attackInterval = 10;
        }
    }

    // ── Main tick (100ms) ────────────────────────────────────────────────────

    function step() {
        gameTick++;
        runTick++;
        if (dmgTick > 0) { dmgTick--; }

        if (state == DS_RUN) {
            tickRun();
        } else if (state == DS_COMBAT) {
            tickCombat();
        } else if (state == DS_CHOICE) {
            tickChoice();
        } else if (state == DS_DANGER) {
            tickDanger();
        } else if (state == DS_POWERUP) {
            tickPowerup();
        }
    }

    // ── Run phase ────────────────────────────────────────────────────────────

    hidden function tickRun() {
        if (hasRegen) {
            regenTimer++;
            if (regenTimer >= 5) { regenTimer = 0; heal(1); }
        }

        if (runTick >= nextEventTick) {
            triggerNextEvent();
        }
    }

    hidden function triggerNextEvent() {
        depth++;
        if (depth > bestDepth) {
            bestDepth = depth;
            Application.Storage.setValue("dg_best", bestDepth);
        }

        // Boss at depth 10, 20, 30 ...
        if (depth % 10 == 0) {
            spawnEnemies(EN_BOSS, 1);
            state = DS_COMBAT;
            nextEventTick = runTick + eventInterval();
            return;
        }

        // Weighted event roll
        var roll = (Math.rand() % 100).toNumber();
        if (roll < 35) {
            // Combat encounter
            spawnEncounter();
            state = DS_COMBAT;
        } else if (roll < 65) {
            // Path fork
            setupChoice();
            state = DS_CHOICE;
            choiceTimer = 22;
        } else {
            // Free power-up chest (rare)
            setupPowerup();
            state = DS_POWERUP;
            puTimer = 30;
        }
        nextEventTick = runTick + eventInterval();
    }

    hidden function eventInterval() {
        var base = 45 - depth;
        if (base < 20) { base = 20; }
        return base;
    }

    // ── Enemy spawning ────────────────────────────────────────────────────────

    hidden function spawnEncounter() {
        if (depth <= 3) {
            var n = 1 + (Math.rand() % 2).toNumber();
            spawnEnemies(EN_GOBLIN, n);
        } else if (depth <= 6) {
            var roll = (Math.rand() % 3).toNumber();
            if (roll == 0) { spawnEnemies(EN_GOBLIN, 2); }
            else if (roll == 1) { spawnEnemies(EN_SKELETON, 1); }
            else { spawnEnemies(EN_GOBLIN, 1); spawnEnemy(EN_SKELETON); }
        } else if (depth <= 10) {
            var roll2 = (Math.rand() % 3).toNumber();
            if (roll2 == 0) { spawnEnemies(EN_SKELETON, 2); }
            else if (roll2 == 1) { spawnEnemies(EN_DEMON, 1); }
            else { spawnEnemies(EN_SKELETON, 1); spawnEnemy(EN_DEMON); }
        } else {
            var roll3 = (Math.rand() % 3).toNumber();
            if (roll3 == 0) { spawnEnemies(EN_DEMON, 2); }
            else if (roll3 == 1) { spawnEnemies(EN_ELITE, 1); }
            else { spawnEnemies(EN_DEMON, 1); spawnEnemy(EN_ELITE); }
        }

        playerAttackTimer = attackInterval;
        enAttackTimer     = 12;
    }

    hidden function spawnEnemies(type, count) {
        enCount = 0;
        for (var i = 0; i < count && i < MAX_EN; i++) { spawnEnemy(type); }
    }

    hidden function spawnEnemy(type) {
        if (enCount >= MAX_EN) { return; }
        var i = enCount;
        enType[i] = type;
        var h2 = enemyBaseHp(type) + depth * enemyHpScale(type);
        enMaxHp[i] = h2; enHp[i] = h2;
        enCount++;
    }

    hidden function enemyBaseHp(t) {
        if (t == EN_GOBLIN)   { return 12; }
        if (t == EN_SKELETON) { return 22; }
        if (t == EN_DEMON)    { return 38; }
        if (t == EN_ELITE)    { return 60; }
        return 100;   // BOSS
    }

    hidden function enemyHpScale(t) {
        if (t == EN_GOBLIN)   { return 2; }
        if (t == EN_SKELETON) { return 3; }
        if (t == EN_DEMON)    { return 4; }
        if (t == EN_ELITE)    { return 6; }
        return 8;   // BOSS
    }

    hidden function enemyBaseDmg(t) {
        if (t == EN_GOBLIN)   { return 4; }
        if (t == EN_SKELETON) { return 7; }
        if (t == EN_DEMON)    { return 11; }
        if (t == EN_ELITE)    { return 16; }
        return 22;   // BOSS
    }

    // ── Combat phase ─────────────────────────────────────────────────────────

    hidden function tickCombat() {
        if (enCount == 0) { combatVictory(); return; }

        // Poison damage to all enemies
        if (poisonDmg > 0 && (runTick % 10) == 0) {
            for (var i = 0; i < enCount; i++) { hurtEnemy(i, poisonDmg); }
            cleanDeadEnemies();
            if (enCount == 0) { combatVictory(); return; }
        }

        // Regen
        if (hasRegen) {
            regenTimer++;
            if (regenTimer >= 5) { regenTimer = 0; heal(1); }
        }

        // Player auto-attack
        playerAttackTimer--;
        if (playerAttackTimer <= 0) {
            playerAttackTimer = hasSpeed() ? 7 : attackInterval;
            doPlayerAttack();
            if (enCount == 0) { combatVictory(); return; }
        }

        // Enemy auto-attack
        enAttackTimer--;
        if (enAttackTimer <= 0) {
            enAttackTimer = 10 + (Math.rand() % 5).toNumber();
            doEnemyAttack();
            if (hp <= 0) { state = DS_DEAD; return; }
        }

        // Danger window chance (every 18-28 ticks if no danger active)
        if ((runTick % (20 + (Math.rand() % 8).toNumber())) == 0) {
            spawnDanger();
        }
    }

    hidden function doPlayerAttack() {
        var isCrit = (Math.rand() % 100).toNumber() < critChance;
        var d      = dmg;
        if (isCrit)   { d = d * 2; }
        if (hasBerserk && hp.toFloat() < maxHp.toFloat() * 0.40) { d = d * 18 / 10; }

        // Apply to first living enemy (or all if AOE)
        var aoe = hasExplode && (Math.rand() % 100).toNumber() < 35;
        if (aoe) {
            for (var i = 0; i < enCount; i++) { hurtEnemy(i, d); }
        } else {
            hurtEnemy(0, d);
            if (hasDouble) { hurtEnemy(0, d / 2 + 1); }
        }
        lastDmgDealt = isCrit ? (d * -1) : d;  // negative = crit flag
        dmgTick = 8;
        cleanDeadEnemies();
    }

    hidden function doEnemyAttack() {
        if (enCount == 0) { return; }
        var rawDmg = enemyBaseDmg(enType[0]) + depth / 2;
        var actual = rawDmg - def;
        if (actual < 1) { actual = 1; }
        if (shieldCharges > 0) {
            shieldCharges--;
            lastDmgTaken = 0;  // blocked
            dmgTick = 8;
            return;
        }
        hp -= actual;
        if (hp < 0) { hp = 0; }
        lastDmgTaken = actual;
        dmgTick = 8;
    }

    hidden function hurtEnemy(idx, d) {
        if (idx >= enCount || enHp[idx] <= 0) { return; }
        enHp[idx] -= d;
        if (enHp[idx] <= 0) {
            enHp[idx] = 0;
            killedCount++;
            if (hasStealing) { heal(5); }
        }
    }

    hidden function cleanDeadEnemies() {
        var w = 0;
        for (var r = 0; r < enCount; r++) {
            if (enHp[r] > 0) {
                enType[w] = enType[r]; enHp[w] = enHp[r]; enMaxHp[w] = enMaxHp[r]; w++;
            }
        }
        enCount = w;
    }

    hidden function combatVictory() {
        // Chance of power-up chest after combat (40% + scales with depth)
        var chestChance = 30 + depth * 3;
        if (chestChance > 65) { chestChance = 65; }
        if ((Math.rand() % 100).toNumber() < chestChance) {
            setupPowerup();
            state = DS_POWERUP;
            puTimer = 30;
        } else {
            heal(8 + depth);  // small heal for surviving
            state = DS_RUN;
        }
    }

    // ── Danger QTE ────────────────────────────────────────────────────────────

    hidden function spawnDanger() {
        dangerType     = (Math.rand() % 2).toNumber();
        dangerTimer    = 12;
        dangerResolved = false;
        state          = DS_DANGER;
    }

    hidden function tickDanger() {
        dangerTimer--;
        if (dangerTimer <= 0) {
            if (!dangerResolved) {
                // Missed dodge: take full enemy hit
                if (dangerType == DNG_DODGE) { doEnemyAttack(); }
            }
            state = DS_COMBAT;
        }
    }

    // Player pressed A during danger window
    function resolveDanger() {
        if (state != DS_DANGER || dangerResolved) { return; }
        dangerResolved = true;
        if (dangerType == DNG_DODGE) {
            // Take only 20% damage
            var rawDmg = enemyBaseDmg(enType[0]) + depth / 2;
            var actual = (rawDmg / 5) - def;
            if (actual < 0) { actual = 0; }
            hp -= actual;
            if (hp < 0) { hp = 0; }
            lastDmgTaken = actual;
        } else {
            // STRIKE: guaranteed crit bonus hit
            var bonusDmg = dmg * 2;
            hurtEnemy(0, bonusDmg);
            lastDmgDealt = bonusDmg * -1;  // flag as crit
            cleanDeadEnemies();
            if (enCount == 0) { combatVictory(); }
        }
        dmgTick = 8;
        state = (enCount > 0) ? DS_COMBAT : DS_RUN;
    }

    // ── Path choice ───────────────────────────────────────────────────────────

    hidden function setupChoice() {
        var roll = (Math.rand() % 3).toNumber();
        if (roll == 0) {
            choiceLeft = "Shrine +HP"; choiceRight = "Goblin nest";
            choiceLeftRisk = 0;
        } else if (roll == 1) {
            choiceLeft = "Safe path"; choiceRight = "Treasure!";
            choiceLeftRisk = 0;
        } else {
            choiceLeft = "Rest +heal"; choiceRight = "Fight +gem";
            choiceLeftRisk = 0;
        }
    }

    hidden function tickChoice() {
        choiceTimer--;
        if (choiceTimer <= 0) { resolveChoice(0); }  // auto LEFT on timeout
    }

    function resolveChoice(side) {
        // side 0=LEFT (safer), side 1=RIGHT (risky+rewarding)
        if (side == 0) {
            heal(10 + depth * 2);
        } else {
            // Right: harder encounter + power-up
            spawnEncounter();
            // Harder: add an extra enemy
            if (enCount < MAX_EN && depth > 3) {
                spawnEnemy(depth > 8 ? EN_DEMON : EN_SKELETON);
            }
            setupPowerup();
            // Store pending powerup for after combat
            state = DS_COMBAT;
            return;
        }
        state = DS_RUN;
    }

    // ── Power-up system ───────────────────────────────────────────────────────

    hidden function setupPowerup() {
        var a = (Math.rand() % 12).toNumber();
        var b = (Math.rand() % 12).toNumber();
        while (b == a) { b = (Math.rand() % 12).toNumber(); }
        puOpts[0] = a; puOpts[1] = b;
    }

    hidden function tickPowerup() {
        puTimer--;
        if (puTimer <= 0) { pickPowerup(0); }  // auto-pick A on timeout
    }

    function pickPowerup(idx) {
        if (state != DS_POWERUP) { return; }
        var pu = puOpts[idx];
        applyPowerup(pu);
        if (puCount < MAX_PU) { puList[puCount] = pu; puCount++; }
        state = DS_RUN;
    }

    hidden function applyPowerup(pu) {
        if (pu == PU_DMG2)    { dmg = dmg * 16 / 10; }
        else if (pu == PU_CRIT)    { critChance += 20; if (critChance > 75) { critChance = 75; } }
        else if (pu == PU_SHIELD)  { shieldCharges++; }
        else if (pu == PU_MAXHP)   { maxHp += 25; heal(25); }
        else if (pu == PU_SPEED)   { attackInterval = 7; }
        else if (pu == PU_STEAL)   { hasStealing = true; }
        else if (pu == PU_DOUBLE)  { hasDouble = true; }
        else if (pu == PU_ARMOR)   { def += 3; }
        else if (pu == PU_BERSERK) { hasBerserk = true; }
        else if (pu == PU_POISON)  { poisonDmg += 2; }
        else if (pu == PU_EXPLODE) { hasExplode = true; }
        else if (pu == PU_REGEN)   { hasRegen = true; }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function heal(amount) {
        hp += amount;
        if (hp > maxHp) { hp = maxHp; }
    }

    function hasSpeed() { return attackInterval == 7; }

    // Human-readable power-up names (short, fits on watch screen)
    function puName(pu) {
        if (pu == PU_DMG2)    { return "x1.6 DMG"; }
        if (pu == PU_CRIT)    { return "+20% CRIT"; }
        if (pu == PU_SHIELD)  { return "SHIELD"; }
        if (pu == PU_MAXHP)   { return "+25 HP"; }
        if (pu == PU_SPEED)   { return "HASTE"; }
        if (pu == PU_STEAL)   { return "LIFESTEAL"; }
        if (pu == PU_DOUBLE)  { return "TWIN BLADE"; }
        if (pu == PU_ARMOR)   { return "+3 ARMOR"; }
        if (pu == PU_BERSERK) { return "BERSERK"; }
        if (pu == PU_POISON)  { return "+POISON"; }
        if (pu == PU_EXPLODE) { return "EXPLODE"; }
        if (pu == PU_REGEN)   { return "REGEN"; }
        return "?";
    }

    function puColor(pu) {
        if (pu == PU_DMG2 || pu == PU_DOUBLE)   { return 0xFF4422; }
        if (pu == PU_CRIT || pu == PU_BERSERK)  { return 0xFFDD22; }
        if (pu == PU_SHIELD || pu == PU_ARMOR)  { return 0x44CCFF; }
        if (pu == PU_MAXHP || pu == PU_REGEN)   { return 0x44FF88; }
        if (pu == PU_STEAL || pu == PU_POISON)  { return 0xAA44FF; }
        if (pu == PU_SPEED || pu == PU_EXPLODE) { return 0xFF8800; }
        return 0xFFFFFF;
    }

    function enemyName(t) {
        if (t == EN_GOBLIN)   { return "GOBLIN"; }
        if (t == EN_SKELETON) { return "SKELETON"; }
        if (t == EN_DEMON)    { return "DEMON"; }
        if (t == EN_ELITE)    { return "ELITE"; }
        return "BOSS";
    }

    function enemyColor(t) {
        if (t == EN_GOBLIN)   { return 0x44AA22; }
        if (t == EN_SKELETON) { return 0xCCCCCC; }
        if (t == EN_DEMON)    { return 0xCC2222; }
        if (t == EN_ELITE)    { return 0xFF8800; }
        return 0xFF00AA;  // BOSS: magenta
    }

    function clsName(c) {
        if (c == CLS_WARRIOR) { return "WARRIOR"; }
        if (c == CLS_ROGUE)   { return "ROGUE"; }
        return "MAGE";
    }

    function clsColor(c) {
        if (c == CLS_WARRIOR) { return 0x4488FF; }
        if (c == CLS_ROGUE)   { return 0xFF8800; }
        return 0xCC44FF;
    }
}
