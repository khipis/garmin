// ═══════════════════════════════════════════════════════════════
// GameController.mc — Top-level state machine glueing it all.
//
// Every screen = one state. Player input either confirms the current
// screen (advancing to the next state) or picks an option from the
// 2–4 listed choices. The controller keeps a small "cursor" index
// the UI highlights. Selecting an option triggers a state-specific
// branch that mutates Player / Enemy / Inventory and transitions to
// the next screen.
//
// The state machine is intentionally flat — no nested combat
// sub-machine. Combat is just GS_COMBAT (waiting on action) and
// GS_COMBAT_RESULT (showing the round's log) in a loop until the
// combat ends.
//
// Best floor reached persists via Application.Storage.
// ═══════════════════════════════════════════════════════════════

using Toybox.Application;
using Toybox.System;

// State codes
const GS_TITLE          = 0;
const GS_FLOOR_INTRO    = 1;   // brief "Entering Floor N"
const GS_EVENT_SHOW     = 2;   // banner of current event ("A Goblin!")
const GS_COMBAT         = 3;   // pick action
const GS_COMBAT_LOG     = 4;   // show round log
const GS_TREASURE_LOG   = 5;
const GS_TRAP_LOG       = 6;
const GS_REST_PROMPT    = 7;
const GS_MERCHANT       = 8;
const GS_INVENTORY      = 9;   // accessed from combat
const GS_LEVELUP        = 10;
const GS_VICTORY_LOG    = 11;  // beat enemy / boss
const GS_DEATH          = 12;
const GS_PAUSE_CONFIRM  = 13;  // BACK pressed during play
const GS_RUN_DONE       = 14;  // continue after run / fled

class GameController {
    var state;
    var player;
    var floor;
    var events;          // GameEvent[]
    var eventIdx;
    var curEvent;
    var enemy;           // == curEvent.enemy when in combat
    var isBossFight;

    // Cursor across the option list (0..optionCount-1)
    var cursor;
    var optionCount;
    var optionLabels;    // String[]

    // Log lines for the various log-style screens
    var logTitle;        // headline
    var logLine1;
    var logLine2;
    var logColor;        // tinted accent for the screen (0xRRGGBB)

    // Persistence
    var bestFloor;

    function initialize() {
        state       = GS_TITLE;
        player      = new Player();
        floor       = 1;
        events      = [];
        eventIdx    = 0;
        curEvent    = null;
        enemy       = null;
        isBossFight = false;
        cursor      = 0;
        optionCount = 0;
        optionLabels = [];
        logTitle = ""; logLine1 = ""; logLine2 = ""; logColor = 0xFFFFFF;
        bestFloor   = _loadBestFloor();
    }

    hidden function _loadBestFloor() {
        try {
            var v = Application.Storage.getValue("bestFloor");
            if (v != null && v instanceof Number && v > 0) { return v; }
        } catch (e) { }
        return 0;
    }
    hidden function _saveBestFloor() {
        try { Application.Storage.setValue("bestFloor", bestFloor); } catch (e) { }
    }

    // ── Game flow ───────────────────────────────────────────────────
    function newGame() {
        player = new Player();
        floor  = 1;
        _enterFloor();
    }

    function gotoTitle() {
        if (floor > bestFloor) { bestFloor = floor; _saveBestFloor(); }
        state = GS_TITLE;
        _setOptions(["NEW GAME"]);
    }

    hidden function _enterFloor() {
        events       = DungeonGenerator.buildFloor(floor);
        eventIdx     = 0;
        state        = GS_FLOOR_INTRO;
        _setOptions(["ENTER"]);
    }

    // Advance to the next event in the current floor (or descend).
    hidden function _advanceEvent() {
        eventIdx = eventIdx + 1;
        if (eventIdx >= events.size()) {
            // Floor cleared — descend.
            floor = floor + 1;
            if (floor > bestFloor) { bestFloor = floor; _saveBestFloor(); }
            _enterFloor();
            return;
        }
        _showCurrentEvent();
    }

    hidden function _showCurrentEvent() {
        curEvent = events[eventIdx];
        // Common: show event banner, then options/screen vary by type.
        if (curEvent.type == EV_ENEMY || curEvent.type == EV_BOSS) {
            enemy = curEvent.enemy;
            isBossFight = (curEvent.type == EV_BOSS);
            // Show the banner first ("A Goblin!"), tap to start combat.
            state = GS_EVENT_SHOW;
            _setOptions(["FIGHT"]);
            logTitle = curEvent.label;
            logLine1 = "HP " + enemy.hp.format("%d") + "/" + enemy.maxHp.format("%d")
                     + "  ATK " + enemy.atk.format("%d");
            logLine2 = "";
            logColor = isBossFight ? 0xFF4466 : 0xFF8844;
        } else if (curEvent.type == EV_TREASURE) {
            // Apply immediately, then show log.
            if (curEvent.itemKind >= 0) {
                _grantItem(curEvent.itemKind);
            } else {
                player.addGold(curEvent.goldAmt);
            }
            state    = GS_TREASURE_LOG;
            logTitle = "TREASURE";
            logLine1 = curEvent.label;
            logLine2 = "";
            logColor = 0xFFCC22;
            _setOptions(["CONTINUE"]);
        } else if (curEvent.type == EV_TRAP) {
            var actual = curEvent.damage;
            // Trap bypasses DEF for that brutal "ouch" feel.
            player.hp = player.hp - actual;
            if (player.hp < 0) { player.hp = 0; }
            if (!player.isAlive()) { _die(); return; }
            state    = GS_TRAP_LOG;
            logTitle = "TRAP!";
            logLine1 = curEvent.label;
            logLine2 = "";
            logColor = 0xFF4466;
            _setOptions(["CONTINUE"]);
        } else if (curEvent.type == EV_REST) {
            state    = GS_REST_PROMPT;
            logTitle = "REST AREA";
            logLine1 = "Heal full for " + curEvent.goldAmt.format("%d") + " gold?";
            logLine2 = "";
            logColor = 0x44CCFF;
            _setOptions(["REST", "SKIP"]);
        } else if (curEvent.type == EV_MERCHANT) {
            state    = GS_MERCHANT;
            logTitle = "MERCHANT";
            logLine1 = "P:" + curEvent.goldAmt.format("%d")
                     + " B:" + (curEvent.goldAmt + 4).format("%d")
                     + " S:" + (curEvent.goldAmt + 8).format("%d");
            logLine2 = "";
            logColor = 0x44FFCC;
            _setOptions(["POTION", "BOMB", "SHIELD", "LEAVE"]);
        }
    }

    hidden function _grantItem(kind) {
        if (kind == 0) { player.potions = player.potions + 1; }
        else if (kind == 1) { player.bombs = player.bombs + 1; }
        else { player.shields = player.shields + 1; }
    }

    // ── Combat ──────────────────────────────────────────────────────
    hidden function _enterCombat() {
        state = GS_COMBAT;
        logTitle = enemy.name + "  HP " + enemy.hp.format("%d") + "/" + enemy.maxHp.format("%d");
        logLine1 = "";
        logLine2 = "";
        logColor = isBossFight ? 0xFF4466 : 0xFFCC22;
        _setOptions(["ATTACK", "DEFEND", "ITEM", "RUN"]);
    }

    hidden function _resolveCombatAction(action, itemDamage) {
        var res = CombatSystem.resolveRound(player, enemy, action,
                                            isBossFight, itemDamage);
        logTitle = enemy.name + " " + enemy.hp.format("%d") + "/" + enemy.maxHp.format("%d");
        logLine1 = res.playerLog;
        logLine2 = res.enemyLog;
        if (res.outcome == CR_VICTORY) {
            player.addGold(enemy.goldReward);
            var ups = player.gainXp(enemy.xpReward);
            logColor = 0x44FF66;
            logTitle = "VICTORY!";
            logLine2 = "+" + enemy.xpReward.format("%d") + " XP  +"
                     + enemy.goldReward.format("%d") + "G";
            player.resetCombatBuffs();
            if (ups > 0) {
                // Defer level-up screen until the player taps next.
                state = GS_VICTORY_LOG;
                _setOptions(["NEXT"]);
                _pendingLevelUps = ups;
                return;
            }
            state = GS_VICTORY_LOG;
            _setOptions(["NEXT"]);
        } else if (res.outcome == CR_DEATH) {
            _die();
        } else if (res.outcome == CR_FLED) {
            player.resetCombatBuffs();
            logColor = 0xAACCEE;
            logTitle = "You escape.";
            state    = GS_RUN_DONE;
            _setOptions(["NEXT"]);
        } else {
            // Continue: enemy still alive, show round log → wait for tap.
            state = GS_COMBAT_LOG;
            logColor = 0xFFCC22;
            _setOptions(["NEXT"]);
        }
    }

    hidden var _pendingLevelUps;

    hidden function _enterLevelUp() {
        state    = GS_LEVELUP;
        logTitle = "LEVEL UP!";
        logLine1 = "Lvl " + player.level.format("%d")
                 + "  HP " + player.maxHp.format("%d")
                 + "  ATK " + player.atk.format("%d")
                 + "  DEF " + player.def.format("%d");
        logLine2 = "";
        logColor = 0xFFCC22;
        _setOptions(["NEXT"]);
    }

    hidden function _die() {
        if (floor > bestFloor) { bestFloor = floor; _saveBestFloor(); }
        state    = GS_DEATH;
        logTitle = "YOU DIED";
        logLine1 = "Reached Floor " + floor.format("%d");
        logLine2 = "Lvl " + player.level.format("%d")
                 + "  Gold " + player.gold.format("%d");
        logColor = 0xFF4466;
        _setOptions(["TITLE"]);
    }

    // ── Inventory (modal during combat / explore) ───────────────────
    function openInventory() {
        // Only meaningful when player has at least one item.
        state = GS_INVENTORY;
        logTitle = "INVENTORY";
        logLine1 = "Pot " + player.potions.format("%d")
                 + "  Bmb " + player.bombs.format("%d")
                 + "  Shd " + player.shields.format("%d");
        logLine2 = "";
        logColor = 0x44FFCC;
        _setOptions(["POTION", "BOMB", "SHIELD", "BACK"]);
    }

    // ── Input ───────────────────────────────────────────────────────
    function moveCursor(dir) {
        if (optionCount <= 0) { return; }
        cursor = cursor + dir;
        if (cursor < 0) { cursor = optionCount - 1; }
        if (cursor >= optionCount) { cursor = 0; }
    }

    function back() {
        // BACK from menu = exit. From play = pause confirm.
        if (state == GS_TITLE) { return false; }
        if (state == GS_DEATH) { gotoTitle(); return true; }
        if (state == GS_PAUSE_CONFIRM) { state = _resumeState; return true; }
        // Open pause confirm.
        _resumeState = state;
        var prevOptions = optionLabels;
        var prevCursor  = cursor;
        state    = GS_PAUSE_CONFIRM;
        logTitle = "QUIT TO MENU?";
        logLine1 = "Floor " + floor.format("%d") + "  Lvl "
                 + player.level.format("%d");
        logLine2 = "Progress will be lost.";
        logColor = 0xFFAA22;
        _setOptions(["RESUME", "QUIT"]);
        return true;
    }
    hidden var _resumeState;

    // Confirm current option — main game-flow dispatcher.
    function confirm() {
        if (state == GS_TITLE) {
            newGame();
            return;
        }
        if (state == GS_FLOOR_INTRO) {
            _showCurrentEvent();
            return;
        }
        if (state == GS_EVENT_SHOW) {
            // From banner → combat or continue depending on event type.
            if (curEvent.type == EV_ENEMY || curEvent.type == EV_BOSS) {
                _enterCombat();
            } else {
                _advanceEvent();
            }
            return;
        }
        if (state == GS_TREASURE_LOG || state == GS_TRAP_LOG) {
            _advanceEvent();
            return;
        }
        if (state == GS_RUN_DONE) {
            _advanceEvent();
            return;
        }
        if (state == GS_VICTORY_LOG) {
            if (_pendingLevelUps != null && _pendingLevelUps > 0) {
                _pendingLevelUps = _pendingLevelUps - 1;
                _enterLevelUp();
                return;
            }
            _advanceEvent();
            return;
        }
        if (state == GS_LEVELUP) {
            if (_pendingLevelUps != null && _pendingLevelUps > 0) {
                _enterLevelUp();
                return;
            }
            _advanceEvent();
            return;
        }
        if (state == GS_COMBAT_LOG) {
            _enterCombat();
            return;
        }
        if (state == GS_COMBAT) {
            if (cursor == 0)      { _resolveCombatAction(PA_ATTACK, 0); }
            else if (cursor == 1) { _resolveCombatAction(PA_DEFEND, 0); }
            else if (cursor == 2) {
                if (!player.hasAnyItem()) {
                    // Re-show combat with a brief "no items" prompt.
                    logLine2 = "No items!";
                    return;
                }
                openInventory();
            }
            else                  { _resolveCombatAction(PA_RUN, 0); }
            return;
        }
        if (state == GS_REST_PROMPT) {
            if (cursor == 0) {
                if (player.spendGold(curEvent.goldAmt)) {
                    player.heal(player.maxHp);
                    logTitle = "Healed!";
                    logLine1 = "HP " + player.hp.format("%d") + "/"
                             + player.maxHp.format("%d");
                    logLine2 = "";
                    logColor = 0x44FF66;
                    state    = GS_TREASURE_LOG;
                    _setOptions(["CONTINUE"]);
                } else {
                    logLine2 = "Not enough gold.";
                }
            } else {
                _advanceEvent();
            }
            return;
        }
        if (state == GS_MERCHANT) {
            var price;
            if (cursor == 0) { price = curEvent.goldAmt; }
            else if (cursor == 1) { price = curEvent.goldAmt + 4; }
            else if (cursor == 2) { price = curEvent.goldAmt + 8; }
            else { _advanceEvent(); return; }
            if (player.spendGold(price)) {
                _grantItem(cursor);
                logLine2 = "Bought!";
            } else {
                logLine2 = "Not enough gold.";
            }
            return;
        }
        if (state == GS_INVENTORY) {
            if (cursor == 0) {
                var healed = player.usePotion();
                if (healed == 0) {
                    logLine2 = "No potions!";
                    return;
                }
                _resolveCombatAction(PA_ITEM, -healed);
                return;
            }
            if (cursor == 1) {
                if (player.bombs <= 0) { logLine2 = "No bombs!"; return; }
                var dmg = player.useBomb(enemy);
                _resolveCombatAction(PA_ITEM, dmg);
                return;
            }
            if (cursor == 2) {
                if (player.shields <= 0) { logLine2 = "No shields!"; return; }
                player.useShield();
                _resolveCombatAction(PA_ITEM, 0);
                return;
            }
            // Back to combat without spending a turn
            _enterCombat();
            return;
        }
        if (state == GS_DEATH) {
            gotoTitle();
            return;
        }
        if (state == GS_PAUSE_CONFIRM) {
            if (cursor == 0) { state = _resumeState; return; }
            gotoTitle();
            return;
        }
    }

    // ── Options bookkeeping ─────────────────────────────────────────
    hidden function _setOptions(arr) {
        optionLabels = arr;
        optionCount  = arr.size();
        cursor       = 0;
    }
}
