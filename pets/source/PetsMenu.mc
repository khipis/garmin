// ═══════════════════════════════════════════════════════════════
// PetsMenu.mc — Pixel Pets' wiring into the shared unified menu.
//
// Pets has no classic "game menu": the app IS a living creature. The unified
// menu becomes a clean front door — START opens the pet (or the creature-setup
// flow on first run), OPTIONS holds preferences (vibration), and LEADERBOARD
// shows the global Pixel Pets quality board (variant "", matching submit).
// ═══════════════════════════════════════════════════════════════
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class PetsHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function startGame() as Void {
        var pet = gPet;
        if (pet == null) {
            pet = new Pet();
            pet.load();
            gPet = pet;
        }
        if (pet.isCreated) {
            var v = new MainView(pet);
            WatchUi.pushView(v, new MainDelegate(pet, v), WatchUi.SLIDE_LEFT);
        } else {
            var sv = new SetupView(pet);
            WatchUi.pushView(sv, new SetupDelegate(pet, sv), WatchUi.SLIDE_LEFT);
        }
    }

    // Signature art: the player's own creature, reusing the real pet renderer.
    function drawArt(dc, cx, cy, w, h) as Void {
        var pet = gPet;
        var type = 0;
        if (pet == null) { pet = new Pet(); }
        else if (pet.isCreated) { type = pet.petType; }
        pet.drawPreview(dc, cx, cy, 3, type);
    }

    // Single global quality board (no per-variant split on the front row).
    function lbVariant() as Lang.String { return ""; }

    // Footer: the current creature's name, if one is being raised.
    function footerText() as Lang.String or Null {
        var pet = gPet;
        if (pet != null && pet.isCreated && pet.petName != null) {
            return pet.petName;
        }
        return null;
    }
}

function buildPetsMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "pets",
        :title1  => "PIXEL",
        :title2  => "PETS",
        :col1    => 0x66CCFF,
        :col2    => 0xFF88CC,
        :bg      => 0x0F0F23,
        :circle  => 0x171733,
        :accent  => 0x66CCFF,
        :lbTitle => "PIXEL PETS",
        :hooks   => new PetsHooks(),
        :options => [
            new GmOption("petVibe", "Vibration", ["OFF", "ON"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
