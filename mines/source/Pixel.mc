using Toybox.Graphics;
using Toybox.Lang;
module Px {
    function spr(dc, rows, pal, ox, oy, px, flipX) {
        if (rows == null) { return; }
        for (var r = 0; r < rows.size(); r++) {
            var row = rows[r]; var w = row.length();
            for (var c = 0; c < w; c++) {
                var ch = row.substring(c, c + 1);
                if (ch.equals(".") || ch.equals(" ")) { continue; }
                var col = pal.get(ch); if (col == null) { continue; }
                var cc = flipX ? (w - 1 - c) : c;
                dc.setColor(col, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(ox + cc * px, oy + r * px, px, px);
            }
        }
    }
    function rect(dc, x, y, w, h, col) { dc.setColor(col, Graphics.COLOR_TRANSPARENT); dc.fillRectangle(x, y, w, h); }

    // ── Tiny 3x5 pixel font ──────────────────────────────────────────────────
    // A crisp bitmap font drawn from fillRectangles so HUD text can be far
    // smaller than FONT_XTINY yet stay sharp & bright on every device. Each
    // glyph is 3 wide x 5 tall; advance is 4*sc (1px gap). Use gtxtC for centred
    // text and gsh/gshC for a dark drop-shadow version (legible over art).
    var _F = null;
    function _font() {
        if (_F != null) { return _F; }
        _F = {
            "0"=>["###","#.#","#.#","#.#","###"], "1"=>[".#.","##.",".#.",".#.","###"],
            "2"=>["###","..#","###","#..","###"], "3"=>["###","..#","###","..#","###"],
            "4"=>["#.#","#.#","###","..#","..#"], "5"=>["###","#..","###","..#","###"],
            "6"=>["###","#..","###","#.#","###"], "7"=>["###","..#","..#","..#","..#"],
            "8"=>["###","#.#","###","#.#","###"], "9"=>["###","#.#","###","..#","###"],
            "A"=>["###","#.#","###","#.#","#.#"], "B"=>["##.","#.#","##.","#.#","##."],
            "C"=>["###","#..","#..","#..","###"], "D"=>["##.","#.#","#.#","#.#","##."],
            "E"=>["###","#..","##.","#..","###"], "F"=>["###","#..","##.","#..","#.."],
            "G"=>["###","#..","#.#","#.#","###"], "H"=>["#.#","#.#","###","#.#","#.#"],
            "I"=>["###",".#.",".#.",".#.","###"], "J"=>["..#","..#","..#","#.#","###"],
            "K"=>["#.#","#.#","##.","#.#","#.#"], "L"=>["#..","#..","#..","#..","###"],
            "M"=>["#.#","###","###","#.#","#.#"], "N"=>["#.#","##.","#.#",".##","#.#"],
            "O"=>["###","#.#","#.#","#.#","###"], "P"=>["###","#.#","###","#..","#.."],
            "Q"=>["###","#.#","#.#","###","..#"], "R"=>["##.","#.#","##.","#.#","#.#"],
            "S"=>["###","#..","###","..#","###"], "T"=>["###",".#.",".#.",".#.",".#."],
            "U"=>["#.#","#.#","#.#","#.#","###"], "V"=>["#.#","#.#","#.#","#.#",".#."],
            "W"=>["#.#","#.#","###","###","#.#"], "X"=>["#.#","#.#",".#.","#.#","#.#"],
            "Y"=>["#.#","#.#",".#.",".#.",".#."], "Z"=>["###","..#",".#.","#..","###"],
            " "=>["...","...","...","...","..."], "."=>["...","...","...","...",".#."],
            "/"=>["..#","..#",".#.","#..","#.."], "%"=>["#.#","..#",".#.","#..","#.#"],
            "+"=>["...",".#.","###",".#.","..."], "-"=>["...","...","###","...","..."],
            ":"=>["...",".#.","...",".#.","..."], "*"=>["#.#",".#.","###",".#.","#.#"],
            "|"=>[".#.",".#.",".#.",".#.",".#."]
        };
        return _F;
    }
    function gtxtW(s, sc) { if (s == null) { return 0; } return s.length() * 4 * sc; }
    function gtxt(dc, s, x, y, sc, col) {
        if (s == null) { return; }
        var f = _font();
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        var cxp = x;
        for (var i = 0; i < s.length(); i++) {
            var ch = s.substring(i, i + 1).toUpper();
            var g = f.get(ch);
            if (g != null) {
                for (var r = 0; r < 5; r++) {
                    var row = g[r];
                    for (var c = 0; c < 3; c++) {
                        if (row.substring(c, c + 1).equals("#")) {
                            dc.fillRectangle(cxp + c * sc, y + r * sc, sc, sc);
                        }
                    }
                }
            }
            cxp += 4 * sc;
        }
    }
    // Centred at cxc; y is the TOP of the glyphs.
    function gtxtC(dc, s, cxc, y, sc, col) { gtxt(dc, s, cxc - gtxtW(s, sc) / 2, y, sc, col); }
    // Shadowed (dark 1px offset) — readable over bright art.
    function gsh(dc, s, x, y, sc, col) {
        gtxt(dc, s, x + 1, y + 1, sc, 0x000000);
        gtxt(dc, s, x, y, sc, col);
    }
    function gshC(dc, s, cxc, y, sc, col) { gsh(dc, s, cxc - gtxtW(s, sc) / 2, y, sc, col); }
    function vgrad(dc, x, y, w, h, c0, c1, n) {
        if (n < 1) { n = 1; }
        var r0=(c0>>16)&0xFF,g0=(c0>>8)&0xFF,b0=c0&0xFF, r1=(c1>>16)&0xFF,g1=(c1>>8)&0xFF,b1=c1&0xFF;
        for (var i=0;i<n;i++){ var t=i*100/n; var rr=(r0*(100-t)+r1*t)/100; var gg=(g0*(100-t)+g1*t)/100; var bb=(b0*(100-t)+b1*t)/100;
            dc.setColor((rr<<16)|(gg<<8)|bb, Graphics.COLOR_TRANSPARENT); var by=y+i*h/n; dc.fillRectangle(x, by, w, (y+(i+1)*h/n)-by); }
    }
}
