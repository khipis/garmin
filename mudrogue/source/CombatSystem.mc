// ═══════════════════════════════════════════════════════════════
// CombatSystem.mc — Turn resolution + outcome plumbing.
//
// Combat is strictly turn-based:
//   1. Player picks an action (Attack / Defend / Item / Run).
//   2. CombatSystem applies it → produces a `playerLog` line.
//   3. If the enemy is still alive, it picks an action and we apply
//      the enemy turn → `enemyLog` line.
//   4. The controller renders both lines, waits for SELECT, then
//      loops back to step 1 unless the fight has ended.
//
// Functions return `CombatResult` records — pure data, no view code.
// Damage formulae mirror Player.takeDamage()'s reduction.
// ═══════════════════════════════════════════════════════════════

using Toybox.Math;

// Player action codes
const PA_ATTACK  = 0;
const PA_DEFEND  = 1;
const PA_ITEM    = 2;       // resolved out-of-band via inventory screen
const PA_RUN     = 3;

// Fight outcomes
const CR_CONTINUE = 0;      // still fighting after this round
const CR_VICTORY  = 1;      // enemy killed
const CR_DEATH    = 2;      // player killed
const CR_FLED     = 3;      // run succeeded

class CombatResult {
    var playerLog;
    var enemyLog;
    var outcome;
    var playerDefendingThisRound;
    function initialize() {
        playerLog = "";
        enemyLog  = "";
        outcome   = CR_CONTINUE;
        playerDefendingThisRound = false;
    }
}

class CombatSystem {
    // Process one full combat round given the chosen action.
    // For PA_ITEM, the controller pre-applies the item and only calls
    // this to run the enemy turn (so itemDamage is the dmg done if any).
    static function resolveRound(player, enemy, action, isBoss, itemDamage) {
        var res = new CombatResult();
        var playerDefending = false;

        // ── Player turn ─────────────────────────────────────────────
        if (action == PA_ATTACK) {
            var raw = player.atk + (Math.rand() % 3);
            var dmg = raw - enemy.def - (enemy.defending == 1 ? 2 : 0);
            if (dmg < 1) { dmg = 1; }
            enemy.hp = enemy.hp - dmg;
            if (enemy.hp < 0) { enemy.hp = 0; }
            res.playerLog = "You strike for " + dmg.format("%d") + ".";
        } else if (action == PA_DEFEND) {
            playerDefending = true;
            res.playerLog = "You raise your guard.";
        } else if (action == PA_ITEM) {
            // Item already used — caller passed the resulting dmg/heal.
            if (itemDamage > 0) {
                res.playerLog = "Bomb hits for " + itemDamage.format("%d") + "!";
            } else if (itemDamage < 0) {
                res.playerLog = "You heal " + (-itemDamage).format("%d") + " HP.";
            } else {
                res.playerLog = "You ready a shield.";
            }
        } else if (action == PA_RUN) {
            var roll = Math.rand() % 100;
            if (isBoss) {
                res.playerLog = "The boss blocks you!";
                // Boss enrages — gets a free attack instead.
            } else if (roll < 60) {
                res.playerLog = "You escape!";
                res.outcome   = CR_FLED;
                return res;
            } else {
                res.playerLog = "You stumble — escape failed.";
            }
        }

        // Enemy KO check before enemy gets a turn.
        if (enemy.hp <= 0) {
            res.enemyLog = enemy.name + " is slain!";
            res.outcome  = CR_VICTORY;
            return res;
        }

        // ── Enemy turn ──────────────────────────────────────────────
        enemy.defending = 0;     // reset previous-round defense
        var ea = enemy.pickAction(isBoss);
        if (ea == EA_DEFEND) {
            enemy.defending = 1;
            res.enemyLog = enemy.name + " braces.";
        } else {
            var raw = enemy.rollAttack();
            var taken = player.takeDamage(raw, playerDefending);
            res.enemyLog = enemy.name + " hits you " + taken.format("%d") + ".";
            if (!player.isAlive()) {
                res.outcome = CR_DEATH;
                return res;
            }
        }
        res.playerDefendingThisRound = playerDefending;
        return res;
    }
}
