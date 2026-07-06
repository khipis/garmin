// ═══════════════════════════════════════════════════════════════════════════
// CategoryMenu.mc — "FLEX ON THE WORLD" chooser + the core addictive loop.
//
// Every row is a real stat with its live value as the subtitle. Pick one and we
// instantly submit it to the global leaderboard and slide up the post-game rank
// card (YOU #12 / 3,401 · +85 to pass the player above you) — the little hit of
// competitive dopamine that keeps people coming back to out-flex the world.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Lang;

const FLEX_BOARD_ID  = "__board";
const FLEX_RENAME_ID = "__rename";

class FlexMenu extends WatchUi.Menu2 {
    function initialize(snap as Lang.Dictionary) {
        Menu2.initialize({ :title => "FLEX ON WORLD" });

        // Headline: the signature Flex Score.
        var flex = Metrics.flexScore(snap);
        addItem(new WatchUi.MenuItem("Flex Score",
            Metrics.groupNum(flex) + " pts", Metrics.V_FLEX, null));

        // Each real metric with its current value.
        var cat = Metrics.catalog();
        for (var i = 0; i < cat.size(); i++) {
            var v = cat[i][0];
            addItem(new WatchUi.MenuItem(cat[i][1],
                Metrics.display(v, Metrics.valueFor(v, snap)), v, null));
        }

        // Browse the boards without submitting, plus rename.
        addItem(new WatchUi.MenuItem("Leaderboard", "browse the boards", FLEX_BOARD_ID, null));
        var nm = Leaderboard.loadUser();
        addItem(new WatchUi.MenuItem("Change name", (nm != null) ? nm : "set your tag", FLEX_RENAME_ID, null));
    }
}

class FlexMenuDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _snap;

    function initialize(snap as Lang.Dictionary) {
        Menu2InputDelegate.initialize();
        _snap = snap;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == null) { return; }
        WatchUi.popView(WatchUi.SLIDE_DOWN);

        if (id.equals(FLEX_BOARD_ID)) {
            _openBoard(Metrics.V_FLEX);
            return;
        }
        if (id.equals(FLEX_RENAME_ID)) {
            var nv = new LbNameEntryView();
            WatchUi.pushView(nv, new LbNameEntryDelegate(nv), WatchUi.SLIDE_LEFT);
            return;
        }

        // A real metric variant → submit the value and open the rank card/board.
        var val = Metrics.valueFor(id, _snap);
        Leaderboard.submitScore(LB_GAME_ID, val, id);
        Leaderboard.showPostGame(LB_GAME_ID, id, "ACTIVITY BOARD");
    }

    hidden function _openBoard(variant as Lang.String) {
        var v = new LbScoresView(LB_GAME_ID, variant, "ACTIVITY BOARD");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }
}
