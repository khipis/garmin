// ═══════════════════════════════════════════════════════════════════════════
// MainView.mc — The live, scrollable "flex dashboard".
//
// Shows the player's signature FLEX SCORE (with a quick count-up animation) and
// their real activity/sport metrics, each with a subtle progress bar against the
// device's own goal. With more sport boards than fit on one round screen, the
// whole dashboard scrolls vertically (swipe up/down or the UP/DOWN buttons); a
// slim indicator on the right shows position. A gold call-to-action nudges the
// core loop: press SELECT to slam a stat onto the global leaderboard.
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
    hidden var _scrollY;       // current vertical scroll offset (px)
    hidden var _maxScroll;     // max scroll, recomputed each draw
    hidden var _contentH;      // total content height

    function initialize() {
        View.initialize();
        _snap = Metrics.snapshot();
        _flex = Metrics.flexScore(_snap);
        _shown = 0;
        _anim = null;
        _announced = false;
        _w = 0; _h = 0;
        _scrollY = 0; _maxScroll = 0; _contentH = 0;
    }

    function onShow() {
        // Refresh real stats every time the dashboard reappears (e.g. back from
        // the leaderboard) so the numbers stay honest and current.
        _snap = Metrics.snapshot();
        _flex = Metrics.flexScore(_snap);
        _scrollY = 0;
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

    // ── Scrolling ────────────────────────────────────────────────────────────
    // Called from InputHandler on swipe / button. dy > 0 reveals content below.
    function scrollBy(dy as Lang.Number) as Void {
        _scrollY += dy;
        if (_scrollY > _maxScroll) { _scrollY = _maxScroll; }
        if (_scrollY < 0) { _scrollY = 0; }
        WatchUi.requestUpdate();
    }
    function canScroll() as Lang.Boolean { return _maxScroll > 0; }
    function pageStep() as Lang.Number {
        var s = _h / 2;
        return (s < 30) ? 30 : s;
    }

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
        var big = Graphics.FONT_NUMBER_MEDIUM;
        var bigH = dc.getFontHeight(big);
        var gapS = fh / 2;

        dc.setColor(LB_BG, LB_BG);
        dc.clear();

        var pad = (_h * 6) / 100;
        if (pad < 6) { pad = 6; }

        // Everything is laid out in "content space" (y grows downward from 0)
        // and drawn shifted up by _scrollY. Off-screen text is harmlessly
        // clipped by the device context.
        var y = pad;
        var sy;   // reused screen-space y

        // Title.
        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (y + fh / 2) - _scrollY, Graphics.FONT_XTINY, "ACTIVITY BOARD", VC);
        y += fh + gapS;

        // FLEX SCORE headline (animated count-up).
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (y + bigH / 2) - _scrollY, big, Metrics.groupNum(_shown), VC);
        y += bigH;
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (y + fh / 2) - _scrollY, Graphics.FONT_XTINY, "FLEX SCORE", VC);
        y += fh + gapS + gapS;

        // Metric / sport rows.
        var cat = Metrics.catalog();
        var n = cat.size();
        var rowH = fh + (fh * 3) / 4;
        var lcol = (_w * 16) / 100;
        var rcol = (_w * 84) / 100;

        for (var i = 0; i < n; i++) {
            var variant = cat[i][0];
            var label   = cat[i][1];
            var val     = Metrics.valueFor(variant, _snap);
            var goal    = Metrics.goalFor(variant, _snap);
            var rowCY   = (y + rowH / 2) - _scrollY;

            // Subtle goal progress bar behind the row (only when a goal exists).
            if (goal > 0) {
                var pct = (val * 100) / goal;
                if (pct > 100) { pct = 100; }
                var barW = (_w * 72 / 100) * pct / 100;
                if (barW > 0) {
                    dc.setColor(0x0E2A33, Graphics.COLOR_TRANSPARENT);
                    dc.fillRectangle((_w * 14) / 100, rowCY - rowH / 2 + 1, barW, rowH - 2);
                }
            }

            var hit = (goal > 0 && val >= goal);
            dc.setColor(hit ? LB_GREEN : LB_TEXT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(lcol, rowCY, Graphics.FONT_XTINY, label,
                        Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(hit ? LB_GREEN : LB_ACCENT, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rcol, rowCY, Graphics.FONT_XTINY, Metrics.display(variant, val),
                        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            y += rowH;
        }

        y += gapS + gapS;

        // Call-to-action + footer.
        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (y + fh / 2) - _scrollY, Graphics.FONT_XTINY, "SELECT = FLEX ON WORLD", VC);
        y += fh + gapS;
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (y + fh / 2) - _scrollY, Graphics.FONT_XTINY, "bitochi.com", VC);
        y += fh + pad;

        // Finalise scroll metrics.
        _contentH  = y;
        _maxScroll = _contentH - _h;
        if (_maxScroll < 0) { _maxScroll = 0; }
        if (_scrollY > _maxScroll) { _scrollY = _maxScroll; }

        _drawScrollbar(dc);
    }

    // Slim right-edge scroll indicator, only when content overflows.
    hidden function _drawScrollbar(dc) {
        if (_maxScroll <= 0 || _contentH <= 0) { return; }
        var trackH = (_h * 56) / 100;
        var trackY = (_h - trackH) / 2;
        var trackX = _w - 4;

        var thumbH = (trackH * _h) / _contentH;
        if (thumbH < 12) { thumbH = 12; }
        if (thumbH > trackH) { thumbH = trackH; }
        var thumbY = trackY + ((trackH - thumbH) * _scrollY) / _maxScroll;

        dc.setColor(0x1A2630, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(trackX, trackY, 3, trackH, 1);
        dc.setColor(LB_ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.fillRoundedRectangle(trackX, thumbY, 3, thumbH, 1);
    }
}
