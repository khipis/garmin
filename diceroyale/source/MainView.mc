// ═══════════════════════════════════════════════════════════════
// MainView.mc — DiceRoyale view + tap hit-testing.
//
// We don't run a continuous timer — the game is turn-based, so we
// just request updates whenever input arrives.
// ═══════════════════════════════════════════════════════════════

using Toybox.WatchUi;
using Toybox.Graphics;

class MainView extends WatchUi.View {

    var ctrl;
    hidden var _sw;
    hidden var _sh;

    function initialize() {
        View.initialize();
        ctrl = new GameController();
        _sw = 0; _sh = 0;
    }

    function onShow() {}
    function onHide() {}

    function onUpdate(dc) {
        _sw = dc.getWidth(); _sh = dc.getHeight();
        // Menu lives in the shared root view — drop straight into play and
        // never render an in-game menu here.
        if (ctrl.state == DR_MENU) { ctrl.beginGame(); }
        if (ctrl.state == DR_OVER) {
            UIManager.drawOver(dc, _sw, _sh, ctrl); return;
        }
        // DR_PLAY
        if (ctrl.phase == DR_PHASE_ROLL) {
            UIManager.drawPlay(dc, _sw, _sh, ctrl);
        } else {
            UIManager.drawScoreScreen(dc, _sw, _sh, ctrl);
        }
    }

    // ── Intents ─────────────────────────────────────────────────
    function navPrev() {
        if (ctrl.state == DR_MENU) { ctrl.menuPrev(); return; }
        if (ctrl.state == DR_OVER) { ctrl.gotoMenu(); return; }
        ctrl.navPrev();
    }
    function navNext() {
        if (ctrl.state == DR_MENU) { ctrl.menuNext(); return; }
        if (ctrl.state == DR_OVER) { ctrl.gotoMenu(); return; }
        ctrl.navNext();
    }
    function navSelect() {
        if (ctrl.state == DR_MENU) {
            if (ctrl.menuRow == DR_ROW_LB) { openLeaderboard(); return; }
            ctrl.menuActivate(); return;
        }
        if (ctrl.state == DR_OVER) { ctrl.gotoMenu(); return; }
        ctrl.selectAction();
    }
    function navBack() {
        // BACK always returns to the shared menu (pop the gameplay view).
        return false;
    }

    // Open the shared global leaderboard for the current mode.
    function openLeaderboard() {
        var v = new LbScoresView(LB_GAME_ID, ctrl.variantName(), "DICE ROYALE");
        WatchUi.pushView(v, new LbScoresDelegate(v), WatchUi.SLIDE_LEFT);
    }

    // Tap hit-test for menu rows / dice / buttons / categories.
    function handleTap(x, y) {
        if (ctrl.state == DR_MENU) {
            var rg = UIManager.rowGeom(_sw, _sh);
            var rowH = rg[0]; var rowW = rg[1];
            var rowX = rg[2]; var rowY0 = rg[3]; var gap = rg[4];
            for (var i = 0; i < DR_MENU_ROWS; i++) {
                var ry = rowY0 + i * (rowH + gap);
                if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH) {
                    ctrl.setMenuRow(i);
                    if (i == DR_ROW_LB) { openLeaderboard(); }
                    else { ctrl.menuActivate(); }
                    return;
                }
            }
            return;
        }
        if (ctrl.state == DR_OVER) { ctrl.gotoMenu(); return; }

        // DR_PLAY
        if (ctrl.phase == DR_PHASE_ROLL) {
            _tapPhaseRoll(x, y);
        } else {
            _tapPhaseScore(x, y);
        }
    }

    hidden function _tapPhaseRoll(x, y) {
        // 1. Dice row.
        var dl  = UIManager.diceLayout(_sw, _sh);
        var s   = dl[0]; var gap = dl[1]; var x0 = dl[2]; var y0 = dl[3];
        if (y >= y0 - 4 && y < y0 + s + 4) {
            for (var i = 0; i < DR_DICE_COUNT; i++) {
                var dx = x0 + i * (s + gap);
                if (x >= dx - 2 && x < dx + s + 2) {
                    ctrl.setRollCursor(i);
                    ctrl.selectAction();
                    return;
                }
            }
        }
        // 2. ROLL / SCORE buttons.
        var bl = UIManager.buttonLayout(_sw, _sh);
        var bw = bl[0]; var bh = bl[1]; var bx0 = bl[2]; var by = bl[3]; var bgap = bl[4];
        if (y >= by - 4 && y < by + bh + 4) {
            if (x >= bx0 - 2 && x < bx0 + bw + 2) {
                ctrl.setRollCursor(DR_POS_ROLL);
                ctrl.selectAction();
                return;
            }
            var bx1 = bx0 + bw + bgap;
            if (x >= bx1 - 2 && x < bx1 + bw + 2) {
                ctrl.setRollCursor(DR_POS_SCORE);
                ctrl.selectAction();
                return;
            }
        }
    }

    hidden function _tapPhaseScore(x, y) {
        var rg = UIManager.scoreRowGeom(_sw, _sh);
        var rowH = rg[0]; var rowW = rg[1]; var rowX = rg[2]; var listY0 = rg[3];

        // Compute the window first row exactly like drawScoreScreen.
        var window = 7;
        var first = ctrl.scoreCursor - window / 2;
        var maxFirst = DR_CAT_COUNT - window;
        if (first < 0) { first = 0; }
        if (first > maxFirst) { first = maxFirst; }
        if (first < 0) { first = 0; }
        var last = first + window;
        if (last > DR_CAT_COUNT) { last = DR_CAT_COUNT; }

        for (var i = first; i < last; i++) {
            var ry = listY0 + (i - first) * rowH;
            if (x >= rowX && x < rowX + rowW && y >= ry && y < ry + rowH - 2) {
                if (ctrl.scores.isAvailable(i) && !ctrl.scores.isUsed(i)) {
                    ctrl.setScoreCursor(i);
                    ctrl.selectAction();
                }
                return;
            }
        }
    }
}
