// ═══════════════════════════════════════════════════════════════
// EventSystem.mc — Event type codes + shared payload class.
//
// Events are POD (plain data — name, value, optional Enemy ref).
// They're rolled at FLOOR ENTRY by DungeonGenerator and stored in a
// list inside the controller — no event ever needs to be generated
// during input handling, which keeps every screen transition
// instant.
// ═══════════════════════════════════════════════════════════════

const EV_ENEMY    = 0;
const EV_TREASURE = 1;
const EV_TRAP     = 2;
const EV_MERCHANT = 3;
const EV_REST     = 4;
const EV_BOSS     = 5;

class GameEvent {
    var type;
    var enemy;        // Enemy or null
    var goldAmt;      // for treasure / rest cost
    var itemKind;     // 0=potion 1=bomb 2=shield   (treasure / merchant)
    var damage;       // for trap
    var label;        // pre-baked headline string

    function initialize(t) {
        type = t; enemy = null; goldAmt = 0; itemKind = -1;
        damage = 0; label = "";
    }
}
