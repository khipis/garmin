#!/usr/bin/env python3
"""Generate professional 1440x720 hero images for 14 Garmin Connect IQ apps."""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math

W, H = 1440, 720
OUT = os.path.dirname(os.path.abspath(__file__))

def get_font(size):
    for p in ["/System/Library/Fonts/Helvetica.ttc",
              "/System/Library/Fonts/SFNSMono.ttf",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(p):
            try: return ImageFont.truetype(p, size)
            except: pass
    return ImageFont.load_default()

def gradient_bg(draw, c1, c2, w=W, h=H):
    for y in range(h):
        t = y / h
        r = int(c1[0]*(1-t) + c2[0]*t)
        g = int(c1[1]*(1-t) + c2[1]*t)
        b = int(c1[2]*(1-t) + c2[2]*t)
        draw.line([(0,y),(w,y)], fill=(r,g,b))

def vignette(img, strength=80):
    v = Image.new('RGBA', img.size, (0,0,0,0))
    vd = ImageDraw.Draw(v)
    cx, cy = img.size[0]//2, img.size[1]//2
    maxR = math.sqrt(cx*cx + cy*cy)
    for ring in range(int(maxR), 0, -3):
        a = int(strength * max(0, (ring/maxR - 0.5)*2)**2)
        if a > 0:
            vd.ellipse([cx-ring, cy-ring, cx+ring, cy+ring], fill=(0,0,0,a))
    return Image.alpha_composite(img.convert('RGBA'), v)

def title_bar(draw, title, subtitle, accent=(0,136,204)):
    barH = 100
    barY = H - barH
    draw.rectangle([0, barY, W, H], fill=(0,0,0))
    draw.line([(0, barY), (W, barY)], fill=accent, width=3)
    f_title = get_font(42)
    f_sub = get_font(20)
    draw.text((W//2, barY+18), title, fill=(255,255,255), font=f_title, anchor="mt")
    draw.text((W//2, barY+68), subtitle, fill=accent, font=f_sub, anchor="mt")

def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print(f"  -> {p}")

def draw_watch(draw, cx, cy, r, screen_lines=None, accent=(0,136,204)):
    draw.ellipse([cx-r-8, cy-r-8, cx+r+8, cy+r+8], fill=(40,40,40))
    draw.ellipse([cx-r-5, cy-r-5, cx+r+5, cy+r+5], fill=(60,60,60))
    draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=(0,0,0))
    draw.rectangle([cx+r+3, cy-12, cx+r+14, cy+12], fill=(80,80,80))
    if screen_lines:
        f = get_font(max(14, r//4))
        y = cy - len(screen_lines)*12
        for line, col in screen_lines:
            draw.text((cx, y), line, fill=col, font=f, anchor="mt")
            y += 24

# ── 1. ADHD DECIDER ──────────────────────────────────────────────────────────
def gen_adhd():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (5,5,10), (0,0,0))
    draw.text((W//2, 120), "?", fill=(255,255,255), font=get_font(120), anchor="mt")
    for i, t in enumerate(["Task A", "Task B", "Task C"]):
        y = 210 + i*42
        c = (255,255,255) if i==1 else (80,80,80)
        draw.text((W//2, y), t, fill=c, font=get_font(26), anchor="mt")
    draw.rounded_rectangle([W//2-120, 370, W//2+120, 420], radius=10, fill=(255,255,255))
    draw.text((W//2, 385), "DECIDE", fill=(0,0,0), font=get_font(32), anchor="mt")
    title_bar(draw, "ADHD DECIDER", "Can't choose? Let the watch decide.", accent=(255,255,255))
    img = vignette(img)
    save(img, "adhddecider_hero.png")

# ── 2. BOAT MODE DIVE PLANNER ────────────────────────────────────────────────
def gen_boat():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,8,20), (0,0,0))
    draw.line([(0,280),(W,280)], fill=(0,68,102), width=2)
    for x in range(0, W, 80):
        draw.arc([x, 268, x+80, 292], 0, 180, fill=(0,50,80), width=1)
    f = get_font(26)
    labels = [("GAS", "Nitrox 32"), ("DEPTH", "25m"), ("TIME", "30 min")]
    for i, (l, v) in enumerate(labels):
        y = 100 + i*48
        draw.text((280, y), l, fill=(102,170,221), font=f, anchor="lm")
        draw.text((620, y), v, fill=(255,255,255), font=f, anchor="lm")
    draw.rounded_rectangle([280, 280, 620, 350], radius=10, fill=(0,204,68))
    draw.text((450, 300), "GO", fill=(0,0,0), font=get_font(38), anchor="mt")
    draw_watch(draw, 1050, 260, 120,
        [("QUICK PLAN", (0,136,204)), ("PO2: 1.28", (255,255,255)), ("GO", (0,204,68))],
        accent=(0,136,204))
    title_bar(draw, "BOAT MODE DIVE PLANNER", "3 modes  /  Quick Plan  /  Safety Check  /  Gas Check")
    img = vignette(img)
    save(img, "boatmodediveplanner_hero.png")

# ── 3. BREATHING GAS CONTROL ─────────────────────────────────────────────────
def gen_breathing():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,15), (0,0,0))
    cx, cy, r = W//2, 260, 140
    for ring_r in range(r, r-30, -1):
        a = int(255 * (ring_r - r + 30) / 30)
        col = (0, int(136*a/255), int(204*a/255))
        draw.ellipse([cx-ring_r, cy-ring_r, cx+ring_r, cy+ring_r], outline=col)
    draw.ellipse([cx-75, cy-75, cx+75, cy+75], fill=(0,80,120))
    draw.text((cx, cy-16), "4s", fill=(255,255,255), font=get_font(42), anchor="mt")
    draw.text((cx, cy+22), "INHALE", fill=(200,230,255), font=get_font(20), anchor="mt")
    phases = [("INHALE", (0,136,204)), ("HOLD", (0,170,119)), ("EXHALE", (102,68,187)), ("HOLD", (204,102,51))]
    for i, (p, c) in enumerate(phases):
        x = 140 + i*330
        draw.text((x, 460), p, fill=c, font=get_font(20), anchor="mt")
        if i < 3:
            draw.line([(x+60, 465), (x+260, 465)], fill=(50,50,50))
    title_bar(draw, "BREATHING GAS CONTROL", "Breathing patterns for divers  /  Recovery  /  Breathe-Up  /  CO2 Tol")
    img = vignette(img)
    save(img, "breathinggascontrol_hero.png")

# ── 4. DIVE GAS BLENDER ──────────────────────────────────────────────────────
def gen_gasblender():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,15), (0,0,0))
    for i in range(3):
        x = 160 + i*150
        draw.rounded_rectangle([x, 80, x+100, 320], radius=14, fill=(20,20,20), outline=(80,80,80))
        labels = ["O2", "AIR", "MIX"]
        colors = [(68,204,255), (150,150,150), (0,204,68)]
        draw.text((x+50, 200), labels[i], fill=colors[i], font=get_font(22), anchor="mm")
    draw.text((380, 370), "+", fill=(255,255,255), font=get_font(60), anchor="mm")
    draw.text((520, 370), "=", fill=(255,255,255), font=get_font(60), anchor="mm")
    draw.text((680, 370), "EAN32", fill=(0,204,68), font=get_font(42), anchor="mm")
    draw_watch(draw, 1080, 240, 120,
        [("PP BLEND", (0,136,204)), ("Fill O2: 48 bar", (68,204,255)), ("Top air: 200", (0,204,68))],
        accent=(0,136,204))
    title_bar(draw, "DIVE GAS BLENDER", "PP Blend  /  Mix Check  /  MOD Lookup")
    img = vignette(img)
    save(img, "divegasblender_hero.png")

# ── 5. DIVE PLAN TOOLKIT ─────────────────────────────────────────────────────
def gen_diveplantoolkit():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,15), (0,0,0))
    tools = ["MOD/PO2", "Best Mix", "EAD", "SAC", "NDL"]
    for i, t in enumerate(tools):
        y = 60 + i*68
        sel = (i == 0)
        if sel:
            draw.rounded_rectangle([100, y-4, 560, y+52], radius=6, fill=(10,21,32))
        c = (255,255,255) if sel else (85,85,85)
        draw.text((140, y+16), t, fill=c, font=get_font(28), anchor="lm")
    draw_watch(draw, 1020, 250, 130,
        [("MOD", (0,136,204)), ("33m", (255,255,255)), ("@PO2 1.4", (85,85,85))],
        accent=(0,136,204))
    title_bar(draw, "DIVE PLAN TOOLKIT", "5 calculators  /  MOD  /  Best Mix  /  EAD  /  SAC  /  NDL")
    img = vignette(img)
    save(img, "diveplantoolkit_hero.png")

# ── 6. DIVE PREPARATION CHECKER ──────────────────────────────────────────────
def gen_diveprep():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,10), (0,0,0))
    cx = 360
    draw.text((cx, 50), "DIVE READY", fill=(0,136,204), font=get_font(26), anchor="mt")
    draw.text((cx, 130), "82", fill=(0,204,68), font=get_font(130), anchor="mt")
    draw.text((cx, 310), "GOOD", fill=(0,204,68), font=get_font(36), anchor="mt")
    factors = [("Time of Day", "+15"), ("Conditions", "+12"), ("Temperature", "+8"), ("Stress", "-5")]
    for i, (f, v) in enumerate(factors):
        y = 380 + i*36
        c = (0,204,68) if v.startswith("+") else (255,34,34)
        draw.text((820, y), f, fill=(85,85,85), font=get_font(20), anchor="lm")
        draw.text((1200, y), v, fill=c, font=get_font(20), anchor="lm")
    title_bar(draw, "DIVE PREPARATION CHECKER", "Readiness score  /  SCUBA & Freedive  /  Auto + manual factors")
    img = vignette(img)
    save(img, "divepreparationchecker_hero.png")

# ── 7. DIVER COMMUNICATOR ────────────────────────────────────────────────────
def gen_divercomm():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,15), (0,0,0))
    cats = [("OK", (0,204,68)), ("AIR", (0,136,204)), ("MOVE", (255,170,0)), ("ISSUE", (255,102,0)), ("SOS", (255,34,34))]
    for i, (c, col) in enumerate(cats):
        x = 80 + i*268
        draw.rounded_rectangle([x, 80, x+220, 180], radius=10, fill=(15,15,15), outline=col)
        draw.text((x+110, 120), c, fill=col, font=get_font(34), anchor="mt")
    draw_watch(draw, W//2, 350, 100,
        [("LOW AIR!", (255,34,34))],
        accent=(255,34,34))
    title_bar(draw, "DIVER COMMUNICATOR", "Underwater buddy signals  /  5 categories  /  High contrast")
    img = vignette(img)
    save(img, "divercommunicator_hero.png")

# ── 8. DIVE RISK INDICATOR ───────────────────────────────────────────────────
def gen_diverisk():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,10), (0,0,0))
    cx = W//2
    draw.text((cx, 30), "DIVE RISK", fill=(85,85,85), font=get_font(26), anchor="mt")
    draw.text((cx, 80), "32", fill=(0,204,68), font=get_font(160), anchor="mt")
    draw.text((cx, 310), "LOW RISK", fill=(0,204,68), font=get_font(40), anchor="mt")
    draw.line([(cx-300, 370), (cx+300, 370)], fill=(17,17,17), width=2)
    info = [("Depth 25m", "NDL 29 min"), ("Gas Air 21%", "PO2 1.47")]
    for i, (l, r) in enumerate(info):
        y = 400 + i*42
        draw.text((cx-280, y), l, fill=(85,85,85), font=get_font(22), anchor="lm")
        draw.text((cx+280, y), r, fill=(102,170,221), font=get_font(22), anchor="rm")
    title_bar(draw, "DIVE RISK INDICATOR", "Real-time risk score  /  Depth  /  Time  /  Gas  /  NDL model")
    img = vignette(img)
    save(img, "diveriskindicator_hero.png")

# ── 9. DRONE FLIGHT CHECKER ──────────────────────────────────────────────────
def gen_drone():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (5,5,10), (0,0,0))
    cx = 360
    draw.text((cx, 50), "FLIGHT CHECK", fill=(85,85,85), font=get_font(26), anchor="mt")
    draw.text((cx, 110), "91", fill=(0,204,68), font=get_font(130), anchor="mt")
    draw.text((cx, 300), "FLY", fill=(0,204,68), font=get_font(40), anchor="mt")
    draw.text((880, 80), "W: Low", fill=(0,204,68), font=get_font(22), anchor="lm")
    draw.text((880, 118), "E: Clear", fill=(0,204,68), font=get_font(22), anchor="lm")
    draw.text((880, 156), "V: Good", fill=(0,204,68), font=get_font(22), anchor="lm")
    draw.text((880, 210), "HR: 72", fill=(85,85,85), font=get_font(20), anchor="lm")
    draw.text((880, 244), "Baro: Stable", fill=(85,85,85), font=get_font(20), anchor="lm")
    draw.text((880, 278), "Stress: Low", fill=(85,85,85), font=get_font(20), anchor="lm")
    title_bar(draw, "DRONE FLIGHT CHECKER", "Pre-flight readiness  /  Wind + Environment + Visibility + Bio sensors")
    img = vignette(img)
    save(img, "droneflightchecker_hero.png")

# ── 10. FISHING BITE PREDICTOR ────────────────────────────────────────────────
def gen_fishing():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (3,5,10), (0,0,0))
    cx = W//2
    draw.text((cx, 30), "FISHING SCORE", fill=(85,85,85), font=get_font(26), anchor="mt")
    draw.text((cx, 80), "78", fill=(0,204,68), font=get_font(160), anchor="mt")
    draw.text((cx, 310), "HIGH", fill=(0,204,68), font=get_font(40), anchor="mt")
    factors = [("Time: Dawn", "+20", True), ("Weather: Overcast", "+15", True),
               ("Pressure: Falling", "+10", True), ("Moon: Full", "-5", False)]
    for i, (f, v, pos) in enumerate(factors):
        y = 380 + i*34
        draw.text((280, y), f, fill=(85,85,85), font=get_font(18), anchor="lm")
        draw.text((1160, y), v, fill=(0,204,68) if pos else (255,34,34), font=get_font(18), anchor="rm")
    title_bar(draw, "FISHING BITE PREDICTOR", "Heuristic bite score  /  Time  /  Weather  /  Pressure  /  Moon")
    img = vignette(img)
    save(img, "fishingbitepredictor_hero.png")

# ── 11. FREEDIVER BREATHING TRAINER ──────────────────────────────────────────
def gen_freediver():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,15), (0,0,0))
    modes = [("RELAX", (0,136,204)), ("CO2", (0,170,119)), ("O2", (102,68,187))]
    for i, (m, c) in enumerate(modes):
        x = 120 + i*420
        draw.rounded_rectangle([x, 60, x+320, 160], radius=10, fill=(15,15,15), outline=c)
        draw.text((x+160, 100), m, fill=c, font=get_font(40), anchor="mt")
    cx = W//2
    for ring_r in range(100, 70, -1):
        a = int(255 * (ring_r - 70) / 30)
        col = (0, int(136*a/255), int(204*a/255))
        draw.ellipse([cx-ring_r, 320-ring_r, cx+ring_r, 320+ring_r], outline=col)
    draw.text((cx, 304), "HOLD", fill=(0,170,119), font=get_font(26), anchor="mt")
    draw.text((cx, 332), "4s", fill=(255,255,255), font=get_font(34), anchor="mt")
    title_bar(draw, "FREEDIVER BREATHING TRAINER", "Relax  /  CO2 Tolerance  /  O2 Tables  /  Animated guide + haptics")
    img = vignette(img)
    save(img, "freediverbreathingtrainer_hero.png")

# ── 12. INTERVAL BEEPER ──────────────────────────────────────────────────────
def gen_interval():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    cx = W//2
    draw.text((cx, 50), "WORK", fill=(255,255,255), font=get_font(30), anchor="mt")
    draw.text((cx, 90), "0:28", fill=(255,255,255), font=get_font(160), anchor="mt")
    barY, barH = 320, 6
    mg = 300
    draw.rounded_rectangle([mg, barY, W-mg, barY+barH], radius=3, fill=(26,26,26))
    draw.rounded_rectangle([mg, barY, mg+460, barY+barH], radius=3, fill=(255,255,255))
    dotY = 350
    for i in range(10):
        x = cx - 75 + i*17
        c = (255,255,255) if i < 4 else (85,85,85) if i==4 else (26,26,26)
        draw.ellipse([x-3, dotY-3, x+3, dotY+3], fill=c)
    draw.text((cx, 390), "3/10", fill=(51,51,51), font=get_font(20), anchor="mt")
    title_bar(draw, "INTERVAL BEEPER", "Work/Rest intervals  /  Haptic alerts  /  Fully configurable")
    img = vignette(img)
    save(img, "intervalbeeper_hero.png")

# ── 13. DIVE QUICK CALCULATOR ────────────────────────────────────────────────
def gen_quickcalc():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    gradient_bg(draw, (0,5,12), (0,0,0))
    f = get_font(26)
    rows = [("GAS", "Nitrox 32", True), ("DEPTH", "25m", False)]
    for i, (l, v, sel) in enumerate(rows):
        y = 70 + i*52
        if sel:
            draw.rounded_rectangle([200, y-6, 740, y+40], radius=6, fill=(10,21,32))
        draw.text((230, y+10), l, fill=(102,170,221) if sel else (51,51,51), font=f, anchor="lm")
        draw.text((710, y+10), v, fill=(255,255,255) if sel else (85,85,85), font=f, anchor="rm")
    draw.line([(200, 200), (740, 200)], fill=(17,17,17), width=1)
    draw.text((470, 220), "PO2: 1.28", fill=(0,204,68), font=get_font(36), anchor="mt")
    draw.rounded_rectangle([280, 280, 660, 350], radius=10, fill=(0,204,68))
    draw.text((470, 300), "SAFE", fill=(0,0,0), font=get_font(38), anchor="mt")
    draw_watch(draw, 1080, 250, 120,
        [("BEST MIX", (0,136,204)), ("EAN 36", (68,204,255)), ("MOD: 28m", (85,85,85))],
        accent=(0,136,204))
    title_bar(draw, "DIVE QUICK CALCULATOR", "Instant PO2 check  /  MOD  /  NDL  /  Best Mix  /  Swipe between pages")
    img = vignette(img)
    save(img, "divequickcalculator_hero.png")

# ── 14. RECOVERY TIMER ───────────────────────────────────────────────────────
def gen_recovery():
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)
    cx = W//2
    draw.text((cx, 40), "COLD", fill=(255,255,255), font=get_font(30), anchor="mt")
    draw.text((cx, 80), "1:42", fill=(255,255,255), font=get_font(160), anchor="mt")
    barY, barH = 310, 6
    mg = 300
    draw.rounded_rectangle([mg, barY, W-mg, barY+barH], radius=3, fill=(26,26,26))
    draw.rounded_rectangle([mg, barY, mg+520, barY+barH], radius=3, fill=(255,255,255))
    presets = ["30s", "1m", "2m", "3m", "5m"]
    for i, p in enumerate(presets):
        x = 350 + i*150
        sel = (i == 2)
        draw.text((x, 350), p, fill=(255,255,255) if sel else (85,85,85), font=get_font(24), anchor="mt")
    draw.text((cx, 400), "2x 2:00/1:00", fill=(51,51,51), font=get_font(20), anchor="mt")
    title_bar(draw, "RECOVERY TIMER", "Cold exposure  /  Single or interval  /  Haptic countdown  /  Presets")
    img = vignette(img)
    save(img, "recoverytimer_hero.png")

# ── 15. SOLITAIRE ───────────────────────────────────────────────────────────
def _draw_suit(draw, cx, cy, suit, size, color):
    """Draw suit shapes programmatically: 0=spade 1=heart 2=diamond 3=club"""
    s = size
    r = s * 45 // 100
    if r < 2: r = 2
    if suit == 0:  # spade
        draw.polygon([(cx, cy-s), (cx-s, cy+s//4), (cx+s, cy+s//4)], fill=color)
        draw.ellipse([cx-r-1, cy-r//2+s//6, cx+r-1, cy+r//2+s//3], fill=color)
        draw.ellipse([cx-r+1, cy-r//2+s//6, cx+2*r-1, cy+r//2+s//3], fill=color)
        draw.rectangle([cx-s//8, cy+s//3, cx+s//8, cy+s*7//10], fill=color)
    elif suit == 1:  # heart
        draw.ellipse([cx-r-1, cy-s//2-r//3, cx+1, cy+r//3], fill=color)
        draw.ellipse([cx-1, cy-s//2-r//3, cx+r+1, cy+r//3], fill=color)
        draw.polygon([(cx-s, cy-s//6), (cx, cy+s), (cx+s, cy-s//6)], fill=color)
    elif suit == 2:  # diamond
        draw.polygon([(cx, cy-s), (cx+s*6//10, cy), (cx, cy+s), (cx-s*6//10, cy)], fill=color)
    else:  # club
        draw.ellipse([cx-r, cy-s//2-r//3, cx+r, cy+r//3-s//6], fill=color)
        draw.ellipse([cx-s//2-r//3, cy-r, cx+r//3-s//6, cy+r], fill=color)
        draw.ellipse([cx-r//3+s//6, cy-r, cx+s//2+r//3, cy+r], fill=color)
        draw.rectangle([cx-s//8, cy+r//2, cx+s//8, cy+s*7//10], fill=color)

def gen_solitaire():
    import random
    random.seed(42)
    img = Image.new('RGB', (W,H), (0,0,0))
    draw = ImageDraw.Draw(img)

    # Rich felt-green gradient
    for y in range(H):
        t = y / H
        rr = int(6*(1-t) + 2*t)
        gg = int(34*(1-t) + 16*t)
        bb = int(18*(1-t) + 8*t)
        draw.line([(0,y),(W,y)], fill=(rr,gg,bb))

    # Felt texture
    for _ in range(800):
        tx = random.randint(0, W)
        ty = random.randint(0, H-110)
        a = random.randint(4, 12)
        draw.ellipse([tx-1, ty-1, tx+1, ty+1], fill=(a, a+16, a+7))

    cw, ch = 105, 148
    ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]

    def card_shadow(x, y, w=cw, h=ch):
        for s in range(8, 0, -1):
            c = max(0, 5 - s)
            draw.rounded_rectangle([x+s, y+s, x+w+s, y+h+s], radius=8, fill=(c,c+2,c))

    def card_face(x, y, rank_i, suit_i, w=cw, h=ch):
        card_shadow(x, y, w, h)
        is_red = suit_i in (1, 2)
        tc = (200,25,25) if is_red else (25,25,25)
        draw.rounded_rectangle([x, y, x+w, y+h], radius=8, fill=(252,250,244))
        draw.rounded_rectangle([x, y, x+w, y+h], radius=8, outline=(195,190,180))
        draw.rounded_rectangle([x+2, y+2, x+w-2, y+h-2], radius=6, outline=(235,232,225))
        # Top-left: rank
        f = get_font(max(20, w//4))
        draw.text((x+10, y+6), ranks[rank_i], fill=tc, font=f)
        # Top-left: small suit
        _draw_suit(draw, x+16, y+38, suit_i, max(6, w//12), tc)
        # Center: large suit
        _draw_suit(draw, x+w//2, y+h//2+4, suit_i, max(14, w//4), tc)
        # Bottom-right: rank
        fs = get_font(max(14, w//6))
        draw.text((x+w-10, y+h-10), ranks[rank_i], fill=tc, font=fs, anchor="rb")

    def card_back(x, y, w=cw, h=ch):
        card_shadow(x, y, w, h)
        draw.rounded_rectangle([x, y, x+w, y+h], radius=8, fill=(22,42,85))
        draw.rounded_rectangle([x, y, x+w, y+h], radius=8, outline=(55,85,135))
        draw.rounded_rectangle([x+5, y+5, x+w-5, y+h-5], radius=5, outline=(32,58,108))
        mx, my = x+w//2, y+h//2
        ds = w//4
        draw.polygon([(mx,my-ds),(mx+ds,my),(mx,my+ds),(mx-ds,my)], fill=(38,64,115))
        draw.polygon([(mx,my-ds),(mx+ds,my),(mx,my+ds),(mx-ds,my)], outline=(55,85,145))
        ds2 = ds//2
        draw.polygon([(mx,my-ds2),(mx+ds2,my),(mx,my+ds2),(mx-ds2,my)], outline=(42,72,125))

    # ── LEFT: Fan of 5 premium cards ──
    fan_cards = [(0,0), (12,1), (11,0), (10,2), (9,3)]
    fan_spread = 60
    fan_cx = 360
    fan_start_x = fan_cx - (len(fan_cards)-1)*fan_spread//2
    for i, (ri, si) in enumerate(fan_cards):
        fx = fan_start_x + i * fan_spread
        fy = 220 + abs(i - 2) * 14
        card_face(fx, fy, ri, si)

    # ── RIGHT: Watch mockup ──
    wcx, wcy, wr = 1060, 280, 158
    for ring in range(14, 0, -1):
        c = 25 + ring * 3
        draw.ellipse([wcx-wr-ring, wcy-wr-ring, wcx+wr+ring, wcy+wr+ring], fill=(c,c,c))
    draw.ellipse([wcx-wr, wcy-wr, wcx+wr, wcy+wr], fill=(10,30,18))
    draw.rounded_rectangle([wcx+wr+2, wcy-16, wcx+wr+16, wcy+16], radius=4, fill=(65,65,65))

    # Mini cards inside watch
    mcw, mch = 24, 33
    mg = 4
    my_top = wcy - wr + 35
    msx = wcx - 3*(mcw+mg)
    # Stock back
    draw.rounded_rectangle([msx, my_top, msx+mcw, my_top+mch], radius=3, fill=(22,42,85), outline=(50,80,130))
    # Waste
    wx = msx + mcw + mg*2
    draw.rounded_rectangle([wx, my_top, wx+mcw, my_top+mch], radius=3, fill=(252,250,244), outline=(195,190,180))
    _draw_suit(draw, wx+mcw//2, my_top+mch//2, 1, 5, (200,25,25))
    # 4 foundations
    for fi in range(4):
        fx = wcx - mcw + fi*(mcw+mg)
        fc = (200,25,25) if fi in (1,2) else (25,25,25)
        draw.rounded_rectangle([fx, my_top, fx+mcw, my_top+mch], radius=3, fill=(252,250,244), outline=(195,190,180))
        _draw_suit(draw, fx+mcw//2, my_top+mch//2, fi, 4, fc)
    # Mini tableau
    mt_y = my_top + mch + 8
    for c in range(7):
        mx = wcx - 3*(mcw+mg)//2 - mcw//2 + c*(mcw+mg-1)
        nc = min(c+1, 4)
        for ci in range(nc):
            my = mt_y + ci * 8
            if ci < c:
                draw.rounded_rectangle([mx, my, mx+mcw, my+mch], radius=2, fill=(22,42,85), outline=(40,60,100))
            else:
                draw.rounded_rectangle([mx, my, mx+mcw, my+mch], radius=2, fill=(252,250,244), outline=(195,190,180))

    # ── Decorative suits in background ──
    deco = [(55,45,0,20), (1365,55,1,22), (65,490,2,18), (1370,475,3,20),
            (720,25,0,16), (195,395,3,18), (1255,345,1,20), (480,30,2,14)]
    for dx, dy, ds, dsz in deco:
        sc = (16,32,20) if ds in (0,3) else (32,16,16)
        _draw_suit(draw, dx, dy, ds, dsz, sc)

    # ── GOLDEN TITLE BAR ──
    barH = 105
    barY = H - barH
    draw.rectangle([0, barY, W, H], fill=(8,8,8))
    draw.line([(0, barY), (W, barY)], fill=(185,155,55), width=3)
    draw.line([(0, barY+3), (W, barY+3)], fill=(125,105,35), width=1)
    f_title = get_font(46)
    f_sub = get_font(20)
    f_detail = get_font(16)
    draw.text((W//2, barY+14), "SOLITAIRE", fill=(240,220,140), font=f_title, anchor="mt")
    draw.text((W//2, barY+64), "Classic Klondike  |  Tap & Double-Tap  |  Auto-Stack  |  Win Animation",
              fill=(140,120,60), font=f_sub, anchor="mt")
    draw.text((W//2, barY+88), "Designed for Garmin Smartwatches",
              fill=(70,65,45), font=f_detail, anchor="mt")

    img = vignette(img, strength=100)
    save(img, "solitaire_hero.png")

# ── Generate all ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    print("Generating 1440x720 hero images...")
    gen_adhd()
    gen_boat()
    gen_breathing()
    gen_gasblender()
    gen_diveplantoolkit()
    gen_diveprep()
    gen_divercomm()
    gen_diverisk()
    gen_drone()
    gen_fishing()
    gen_freediver()
    gen_interval()
    gen_quickcalc()
    gen_recovery()
    gen_solitaire()
    print("Done! 15 hero images at 1440x720.")
