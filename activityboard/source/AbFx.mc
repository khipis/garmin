// ═══════════════════════════════════════════════════════════════════════════
// AbFx.mc — Subtle, guarded sound + haptics for the Activity Board.
//
// This app is a data dashboard, not a game, so feedback is intentionally
// minimal: a light confirm tick when the player opens the "flex" chooser or
// slams a stat onto the world board. Everything is best-effort — silent /
// absent Attention hardware is fine and never crashes.
//
// Master switch lives in Application.Storage under AB_FX_KEY:
//   0 / unset = ON, 1 = OFF (toggled from the FLEX menu's "Sound & Haptics"
//   row). There's no long-lived controller here, so state is read per event
//   (taps are rare — no hot path).
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;

const AB_FX_KEY = "ab_fx";   // 0 = sound+haptics ON, 1 = OFF

class AbFx {
    static function isOn() {
        try {
            var v = Application.Storage.getValue(AB_FX_KEY);
            // NOTE: must be Lang.Number, not a bare `Number`. This file has no
            // implicit Lang import, so a bare `Number` throws a runtime
            // "Symbol Not Found" error (uncatchable by catch(e)) the first time
            // AbFx runs — that was the Activity Board flex-chooser crash.
            if (v instanceof Lang.Number && v == 1) { return false; }
        } catch (e) { }
        return true;
    }
    static function tone(kind) {
        if (!isOn()) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :playTone)) { return; }
        var t;
        if      (kind == 0) { t = Attention.TONE_KEY; }
        else if (kind == 1) { t = Attention.TONE_LOUD_BEEP; }
        else                { t = Attention.TONE_ALERT_LO; }
        try { Attention.playTone(t); } catch (e) {}
    }
    static function vibe(intensity, duration) {
        if (!isOn()) { return; }
        if (!(Toybox has :Attention)) { return; }
        if (!(Attention has :vibrate)) { return; }
        try { Attention.vibrate([new Attention.VibeProfile(intensity, duration)]); } catch (e) {}
    }
}
