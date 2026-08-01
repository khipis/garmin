#!/usr/bin/env python3
"""Offline balance check for the idle night simulation.

A faithful port of BattleSim.mc + WaveGen.mc so the difficulty curve can be
inspected in a second instead of a fortnight of real evenings. The game gives
the player exactly one wave per calendar day, which makes balance impossible
to test by playing: a bad curve would take a month to discover and a month to
confirm the fix.

Run:  python3 _balance.py
"""

LANES = 3
WX_SPAWN = 10000
WX_SPIKES = 1500
WX_WIRE = 3800
WX_SPIT = 2600
SIM_MAX_TICKS = 5400
BOSS_EVERY = 5
FOG_RANGE = 5200

MOD_NONE, MOD_FOG, MOD_RAGE, MOD_HORDE, MOD_BLOOD = range(5)
Z_WALKER, Z_RUNNER, Z_BRUTE, Z_CRAWLER, Z_SPITTER, Z_SCREAMER, Z_BOSS = range(7)

Z_HP     = [34, 22, 150, 16, 44, 60, 520]
Z_SPEED  = [46, 104, 27, 74, 38, 52, 22]
Z_DMG    = [7, 5, 26, 4, 9, 8, 44]
Z_BITE   = [14, 10, 22, 9, 16, 14, 20]
Z_ARMOR  = [0, 0, 6, 0, 0, 2, 12]
Z_SCRAP  = [3, 4, 14, 2, 7, 9, 90]

# Defence indices, matching Zs.D_*
D_WALL, D_GATE, D_MG, D_MORTAR, D_TESLA, D_SPIKES, D_WIRE, D_REPAIR, \
    D_PLATING, D_SALVAGE, D_RIFLE = range(11)
D_N = 11
D_LVL_MAX = 15
D_NAME = ["WALL", "GATE", "MG", "MORTAR", "TESLA", "SPIKES", "WIRE",
          "REPAIR", "PLATING", "SALVAGE", "RIFLE"]
D_BASE_COST = [60, 90, 80, 150, 190, 70, 65, 130, 110, 85, 100]


def dcost(i, lvl):
    b = D_BASE_COST[i]
    return b + b * lvl * 9 // 10 + lvl * lvl * 22


def wall_hp(l):    return 260 + l * 47
def gate_hp(l):    return 0 if l <= 0 else 120 + l * 90
def mg_dmg(l):     return 0 if l <= 0 else 9 + l * 4
def mg_rate(l):    return max(4, 11 - l // 3)
def mortar_dmg(l): return 0 if l <= 0 else 40 + l * 26
def mortar_rate(l):return max(24, 46 - l * 2)
def tesla_dmg(l):  return 0 if l <= 0 else 12 + l * 9
def tesla_rate(l): return max(18, 34 - l)
def tesla_chain(l):return min(4, 1 + l // 3)
def spike_dmg(l):  return 0 if l <= 0 else 14 + l * 11
def wire_slow(l):  return max(45, 100 - l * 5)
def repair_pct(l): return min(90, l * 8)
def plating(l):    return l
def salvage(l):    return 100 + l * 9
def rifle_dmg(l):  return 30 + l * 16


# ── WaveGen ────────────────────────────────────────────────────────────────
def _next(s):
    return (s * 1103515245 + 12345) & 0x7FFFFFFF


def seed_for(night):
    return (max(1, night) * 40503 + 1013904223) & 0x7FFFFFFF


def mod_for(wave, seed):
    if wave < 3:
        return MOD_NONE
    roll = _next(seed + wave * 7919) % 100
    if roll < 44: return MOD_NONE
    if roll < 58: return MOD_FOG
    if roll < 72: return MOD_RAGE
    if roll < 88: return MOD_HORDE
    return MOD_BLOOD


def is_boss(w):
    return w > 0 and w % BOSS_EVERY == 0


def pick_type(wave, roll):
    if wave <= 1: return Z_WALKER
    r = roll % 100
    if wave < 3:
        return Z_WALKER if r < 76 else Z_RUNNER
    if wave < 5:
        if r < 54: return Z_WALKER
        if r < 78: return Z_RUNNER
        return Z_CRAWLER
    if wave < 8:
        if r < 40: return Z_WALKER
        if r < 62: return Z_RUNNER
        if r < 76: return Z_CRAWLER
        if r < 92: return Z_BRUTE
        return Z_SPITTER
    if wave < 13:
        if r < 30: return Z_WALKER
        if r < 52: return Z_RUNNER
        if r < 64: return Z_CRAWLER
        if r < 80: return Z_BRUTE
        if r < 92: return Z_SPITTER
        return Z_SCREAMER
    if r < 20: return Z_WALKER
    if r < 44: return Z_RUNNER
    if r < 54: return Z_CRAWLER
    if r < 74: return Z_BRUTE
    if r < 88: return Z_SPITTER
    return Z_SCREAMER


def build(wave, seed):
    w = max(1, wave)
    mod = mod_for(w, seed)
    n = 6 + w * 2 + w * w // 10
    if mod == MOD_HORDE: n = n * 15 // 10
    n = min(64, n)

    s = (seed + w * 10007 + 4242) & 0x7FFFFFFF
    gap = max(9, 30 - w)
    if mod == MOD_HORDE: gap = max(6, gap * 7 // 10)

    sched, t, lane = [], 14, 0
    for i in range(n):
        s = _next(s)
        typ = pick_type(w, s // 7)
        s = _next(s)
        lane = (lane + 1 + (s % 3)) % LANES
        sched += [t, typ, lane]
        s = _next(s)
        step = gap * (70 + (s % 70)) // 100
        if i % 7 == 6: step //= 3
        t += max(3, step)

    hp = 100 + (w - 1) * 14 + w * w // 6
    if mod == MOD_BLOOD: hp = hp * 125 // 100
    if mod == MOD_HORDE: hp = hp * 80 // 100
    hp = min(6000, hp)

    sp = min(210, 100 + (w - 1) * 3 + (30 if mod == MOD_RAGE else 0))

    return {"wave": w, "mod": mod, "count": n, "sched": sched, "hpPct": hp,
            "spPct": sp, "boss": is_boss(w),
            "bossHp": Z_HP[Z_BOSS] * (100 + (w - BOSS_EVERY) * 34) // 100
                      if is_boss(w) else 0}


# ── BattleSim ──────────────────────────────────────────────────────────────
ZMAX = 16


class Sim:
    def __init__(self, lvl, night, wall_pct=100):
        self.lvl = lvl
        self.night = night
        self.wv = build(night, seed_for(night))
        self.sched = self.wv["sched"]
        self.total = self.wv["count"]
        self.mod = self.wv["mod"]
        self.si = 0
        self.tick_n = 0
        self.state = 0                      # 0 fight / 1 won / 2 lost
        self.kills = 0
        self.scrap = 0
        self.seed = (seed_for(night) ^ 0x5D3F) & 0x7FFFFFFF
        self.boss_spawned = False

        self.alive = [False] * ZMAX
        self.zx = [0] * ZMAX
        self.zl = [0] * ZMAX
        self.zt = [0] * ZMAX
        self.zhp = [0] * ZMAX
        self.zbite = [0] * ZMAX
        self.zflash = [0] * ZMAX
        self.zspiked = [False] * ZMAX

        seg = wall_hp(lvl[D_WALL]) + gate_hp(lvl[D_GATE])
        pct = max(5, wall_pct)
        self.wall = [max(1, seg * pct // 100)] * LANES
        self.wall_max = [seg] * LANES

        self.mgT = self.morT = self.tesT = 0

    def rnd(self, n):
        self.seed = (self.seed * 1103515245 + 12345) & 0x7FFFFFFF
        return (self.seed // 65536) % n if n > 0 else 0

    def jitter(self, d):
        return max(1, d * (88 + self.rnd(25)) // 100) if d > 0 else 0

    def run(self):
        while self.state == 0 and self.tick_n <= SIM_MAX_TICKS + 8:
            self.step()
        return self

    def step(self):
        self.tick_n += 1
        self.spawns()
        self.zombies()
        self.turrets()
        if (self.n_alive() == 0 and self.si >= len(self.sched)
                and (not self.wv["boss"] or self.boss_spawned)):
            self.state = 1
        if self.state == 0 and self.tick_n > SIM_MAX_TICKS:
            self.state = 2

    def spawns(self):
        while self.si + 2 < len(self.sched) and self.sched[self.si] <= self.tick_n:
            if not self.spawn(self.sched[self.si + 1], self.sched[self.si + 2],
                              self.wv["hpPct"]):
                return
            self.si += 3
        if (self.wv["boss"] and not self.boss_spawned
                and self.si >= len(self.sched) // 3):
            if self.spawn(Z_BOSS, 1, 100):
                self.boss_spawned = True

    def spawn(self, typ, lane, pct):
        for i in range(ZMAX):
            if self.alive[i]:
                continue
            hp = self.wv["bossHp"] if typ == Z_BOSS else Z_HP[typ] * pct // 100
            self.alive[i] = True
            self.zx[i] = WX_SPAWN + self.rnd(600)
            self.zl[i] = lane
            self.zt[i] = typ
            self.zhp[i] = max(1, hp)
            self.zbite[i] = 0
            self.zflash[i] = 0
            self.zspiked[i] = False
            return True
        return False

    def n_alive(self):
        return sum(1 for a in self.alive if a)

    def zombies(self):
        sd = spike_dmg(self.lvl[D_SPIKES])
        wp = wire_slow(self.lvl[D_WIRE])
        pl = plating(self.lvl[D_PLATING])
        for i in range(ZMAX):
            if not self.alive[i]:
                continue
            if self.zflash[i] > 0:
                self.zflash[i] -= 1
            t = self.zt[i]
            stop = WX_SPIT if t == Z_SPITTER else 0
            if self.zx[i] > stop:
                sp = Z_SPEED[t] * self.wv["spPct"] // 100
                if self.zx[i] < WX_WIRE:
                    sp = sp * wp // 100
                self.zx[i] -= max(4, sp)
                if not self.zspiked[i] and sd > 0 and self.zx[i] <= WX_SPIKES:
                    self.zspiked[i] = True
                    self.damage(i, self.jitter(sd))
                    if not self.alive[i]:
                        continue
                self.zx[i] = max(stop, self.zx[i])
                continue
            self.zbite[i] -= 1
            if self.zbite[i] > 0:
                continue
            self.zbite[i] = Z_BITE[t]
            tgt = self.bite_target(self.zl[i])
            if tgt < 0:
                continue
            self.hit_wall(tgt, self.jitter(max(1, Z_DMG[t] - pl)))

    def bite_target(self, lane):
        if self.wall[lane] > 0:
            return lane
        best = -1
        for l in range(LANES):
            if self.wall[l] <= 0:
                continue
            if best < 0 or self.wall[l] < self.wall[best]:
                best = l
        return best

    def hit_wall(self, lane, dmg):
        self.wall[lane] -= dmg
        if self.wall[lane] <= 0:
            self.wall[lane] = 0
            if all(w <= 0 for w in self.wall):
                self.state = 2

    def turrets(self):
        lvl = self.lvl
        reach = FOG_RANGE if self.mod == MOD_FOG else WX_SPAWN + 1000
        if mg_dmg(lvl[D_MG]) > 0:
            self.mgT -= 1
            if self.mgT <= 0:
                m = self.nearest(reach)
                if m >= 0:
                    self.mgT = mg_rate(lvl[D_MG])
                    self.damage(m, self.jitter(mg_dmg(lvl[D_MG])))
        if mortar_dmg(lvl[D_MORTAR]) > 0:
            self.morT -= 1
            if self.morT <= 0:
                b = self.toughest(reach)
                if b >= 0:
                    self.morT = mortar_rate(lvl[D_MORTAR])
                    lane = self.zl[b]
                    d = mortar_dmg(lvl[D_MORTAR])
                    self.damage(b, self.jitter(d))
                    for i in range(ZMAX):
                        if self.alive[i] and i != b and self.zl[i] == lane:
                            self.damage(i, self.jitter(d // 2))
        if tesla_dmg(lvl[D_TESLA]) > 0:
            self.tesT -= 1
            if self.tesT <= 0:
                hit = 0
                chain = tesla_chain(lvl[D_TESLA])
                for _ in range(ZMAX):
                    if hit >= chain:
                        break
                    n = self.nearest(reach, skip_flashed=True)
                    if n < 0:
                        break
                    self.damage(n, self.jitter(tesla_dmg(lvl[D_TESLA])))
                    self.zflash[n] = 2
                    hit += 1
                if hit:
                    self.tesT = tesla_rate(lvl[D_TESLA])

    def nearest(self, reach, skip_flashed=False):
        best = -1
        for i in range(ZMAX):
            if not self.alive[i] or self.zx[i] > reach:
                continue
            if skip_flashed and self.zflash[i] > 0:
                continue
            if best < 0 or self.zx[i] < self.zx[best]:
                best = i
        return best

    def toughest(self, reach):
        best = -1
        for i in range(ZMAX):
            if not self.alive[i] or self.zx[i] > reach:
                continue
            if best < 0 or self.zhp[i] > self.zhp[best]:
                best = i
        return best

    def damage(self, i, dmg):
        self.zhp[i] -= max(1, dmg - Z_ARMOR[self.zt[i]])
        self.zflash[i] = 2
        if self.zhp[i] <= 0:
            self.alive[i] = False
            self.kills += 1
            s = Z_SCRAP[self.zt[i]]
            if self.mod == MOD_BLOOD:
                s = s * 130 // 100
            self.scrap += s

    def wall_pct(self):
        cur, mx = sum(self.wall), sum(self.wall_max)
        return cur * 100 // mx if mx else 0


# ── Player model ───────────────────────────────────────────────────────────
# A plausible daily income: the cap is 400 scrap from steps plus up to 200
# from active minutes. "Casual" walks enough for half the cap; "keen" hits it.
INCOME = {"casual": 260, "keen": 600}

# What a sensible player buys next, in priority order, given what a loss
# tends to be caused by. Nothing clever — just not obviously stupid.
PRIORITY = [D_MG, D_SPIKES, D_WALL, D_MG, D_MORTAR, D_WALL, D_MG, D_REPAIR,
            D_TESLA, D_SALVAGE, D_WIRE, D_PLATING, D_GATE]


def autobuy(lvl, scrap):
    """Spend greedily down the priority list, cheapest useful thing first."""
    changed = True
    while changed:
        changed = False
        for d in PRIORITY:
            if lvl[d] >= D_LVL_MAX:
                continue
            c = dcost(d, lvl[d])
            if scrap >= c:
                scrap -= c
                lvl[d] += 1
                changed = True
                break
    return scrap


def simulate_player(days, income, verbose=False):
    lvl = [0] * D_N
    lvl[D_MG] = 1
    scrap = 0
    night = 1
    wall_pct = 100
    log = []
    for day in range(1, days + 1):
        scrap += income * salvage(lvl[D_SALVAGE]) // 100
        scrap = autobuy(lvl, scrap)
        s = Sim(lvl, night, wall_pct).run()
        won = s.state == 1
        gain = s.scrap * salvage(lvl[D_SALVAGE]) // 100
        if not won:
            gain = gain * 60 // 100
        scrap += gain
        if won:
            wall_pct = min(100, max(25, s.wall_pct()
                           + (100 - s.wall_pct()) * repair_pct(lvl[D_REPAIR]) // 100))
            night += 1
        else:
            wall_pct = min(100, 45 + repair_pct(lvl[D_REPAIR]) // 2)
        log.append((day, night - (1 if won else 0), won, s.kills, s.total,
                    s.wall_pct(), scrap, s.tick_n, sum(lvl)))
        if verbose:
            print(f"  day {day:3d}  night {log[-1][1]:3d}  "
                  f"{'HELD ' if won else 'LOST '} "
                  f"{s.kills:3d}/{s.total:3d}  wall {s.wall_pct():3d}%  "
                  f"scrap {scrap:5d}")
    return night - 1, log


def main():
    print("=" * 68)
    print("Fixed-loadout sweep — can a night be beaten at all?")
    print("=" * 68)
    print(f"{'night':>5} {'count':>6} {'hp%':>6} {'mod':>6} {'starter':>15} {'mid':>15} {'strong':>15}")
    starter = [0] * D_N; starter[D_MG] = 1
    mid = [0] * D_N
    mid[D_MG], mid[D_WALL], mid[D_SPIKES], mid[D_MORTAR] = 5, 4, 3, 2
    strong = [0] * D_N
    strong = [15] * D_N
    names = ["-", "FOG", "RAGE", "HORDE", "BLOOD"]
    for n in range(1, 31):
        row = []
        for lvl in (starter, mid, strong):
            wins = sum(1 for _ in range(1) if Sim(list(lvl), n).run().state == 1)
            s = Sim(list(lvl), n).run()
            row.append(f"{'HELD' if s.state == 1 else 'lost'} {s.wall_pct():3d}% {s.tick_n:4d}t")
        wv = build(n, seed_for(n))
        print(f"{n:>5} {wv['count']:>6} {wv['hpPct']:>6} {names[wv['mod']]:>6} "
              f"{row[0]:>15} {row[1]:>15} {row[2]:>15}")

    for profile, income in INCOME.items():
        print()
        print("=" * 68)
        print(f"90 days as a {profile} walker ({income} scrap/day)")
        print("=" * 68)
        reached, log = simulate_player(90, income)
        wins = sum(1 for e in log if e[2])
        print(f"  reached night {reached}, held {wins}/90 nights, "
              f"lost {90 - wins}")
        for e in log[:12] + [None] + log[-8:]:
            if e is None:
                print("   ...")
                continue
            d, n, won, k, tot, wp, sc, tk, lv = e
            print(f"  day {d:3d}  night {n:3d}  {'HELD' if won else 'lost'}  "
                  f"{k:3d}/{tot:3d}  wall {wp:3d}%  scrap {sc:6d}  "
                  f"{tk:4d}t  lvls {lv:3d}")


if __name__ == "__main__":
    main()
