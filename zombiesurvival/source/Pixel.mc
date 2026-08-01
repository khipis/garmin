// ═══════════════════════════════════════════════════════════════════════════
// Pixel.mc — chunky-pixel drawing helpers (module `Px`).
//
// spr()   paints a string-row sprite (one char per cell) through a palette
//         dict, skipping '.'/' ' as transparent, with optional flip.
// vgrad() a banded vertical gradient — used for every sky in the game.
// gtxt()  a 3x5 bitmap font, far smaller than FONT_XTINY and still sharp,
//         with a shadowed variant that survives being drawn over the yard.
//
// Everything is fillRectangle work, so it is fast and cannot throw.
// ═══════════════════════════════════════════════════════════════════════════
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
    // Bottom-centred placement, which is how every object in the yard is
    // positioned: on its own footprint, at whatever depth it stands.
    function place(dc, rows, pal, cx, baseY, px, flip) {
        if (rows == null || rows.size() == 0) { return; }
        if (px < 1) { px = 1; }
        var wc = rows[0].length();
        var hc = rows.size();
        spr(dc, rows, pal, cx - wc * px / 2, baseY - hc * px, px, flip);
    }
    function rect(dc, x, y, w, h, col) {
        if (w < 1) { w = 1; }
        if (h < 1) { h = 1; }
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, w, h);
    }
    function vgrad(dc, x, y, w, h, c0, c1, n) {
        if (n < 1) { n = 1; }
        var r0=(c0>>16)&0xFF,g0=(c0>>8)&0xFF,b0=c0&0xFF;
        var r1=(c1>>16)&0xFF,g1=(c1>>8)&0xFF,b1=c1&0xFF;
        for (var i=0;i<n;i++){
            var t=i*100/n;
            var rr=(r0*(100-t)+r1*t)/100;
            var gg=(g0*(100-t)+g1*t)/100;
            var bb=(b0*(100-t)+b1*t)/100;
            dc.setColor((rr<<16)|(gg<<8)|bb, Graphics.COLOR_TRANSPARENT);
            var by=y+i*h/n;
            dc.fillRectangle(x, by, w, (y+(i+1)*h/n)-by);
        }
    }
    // Blend two colours, t = 0..100 towards b.
    function mix(a, b, t) {
        var ra=(a>>16)&0xFF, ga=(a>>8)&0xFF, ba=a&0xFF;
        var rb=(b>>16)&0xFF, gb=(b>>8)&0xFF, bb=b&0xFF;
        return (((ra*(100-t)+rb*t)/100)<<16)
             | (((ga*(100-t)+gb*t)/100)<<8)
             | ((ba*(100-t)+bb*t)/100);
    }
    function shade(c, pct) {
        var r=((c>>16)&0xFF)*pct/100, g=((c>>8)&0xFF)*pct/100, b=(c&0xFF)*pct/100;
        return (r<<16)|(g<<8)|b;
    }

    // ── Tiny 3x5 pixel font ──────────────────────────────────────────────────
    // Each glyph is 3 wide by 5 tall; the advance is 4*sc. Use gtxtC to centre
    // and gsh/gshC for the shadowed version, which is the only one readable
    // over the diorama.
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
            "M"=>["#.#","###","###","#.#","#.#"], "N"=>["#.#","##.","###",".##","#.#"],
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
            "!"=>[".#.",".#.",".#.","...",".#."], "?"=>["###","..#",".##","...",".#."],
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
    function gtxtC(dc, s, cxc, y, sc, col) { gtxt(dc, s, cxc - gtxtW(s, sc) / 2, y, sc, col); }
    function gsh(dc, s, x, y, sc, col) {
        gtxt(dc, s, x + 1, y + 1, sc, 0x000000);
        gtxt(dc, s, x, y, sc, col);
    }
    function gshC(dc, s, cxc, y, sc, col) { gsh(dc, s, cxc - gtxtW(s, sc) / 2, y, sc, col); }
}
