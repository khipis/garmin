// ═══════════════════════════════════════════════════════════════════════════
// arcade.js — animated, self-playing canvas recreations of the Bitochi games.
//
// Each game exposes { bg, draw(ctx, S, t, st) } where:
//   ctx = 2D context, S = square canvas size (px), t = seconds since scene start,
//   st  = per-instance mutable state object (auto-created, persists across frames).
// Everything is deterministic + allocation-light so Playwright records smooth,
// repeatable motion. No external/copyrighted assets — pure procedural gameplay.
// ═══════════════════════════════════════════════════════════════════════════
(function () {
  "use strict";

  // ── tiny helpers ──────────────────────────────────────────────────────────
  function rr(ctx, x, y, w, h, r) {
    r = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  }
  function circ(ctx, x, y, r) { ctx.beginPath(); ctx.arc(x, y, r, 0, 7); ctx.closePath(); }
  function lerp(a, b, u) { return a + (b - a) * u; }
  function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
  function ease(u) { return u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2; }
  // deterministic pseudo-random from integer seed
  function rnd(n) { var x = Math.sin(n * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
  function fill(ctx, c) { ctx.fillStyle = c; }
  function bgGrad(ctx, S, c0, c1) {
    var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, c0); g.addColorStop(1, c1);
    ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
  }
  function centerText(ctx, txt, x, y, font, color, S) {
    ctx.font = font; ctx.fillStyle = color; ctx.textAlign = "center"; ctx.textBaseline = "middle";
    ctx.fillText(txt, x, y);
  }

  var G = {};

  // ── BILLIARDS ─────────────────────────────────────────────────────────────
  G.billiards = {
    bg: "#0b3d2e",
    draw: function (ctx, S, t, st) {
      if (!st.init) {
        st.init = 1; st.cycle = 4.2; st.balls = [];
        st.colors = ["#f4d03f", "#2e86de", "#e74c3c", "#8e44ad", "#e67e22", "#16a085", "#2c3e50"];
        st.reset = function () {
          st.balls = [];
          // cue ball
          st.balls.push({ x: S * 0.28, y: S * 0.5, vx: 0, vy: 0, r: S * 0.032, c: "#f7f7f7", cue: 1, live: 1 });
          // rack triangle on right
          var ox = S * 0.68, oy = S * 0.5, rr2 = S * 0.033, k = 0;
          for (var row = 0; row < 4; row++) {
            for (var i = 0; i <= row; i++) {
              st.balls.push({ x: ox + row * rr2 * 1.8, y: oy + (i - row / 2) * rr2 * 2.05, vx: 0, vy: 0, r: rr2, c: st.colors[k % st.colors.length], live: 1 });
              k++;
            }
          }
        };
        st.reset();
      }
      var per = t % st.cycle;
      // strike at per=1.0
      if (per >= 1.0 && !st.struck) { st.struck = 1; var cue = st.balls[0]; cue.vx = S * 0.020; cue.vy = (rnd(Math.floor(t)) - 0.5) * S * 0.004; }
      if (per < 1.0) { st.struck = 0; if (st.needReset) { st.reset(); st.needReset = 0; } }
      if (per > st.cycle - 0.1) { st.needReset = 1; }

      // felt
      bgGrad(ctx, S, "#0e5b40", "#083826");
      // rails
      ctx.fillStyle = "#5b3a1e"; ctx.fillRect(0, 0, S, S * 0.06); ctx.fillRect(0, S * 0.94, S, S * 0.06);
      ctx.fillRect(0, 0, S * 0.05, S); ctx.fillRect(S * 0.95, 0, S * 0.05, S);
      // pockets
      ctx.fillStyle = "#04140d";
      var pk = [[S * 0.06, S * 0.08], [S * 0.5, S * 0.05], [S * 0.94, S * 0.08], [S * 0.06, S * 0.92], [S * 0.5, S * 0.95], [S * 0.94, S * 0.92]];
      for (var p = 0; p < pk.length; p++) { circ(ctx, pk[p][0], pk[p][1], S * 0.045); ctx.fill(); }

      // physics step (fixed substeps for stability)
      for (var s = 0; s < 2; s++) {
        for (var b = 0; b < st.balls.length; b++) {
          var o = st.balls[b]; if (!o.live) continue;
          o.x += o.vx / 2; o.y += o.vy / 2; o.vx *= 0.992; o.vy *= 0.992;
          if (Math.abs(o.vx) < 0.02) o.vx = 0; if (Math.abs(o.vy) < 0.02) o.vy = 0;
          // walls
          if (o.x < S * 0.07 + o.r) { o.x = S * 0.07 + o.r; o.vx = Math.abs(o.vx) * 0.8; }
          if (o.x > S * 0.93 - o.r) { o.x = S * 0.93 - o.r; o.vx = -Math.abs(o.vx) * 0.8; }
          if (o.y < S * 0.08 + o.r) { o.y = S * 0.08 + o.r; o.vy = Math.abs(o.vy) * 0.8; }
          if (o.y > S * 0.92 - o.r) { o.y = S * 0.92 - o.r; o.vy = -Math.abs(o.vy) * 0.8; }
          // pockets swallow
          for (var q = 0; q < pk.length; q++) {
            var dx = o.x - pk[q][0], dy = o.y - pk[q][1];
            if (dx * dx + dy * dy < (S * 0.04) * (S * 0.04) && !o.cue) { o.live = 0; }
          }
        }
        // collisions
        for (var i2 = 0; i2 < st.balls.length; i2++) {
          for (var j = i2 + 1; j < st.balls.length; j++) {
            var a = st.balls[i2], c2 = st.balls[j]; if (!a.live || !c2.live) continue;
            var ddx = c2.x - a.x, ddy = c2.y - a.y, d = Math.hypot(ddx, ddy), min = a.r + c2.r;
            if (d > 0 && d < min) {
              var nx = ddx / d, ny = ddy / d, ov = (min - d) / 2;
              a.x -= nx * ov; a.y -= ny * ov; c2.x += nx * ov; c2.y += ny * ov;
              var dvx = c2.vx - a.vx, dvy = c2.vy - a.vy, dot = dvx * nx + dvy * ny;
              if (dot < 0) { a.vx += nx * dot; a.vy += ny * dot; c2.vx -= nx * dot; c2.vy -= ny * dot; }
            }
          }
        }
      }
      // aim guide before strike
      if (per < 1.0) {
        var cue2 = st.balls[0];
        ctx.strokeStyle = "rgba(255,255,255,0.35)"; ctx.setLineDash([6, 8]); ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(cue2.x, cue2.y); ctx.lineTo(S * 0.72, S * 0.5); ctx.stroke(); ctx.setLineDash([]);
        // cue stick
        ctx.strokeStyle = "#c8975a"; ctx.lineWidth = S * 0.018;
        var back = lerp(0.22, 0.10, ease(per));
        ctx.beginPath(); ctx.moveTo(cue2.x - S * back, cue2.y); ctx.lineTo(cue2.x - S * 0.05, cue2.y); ctx.stroke();
      }
      // draw balls
      for (var d2 = 0; d2 < st.balls.length; d2++) {
        var o2 = st.balls[d2]; if (!o2.live) continue;
        circ(ctx, o2.x, o2.y, o2.r); ctx.fillStyle = o2.c; ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.45)"; circ(ctx, o2.x - o2.r * 0.3, o2.y - o2.r * 0.3, o2.r * 0.28); ctx.fill();
      }
    }
  };

  // ── STACK TOWER ───────────────────────────────────────────────────────────
  G.stacktower = {
    bg: "#0a1830",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.stack = []; st.baseW = S * 0.5; st.h = S * 0.075; st.next = 0.9; st.n = 0; st.moving = null; st.cam = 0; }
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#122a52"); g.addColorStop(1, "#050a18");
      ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      // stars
      for (var i = 0; i < 30; i++) { ctx.fillStyle = "rgba(255,255,255," + (0.2 + 0.5 * rnd(i)) + ")"; ctx.fillRect(rnd(i) * S, (rnd(i + 9) * S + t * 6) % S, 2, 2); }

      var groundY = S * 0.92;
      if (st.stack.length === 0) { st.stack.push({ x: S * 0.5 - st.baseW / 2, w: st.baseW, hue: 200 }); }
      // spawn moving block
      if (!st.moving && t > st.next) {
        var top = st.stack[st.stack.length - 1];
        st.moving = { w: top.w, hue: (200 + st.n * 24) % 360, x: 0, dir: 1, y: 0 };
      }
      // camera target: keep top near center
      var stackH = st.stack.length * st.h;
      var camTarget = Math.max(0, stackH - S * 0.45);
      st.cam = lerp(st.cam, camTarget, 0.08);

      function drawBlock(bx, level, w, hue, extra) {
        var y = groundY - (level + 1) * st.h + st.cam;
        var gg = ctx.createLinearGradient(bx, y, bx, y + st.h);
        gg.addColorStop(0, "hsl(" + hue + ",70%,62%)"); gg.addColorStop(1, "hsl(" + hue + ",70%,42%)");
        ctx.fillStyle = gg; rr(ctx, bx, y, w, st.h - 3, 5); ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.18)"; ctx.fillRect(bx + 3, y + 3, w - 6, 4);
        return y;
      }
      // draw settled stack
      for (var b = 0; b < st.stack.length; b++) { drawBlock(st.stack[b].x, b, st.stack[b].w, st.stack[b].hue); }
      // move + drop
      if (st.moving) {
        var m = st.moving, top2 = st.stack[st.stack.length - 1];
        var range = S * 0.34;
        m.x = S * 0.5 - m.w / 2 + Math.sin(t * 3.2) * range;
        var yy = drawBlock(m.x, st.stack.length, m.w, m.hue);
        // auto "lock" on a timer with near-perfect alignment
        if (t > st.next + 0.62) {
          var overlapX = clamp(m.x, top2.x, top2.x + top2.w);
          var perfect = rnd(st.n) > 0.35;
          var nx = perfect ? top2.x + (rnd(st.n + 3) - 0.5) * 6 : overlapX;
          var nw = perfect ? top2.w : Math.max(top2.w - Math.abs(m.x - top2.x), st.baseW * 0.3);
          st.stack.push({ x: nx, w: nw, hue: m.hue });
          st.n++; st.moving = null; st.next = t + 0.85 + rnd(st.n) * 0.2;
          st.flash = t;
          if (st.stack.length > 16) { st.stack.splice(0, 1); } // trim off bottom for endless feel
        }
      }
      // perfect flash
      if (st.flash && t - st.flash < 0.25) {
        ctx.fillStyle = "rgba(255,255,255," + (0.4 * (1 - (t - st.flash) / 0.25)) + ")"; ctx.fillRect(0, 0, S, S);
      }
      // score
      centerText(ctx, "" + st.n, S * 0.5, S * 0.12, "900 " + Math.round(S * 0.13) + "px Arial", "#ffffff", S);
    }
  };

  // ── SLOT BANDIT ───────────────────────────────────────────────────────────
  G.slotbandit = {
    bg: "#1a0f24",
    draw: function (ctx, S, t, st) {
      var syms = ["7", "$", "★", "♦", "♣", "BAR", "🍒"];
      if (!st.init) { st.init = 1; st.cycle = 3.6; st.spinDur = 1.9; }
      var per = t % st.cycle, spinning = per < st.spinDur;
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#3a1c4d"); g.addColorStop(1, "#160a20");
      ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      // marquee bulbs
      for (var i = 0; i < 14; i++) { var on = (Math.floor(t * 6) + i) % 2; ctx.fillStyle = on ? "#ffd24a" : "#7a5a10"; circ(ctx, S * 0.08 + i * S * 0.065, S * 0.1, S * 0.012); ctx.fill(); }
      centerText(ctx, "JACKPOT", S * 0.5, S * 0.2, "900 " + Math.round(S * 0.075) + "px Arial", "#ffd24a", S);

      var rw = S * 0.24, gap = S * 0.03, x0 = S * 0.5 - (rw * 1.5 + gap), ry = S * 0.32, rh = S * 0.44;
      var stops = [Math.floor(rnd(Math.floor(t / 3.6) + 1) * 7), 0, 0]; // reel1 target
      stops[1] = (stops[0]) % 7; stops[2] = stops[0]; // force a win row sometimes
      var win = rnd(Math.floor(t / 3.6) + 7) > 0.5;
      for (var r = 0; r < 3; r++) {
        var x = x0 + r * (rw + gap);
        ctx.fillStyle = "#0d0714"; rr(ctx, x, ry, rw, rh, 12); ctx.fill();
        ctx.save(); rr(ctx, x, ry, rw, rh, 12); ctx.clip();
        var reelStop = st.spinDur + r * 0.35;
        var moving = per < reelStop;
        var off;
        if (moving) { off = (t * (900 + r * 40)) % (S); } else { off = (stops[r] * (rh / 3)); }
        for (var k = -1; k < 5; k++) {
          var sy = ry + ((k * (rh / 3) - off) % (rh * 2) + rh * 2) % (rh * 2);
          var idx = ((k + Math.floor(off / (rh / 3))) % 7 + 7) % 7;
          var sym = moving ? syms[(k + Math.floor(t * 14) + r) % 7] : syms[(stops[r] + k + 6) % 7];
          ctx.globalAlpha = moving ? 0.85 : 1;
          centerText(ctx, sym, x + rw / 2, sy + rh / 6, "900 " + Math.round(rw * 0.42) + "px Arial", "#ffffff", S);
          ctx.globalAlpha = 1;
          if (moving) ctx.filter = "none";
        }
        ctx.restore();
        ctx.strokeStyle = "#ffd24a"; ctx.lineWidth = 4; rr(ctx, x, ry, rw, rh, 12); ctx.stroke();
      }
      // win line + payout
      if (!spinning && per > st.spinDur + 1.0 && win) {
        var fl = Math.sin(t * 20) > 0;
        ctx.strokeStyle = fl ? "#ffef8a" : "#ff5db1"; ctx.lineWidth = 6;
        ctx.beginPath(); ctx.moveTo(x0, ry + rh / 2); ctx.lineTo(x0 + rw * 3 + gap * 2, ry + rh / 2); ctx.stroke();
        centerText(ctx, "WIN +250", S * 0.5, S * 0.86, "900 " + Math.round(S * 0.08) + "px Arial", "#ffef8a", S);
        // coins
        for (var c = 0; c < 10; c++) { var cy = (S * 0.8 + (t * 200 + c * 40) % (S * 0.3)); ctx.fillStyle = "#ffd24a"; circ(ctx, S * 0.2 + rnd(c) * S * 0.6, cy, S * 0.02); ctx.fill(); }
      }
    }
  };

  // ── DRWAL (timber chop) ───────────────────────────────────────────────────
  G.drwal = {
    bg: "#0b1a10",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.scroll = 0; st.side = 1; st.chops = 0; st.chopT = -9; st.chips = []; }
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#16351f"); g.addColorStop(1, "#07130b");
      ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      // chop rhythm
      var beat = 0.62;
      if (t - st.chopT > beat) { st.chopT = t; st.chops++; st.scrollTo = (st.scroll || 0) + S * 0.14; if (rnd(st.chops) > 0.6) st.side *= -1; for (var c = 0; c < 6; c++) st.chips.push({ x: S * 0.5, y: S * 0.55, vx: (rnd(st.chops * 6 + c) - 0.5) * 12, vy: -rnd(st.chops + c) * 10 - 4, life: 1 }); }
      st.scroll = lerp(st.scroll || 0, st.scrollTo || 0, 0.25);
      // trunk
      var tw = S * 0.2, tx = S * 0.5 - tw / 2;
      var tg = ctx.createLinearGradient(tx, 0, tx + tw, 0); tg.addColorStop(0, "#7a4a22"); tg.addColorStop(0.5, "#9c6a34"); tg.addColorStop(1, "#6a3d1c");
      ctx.fillStyle = tg; ctx.fillRect(tx, 0, tw, S);
      // bark rings scrolling
      ctx.strokeStyle = "rgba(60,30,10,0.5)"; ctx.lineWidth = 3;
      for (var i = 0; i < 12; i++) { var yy = ((i * S * 0.14 + st.scroll) % (S + 40)) - 20; ctx.beginPath(); ctx.moveTo(tx, yy); ctx.lineTo(tx + tw, yy + 8); ctx.stroke(); }
      // branches
      for (var b = 0; b < 6; b++) {
        var by = ((b * S * 0.28 - st.scroll * 0.6) % (S + 80) + (S + 80)) % (S + 80) - 40;
        var bs = (b % 2 === 0) ? -1 : 1;
        ctx.fillStyle = "#5a3418";
        if (bs < 0) ctx.fillRect(tx - S * 0.14, by, S * 0.14, S * 0.05);
        else ctx.fillRect(tx + tw, by, S * 0.14, S * 0.05);
      }
      // lumberjack
      var lx = st.side < 0 ? S * 0.24 : S * 0.76, ly = S * 0.6;
      var swing = clamp((t - st.chopT) / 0.18, 0, 1);
      ctx.save(); ctx.translate(lx, ly); if (st.side > 0) ctx.scale(-1, 1);
      ctx.fillStyle = "#2b6cb0"; rr(ctx, -S * 0.04, -S * 0.02, S * 0.08, S * 0.14, 6); ctx.fill(); // body
      ctx.fillStyle = "#f1c27d"; circ(ctx, 0, -S * 0.05, S * 0.045); ctx.fill(); // head
      ctx.fillStyle = "#8b3a2b"; circ(ctx, 0, -S * 0.075, S * 0.05); ctx.fill(); // hat
      // axe
      ctx.save(); ctx.translate(S * 0.03, -S * 0.01); ctx.rotate(lerp(-1.2, 0.5, ease(1 - swing)));
      ctx.strokeStyle = "#6b4a2a"; ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(S * 0.11, 0); ctx.stroke();
      ctx.fillStyle = "#cfd6dd"; rr(ctx, S * 0.1, -S * 0.03, S * 0.05, S * 0.06, 3); ctx.fill();
      ctx.restore(); ctx.restore();
      // chips
      for (var ci = st.chips.length - 1; ci >= 0; ci--) { var p = st.chips[ci]; p.x += p.vx; p.y += p.vy; p.vy += 1.2; p.life -= 0.03; if (p.life <= 0) { st.chips.splice(ci, 1); continue; } ctx.globalAlpha = clamp(p.life, 0, 1); ctx.fillStyle = "#d9a066"; ctx.fillRect(p.x, p.y, 8, 8); ctx.globalAlpha = 1; }
      // score
      centerText(ctx, "" + st.chops, S * 0.5, S * 0.12, "900 " + Math.round(S * 0.12) + "px Arial", "#ffcc22", S);
    }
  };

  // ── FISH ──────────────────────────────────────────────────────────────────
  G.fish = {
    bg: "#062a45",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.cycle = 4.5; }
      var per = t % st.cycle;
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#2a7fb8"); g.addColorStop(0.28, "#1a6aa0"); g.addColorStop(1, "#04263f");
      ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      // sky strip + sun
      ctx.fillStyle = "#bfe6ff"; ctx.fillRect(0, 0, S, S * 0.22);
      ctx.fillStyle = "#ffe07a"; circ(ctx, S * 0.78, S * 0.1, S * 0.06); ctx.fill();
      // water surface waves
      ctx.strokeStyle = "rgba(255,255,255,0.25)"; ctx.lineWidth = 3;
      ctx.beginPath(); for (var x = 0; x <= S; x += 8) { var yy = S * 0.22 + Math.sin(x * 0.03 + t * 2) * 6; if (x === 0) ctx.moveTo(x, yy); else ctx.lineTo(x, yy); } ctx.stroke();
      // light rays
      ctx.globalAlpha = 0.08; ctx.fillStyle = "#bfe8ff";
      for (var r = 0; r < 4; r++) { ctx.beginPath(); ctx.moveTo(S * (0.2 + r * 0.2), S * 0.22); ctx.lineTo(S * (0.1 + r * 0.2), S); ctx.lineTo(S * (0.3 + r * 0.2), S); ctx.closePath(); ctx.fill(); }
      ctx.globalAlpha = 1;
      // line + bobber
      var bite = per > 2.2 && per < 2.8;
      var reeling = per >= 2.8;
      var bobY = S * 0.42 + (bite ? Math.sin(t * 30) * 10 : Math.sin(t * 2) * 4) - (reeling ? ease(clamp((per - 2.8) / 1.2, 0, 1)) * S * 0.28 : 0);
      ctx.strokeStyle = "rgba(255,255,255,0.7)"; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(S * 0.5, S * 0.22); ctx.lineTo(S * 0.5, bobY); ctx.stroke();
      ctx.fillStyle = "#e74c3c"; circ(ctx, S * 0.5, bobY, S * 0.022); ctx.fill(); ctx.fillStyle = "#fff"; circ(ctx, S * 0.5, bobY + S * 0.01, S * 0.012); ctx.fill();
      // fish approaching bait then hooked
      var fishX, fishY, fishA = 0;
      if (per < 2.2) { fishX = lerp(S * 1.1, S * 0.56, ease(per / 2.2)); fishY = S * 0.55; }
      else if (bite) { fishX = S * 0.53; fishY = S * 0.46; }
      else { fishX = S * 0.5; fishY = bobY + S * 0.03; }
      drawFish(ctx, fishX, fishY, S * 0.09, t, "#ffa13c");
      // ambient fish
      drawFish(ctx, (S * 1.2 - (t * 40) % (S * 1.4)), S * 0.75, S * 0.06, t, "#7ad1ff");
      drawFish(ctx, (S * 1.4 - (t * 26 + 200) % (S * 1.6)), S * 0.88, S * 0.05, t, "#5df0a0");
      // catch popup
      if (reeling && per > 3.6) { ctx.fillStyle = "rgba(0,0,0,0.45)"; rr(ctx, S * 0.2, S * 0.34, S * 0.6, S * 0.18, 14); ctx.fill(); centerText(ctx, "NICE CATCH!", S * 0.5, S * 0.43, "900 " + Math.round(S * 0.06) + "px Arial", "#ffe07a", S); }
      function drawFish(ctx, fx, fy, r, tt, col) {
        ctx.save(); ctx.translate(fx, fy);
        ctx.fillStyle = col; ctx.beginPath(); ctx.ellipse(0, 0, r, r * 0.6, 0, 0, 7); ctx.fill();
        var tw = Math.sin(tt * 12) * 0.3;
        ctx.beginPath(); ctx.moveTo(r * 0.8, 0); ctx.lineTo(r * 1.4, -r * 0.5 + tw * r); ctx.lineTo(r * 1.4, r * 0.5 + tw * r); ctx.closePath(); ctx.fill();
        ctx.fillStyle = "#fff"; circ(ctx, -r * 0.5, -r * 0.15, r * 0.14); ctx.fill(); ctx.fillStyle = "#000"; circ(ctx, -r * 0.52, -r * 0.15, r * 0.07); ctx.fill();
        ctx.restore();
      }
    }
  };

  // ── JUMP TOWER ────────────────────────────────────────────────────────────
  G.jumptower = {
    bg: "#0a1226",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.plats = []; for (var i = 0; i < 10; i++) st.plats.push({ x: 0.2 + rnd(i) * 0.6, y: i * 0.16, w: 0.26 }); st.scroll = 0; st.pi = 0; st.jt = 0; st.px = st.plats[0].x; }
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#26306a"); g.addColorStop(1, "#070c1c");
      ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      for (var s = 0; s < 24; s++) { ctx.fillStyle = "rgba(255,255,255," + (0.15 + 0.4 * rnd(s + 3)) + ")"; ctx.fillRect(rnd(s) * S, (rnd(s + 5) * S + t * 10) % S, 2, 2); }
      st.scroll += S * 0.0016 * 16; // continuous climb
      var jump = 0.9;
      if (t - st.jt > jump) { st.jt = t; st.pi++; }
      function py(py01) { return ((py01 * S - st.scroll) % (S * 1.6) + S * 1.6) % (S * 1.6); }
      // platforms
      for (var p = 0; p < st.plats.length; p++) {
        var pl = st.plats[p]; var yy = S - py(pl.y * 6) ; // spread out
        ctx.fillStyle = "#3ad17a"; rr(ctx, pl.x * S - pl.w * S / 2, yy, pl.w * S, S * 0.03, 6); ctx.fill();
      }
      // hero hops between two virtual platforms
      var u = clamp((t - st.jt) / jump, 0, 1);
      var fromX = 0.3 + 0.4 * rnd(st.pi), toX = 0.3 + 0.4 * rnd(st.pi + 1);
      var hx = lerp(fromX, toX, u) * S;
      var hy = S * 0.5 - Math.sin(u * Math.PI) * S * 0.16;
      ctx.fillStyle = "#ffd24a"; rr(ctx, hx - S * 0.03, hy - S * 0.04, S * 0.06, S * 0.08, 6); ctx.fill();
      ctx.fillStyle = "#222"; circ(ctx, hx - S * 0.012, hy - S * 0.02, S * 0.008); ctx.fill(); circ(ctx, hx + S * 0.012, hy - S * 0.02, S * 0.008); ctx.fill();
      centerText(ctx, "" + (st.pi * 10), S * 0.5, S * 0.1, "900 " + Math.round(S * 0.1) + "px Arial", "#fff", S);
    }
  };

  // ── 8 BALL ────────────────────────────────────────────────────────────────
  G.eightball = {
    bg: "#0a0a12",
    draw: function (ctx, S, t, st) {
      var answers = ["YES", "NO", "MAYBE", "ASK LATER", "FOR SURE", "NOPE", "DEFINITELY"];
      if (!st.init) { st.init = 1; st.cycle = 3.2; }
      var per = t % st.cycle;
      bgGrad(ctx, S, "#1a1030", "#05050c");
      var shake = per < 1.2 ? Math.sin(t * 40) * (S * 0.02) * (1 - per / 1.2) : 0;
      var cx = S * 0.5 + shake, cy = S * 0.5;
      var rg = ctx.createRadialGradient(cx - S * 0.12, cy - S * 0.12, S * 0.05, cx, cy, S * 0.36);
      rg.addColorStop(0, "#444"); rg.addColorStop(1, "#000"); ctx.fillStyle = rg; circ(ctx, cx, cy, S * 0.34); ctx.fill();
      // white circle with 8
      ctx.fillStyle = "#fff"; circ(ctx, cx, cy - S * 0.14, S * 0.1); ctx.fill();
      centerText(ctx, "8", cx, cy - S * 0.14, "900 " + Math.round(S * 0.12) + "px Arial", "#000", S);
      // answer window
      if (per > 1.4) {
        var a = answers[Math.floor(rnd(Math.floor(t / 3.2) + 1) * answers.length)];
        var al = clamp((per - 1.4) / 0.5, 0, 1);
        ctx.save(); ctx.globalAlpha = al;
        ctx.fillStyle = "#0a2a6a"; ctx.beginPath();
        ctx.moveTo(cx, cy + S * 0.02); ctx.lineTo(cx - S * 0.16, cy + S * 0.2); ctx.lineTo(cx + S * 0.16, cy + S * 0.2); ctx.closePath(); ctx.fill();
        centerText(ctx, a, cx, cy + S * 0.15, "900 " + Math.round(S * 0.05) + "px Arial", "#7fd0ff", S);
        ctx.restore();
      }
    }
  };

  // ── CHECKERS ──────────────────────────────────────────────────────────────
  G.checkers = {
    bg: "#20140a",
    draw: function (ctx, S, t, st) {
      var N = 6, cell = S / N;
      if (!st.init) {
        st.init = 1; st.cycle = 3.0;
        st.pieces = [{ c: 0, r: 4, col: "#e74c3c" }, { c: 2, r: 4, col: "#e74c3c" }, { c: 3, r: 1, col: "#2c3e50" }, { c: 5, r: 1, col: "#2c3e50" }, { c: 4, r: 3, col: "#2c3e50" }];
      }
      var per = t % st.cycle;
      // board
      for (var r = 0; r < N; r++) for (var c = 0; c < N; c++) { ctx.fillStyle = (r + c) % 2 ? "#3b2416" : "#c9a06a"; ctx.fillRect(c * cell, r * cell, cell, cell); }
      // moving red piece jumps the dark at (4,3): from (2,4) to (5,2) capturing
      var mover = st.pieces[1], target = st.pieces[4];
      var u = ease(clamp(per / 1.6, 0, 1));
      var fromC = 2, fromR = 4, toC = 5, toR = 2;
      var mx = lerp(fromC + 0.5, toC + 0.5, u) * cell, my = lerp(fromR + 0.5, toR + 0.5, u) * cell - Math.sin(u * Math.PI) * cell * 0.5;
      // draw static pieces
      for (var p = 0; p < st.pieces.length; p++) {
        if (p === 1) continue;
        if (p === 4 && per > 0.8) continue; // captured disappears
        var pc = st.pieces[p]; drawPiece(ctx, (pc.c + 0.5) * cell, (pc.r + 0.5) * cell, cell * 0.38, pc.col);
      }
      drawPiece(ctx, mx, my, cell * 0.38, mover.col);
      if (per > 2.0) centerText(ctx, "JUMP!", S * 0.5, S * 0.12, "900 " + Math.round(S * 0.08) + "px Arial", "#ffef8a", S);
      function drawPiece(ctx, x, y, r, col) {
        ctx.fillStyle = "rgba(0,0,0,0.4)"; circ(ctx, x, y + 4, r); ctx.fill();
        ctx.fillStyle = col; circ(ctx, x, y, r); ctx.fill();
        ctx.strokeStyle = "rgba(255,255,255,0.4)"; ctx.lineWidth = 3; circ(ctx, x, y, r * 0.7); ctx.stroke();
      }
    }
  };

  // ── BLOBS (artillery) ─────────────────────────────────────────────────────
  G.blobs = {
    bg: "#0a1a22",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.cycle = 3.0; st.parts = []; }
      var per = t % st.cycle;
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#123a4a"); g.addColorStop(1, "#06131a");
      ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      // hills
      ctx.fillStyle = "#1e5a3a"; ctx.beginPath(); ctx.moveTo(0, S); ctx.quadraticCurveTo(S * 0.2, S * 0.7, S * 0.35, S * 0.78); ctx.lineTo(0, S); ctx.fill();
      ctx.beginPath(); ctx.moveTo(S, S); ctx.quadraticCurveTo(S * 0.8, S * 0.65, S * 0.65, S * 0.8); ctx.lineTo(S, S); ctx.fill();
      // blobs
      drawBlob(ctx, S * 0.16, S * 0.74, S * 0.07, "#5df08a");
      drawBlob(ctx, S * 0.84, S * 0.77, S * 0.07, "#ff6b9d");
      // projectile arc left→right
      var u = clamp(per / 1.6, 0, 1);
      if (per < 1.6) {
        var px = lerp(S * 0.16, S * 0.84, u), py = lerp(S * 0.7, S * 0.73, u) - Math.sin(u * Math.PI) * S * 0.5;
        ctx.strokeStyle = "rgba(255,255,255,0.25)"; ctx.setLineDash([4, 8]); ctx.lineWidth = 2;
        ctx.beginPath(); for (var s = 0; s <= u; s += 0.05) { var xx = lerp(S * 0.16, S * 0.84, s), yy = lerp(S * 0.7, S * 0.73, s) - Math.sin(s * Math.PI) * S * 0.5; if (s === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy); } ctx.stroke(); ctx.setLineDash([]);
        ctx.fillStyle = "#ffd24a"; circ(ctx, px, py, S * 0.025); ctx.fill();
      } else if (per < 1.75 && !st.boomed) { st.boomed = 1; for (var i = 0; i < 20; i++) st.parts.push({ x: S * 0.84, y: S * 0.73, vx: (rnd(i) - 0.5) * 20, vy: (rnd(i + 5) - 0.5) * 20 - 5, life: 1, c: ["#ffd24a", "#ff6b9d", "#fff"][i % 3] }); }
      if (per < 0.1) st.boomed = 0;
      for (var pi = st.parts.length - 1; pi >= 0; pi--) { var p = st.parts[pi]; p.x += p.vx; p.y += p.vy; p.vy += 0.8; p.life -= 0.03; if (p.life <= 0) { st.parts.splice(pi, 1); continue; } ctx.globalAlpha = clamp(p.life, 0, 1); ctx.fillStyle = p.c; circ(ctx, p.x, p.y, S * 0.015); ctx.fill(); ctx.globalAlpha = 1; }
      function drawBlob(ctx, x, y, r, col) { ctx.fillStyle = col; circ(ctx, x, y, r); ctx.fill(); ctx.fillStyle = "#fff"; circ(ctx, x - r * 0.3, y - r * 0.2, r * 0.18); ctx.fill(); ctx.fillStyle = "#000"; circ(ctx, x - r * 0.28, y - r * 0.2, r * 0.09); ctx.fill(); circ(ctx, x + r * 0.28, y - r * 0.2, r * 0.09); ctx.fillStyle = "#000"; ctx.fill(); }
    }
  };

  // ── CATAPULT ──────────────────────────────────────────────────────────────
  G.catapult = {
    bg: "#12203a",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.cycle = 3.2; st.deb = []; }
      var per = t % st.cycle;
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#5a86c9"); g.addColorStop(0.6, "#2a4a7a"); g.addColorStop(1, "#0d1a30");
      ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      // ground
      ctx.fillStyle = "#3a6b32"; ctx.fillRect(0, S * 0.82, S, S * 0.18);
      // castle right
      if (per < 1.9 || rnd(Math.floor(t / 3.2)) > 0.5) {
        ctx.fillStyle = "#8a8f99"; ctx.fillRect(S * 0.72, S * 0.55, S * 0.18, S * 0.27);
        for (var b = 0; b < 4; b++) ctx.fillRect(S * 0.72 + b * S * 0.045, S * 0.52, S * 0.03, S * 0.04);
      }
      // catapult left
      ctx.strokeStyle = "#6b4a2a"; ctx.lineWidth = S * 0.02;
      ctx.beginPath(); ctx.moveTo(S * 0.12, S * 0.82); ctx.lineTo(S * 0.2, S * 0.62); ctx.stroke();
      var swing = clamp(per / 0.7, 0, 1);
      ctx.save(); ctx.translate(S * 0.2, S * 0.62); ctx.rotate(lerp(0.9, -0.6, ease(swing)));
      ctx.strokeStyle = "#8a5a2a"; ctx.lineWidth = S * 0.016; ctx.beginPath(); ctx.moveTo(0, 0); ctx.lineTo(0, -S * 0.16); ctx.stroke();
      ctx.restore();
      // boulder arc after release (per>0.7)
      if (per > 0.7 && per < 1.9) {
        var u = (per - 0.7) / 1.2, bx = lerp(S * 0.22, S * 0.8, u), by = lerp(S * 0.46, S * 0.6, u) - Math.sin(u * Math.PI) * S * 0.4;
        ctx.fillStyle = "#4a4a4a"; circ(ctx, bx, by, S * 0.03); ctx.fill();
      }
      if (per >= 1.9 && per < 2.0 && !st.hit) { st.hit = 1; for (var i = 0; i < 16; i++) st.deb.push({ x: S * 0.8, y: S * 0.62, vx: (rnd(i) - 0.5) * 18, vy: -rnd(i + 3) * 14, life: 1 }); }
      if (per < 0.1) st.hit = 0;
      for (var di = st.deb.length - 1; di >= 0; di--) { var p = st.deb[di]; p.x += p.vx; p.y += p.vy; p.vy += 1; p.life -= 0.03; if (p.life <= 0) { st.deb.splice(di, 1); continue; } ctx.globalAlpha = clamp(p.life, 0, 1); ctx.fillStyle = "#9a9fa9"; ctx.fillRect(p.x, p.y, 9, 9); ctx.globalAlpha = 1; }
      if (per > 2.0) centerText(ctx, "DIRECT HIT!", S * 0.5, S * 0.16, "900 " + Math.round(S * 0.07) + "px Arial", "#ffd24a", S);
    }
  };

  // ── BREATH TRAINING ───────────────────────────────────────────────────────
  G.breath = {
    bg: "#06171a",
    draw: function (ctx, S, t, st) {
      var g = ctx.createRadialGradient(S / 2, S / 2, S * 0.05, S / 2, S / 2, S * 0.6);
      g.addColorStop(0, "#0e3a3a"); g.addColorStop(1, "#03101a"); ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      var cyc = 8, per = t % cyc; // 4s inhale, 4s exhale
      var inhale = per < 4;
      var u = inhale ? per / 4 : 1 - (per - 4) / 4;
      var e = ease(u);
      var r = lerp(S * 0.14, S * 0.34, e);
      // glow rings
      for (var i = 3; i >= 1; i--) { ctx.globalAlpha = 0.12; ctx.fillStyle = "#7CE0C8"; circ(ctx, S / 2, S / 2, r + i * S * 0.03); ctx.fill(); }
      ctx.globalAlpha = 1;
      var rg = ctx.createRadialGradient(S / 2, S / 2 - r * 0.3, r * 0.1, S / 2, S / 2, r);
      rg.addColorStop(0, "#aef7e6"); rg.addColorStop(1, "#2a9d8f"); ctx.fillStyle = rg; circ(ctx, S / 2, S / 2, r); ctx.fill();
      centerText(ctx, inhale ? "INHALE" : "EXHALE", S / 2, S / 2 - S * 0.01, "800 " + Math.round(S * 0.055) + "px Arial", "#04231f", S);
      var cd = Math.ceil(inhale ? (4 - per) : (8 - per));
      centerText(ctx, "" + cd, S / 2, S / 2 + S * 0.06, "900 " + Math.round(S * 0.07) + "px Arial", "#eafff9", S);
      // dots progress
      for (var d = 0; d < 4; d++) { ctx.fillStyle = (inhale ? per / 4 : 1) > d / 4 ? "#7CE0C8" : "#204a44"; circ(ctx, S * 0.5 + (d - 1.5) * S * 0.06, S * 0.86, S * 0.012); ctx.fill(); }
    }
  };

  // ── SNIPER SCOPE ──────────────────────────────────────────────────────────
  G.sniperscope = {
    bg: "#05070a",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.cycle = 3.4; st.round = 1; }
      ctx.fillStyle = "#04060a"; ctx.fillRect(0, 0, S, S);
      var per = t % st.cycle;
      var cx = S / 2, cy = S / 2, R = S * 0.42;
      // target drifts, settles under crosshair, then gets hit
      var settle = clamp(per / 1.6, 0, 1);
      var driftX = lerp(Math.sin(t * 0.7) * S * 0.12, 0, ease(settle));
      var driftY = lerp(Math.cos(t * 0.5) * S * 0.08, S * 0.05, ease(settle));
      var tx = cx + driftX, ty = cy + driftY;
      // scope glass
      circ(ctx, cx, cy, R); ctx.fillStyle = "#060a06"; ctx.fill();
      // faint mil-dot ring ticks
      ctx.strokeStyle = "rgba(180,220,180,0.35)"; ctx.lineWidth = 1;
      for (var i = 0; i < 36; i++) { var a = i * Math.PI / 18; var r1 = R * 0.97, r2 = (i % 3 === 0) ? R * 0.88 : R * 0.93; ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * r1, cy + Math.sin(a) * r1); ctx.lineTo(cx + Math.cos(a) * r2, cy + Math.sin(a) * r2); ctx.stroke(); }
      ctx.strokeStyle = "rgba(200,230,200,0.5)"; ctx.lineWidth = 2; circ(ctx, cx, cy, R * 0.97); ctx.stroke();
      // target silhouette
      ctx.save(); ctx.translate(tx, ty);
      ctx.fillStyle = "#5a6068"; rr(ctx, -S * 0.028, -S * 0.06, S * 0.056, S * 0.1, 8); ctx.fill();
      circ(ctx, 0, -S * 0.085, S * 0.022); ctx.fill();
      ctx.restore();
      // crosshair
      ctx.strokeStyle = "#ff6b5b"; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(cx - R, cy); ctx.lineTo(cx + R, cy); ctx.moveTo(cx, cy - R); ctx.lineTo(cx, cy + R); ctx.stroke();
      for (var k = -3; k <= 3; k++) { if (k === 0) continue; ctx.beginPath(); ctx.moveTo(cx + k * S * 0.03, cy - S * 0.01); ctx.lineTo(cx + k * S * 0.03, cy + S * 0.01); ctx.stroke(); }
      // hit flash + marker
      if (per > 1.6 && per < 2.0) { ctx.globalAlpha = 1 - (per - 1.6) / 0.4; ctx.fillStyle = "#ffef8a"; circ(ctx, tx, ty, S * 0.05); ctx.fill(); ctx.globalAlpha = 1; }
      // HUD text
      centerText(ctx, "R" + st.round + "/5", cx, S * 0.14, "900 " + Math.round(S * 0.05) + "px Arial", "#8be08b", S);
      centerText(ctx, per < 1.6 ? "HOLD" : "HIT!", cx, S * 0.88, "900 " + Math.round(S * 0.055) + "px Arial", per < 1.6 ? "#ffcf6b" : "#8be08b", S);
      if (per > 2.0 && per < 0.1 + st.cycle) { /* noop */ }
      if (per < 0.05) { st.round = (st.round % 5) + 1; }
    }
  };

  // ── GEM MATCH ─────────────────────────────────────────────────────────────
  G.gemmatch = {
    bg: "#100b1e",
    draw: function (ctx, S, t, st) {
      var N = 6, cell = S * 0.8 / N, ox = S * 0.1, oy = S * 0.12;
      var gems = ["#ff5d73", "#5df08a", "#5db8ff", "#ffd24a", "#c07bff"];
      if (!st.init) {
        st.init = 1; st.cycle = 2.6; st.grid = [];
        for (var r = 0; r < N; r++) { st.grid.push([]); for (var c = 0; c < N; c++) st.grid[r].push(Math.floor(rnd(r * N + c) * gems.length)); }
      }
      bgGrad(ctx, S, "#241a3a", "#0c0816");
      var per = t % st.cycle;
      var swapping = per < 0.5;
      var round = Math.floor(t / st.cycle);
      // pick a deterministic swap pair + a match line for this round
      var sr = Math.floor(rnd(round) * N), sc = Math.floor(rnd(round + 9) * (N - 1));
      var matchRow = Math.floor(rnd(round + 20) * N);
      for (var r2 = 0; r2 < N; r2++) {
        for (var c2 = 0; c2 < N; c2++) {
          var gx = ox + c2 * cell, gy = oy + r2 * cell;
          var idx = st.grid[r2][c2];
          var matched = (per > 0.9 && per < 1.6 && r2 === matchRow);
          var offx = 0;
          if (swapping && r2 === sr && (c2 === sc || c2 === sc + 1)) { var u = ease(per / 0.5); offx = (c2 === sc ? 1 : -1) * cell * (1 - u) * (c2 === sc ? 1 : -1) * 0; offx = (c2 === sc) ? lerp(0, cell, u) - cell * u : 0; }
          ctx.save();
          if (matched) { var pop = 1 + 0.25 * Math.sin((per - 0.9) * 14); ctx.translate(gx + cell / 2, gy + cell / 2); ctx.scale(pop, pop); ctx.translate(-cell / 2, -cell / 2); ctx.globalAlpha = clamp(1.6 - per, 0.2, 1); }
          else { ctx.translate(gx, gy); }
          drawGem(ctx, matched ? 0 : cell * 0.06, matched ? 0 : cell * 0.06, cell * 0.88, gems[idx]);
          ctx.restore();
        }
      }
      if (per > 1.6 && per < 2.2) { ctx.globalAlpha = clamp(2.2 - per, 0, 1) * 1.2; centerText(ctx, "MATCH +50", S / 2, S * 0.06, "900 " + Math.round(S * 0.05) + "px Arial", "#ffef8a", S); ctx.globalAlpha = 1; }
      function drawGem(ctx, x, y, sz, col) {
        ctx.save(); ctx.translate(x + sz / 2, y + sz / 2); ctx.rotate(Math.PI / 4);
        ctx.fillStyle = col; rr(ctx, -sz * 0.32, -sz * 0.32, sz * 0.64, sz * 0.64, sz * 0.12); ctx.fill();
        ctx.restore();
        ctx.fillStyle = "rgba(255,255,255,0.5)"; circ(ctx, x + sz * 0.36, y + sz * 0.34, sz * 0.09); ctx.fill();
      }
    }
  };

  // ── PETS (virtual pixel pet) ─────────────────────────────────────────────
  G.pets = {
    bg: "#1c1030",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.cycle = 3.4; st.hearts = []; }
      bgGrad(ctx, S, "#2a1a44", "#120a20");
      // room floor
      ctx.fillStyle = "#241535"; ctx.fillRect(0, S * 0.78, S, S * 0.22);
      var per = t % st.cycle;
      var feed = per > 1.2 && per < 1.8;
      var cx = S * 0.5, cy = S * 0.56 + Math.sin(t * 2.4) * S * 0.015;
      // pet body (round blob with ears)
      ctx.save(); ctx.translate(cx, cy);
      var squish = feed ? 1.12 : 1;
      ctx.scale(squish, 1 / squish);
      ctx.fillStyle = "#ff9ecb"; circ(ctx, 0, 0, S * 0.14); ctx.fill();
      ctx.fillStyle = "#ff7ab3"; circ(ctx, -S * 0.09, -S * 0.12, S * 0.045); ctx.fill(); circ(ctx, S * 0.09, -S * 0.12, S * 0.045); ctx.fill();
      ctx.restore();
      // face
      var blink = (Math.sin(t * 3) > 0.96);
      ctx.fillStyle = "#2b1030";
      if (blink) { ctx.fillRect(cx - S * 0.05, cy - S * 0.01, S * 0.03, S * 0.006); ctx.fillRect(cx + S * 0.02, cy - S * 0.01, S * 0.03, S * 0.006); }
      else { circ(ctx, cx - S * 0.035, cy - S * 0.01, S * 0.014); ctx.fill(); circ(ctx, cx + S * 0.035, cy - S * 0.01, S * 0.014); ctx.fill(); }
      ctx.lineWidth = S * 0.01; ctx.strokeStyle = "#c2467e"; ctx.beginPath(); ctx.arc(cx, cy + S * 0.02, S * 0.03, 0.15 * Math.PI, 0.85 * Math.PI); ctx.stroke();
      // food bowl + treat arriving during feed
      ctx.fillStyle = "#8a5a2a"; ctx.beginPath(); ctx.ellipse(cx, S * 0.78, S * 0.07, S * 0.02, 0, 0, 7); ctx.fill();
      if (feed) { var u = ease((per - 1.2) / 0.6); var fx = lerp(S * 0.78, cx, u), fy = lerp(S * 0.2, cy + S * 0.05, u); ctx.fillStyle = "#c98a3c"; circ(ctx, fx, fy, S * 0.02); ctx.fill(); }
      // floating hearts on feed
      if (feed && Math.floor(per * 10) % 3 === 0) st.hearts.push({ x: cx + (rnd(Math.floor(per * 20)) - 0.5) * S * 0.1, y: cy, life: 1 });
      for (var i = st.hearts.length - 1; i >= 0; i--) { var h = st.hearts[i]; h.y -= 1.6; h.life -= 0.02; if (h.life <= 0) { st.hearts.splice(i, 1); continue; } ctx.globalAlpha = clamp(h.life, 0, 1); ctx.fillStyle = "#ff5d8f"; heart(ctx, h.x, h.y, S * 0.018); ctx.globalAlpha = 1; }
      // HUD bars
      barRow(ctx, S * 0.08, S * 0.1, S * 0.36, "HAPPY", 0.6 + 0.3 * Math.sin(t), "#ff9ecb");
      barRow(ctx, S * 0.56, S * 0.1, S * 0.36, "HUNGER", feed ? 0.9 : 0.5 + 0.2 * Math.sin(t * 0.7), "#ffd24a");
      function heart(ctx, x, y, r) { ctx.beginPath(); ctx.moveTo(x, y + r * 0.6); ctx.bezierCurveTo(x - r, y - r * 0.3, x - r * 0.4, y - r, x, y - r * 0.3); ctx.bezierCurveTo(x + r * 0.4, y - r, x + r, y - r * 0.3, x, y + r * 0.6); ctx.fill(); }
      function barRow(ctx, x, y, w, label, v, col) {
        ctx.font = "800 " + Math.round(S * 0.026) + "px Arial"; ctx.fillStyle = "#e6d9f2"; ctx.textAlign = "left"; ctx.textBaseline = "middle"; ctx.fillText(label, x, y - S * 0.022);
        ctx.fillStyle = "rgba(255,255,255,0.15)"; rr(ctx, x, y, w, S * 0.022, S * 0.011); ctx.fill();
        ctx.fillStyle = col; rr(ctx, x, y, w * clamp(v, 0, 1), S * 0.022, S * 0.011); ctx.fill();
      }
    }
  };

  // ── SKI JUMP ──────────────────────────────────────────────────────────────
  G.skijump = {
    bg: "#bcd8ea",
    draw: function (ctx, S, t, st) {
      if (!st.init) { st.init = 1; st.cycle = 3.4; }
      var per = t % st.cycle;
      var g = ctx.createLinearGradient(0, 0, 0, S); g.addColorStop(0, "#bfe3f5"); g.addColorStop(1, "#eef8ff"); ctx.fillStyle = g; ctx.fillRect(0, 0, S, S);
      // distant mountains
      ctx.fillStyle = "#d8ecf7"; ctx.beginPath(); ctx.moveTo(0, S * 0.4); ctx.lineTo(S * 0.3, S * 0.22); ctx.lineTo(S * 0.55, S * 0.4); ctx.lineTo(S, S * 0.28); ctx.lineTo(S, S * 0.4); ctx.fill();
      // ramp (fixed) then flat landing hill
      ctx.fillStyle = "#eaf6ff"; ctx.beginPath(); ctx.moveTo(0, S * 0.3); ctx.lineTo(S * 0.34, S * 0.3); ctx.lineTo(S * 0.42, S * 0.42); ctx.lineTo(0, S * 0.5); ctx.closePath(); ctx.fill();
      ctx.strokeStyle = "#9fc7de"; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(0, S * 0.3); ctx.lineTo(S * 0.34, S * 0.3); ctx.lineTo(S * 0.42, S * 0.42); ctx.stroke();
      ctx.fillStyle = "#f4fbff"; ctx.beginPath(); ctx.moveTo(S * 0.3, S); ctx.quadraticCurveTo(S * 0.6, S * 0.55, S, S * 0.62); ctx.lineTo(S, S); ctx.closePath(); ctx.fill();

      var phase; // 0 approach, 1 air, 2 landed
      var skiX, skiY, rot = 0;
      if (per < 0.9) { phase = 0; var u = per / 0.9; skiX = lerp(S * 0.06, S * 0.4, u); skiY = lerp(S * 0.32, S * 0.4, u); }
      else if (per < 2.3) { phase = 1; var u2 = (per - 0.9) / 1.4; skiX = lerp(S * 0.4, S * 0.82, u2); skiY = lerp(S * 0.4, S * 0.6, u2) - Math.sin(u2 * Math.PI) * S * 0.22; rot = lerp(-0.1, 0.35, u2) + Math.sin(u2 * Math.PI * 2) * 0.15; }
      else { phase = 2; skiX = S * 0.82; skiY = S * 0.61; }
      // skier
      ctx.save(); ctx.translate(skiX, skiY); ctx.rotate(rot);
      ctx.strokeStyle = "#2b3a55"; ctx.lineWidth = S * 0.012;
      ctx.beginPath(); ctx.moveTo(-S * 0.05, S * 0.02); ctx.lineTo(S * 0.05, S * 0.02); ctx.stroke();
      ctx.fillStyle = "#e23b4a"; rr(ctx, -S * 0.018, -S * 0.03, S * 0.036, S * 0.05, 4); ctx.fill();
      ctx.fillStyle = "#f1c27d"; circ(ctx, 0, -S * 0.045, S * 0.016); ctx.fill();
      ctx.strokeStyle = "#2b3a55"; ctx.beginPath(); ctx.moveTo(0, -S * 0.01); ctx.lineTo(-S * 0.05, phase === 1 ? -S * 0.03 : S * 0.01); ctx.moveTo(0, -S * 0.01); ctx.lineTo(S * 0.05, phase === 1 ? -S * 0.03 : S * 0.01); ctx.stroke();
      ctx.restore();
      // snow spray on landing
      if (phase === 2 && per < 2.6) { for (var i = 0; i < 8; i++) { ctx.fillStyle = "rgba(255,255,255,0.8)"; circ(ctx, S * 0.82 - i * 6 - rnd(i) * 10, S * 0.61 + rnd(i + 3) * 8, 3); ctx.fill(); } }
      // HUD
      centerText(ctx, phase === 1 ? "SOAR!" : phase === 2 ? "128.4m" : "GO!", S / 2, S * 0.14, "900 " + Math.round(S * 0.06) + "px Arial", "#274060", S);
    }
  };

  window.ARCADE = G;
})();
