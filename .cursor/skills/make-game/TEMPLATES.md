# Templates — MAKE_GAME

Clone **jazzball** (simple) or **bomb** (SaveResume) / **sudoku** (ASC) / **fish** (Progress). Paste patterns below; rename symbols.

## monkey.jungle

```
project.manifest = manifest.xml
base.sourcePath = source;../_shared/leaderboard;../_shared/menu
base.resourcePath = resources
```

Add `;../_shared/progress` only when using Progress.

## App

```mc
using Toybox.Application;
using Toybox.WatchUi;

class BitochiExampleApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }
    function onStart(state) { Leaderboard.logLaunch("example"); }
    function onStop(state) {}
    function getInitialView() { return buildExampleMenu(); }
}
```

## Menu + hooks (+ SaveResume)

```mc
using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Application;
using Toybox.Lang;

class ExampleHooks extends GameHooks {
    function initialize() { GameHooks.initialize(); }

    function hasResume() as Lang.Boolean { return SaveResume.exists("example"); }

    function resumeGame() as Void {
        var v = new BitochiExampleView();
        v.loadResume(SaveResume.load("example"));
        WatchUi.pushView(v, new BitochiExampleDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function startGame() as Void {
        SaveResume.clear("example");
        var v = new BitochiExampleView();
        WatchUi.pushView(v, new BitochiExampleDelegate(v), WatchUi.SLIDE_LEFT);
    }

    function drawArt(dc, cx, cy, w, h) as Void {
        dc.setColor(0x44AAFF, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, 10);
    }

    function lbVariant() as Lang.String {
        var names = ["easy", "normal", "hard"];
        var d = 1;
        try {
            var v = Application.Storage.getValue("ex_diff");
            if (v instanceof Lang.Number && v >= 0 && v <= 2) { d = v; }
        } catch (e) {}
        return names[d];
    }

    function footerText() as Lang.String or Null {
        try {
            var v = Application.Storage.getValue("ex_best");
            if (v instanceof Lang.Number && v > 0) { return "BEST " + v.format("%d"); }
        } catch (e) {}
        return null;
    }
}

function buildExampleMenu() as Lang.Array {
    var cfg = new MenuConfig({
        :gameId  => "example",
        :title1  => "EXAMPLE",
        :title2  => null,
        :col1    => 0x44AAFF,
        :bg      => 0x060810,
        :circle  => 0x0C1220,
        :accent  => 0x44FF88,
        :lbTitle => "EXAMPLE",
        :hooks   => new ExampleHooks(),
        :options => [
            new GmOption("ex_diff", "Difficulty", ["EASY", "NORMAL", "HARD"], 1)
        ]
    });
    var v = new GameMenuView(cfg);
    return [v, new GameMenuDelegate(v)];
}
```

Skip `hasResume` / `resumeGame` if the game has no mid-run save. Still clear nothing in `startGame` then.

## Game-over LB

```mc
Leaderboard.submitScore("example", score, variant);
Leaderboard.showPostGame("example", variant, "EXAMPLE");
```

ASC (time/moves): same calls; register slug in worker `ASC_GAMES` + site `ASC_GAMES_HOF`.

## Delegate BACK + SaveResume

```mc
function onBack() as Lang.Boolean {
    // optional phantom-BACK swallow after swipe/drag — see blobs
    return SaveResume.confirmExit("example", method(:exportSave));
}

function exportSave() as Lang.Dictionary or Null {
    if (!_worthSaving) { return null; }  // null → pop, no prompt
    return _view.exportState();          // Dictionary → prompt Yes/No/Cancel
}
```

View: `exportState()` / `loadResume(dict)`; clear save on win/lose; avoid `submitProgress` in `onHide` while the save Menu2 is covering the view.

## Progress (optional)

Jungle: append `;../_shared/progress`. In `onStart` after `logLaunch`:

```mc
try {
    var ci = Progress.checkIn();
    if (ci["first"]) {
        Application.Storage.setValue("example_daily_msg",
            "Daily +" + ci["bonus"] + "  Streak " + ci["streak"]);
    }
} catch (e) {}
```

## resources/strings.xml

```xml
<strings>
    <string id="AppName">Example</string>
</strings>
```

## resources/drawables.xml

```xml
<drawables>
    <bitmap id="LauncherIcon" filename="launcher_icon.png" />
</drawables>
```

## Website snippet (`leaderboard/index.html`)

```js
// GAMES
{ id: "example", label: "Example", ciq: "<store-app-uuid>" },

// GAME_DESCS
example: "One-line pitch for the catalog.",

// GAME_GENRES — add id under Arcade / Puzzle / …
```

If folder ≠ submit id: `{ id: "folder", label: "…", ciq: "…", lb: "submitid" }`.
