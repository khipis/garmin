#!/usr/bin/env python3
"""
assemble_submit.py
──────────────────────────────────────────────────────────────────────────────
Assembles a ready-to-upload _SUBMIT/ folder for all Garmin Connect IQ apps.

Each app gets its own subfolder:
  _SUBMIT/{app}/
    {app}.iq           ← store package (upload to Connect IQ Developer Portal)
    {app}.prg          ← simulator / sideload build
    store_icon.png     ← 200×200 icon (resized from launcher_icon.png)
    screenshot_1.png   ← hero image (1440×720 promo / screenshot)
    title.txt          ← store title, plain text, ≤50 chars
    description.txt    ← store description, plain text (markdown stripped)
    UPLOAD.md          ← per-app checklist with direct instructions

_SUBMIT/INDEX.md       ← master table of all apps with status
"""

import os
import re
import shutil
from pathlib import Path

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("⚠  Pillow not installed — store_icon.png will be copied as-is (40×40)")

ROOT   = Path(__file__).parent
STORE  = ROOT / "_STORE"
PROD   = ROOT / "_PROD"
LOGOS  = ROOT / "_LOGOS"
SUBMIT = ROOT / "_SUBMIT"

# ── App registry ──────────────────────────────────────────────────────────────
# category: 'game' | 'tool' | 'fitness'
APPS = [
    # Games
    dict(id="8ball",               category="game"),
    dict(id="arcade",              category="game"),
    dict(id="blobs",               category="game"),
    dict(id="blocks",              category="game"),
    dict(id="bomb",                category="game"),
    dict(id="bricks",              category="game"),
    dict(id="catapult",            category="game"),
    dict(id="checkers",            category="game"),
    dict(id="chess",               category="game"),
    dict(id="dungeon",             category="game"),
    dict(id="fish",                category="game"),
    dict(id="jazzball",            category="game"),
    dict(id="minigolf",            category="game"),
    dict(id="moon",                category="game"),
    dict(id="parachute",           category="game"),
    dict(id="pets",                category="game"),
    dict(id="blackjack",           category="game"),
    dict(id="poker",               category="game"),
    dict(id="run",                 category="game"),
    dict(id="serpent",             category="game"),
    dict(id="skijump",             category="game"),
    dict(id="solitare",            category="game"),
    # Fitness / timers
    dict(id="angrypomodoro",       category="fitness"),
    dict(id="boxing",              category="fitness"),
    dict(id="intervalbeeper",      category="fitness"),
    dict(id="meetingescape",       category="fitness"),
    dict(id="timer",               category="fitness"),
    # Dive / planning tools
    dict(id="boatmodediveplanner", category="tool"),
    dict(id="breathinggascontrol", category="tool"),
    dict(id="diveplantoolkit",     category="tool"),
    dict(id="diveriskindicator",   category="tool"),
    dict(id="quickdivecalculator", category="tool"),
    dict(id="recoverytimer",       category="tool"),
    # ADHD tools
    dict(id="adhddecider",               category="fitness"),
    dict(id="bodycheck",                 category="fitness"),
    dict(id="fakenotificationescape",    category="tool"),
]

# ── Helpers ───────────────────────────────────────────────────────────────────

def strip_markdown(text: str) -> str:
    """Remove common markdown syntax, keeping plain readable text."""
    # Remove code fences
    text = re.sub(r"```.*?```", "", text, flags=re.DOTALL)
    # Remove headings
    text = re.sub(r"^#{1,6}\s+", "", text, flags=re.MULTILINE)
    # Remove bold/italic
    text = re.sub(r"\*{1,3}(.+?)\*{1,3}", r"\1", text)
    text = re.sub(r"_{1,3}(.+?)_{1,3}", r"\1", text)
    # Remove inline code
    text = re.sub(r"`(.+?)`", r"\1", text)
    # Remove links [text](url) → text
    text = re.sub(r"\[(.+?)\]\(.+?\)", r"\1", text)
    # Remove horizontal rules
    text = re.sub(r"^[-_*]{3,}\s*$", "", text, flags=re.MULTILINE)
    # Remove blockquotes
    text = re.sub(r"^>\s+", "", text, flags=re.MULTILINE)
    # Collapse 3+ blank lines to 2
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def extract_title(md: str) -> str:
    """Extract first bold **title** or first non-heading non-empty line."""
    # bold text **...**
    m = re.search(r"\*\*(.+?)\*\*", md)
    if m:
        return m.group(1).strip()
    # First non-empty, non-heading line
    for line in md.splitlines():
        line = line.strip().lstrip("#").strip()
        if line and not line.startswith(">") and "Character count" not in line:
            return line
    return "Unknown"


def make_store_icon(src: Path, dst: Path, size: int = 200):
    """Resize launcher_icon.png to 200×200 for the store listing."""
    if not src.exists():
        return False
    if HAS_PIL:
        try:
            img = Image.open(src).convert("RGBA")
            # Scale up using nearest-neighbor (preserves pixel art look)
            img = img.resize((size, size), Image.NEAREST)
            # Place on white background for the store
            bg = Image.new("RGBA", (size, size), (255, 255, 255, 255))
            bg.paste(img, (0, 0), img)
            bg.convert("RGB").save(dst)
            return True
        except Exception as e:
            print(f"  ⚠  PIL resize failed for {src}: {e}")
    # Fallback: just copy
    shutil.copy2(src, dst)
    return True


def make_upload_md(app_id: str, title: str, category: str,
                   has_iq: bool, has_prg: bool, has_icon: bool,
                   has_hero: bool) -> str:
    checks = {
        "iq":          ("✅" if has_iq    else "❌") + f"  `{app_id}.iq` — upload this to Connect IQ Developer Portal",
        "prg":         ("✅" if has_prg   else "❌") + f"  `{app_id}.prg` — test in Garmin Simulator",
        "store_icon":  ("✅" if has_icon  else "❌") + "  `store_icon.png` (200×200) — App Icon field",
        "screenshot":  ("✅" if has_hero  else "❌") + "  `screenshot_1.png` — Screenshots section (up to 5)",
        "title":       "✅  `title.txt` — App Name field (≤50 chars)",
        "description": "✅  `description.txt` — Description field",
    }
    lines = [
        f"# Upload Checklist — {title}",
        "",
        f"**Category:** {category}  ",
        f"**App ID (folder):** `{app_id}`",
        "",
        "## Connect IQ Developer Portal — upload order",
        "",
        "1. Go to https://developer.garmin.com/connect-iq/developer-portal/",
        "2. Click **Add App** (or open your existing app draft)",
        "3. Upload the `.iq` file (file tab)",
        "4. Fill in **App Name** from `title.txt`",
        "5. Paste **Description** from `description.txt`",
        "6. Upload **App Icon** from `store_icon.png`",
        "7. Upload **Screenshot** from `screenshot_1.png`",
        "8. Set category: " + category,
        "",
        "## Files",
        "",
    ]
    for v in checks.values():
        lines.append(f"- {v}")
    return "\n".join(lines) + "\n"


# ── Main assembly ─────────────────────────────────────────────────────────────

def main():
    SUBMIT.mkdir(exist_ok=True)
    rows = []  # for INDEX.md

    for app in APPS:
        app_id   = app["id"]
        category = app["category"]
        app_dir  = ROOT / app_id
        out_dir  = SUBMIT / app_id
        out_dir.mkdir(exist_ok=True)

        print(f"\n▶  {app_id}")

        status = {}

        # ── .iq ──────────────────────────────────────────────────────────────
        iq_src = STORE / f"{app_id}.iq"
        if iq_src.exists():
            shutil.copy2(iq_src, out_dir / f"{app_id}.iq")
            status["iq"] = "✅"
            print(f"   iq       → {app_id}.iq")
        else:
            status["iq"] = "❌"
            print(f"   iq       ❌ not found")

        # ── .prg ─────────────────────────────────────────────────────────────
        prg_src = PROD / f"{app_id}.prg"
        if prg_src.exists():
            shutil.copy2(prg_src, out_dir / f"{app_id}.prg")
            status["prg"] = "✅"
            print(f"   prg      → {app_id}.prg")
        else:
            status["prg"] = "❌"
            print(f"   prg      ❌ not found")

        # ── Launcher icon → 200×200 store icon ───────────────────────────────
        icon_src = app_dir / "resources" / "launcher_icon.png"
        icon_dst = out_dir / "store_icon.png"
        if make_store_icon(icon_src, icon_dst):
            status["icon"] = "✅"
            print(f"   icon     → store_icon.png (200×200)")
        else:
            status["icon"] = "❌"
            print(f"   icon     ❌ launcher_icon.png not found")

        # ── Hero image → screenshot ───────────────────────────────────────────
        # Look in _LOGOS/{app_id}_hero.png or _LOGOS/{app_id}/{app_id}_hero.png
        hero_candidates = [
            LOGOS / f"{app_id}_hero.png",
            LOGOS / app_id / f"{app_id}_hero.png",
        ]
        hero_found = False
        for hc in hero_candidates:
            if hc.exists():
                shutil.copy2(hc, out_dir / "screenshot_1.png")
                status["hero"] = "✅"
                print(f"   hero     → screenshot_1.png")
                hero_found = True
                break
        if not hero_found:
            status["hero"] = "❌"
            print(f"   hero     ❌ hero image not found in _LOGOS/")

        # ── Title ─────────────────────────────────────────────────────────────
        title_md = app_dir / "title.md"
        if title_md.exists():
            raw   = title_md.read_text(encoding="utf-8")
            title = extract_title(raw)
            (out_dir / "title.txt").write_text(title + "\n", encoding="utf-8")
            char_count = len(title)
            flag = "✅" if char_count <= 50 else "⚠ OVER 50"
            print(f"   title    → \"{title}\" ({char_count} chars) {flag}")
        else:
            title = app_id
            (out_dir / "title.txt").write_text(title + "\n", encoding="utf-8")
            status["title"] = "⚠"
            print(f"   title    ⚠  title.md missing — used app ID as placeholder")

        # ── Description ───────────────────────────────────────────────────────
        desc_md = app_dir / "description.md"
        if desc_md.exists():
            raw  = desc_md.read_text(encoding="utf-8")
            desc = strip_markdown(raw)
            (out_dir / "description.txt").write_text(desc + "\n", encoding="utf-8")
            print(f"   desc     → description.txt ({len(desc)} chars)")
        else:
            (out_dir / "description.txt").write_text("Description pending.\n", encoding="utf-8")
            print(f"   desc     ⚠  description.md missing")

        # ── Per-app UPLOAD.md ─────────────────────────────────────────────────
        upload_md = make_upload_md(
            app_id, title, category,
            has_iq   = status.get("iq")   == "✅",
            has_prg  = status.get("prg")  == "✅",
            has_icon = status.get("icon") == "✅",
            has_hero = status.get("hero") == "✅",
        )
        (out_dir / "UPLOAD.md").write_text(upload_md, encoding="utf-8")

        # Collect for INDEX
        rows.append({
            "id":       app_id,
            "title":    title,
            "category": category,
            "iq":       status.get("iq",   "❌"),
            "prg":      status.get("prg",  "❌"),
            "icon":     status.get("icon", "❌"),
            "hero":     status.get("hero", "❌"),
        })

    # ── INDEX.md ──────────────────────────────────────────────────────────────
    index_lines = [
        "# Garmin Connect IQ — Store Submission Index",
        "",
        "Auto-generated by `assemble_submit.py`.  ",
        "Each app folder contains: `.iq` · `.prg` · `store_icon.png` · `screenshot_1.png` · `title.txt` · `description.txt` · `UPLOAD.md`",
        "",
        "## Legend",
        "✅ ready  ❌ missing  ⚠ needs review",
        "",
        "## Apps by Category",
        "",
    ]

    for cat_name, cat_key in [("🎮 Games", "game"), ("💪 Fitness / Timers", "fitness"), ("🤿 Dive / Planning Tools", "tool")]:
        index_lines.append(f"### {cat_name}")
        index_lines.append("")
        index_lines.append("| App folder | Store Title | .iq | .prg | Icon | Screenshot |")
        index_lines.append("|---|---|:---:|:---:|:---:|:---:|")
        for r in rows:
            if r["category"] == cat_key:
                index_lines.append(f"| `{r['id']}` | {r['title']} | {r['iq']} | {r['prg']} | {r['icon']} | {r['hero']} |")
        index_lines.append("")

    index_lines += [
        "## Upload Instructions",
        "",
        "1. Open the Connect IQ Developer Portal: https://developer.garmin.com/connect-iq/developer-portal/",
        "2. For each app, open its `_SUBMIT/{app}/UPLOAD.md` for step-by-step instructions.",
        "3. Upload `.iq` → fill title → paste description → upload icon → upload screenshot.",
        "",
        "## Rebuild",
        "",
        "To rebuild all packages and re-assemble:",
        "```bash",
        "cd /path/to/garmin",
        "python3 assemble_submit.py",
        "```",
    ]

    (SUBMIT / "INDEX.md").write_text("\n".join(index_lines) + "\n", encoding="utf-8")
    print(f"\n✅  INDEX.md written")
    print(f"✅  _SUBMIT/ assembled at {SUBMIT}")
    print(f"    {len(rows)} apps processed")


if __name__ == "__main__":
    main()
