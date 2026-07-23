#!/usr/bin/env node
// Captures live bitochi.com frames (hero + leaderboard) as vertical B-roll for
// the promo videos. Best-effort: failures never abort the pipeline.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, 'assets', 'site');
fs.mkdirSync(OUT, { recursive: true });

const b = await chromium.launch();
const p = await b.newPage({ viewport: { width: 1080, height: 1920 }, deviceScaleFactor: 1 });
try {
  await p.goto('https://bitochi.com', { waitUntil: 'domcontentloaded', timeout: 45000 });
  await p.waitForTimeout(6000); // let leaderboard fetch + render
  await p.screenshot({ path: path.join(OUT, 'top.png') });
  console.log('captured top.png');

  // Try to find and screenshot the leaderboard region.
  const sel = ['#leaderboard', '.leaderboard', 'table', '[class*="leaderboard" i]'];
  for (const s of sel) {
    const el = await p.$(s);
    if (el) {
      await el.scrollIntoViewIfNeeded().catch(() => {});
      await p.waitForTimeout(1500);
      await p.screenshot({ path: path.join(OUT, 'leaderboard.png') });
      console.log('captured leaderboard.png via', s);
      break;
    }
  }
  // Scroll further for a games/preview frame.
  await p.evaluate(() => window.scrollBy(0, 1400));
  await p.waitForTimeout(1500);
  await p.screenshot({ path: path.join(OUT, 'mid.png') });
  console.log('captured mid.png');
} catch (e) {
  console.log('site capture warning:', e.message);
} finally {
  await b.close();
}
console.log('done');
