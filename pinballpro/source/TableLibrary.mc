// ═══════════════════════════════════════════════════════════════
// TableLibrary.mc — Five handcrafted table layouts, complicated.
//
// Every table is now denser than the v1 layout:
//   * 5–8 pop bumpers (was 1–6)
//   * 4–7 drop targets (was 0–5)
//   * Two pairs of slingshots — the usual lower pair near the
//     flippers AND an upper mid-field pair that acts as inner
//     chevrons funnelling the ball back through the bumper field.
//
// Tables:
//   0  CLASSIC  — triangle of three pop bumpers, mid-field 4-drop
//                 bank, upper chevron slings, cyan/red theme.
//   1  NOVA     — diamond of five bumpers, two side drop banks,
//                 magenta/purple theme. Highest scoring potential.
//   2  DERBY    — two big bumpers plus two side bumpers, central
//                 5-drop bank + a 2-drop bonus, red/orange theme.
//   3  STINGER  — high-density: SEVEN small bumpers in three
//                 staggered rows + a 4-drop bank wider than the
//                 v1 mini-bank. Yellow/black wasp; absolute chaos.
//   4  ECLIPSE  — minimalist no longer: one giant bumper plus two
//                 satellite bumpers above the slings, no drops, two
//                 sling pairs. White/blue theme.
// ═══════════════════════════════════════════════════════════════

class TableLibrary {
    static var NAMES = ["CLASSIC", "NOVA", "DERBY", "STINGER", "ECLIPSE",
                        "VORTEX", "COMET"];
    static var COUNT = 7;

    // Returns [bgColor, accentColor] for the given table.
    static function theme(idx) {
        if (idx == 0) { return [0x081428, 0x44CCFF]; }   // dark navy + cyan
        if (idx == 1) { return [0x14081E, 0xCC66FF]; }   // dark purple + magenta
        if (idx == 2) { return [0x1E0808, 0xFF6622]; }   // dark red + orange
        if (idx == 3) { return [0x1A1A05, 0xFFEE00]; }   // wasp black + yellow
        if (idx == 4) { return [0x05101E, 0xCFE3FA]; }   // eclipse blue + white
        if (idx == 5) { return [0x041818, 0x22FFCC]; }   // vortex teal
        return                [0x0A0A20, 0xFF8844];      // comet indigo + amber
    }

    // Decorative-art style hint for MainView's playfield inlay layer.
    static function artStyle(idx) {
        if (idx == 0) { return :dashes; }
        if (idx == 1) { return :diamond; }
        if (idx == 2) { return :bolts; }
        if (idx == 3) { return :hive; }
        if (idx == 4) { return :sun; }
        if (idx == 5) { return :spiral; }
        return :streak;
    }

    // Mission chain for a table: array of [type, target].
    //   type 0 = hit N bumpers · 1 = clear the drop bank N times
    //        2 = hit N slingshots
    // Completing the final mission awards an extra ball + big bonus,
    // then the chain loops for endless play.
    static function missions(idx) {
        if (idx == 0) { return [[0, 12], [1, 1], [2, 8]]; }
        if (idx == 1) { return [[0, 15], [1, 2], [0, 25]]; }
        if (idx == 2) { return [[1, 1], [0, 14], [1, 2]]; }
        if (idx == 3) { return [[0, 20], [2, 10], [1, 1]]; }
        if (idx == 4) { return [[0, 18], [2, 12], [0, 30]]; }
        if (idx == 5) { return [[0, 16], [1, 1], [2, 10]]; }
        return [[1, 1], [0, 18], [1, 2]];
    }

    // Build everything for table `idx`. Returns a Dictionary with
    // three keys (:bumpers, :drops, :slings) — the controller applies
    // them via its setters.
    static function build(idx, playX0, playY0, playX1, playY1) {
        var pw = playX1 - playX0;
        var ph = playY1 - playY0;
        var cx = (playX0 + playX1) / 2;

        var dropH = (ph * 5) / 100; if (dropH < 6) { dropH = 6; }

        // ── BUMPERS ─────────────────────────────────────────────────
        var bumpers = [];
        if (idx == 0) {
            // CLASSIC — top triangle + two satellite bumpers near the
            // mid-field for cross-table caroms.
            var bigR = (pw * 7)  / 100; if (bigR < 7) { bigR = 7; }
            var midR = (pw * 6)  / 100; if (midR < 6) { midR = 6; }
            var satR = (pw * 5)  / 100; if (satR < 5) { satR = 5; }
            bumpers = [
                [cx,                       playY0 + ph * 15 / 100, bigR, 0xFF3344],
                [cx - pw / 4,              playY0 + ph * 26 / 100, midR, 0x44CCFF],
                [cx + pw / 4,              playY0 + ph * 26 / 100, midR, 0xFFCC22],
                [cx - (pw * 30) / 100,     playY0 + ph * 38 / 100, satR, 0x44FF88],
                [cx + (pw * 30) / 100,     playY0 + ph * 38 / 100, satR, 0x44FF88]
            ];
        } else if (idx == 1) {
            // NOVA — five-point diamond.
            var r = (pw * 6) / 100; if (r < 6) { r = 6; }
            bumpers = [
                [cx,                         playY0 + ph * 12 / 100, r + 1, 0xCC66FF],
                [cx - (pw * 22) / 100,       playY0 + ph * 22 / 100, r,     0xFF44AA],
                [cx + (pw * 22) / 100,       playY0 + ph * 22 / 100, r,     0xFF44AA],
                [cx - (pw * 14) / 100,       playY0 + ph * 35 / 100, r,     0x44CCFF],
                [cx + (pw * 14) / 100,       playY0 + ph * 35 / 100, r,     0x44CCFF],
                [cx,                         playY0 + ph * 44 / 100, r + 2, 0xFFEE00]
            ];
        } else if (idx == 2) {
            // DERBY — two big bumpers up top + two side bumpers
            // flanking the drop bank below.
            var bigR2 = (pw * 8) / 100; if (bigR2 < 8) { bigR2 = 8; }
            var sideR = (pw * 5) / 100; if (sideR < 5) { sideR = 5; }
            bumpers = [
                [cx - pw / 5,             playY0 + ph * 16 / 100, bigR2, 0xFF6622],
                [cx + pw / 5,             playY0 + ph * 16 / 100, bigR2, 0xFF6622],
                [cx,                      playY0 + ph * 28 / 100, sideR, 0xFFEE00],
                [cx - (pw * 32) / 100,    playY0 + ph * 42 / 100, sideR, 0xCC4422],
                [cx + (pw * 32) / 100,    playY0 + ph * 42 / 100, sideR, 0xCC4422]
            ];
        } else if (idx == 3) {
            // STINGER — three staggered rows of small bumpers.
            var sr = (pw * 5) / 100; if (sr < 5) { sr = 5; }
            var rowA = playY0 + ph * 13 / 100;
            var rowB = playY0 + ph * 24 / 100;
            var rowC = playY0 + ph * 36 / 100;
            var col1 = 0xFFEE00;
            var col2 = 0x111111;
            bumpers = [
                [cx - (pw * 22) / 100, rowA, sr, col1],
                [cx,                   rowA, sr, col2],
                [cx + (pw * 22) / 100, rowA, sr, col1],
                [cx - (pw * 12) / 100, rowB, sr, col2],
                [cx + (pw * 12) / 100, rowB, sr, col2],
                [cx - (pw * 24) / 100, rowC, sr, col1],
                [cx + (pw * 24) / 100, rowC, sr, col1],
                [cx,                   playY0 + ph * 46 / 100, sr + 2, 0xFFEE00]
            ];
        } else if (idx == 4) {
            // ECLIPSE — giant sun + two satellites above the slings.
            var giantR = (pw * 14) / 100; if (giantR < 14) { giantR = 14; }
            var satR2  = (pw * 6)  / 100; if (satR2  < 6)  { satR2  = 6;  }
            bumpers = [
                [cx,                       playY0 + ph * 28 / 100, giantR, 0xCFE3FA],
                [cx - (pw * 28) / 100,     playY0 + ph * 50 / 100, satR2,  0x66BBEE],
                [cx + (pw * 28) / 100,     playY0 + ph * 50 / 100, satR2,  0x66BBEE]
            ];
        } else if (idx == 5) {
            // VORTEX — a hexagonal ring of bumpers spinning around a
            // bright core; caroms tend to orbit the middle.
            var coreR = (pw * 9) / 100; if (coreR < 9) { coreR = 9; }
            var ringR = (pw * 6) / 100; if (ringR < 6) { ringR = 6; }
            var ry0 = playY0 + ph * 30 / 100;
            bumpers = [
                [cx,                     ry0,                      coreR, 0x22FFCC],
                [cx - (pw * 24) / 100,   playY0 + ph * 16 / 100,   ringR, 0x33DDEE],
                [cx + (pw * 24) / 100,   playY0 + ph * 16 / 100,   ringR, 0x33DDEE],
                [cx - (pw * 30) / 100,   playY0 + ph * 40 / 100,   ringR, 0x66FFAA],
                [cx + (pw * 30) / 100,   playY0 + ph * 40 / 100,   ringR, 0x66FFAA],
                [cx,                     playY0 + ph * 50 / 100,   ringR, 0xAAFFEE]
            ];
        } else {
            // COMET — two vertical columns of bumpers framing a fast
            // central lane; amber/blue streak theme.
            var cr = (pw * 6) / 100; if (cr < 6) { cr = 6; }
            var colX = (pw * 20) / 100;
            bumpers = [
                [cx - colX,  playY0 + ph * 14 / 100, cr,     0xFF8844],
                [cx + colX,  playY0 + ph * 14 / 100, cr,     0xFF8844],
                [cx - colX,  playY0 + ph * 27 / 100, cr,     0x44AAFF],
                [cx + colX,  playY0 + ph * 27 / 100, cr,     0x44AAFF],
                [cx,         playY0 + ph * 20 / 100, cr + 1, 0xFFDD66],
                [cx,         playY0 + ph * 40 / 100, cr + 1, 0xFFDD66]
            ];
        }

        // ── DROP TARGETS ────────────────────────────────────────────
        var drops = [];
        if (idx == 0) {
            // CLASSIC — 4-target bank centred mid-field.
            var dW = (pw * 10) / 100; if (dW < 9) { dW = 9; }
            var dY = playY0 + ph * 50 / 100;
            var col = 0x44FF88;
            drops = [
                [cx - 2 * dW - 6 - dW / 2,  dY, dW, dropH, col],
                [cx -     dW - 2 - dW / 2,  dY, dW, dropH, col],
                [cx -             dW / 2 + 2, dY, dW, dropH, col],
                [cx +         dW / 2 + 6,   dY, dW, dropH, col]
            ];
        } else if (idx == 1) {
            // NOVA — TWO 3-target side banks, no centre bank.
            var dW = (pw * 9) / 100; if (dW < 8) { dW = 8; }
            var dY = playY0 + ph * 54 / 100;
            var col = 0x44CCFF;
            drops = [
                [playX0 + (pw * 8) / 100,                  dY, dW, dropH, col],
                [playX0 + (pw * 8) / 100 + dW + 3,         dY, dW, dropH, col],
                [playX0 + (pw * 8) / 100 + (dW + 3) * 2,   dY, dW, dropH, col],
                [playX1 - (pw * 8) / 100 - dW,             dY, dW, dropH, col],
                [playX1 - (pw * 8) / 100 - dW - (dW + 3),  dY, dW, dropH, col],
                [playX1 - (pw * 8) / 100 - dW - (dW + 3)*2,dY, dW, dropH, col]
            ];
        } else if (idx == 2) {
            // DERBY — 5-target main bank + 2-target bonus bank above.
            var dW = (pw * 9) / 100; if (dW < 8) { dW = 8; }
            var dY = playY0 + ph * 56 / 100;
            var bonusY = playY0 + ph * 36 / 100;
            var col = 0xFFEE00;
            drops = [
                [cx - 2 * dW - 6 - dW / 2,  dY, dW, dropH, col],
                [cx -     dW - 2 - dW / 2,  dY, dW, dropH, col],
                [cx -             dW / 2 + 2, dY, dW, dropH, col],
                [cx +         dW / 2 + 6,   dY, dW, dropH, col],
                [cx + 2 * dW + 10 - dW / 2, dY, dW, dropH, col],
                // Bonus pair high up between the two big bumpers
                [cx - dW - 1,               bonusY, dW, dropH, 0xFF8844],
                [cx + 1,                    bonusY, dW, dropH, 0xFF8844]
            ];
        } else if (idx == 3) {
            // STINGER — 4-target bank low + two sentinels at the sides.
            var dW = (pw * 9) / 100; if (dW < 8) { dW = 8; }
            var dY = playY0 + ph * 56 / 100;
            var col = 0xFFEE00;
            drops = [
                [cx - 2 * dW - 6 - dW / 2,  dY, dW, dropH, col],
                [cx -     dW - 2 - dW / 2,  dY, dW, dropH, col],
                [cx -             dW / 2 + 2, dY, dW, dropH, col],
                [cx +         dW / 2 + 6,   dY, dW, dropH, col],
                // Side sentinels — narrow, tall, alone.
                [playX0 + (pw * 6) / 100,           playY0 + ph * 30 / 100, dW * 2 / 3, dropH, 0xFF6644],
                [playX1 - (pw * 6) / 100 - dW * 2 / 3, playY0 + ph * 30 / 100, dW * 2 / 3, dropH, 0xFF6644]
            ];
        } else if (idx == 4) {
            // ECLIPSE — no drop targets. Pure flow.
            drops = [];
        } else if (idx == 5) {
            // VORTEX — a 3-target bank tucked below the ring.
            var dW = (pw * 10) / 100; if (dW < 9) { dW = 9; }
            var dY = playY0 + ph * 60 / 100;
            var col = 0x22FFCC;
            drops = [
                [cx - dW - dW / 2 - 4, dY, dW, dropH, col],
                [cx -      dW / 2,     dY, dW, dropH, col],
                [cx +      dW / 2 + 4, dY, dW, dropH, col]
            ];
        } else {
            // COMET — 5-target bank across the mid-field lane.
            var dW = (pw * 9) / 100; if (dW < 8) { dW = 8; }
            var dY = playY0 + ph * 54 / 100;
            var col = 0xFF8844;
            drops = [
                [cx - 2 * dW - 6 - dW / 2,  dY, dW, dropH, col],
                [cx -     dW - 2 - dW / 2,  dY, dW, dropH, col],
                [cx -             dW / 2 + 2, dY, dW, dropH, col],
                [cx +         dW / 2 + 6,   dY, dW, dropH, col],
                [cx + 2 * dW + 10 - dW / 2, dY, dW, dropH, col]
            ];
        }

        // ── SLINGSHOTS ──────────────────────────────────────────────
        // Lower pair sits over each flipper. Upper pair acts as
        // mid-field chevrons funnelling the ball back into the bumper
        // field — tables that already have 6+ drops skip the upper
        // pair so the field doesn't get over-crowded.
        var slingCol = 0xCC4488;
        if (idx == 2) { slingCol = 0xFFAA22; }
        if (idx == 3) { slingCol = 0xFFEE00; }
        if (idx == 4) { slingCol = 0xCFE3FA; }
        if (idx == 5) { slingCol = 0x22FFCC; }
        if (idx == 6) { slingCol = 0xFF8844; }

        // Lower (flipper-side) slings.
        var top   = playY0 + ph * 72 / 100;
        var bot   = playY0 + ph * 84 / 100;
        var wallL = playX0 + (pw * 6) / 100;
        var wallR = playX1 - (pw * 6) / 100;
        var apexL = playX0 + (pw * 22) / 100;
        var apexR = playX1 - (pw * 22) / 100;
        if (idx == 4) {
            // ECLIPSE — oversized slings reach further toward centre.
            apexL = playX0 + (pw * 30) / 100;
            apexR = playX1 - (pw * 30) / 100;
            top   = playY0 + ph * 68 / 100;
        }

        var slings = [
            [wallL, top,  apexL, bot,  wallL, bot,  slingCol],
            [wallR, top,  apexR, bot,  wallR, bot,  slingCol]
        ];

        // Upper chevron slings — small triangles in the upper third
        // of the playfield, pointing inward. Skipped for NOVA and
        // STINGER which already have lots of structure up there.
        if (idx == 0 || idx == 2 || idx == 4 || idx == 5) {
            var midSlingColor = 0x88AAEE;
            if (idx == 2) { midSlingColor = 0xFFCC44; }
            if (idx == 4) { midSlingColor = 0xAAD0F4; }
            if (idx == 5) { midSlingColor = 0x33DDAA; }
            var chTop = playY0 + ph * 58 / 100;
            var chBot = playY0 + ph * 66 / 100;
            var chLeftA  = playX0 + (pw * 5)  / 100;
            var chLeftB  = playX0 + (pw * 16) / 100;
            var chRightA = playX1 - (pw * 5)  / 100;
            var chRightB = playX1 - (pw * 16) / 100;
            slings = [
                slings[0],
                slings[1],
                // Left chevron — active edge slopes down-right.
                [chLeftA,  chTop, chLeftB,  chBot, chLeftA,  chBot, midSlingColor],
                // Right chevron — active edge slopes down-left.
                [chRightA, chTop, chRightB, chBot, chRightA, chBot, midSlingColor]
            ];
        }

        return { :bumpers => bumpers, :drops => drops, :slings => slings };
    }
}
