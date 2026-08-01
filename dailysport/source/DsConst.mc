// ═══════════════════════════════════════════════════════════════════════════
// DsConst.mc — Constants, palette and small guarded helpers for
// DAILY SPORT CHALLENGE.
//
// Everything here is prefixed Ds/DS_ so it can never collide with the shared
// leaderboard / menu / progress modules that compile alongside the game.
// ═══════════════════════════════════════════════════════════════════════════
using Toybox.Application;
using Toybox.Attention;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;

// Leaderboard + entitlement id. Must match the folder name and the website.
const DS_GAME_ID = "dailysport";

// ── Engine states ───────────────────────────────────────────────────────────
const DS_ST_BRIEF    = 0;   // pre-round card: today's challenge + energy
const DS_ST_AIM      = 1;   // angle meter sweeping
const DS_ST_POWER    = 2;   // power meter sweeping
const DS_ST_RELEASE  = 3;   // release-timing window
const DS_ST_FLIGHT   = 4;   // ball in the air
const DS_ST_FEEDBACK = 5;   // short outcome flash before the next shot
const DS_ST_RESULT   = 6;   // run summary

// ── Shot outcomes ───────────────────────────────────────────────────────────
const DS_OUT_NONE   = 0;
const DS_OUT_SWISH  = 1;   // clean through, no contact
const DS_OUT_RIM    = 2;   // rattled in off the rim
const DS_OUT_BANK   = 3;   // in off the backboard
const DS_OUT_MISS   = 4;

// ── Loop timing ─────────────────────────────────────────────────────────────
const DS_TICK_MS      = 50;      // 20 fps game loop
const DS_RELEASE_MS   = 720;     // length of the release-timing window
const DS_RELEASE_DEAD = 0.18;    // |offset| below this is a perfect release
const DS_FEEDBACK_MS  = 620;     // outcome flash between shots

// ── Physics (tuned in screen units, scaled by screen height at runtime) ─────
const DS_REF_H       = 240.0;    // reference screen height the tuning assumes
const DS_GRAVITY     = 860.0;    // px/s² at the reference height
const DS_DRAG        = 0.22;     // linear air resistance, 1/s
const DS_RESTITUTION = 0.56;     // rim / backboard bounciness
const DS_AIM_MIN     = 24.0;     // aim meter sweeps between these angles
const DS_AIM_MAX     = 76.0;
const DS_AIM_REF     = 52.0;     // angle the power meter is normalised around
const DS_PWR_LO      = 0.46;     // meter 0%   = 46% of the reference power
const DS_PWR_HI      = 1.36;     // meter 100% = 136% of the reference power

// ── Palette ─────────────────────────────────────────────────────────────────
// Every colour is built from the 0x00 / 0x55 / 0xAA / 0xFF channel levels that
// Garmin's memory-in-pixel screens can show. Anything else is snapped to the
// nearest of those on a fēnix, which is how a brown court turns olive and a
// grey pole turns blue — so the whole game stays on-palette instead.
const DS_BG      = 0x000000;
const DS_ACCENT  = 0xFF5500;   // the app's orange
const DS_GOLD    = 0xFFAA00;
const DS_GREEN   = 0x00FFAA;
const DS_RED     = 0xFF5555;
const DS_TEXT    = 0xFFFFFF;
const DS_DIM     = 0xAAAAAA;
const DS_INSET   = 0x0055AA;   // round-screen frame ring
const DS_TRACK   = 0x000000;   // meter groove
const DS_EDGE    = 0x555555;   // hairlines and frames
const DS_GUIDE   = 0x55AAFF;   // predicted-arc dots

// ── Storage keys ────────────────────────────────────────────────────────────
const DS_K_MODE   = "ds_mode";    // GmOption: 0 = daily, 1 = practice
const DS_K_SPORT  = "ds_sport";   // GmOption: 0 = today's sport, else roster+1
const DS_K_GUIDE  = "ds_guide";   // GmOption: 0 = short, 1 = full, 2 = off
const DS_K_BALL   = "ds_ball";    // GmOption: cosmetic ball
const DS_K_COURT  = "ds_court";   // GmOption: cosmetic court
const DS_K_FX     = "ds_fx";      // GmOption: 0 = on, 1 = off
const DS_K_PROF   = "ds_prof";    // Dictionary: lifetime profile
const DS_K_DAY    = "ds_day";     // Dictionary: today's attempts / best

// ── Guarded storage + date helpers ──────────────────────────────────────────
module DsUtil {

    function optIndex(key as Lang.String, def as Lang.Number,
                      count as Lang.Number) as Lang.Number {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Number && v >= 0 && v < count) { return v; }
        } catch (e) {}
        return def;
    }

    function getDict(key as Lang.String) as Lang.Dictionary {
        try {
            var v = Application.Storage.getValue(key);
            if (v instanceof Lang.Dictionary) { return v; }
        } catch (e) {}
        return {};
    }

    function setDict(key as Lang.String, d as Lang.Dictionary) as Void {
        try { Application.Storage.setValue(key, d); } catch (e) {}
    }

    function num(d as Lang.Dictionary, key as Lang.String,
                 def as Lang.Number) as Lang.Number {
        try {
            if (d.hasKey(key) && d[key] instanceof Lang.Number) { return d[key]; }
        } catch (e) {}
        return def;
    }

    function str(d as Lang.Dictionary, key as Lang.String) as Lang.String {
        try {
            if (d.hasKey(key) && d[key] instanceof Lang.String) { return d[key]; }
        } catch (e) {}
        return "";
    }

    // Today as "YYYYMMDD" (local time — daily granularity needs nothing more).
    function todayKey() as Lang.String {
        try {
            var ci = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            var mo = ci.month < 10 ? "0" + ci.month.toString() : ci.month.toString();
            var dy = ci.day   < 10 ? "0" + ci.day.toString()   : ci.day.toString();
            return ci.year.toString() + mo + dy;
        } catch (e) {}
        return "00000000";
    }

    // Days since the unix epoch — the ordinal used both for streak continuity
    // and as the worldwide-identical seed of the daily challenge.
    function dayNumber() as Lang.Number {
        try { return Time.now().value() / 86400; } catch (e) {}
        return 0;
    }

    // Deterministic scramble of the day ordinal. Every watch on the planet
    // derives the same challenge from it — no randomness anywhere.
    // Xorshift mix, masked to 31 bits after every step so the result is a
    // positive Number and bit-identical on every device.
    function hash(seed as Lang.Number, salt as Lang.Number) as Lang.Number {
        var x = (seed * 2749 + salt * 7919 + 12345) & 0x7FFFFFFF;
        x = (x ^ (x << 13)) & 0x7FFFFFFF;
        x = (x ^ (x >> 7))  & 0x7FFFFFFF;
        x = (x ^ (x << 5))  & 0x7FFFFFFF;
        return x;
    }

    function clampF(v as Lang.Float, lo as Lang.Float, hi as Lang.Float) as Lang.Float {
        if (v < lo) { return lo; }
        if (v > hi) { return hi; }
        return v;
    }

    function absF(v as Lang.Float) as Lang.Float {
        return (v < 0.0) ? -v : v;
    }
}

// ── Haptic feedback, honouring the OPTIONS toggle ───────────────────────────
module DsFx {
    function on() as Lang.Boolean {
        return DsUtil.optIndex(DS_K_FX, 0, 2) == 0;
    }

    function buzz(dur as Lang.Number, strength as Lang.Number) as Void {
        if (!on()) { return; }
        try {
            if (Attention has :vibrate) {
                Attention.vibrate([new Attention.VibeProfile(strength, dur)]);
            }
        } catch (e) {}
    }
}
