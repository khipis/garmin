// ═══════════════════════════════════════════════════════════════════════════
// GmOptions.mc — The shared OPTIONS screen + full-version unlock entry.
//
// Reached from the main menu's OPTIONS row. A clean native Menu2 listing:
//   • every per-game setting as a cycler (Difficulty / Speed / Mode / …)
//   • a final "Full version" row → unlock-code entry (Entitlement)
//
// Picking a setting cycles its value in place and persists it (Application.
// Storage) so the game reads it back at start. Settings can be marked premium
// (GmOption.gatedFrom): choosing a gated value while locked routes the player
// to the unlock screen instead of applying it — the foundation for paid modes.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

const GM_UNLOCK_ID = "__unlock";

class GmOptionsMenu extends WatchUi.Menu2 {
    function initialize(cfg as MenuConfig) {
        Menu2.initialize({ :title => "OPTIONS" });

        var opts = cfg.options;
        for (var i = 0; i < opts.size(); i++) {
            var o = opts[i];
            addItem(new WatchUi.MenuItem(o.label, o.valueStr(), i, null));
        }

        // NOTE: the "Full version" unlock row is intentionally hidden for now
        // (product decision pending). The Entitlement + code-entry plumbing is
        // kept intact below so it can be re-enabled by restoring this row.
        // var unlocked = cfg.isUnlocked();
        // addItem(new WatchUi.MenuItem("Full version",
        //     unlocked ? "Active" : "Enter code",
        //     GM_UNLOCK_ID, null));
    }
}

class GmOptionsDelegate extends WatchUi.Menu2InputDelegate {
    hidden var _cfg;

    function initialize(cfg as MenuConfig) {
        Menu2InputDelegate.initialize();
        _cfg = cfg;
    }

    function onSelect(item) {
        var id = item.getId();

        if (id instanceof Lang.String && id.equals(GM_UNLOCK_ID)) {
            if (_cfg.isUnlocked()) { return; }   // already active — nothing to do
            _openUnlock();
            return;
        }

        // A settings cycler (id is the index into cfg.options).
        if (!(id instanceof Lang.Number)) { return; }
        var o    = _cfg.options[id];
        var next = (o.index() + 1) % o.values.size();
        if (o.isGated(next) && !_cfg.isUnlocked()) {
            _openUnlock();
            return;
        }
        o.cycle();
        item.setSubLabel(o.valueStr());
        WatchUi.requestUpdate();
    }

    hidden function _openUnlock() as Void {
        try {
            var v = new GmCodeEntryView(_cfg);
            WatchUi.pushView(v, new GmCodeEntryDelegate(v), WatchUi.SLIDE_LEFT);
        } catch (e) {}
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Unlock-code entry — vertical character wheel (same feel as the leaderboard
// name entry). UP/DOWN pick a char, SELECT advances, HOLD or last-char SELECT
// submits. The code is validated LOCALLY by Entitlement (no network).
// ═══════════════════════════════════════════════════════════════════════════
class GmCodeEntryView extends WatchUi.View {
    hidden var _cfg;
    hidden var _chars;    // indices into Entitlement.ALPHABET
    hidden var _pos;
    hidden var _w;
    hidden var _h;

    function initialize(cfg as MenuConfig) {
        View.initialize();
        _cfg   = cfg;
        _chars = new [Entitlement.CODE_LEN];
        for (var i = 0; i < Entitlement.CODE_LEN; i++) { _chars[i] = 0; }
        _pos = 0;
        _w = 0; _h = 0;
    }

    function adj(d) {
        var n = Entitlement.ALPHABET.length();
        _chars[_pos] = (_chars[_pos] + d + n) % n;
        WatchUi.requestUpdate();
    }
    function next()   { _pos = (_pos + 1) % Entitlement.CODE_LEN; WatchUi.requestUpdate(); }
    function prev()   { _pos = (_pos + Entitlement.CODE_LEN - 1) % Entitlement.CODE_LEN; WatchUi.requestUpdate(); }
    function isLast() { return _pos == Entitlement.CODE_LEN - 1; }
    function atStart(){ return _pos == 0; }

    hidden function _code() as Lang.String {
        var s = "";
        for (var i = 0; i < Entitlement.CODE_LEN; i++) {
            s = s + Entitlement.ALPHABET.substring(_chars[i], _chars[i] + 1);
        }
        return s;
    }

    // Attempt redemption; chain to a result card either way, then back out.
    function submit() as Void {
        var ok = Entitlement.tryRedeem(_cfg.gameId, _code());
        WatchUi.popView(WatchUi.SLIDE_DOWN);   // leave the entry view
        var msg = ok
            ? { "title" => "Unlocked!", "body" => "Full version enabled. Enjoy every mode.", "min_gap_s" => 0 }
            : { "title" => "Invalid code", "body" => "That code didn't match. Check it and try again.", "min_gap_s" => 0 };
        try {
            var mv = new LbMessageView(msg);
            WatchUi.pushView(mv, new LbMessageDelegate(mv), WatchUi.SLIDE_UP);
        } catch (e) {}
    }

    hidden function _chAt(idx) { return Entitlement.ALPHABET.substring(idx, idx + 1); }

    function onUpdate(dc) {
        _w = dc.getWidth();
        _h = dc.getHeight();
        var cx = _w / 2;

        dc.setColor(LB_BG, LB_BG); dc.clear();

        dc.setColor(LB_GOLD, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 8 / 100, Graphics.FONT_XTINY,
                    "UNLOCK CODE", Graphics.TEXT_JUSTIFY_CENTER);

        // Assembled code with a cursor bracket on the active position.
        var disp = "";
        for (var i = 0; i < Entitlement.CODE_LEN; i++) {
            var ch = _chAt(_chars[i]);
            disp = (i == _pos) ? disp + "[" + ch + "]" : disp + " " + ch + " ";
        }
        dc.setColor(LB_TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h * 24 / 100, Graphics.FONT_XTINY, disp, Graphics.TEXT_JUSTIFY_CENTER);

        // Character wheel for the active position.
        var ci   = _chars[_pos];
        var cLen = Entitlement.ALPHABET.length();
        var midY = _h * 52 / 100;
        var step = _h * 11 / 100;

        dc.setColor(0x33414F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY - step, Graphics.FONT_SMALL,
                    _chAt((ci + cLen - 1) % cLen), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY - step / 2, Graphics.FONT_LARGE,
                    _chAt(ci), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(0x33414F, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, midY + step, Graphics.FONT_SMALL,
                    _chAt((ci + 1) % cLen), Graphics.TEXT_JUSTIFY_CENTER);

        var fhn = dc.getFontHeight(Graphics.FONT_XTINY);
        dc.setColor(LB_MUTED, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, _h - fhn - fhn / 2, Graphics.FONT_XTINY,
                    "UP/DN  SEL next", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, _h - fhn / 2, Graphics.FONT_XTINY,
                    "HOLD = submit", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class GmCodeEntryDelegate extends WatchUi.BehaviorDelegate {
    hidden var _v;

    function initialize(v as GmCodeEntryView) { BehaviorDelegate.initialize(); _v = v; }

    function onKey(evt) {
        var k = evt.getKey();
        if (k == WatchUi.KEY_UP)    { _v.adj(1);  return true; }
        if (k == WatchUi.KEY_DOWN)  { _v.adj(-1); return true; }
        if (k == WatchUi.KEY_ENTER) { return _advance(); }
        if (k == WatchUi.KEY_ESC)   { return onBack(); }
        return false;
    }
    function onSelect()       { return _advance(); }
    function onNextPage()     { _v.adj(1);  return true; }
    function onPreviousPage() { _v.adj(-1); return true; }
    function onHold(evt)      { _v.submit(); return true; }

    hidden function _advance() {
        if (_v.isLast()) { _v.submit(); }
        else             { _v.next(); }
        return true;
    }

    function onBack() {
        if (_v.atStart()) { WatchUi.popView(WatchUi.SLIDE_DOWN); }
        else              { _v.prev(); }
        return true;
    }
}
