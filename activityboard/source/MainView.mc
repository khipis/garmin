// ═══════════════════════════════════════════════════════════════════════════
// MainView.mc — The live "flex dashboard".
//
// Shows the player's signature FLEX SCORE (with a quick count-up animation) and
// their real activity metrics, each with a subtle progress bar against the
// device's own goal. A gold call-to-action nudges the core loop: press SELECT
// to slam a stat onto the global leaderboard and race the world.
//
// Colours reuse the shared leaderboard palette (LB_* consts from LbViews.mc) so
// the watch and bitochi.com feel like one product.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;

class MainView extends WatchUi.View {
    hidden var _snap;          // latest real-data snapshot
    hidden var _flex;          // target flex score
    hidden var _shown;         // animated (counting-up) flex value
    hidden var _anim;          // count-up timer
    hidden var _announced;     // launch message shown once this session
    hidden var _w;
    hidden var _h;

    function initialize() {
        View.initialize();
        _snap = Metrics.snapshot();
        _flex = Metrics.flexScore(_snap);
        _shown = 0;
        _anim = null;
        _announced = false;
        _w = 0; _h = 0;
    }

    function onShow() {
        // Refresh real stats every time the dashboard reappears (e.g. back from
        // the leaderboard) so the numbers stay honest and current.
        _snap = Metrics.snapshot();
        _flex = Metrics.flexScore(_snap);
        _startCountUp();

        // One launch announcement per session (cross-promo / paid invite),
        // drawn from the previous session's cached bundle; fully throttled.
        if (!_announced) {
            _announced = true;
            Leaderboard.announce(LB_GAME_ID, null);
        }
    }

    function onHide() {
        if (_anim != null) { _anim.stop(); _anim = null; }
    }

    // Fresh snapshot on demand (used by the delegate when opening the menu).
    function snap() { return _snap; }
    function refresh() { _snap = Metrics.snapshot(); _flex = Metrics.flexScore(_snap); }

    hidden function _startCountUp() {
        _shown = 0;
        if (_flex <= 0) { return; }
        if (_anim == null) { _anim = new Timer.Timer(); }
        try { _anim.start(method(:_tick), 28, true); } catch (e) { _shown = _flex; }
    }

    function _tick() as Void {
        var stepInc = _flex / 22;
        if (stepInc < 1) { stepInc = 1; }
        _shown += stepInc;
        if (_shown >= _flex) {
            _shown = _flex;
            if (_anim != null) { _anim.stop(); }
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;
        var VC = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        var fh = dc.getFontHeight(Graphics.FONT_XTINY);

        dc.setColor(LB_BG, LB_BG);
        dc.clear();

        var pad = (_h * 6) / 100;
        if (pad < 4) { pad = 4; }

        // Title.
        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, pad + fh / 2, Graphics.FONT_XTINY, "ACTIVITY BOARD", VC);

        // FLEX SCORE headline (animated count-up).
        var flexCY = (_h * 27) / 100;
        var big = Graphics.FONT_NUMBER_MEDIUM;
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, flexCY, big, Metrics.groupNum(_shown), VC);
        var bigH = dc.getFontHeight(big);
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, flexCY + bigH / 2 + fh / 2, Graphics.FONT_XTINY, "FLEX SCORE", VC);

        // Footer + call-to-action.
        var footerCY = _h - pad - fh / 2;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, footerCY, Graphics.FONT_XTINY, "bitochi.com", VC);
        var ctaCY = footerCY - fh;
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, ctaCY, Graphics.FONT_XTINY, "SELECT = FLEX ON WORLD", VC);

        // Metric rows between the headline and the CTA.
        var rowsTop = flexCY + bigH / 2 + fh + fh / 2;
        var rowsBot = ctaCY - fh;
        var cat = Metrics.catalog();
        var n = cat.size();
        var rowH = (rowsBot - rowsTop) / n;
        if (rowH < fh + 2) { rowH = fh + 2; }

        var lcol = (_w * 15) / 100;
        var rcol = (_w * 85) / 100;

        for (var i = 0; i < n; i++) {
            var variant = cat[i][0];
            var label   = cat[i][1];
            var val     = Metrics.valueFor(variant, _snap);
            var goal    = Metrics.goalFor(variant, _snap);
            var rowCY   = rowsTop + i * rowH + rowH / 2;

            // Subtle goal progress bar behind the row (only when a goal exists).
            if (goal > 0) {
                var pct = (val * 100) / goal;
                if (pct > 100) { pct = 100; }
                var barW = (_w * 74 / 100) * pct / 100;
                if (barW > 0) {
                    dc.setColor(0x0E2A33, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle((_w * 13) / 100, rowCY - rowH / 2 + 1, barW, rowH - 2);
                }
            }

            var hit = (goal > 0 && val >= goal);
            dc.setColor(hit ? LB_GREEN : LB_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lcol, rowCY, Graphics.FONT_XTINY, label,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(hit ? LB_GREEN : LB_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rcol, rowCY, Graphics.FONT_XTINY, Metrics.display(variant, val),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
