// ═══════════════════════════════════════════════════════════════════════════
// MainView.mc — Renderer + the 20 fps game loop.
//
// The view owns nothing but pixels and the timer: it hands every input to the
// engine and asks the sport to paint the court. There is no in-game menu — the
// shared Bitochi menu is the root view, and BACK returns to it.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.Timer;
using Toybox.WatchUi;

class MainView extends WatchUi.View {

    var eng;
    hidden var _timer;
    hidden var _w;
    hidden var _h;

    function initialize(ranked as Lang.Boolean) {
        View.initialize();
        eng = new GameEngine(ranked);
        _timer = null;
        _w = 0; _h = 0;
    }

    function onShow() {
        if (_timer == null) { _timer = new Timer.Timer(); }
        try { _timer.start(method(:onTick), DS_TICK_MS, true); } catch (e) {}
    }

    // Release the timer rather than just stopping it: the shared leaderboard
    // pipeline needs timer slots of its own while the post-game card is up, and
    // devices only allow a handful at once.
    function onHide() {
        if (_timer != null) {
            try { _timer.stop(); } catch (e) {}
            _timer = null;
        }
    }

    function onTick() as Void {
        eng.tick();
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        try { _draw(dc); }
        catch (e) {
            try { dc.setColor(DS_BG, DS_BG); dc.clear(); } catch (e2) {}
        }
    }

    hidden function _draw(dc) as Void {
        _w = dc.getWidth();
        _h = dc.getHeight();
        if (!eng.laidOut) { eng.layout(_w, _h); }

        if (eng.state == DS_ST_BRIEF) {
            UIManager.drawBrief(dc, _w, _h, eng);
            return;
        }

        dc.setColor(eng.sport.bgColor(), eng.sport.bgColor());
        dc.clear();
        eng.sport.drawField(dc, eng);

        if (eng.state == DS_ST_AIM || eng.state == DS_ST_POWER ||
            eng.state == DS_ST_RELEASE) {
            // While only the angle is locked in, preview the arc at the court's
            // reference power so the shape of the shot is readable; once the
            // player is on the power meter, show their actual choice.
            var meter = (eng.state == DS_ST_AIM) ? 0.60 : eng.power;
            eng.sport.drawGuide(dc, eng, eng.angle, meter);
        }

        // Confetti and score pops belong to the court, so they land above the
        // rig but under the numbers the player is reading.
        eng.sport.drawOverlay(dc, _w, _h);

        UIManager.drawClockRing(dc, _w, _h, eng);
        UIManager.drawHud(dc, _w, _h, eng);
        UIManager.drawMeter(dc, _w, _h, eng);
        UIManager.drawFeedback(dc, _w, _h, eng);

        // The make flash rings the whole bezel, over everything.
        try { eng.sport.fx.drawRing(dc, _w, _h); } catch (e) {}

        if (eng.state == DS_ST_RESULT) {
            UIManager.drawResult(dc, _w, _h, eng);
        }
    }

    // ── Intents from InputHandler ───────────────────────────────────────────
    function press() as Void {
        if (eng.state == DS_ST_RESULT) {
            try { WatchUi.popView(WatchUi.SLIDE_RIGHT); } catch (e) {}
            return;
        }
        eng.action();
    }

    // Returns true when the engine consumed BACK (a live run just ended into
    // the result card); false lets the delegate pop back to the shared menu.
    function back() as Lang.Boolean { return eng.back(); }
}
