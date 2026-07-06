// ═══════════════════════════════════════════════════════════════════════════
// CategoryMenu.mc — "FLEX ON THE WORLD" chooser + the core addictive loop.
//
// Two submission modes:
//   Flex Score  → submits ALL variants in a sequential queue (one request per
//                 650 ms so Garmin's single-in-flight limit is never hit), then
//                 shows the post-game standing for the flex board.
//   Any stat    → submits just that one variant, shows its standing.
//
// Garmin's Communications.makeWebRequest only allows one pending request at a
// time. Rapid-fire calls throw InvalidValueException (silently swallowed by
// LbSubmitter). The FlexBatchSender queues multiple submissions 650 ms apart —
// comfortably past the typical 100-300 ms round-trip to api.bitochi.com.
//
// _batchSender lives at module scope so the timer chain survives popView
// (otherwise the FlexMenuDelegate is GC'd before the queue finishes).
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Lang;
using Toybox.Timer;

const FLEX_BOARD_ID  = "__board";
const FLEX_RENAME_ID = "__rename";

// Module-level ref so the batch-timer chain isn't GC'd after popView.
var _batchSender = null;

// ── Sequential score submitter ────────────────────────────────────────────────
// Submits an array of [score, variant] pairs one at a time, 650 ms apart.
class FlexBatchSender {
    hidden var _items;   // Array of [score, variant] pairs
    hidden var _idx;
    hidden var _timer;

    function initialize(items as Lang.Array) {
        _items = items;
        _idx   = 0;
        _timer = null;
    }

    function start() as Void { _submit(); }

    function _submit() as Void {
        if (_idx >= _items.size()) { _timer = null; return; }
        var item = _items[_idx];
        _idx++;
        Leaderboard.submitScore(LB_GAME_ID, item[0], item[1]);
        // Schedule the next item only if there are more to send.
        if (_idx < _items.size()) {
            if (_timer == null) { _timer = new Timer.Timer(); }
            _timer.start(method(:_submit), 650, false);
        } else {
            _timer = null;
        }
    }
}

// ── Menu ─────────────────────────────────────────────────────────────────────
class FlexMenu extends WatchUi.Menu2 {
    function initialize(snap as Lang.Dictionary) {
        Menu2.initialize({ :title => "FLEX ON WORLD" });

        // Headline row: Flex Score. Selecting it sends ALL boards at once.
        var flex = Metrics.flexScore(snap);
        addItem(new WatchUi.MenuItem("Flex Score",
            Metrics.groupNum(flex) + " pts  [all boards]",
            Metrics.V_FLEX, null));

        // Individual stat rows — each submits only its own variant.
        var cat = Metrics.catalog();
        for (var i = 0; i < cat.size(); i++) {
            var v = cat[i][0];
            addItem(new WatchUi.MenuItem(cat[i][1],
                Metrics.display(v, Metrics.valueFor(v, snap)), v, null));
        }

        // Non-submission utility rows.
        addItem(new WatchUi.MenuItem("Leaderboard", "browse the boards",
                                     FLEX_BOARD_ID, null));
        var nm = Leaderboard.loadUser();
        addItem(new WatchUi.MenuItem("Change name",
                                     (nm != null) ? nm : "set your tag",
                                     FLEX_RENAME_ID, null));
    }
}

// ── Delegate ─────────────────────────────────────────────────────────────────
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

        // ── Browse only (no submission) ──────────────────────────────────────
        if (id.equals(FLEX_BOARD_ID)) {
            _openBoard(Metrics.V_FLEX);
            return;
        }
        if (id.equals(FLEX_RENAME_ID)) {
            var nv = new LbNameEntryView();
            WatchUi.pushView(nv, new LbNameEntryDelegate(nv), WatchUi.SLIDE_LEFT);
            return;
        }

        // ── Flex Score: submit ALL variants sequentially ─────────────────────
        // Build the queue: flex first (so the standing query matches the
        // post-game card), then every individual metric.
        if (id.equals(Metrics.V_FLEX)) {
            var items = new [0] as Lang.Array;
            items.add([Metrics.flexScore(_snap), Metrics.V_FLEX]);
            var cat = Metrics.catalog();
            for (var i = 0; i < cat.size(); i++) {
                var v   = cat[i][0];
                var val = Metrics.valueFor(v, _snap);
                items.add([val, v]);
            }
            _batchSender = new FlexBatchSender(items);
            _batchSender.start();
            // showPostGame fires 1 600 ms later — the flex submission is
            // already on its way by then (typical round-trip < 400 ms).
            Leaderboard.showPostGame(LB_GAME_ID, Metrics.V_FLEX, "ACTIVITY BOARD");
            return;
        }

        // ── Individual metric: submit only that variant ──────────────────────
        var val = Metrics.valueFor(id, _snap);
        Leaderboard.submitScore(LB_GAME_ID, val, id);
        Leaderboard.showPostGame(LB_GAME_ID, id, "ACTIVITY BOARD");
    }

    hidden function _openBoard(variant as Lang.String) {
        var v = new LbScoresView(LB_GAME_ID, variant, "ACTIVITY BOARD");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }
}
