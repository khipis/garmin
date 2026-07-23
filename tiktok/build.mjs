#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════════════════
// build.mjs — Bitochi TikTok promo video engine.
//
// Composes vertical 1080x1920 promo videos from REAL Connect IQ store gameplay
// screenshots (genuine watch captures), blurred hero art, live bitochi.com
// frames, HTML-rendered captions/cards (headless Chromium), and original
// synth music beds. All motion (Ken Burns, floating watch, xfade transitions)
// is done in ffmpeg. Nothing here uses copyrighted assets.
//
// Usage:
//   node build.mjs            → build every video
//   node build.mjs billiards  → build one video by id
// ═══════════════════════════════════════════════════════════════════════════
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const A = (p) => path.join(HERE, p);
const SHOTS = A('assets/shots');
const HEROES = A('assets/heroes');
const SITE = A('assets/site');
const AUDIO = A('assets/audio');
const WORK = A('scenes/_work');
const OUT = A('out');
fs.mkdirSync(WORK, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });

const W = 1080, H = 1920, FPS = 30, T = 0.4; // transition seconds
const onlyId = process.argv[2] || null;

function ff(args) { execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...args]); }
const dfr = (d) => Math.round(d * FPS);

// Resolve a shot file for a game by index (wraps if fewer shots exist).
function shot(game, i) {
  const dir = path.join(SHOTS, game);
  const files = fs.existsSync(dir) ? fs.readdirSync(dir).filter((f) => f.endsWith('.jpg')).sort() : [];
  if (!files.length) return null;
  return path.join(dir, files[i % files.length]);
}
const hero = (game) => path.join(HEROES, `${game}.png`);

// ── HTML overlay/card rendering (Chromium → PNG) ────────────────────────────
let browser, page;
async function initBrowser() {
  browser = await chromium.launch();
  page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
}
async function shutBrowser() { if (browser) await browser.close(); }

const FONT = `'Arial Black','Helvetica Neue',Arial,sans-serif`;
const FONT2 = `'Inter','Helvetica Neue',Arial,sans-serif`;

function wrap(inner, bg) {
  return `<!doctype html><html><head><meta charset="utf8"><style>
  *{margin:0;padding:0;box-sizing:border-box}
  body{width:${W}px;height:${H}px;background:${bg || 'transparent'};overflow:hidden;font-family:${FONT};-webkit-font-smoothing:antialiased}
  .stroke{-webkit-text-stroke:3px rgba(0,0,0,.55)}
  </style></head><body>${inner}</body></html>`;
}

// Chroma-key the white background out of a watch screenshot → transparent PNG.
function keyedWatch(game, shotFile) {
  const out = path.join(WORK, `key_${game}_${path.basename(shotFile, path.extname(shotFile))}.png`);
  if (!fs.existsSync(out)) {
    ff(['-i', shotFile, '-vf', 'colorkey=0xffffff:0.15:0.06', out]);
  }
  return out;
}

function toDataURI(file) {
  const ext = path.extname(file).slice(1).toLowerCase();
  const mime = ext === 'jpg' || ext === 'jpeg' ? 'image/jpeg' : 'image/png';
  return `data:${mime};base64,${fs.readFileSync(file).toString('base64')}`;
}

async function renderPNG(inner, outPng, opaque) {
  await page.setContent(wrap(inner, opaque ? '#05060a' : 'transparent'));
  await page.evaluate(async () => {
    if (document.fonts && document.fonts.ready) { try { await document.fonts.ready; } catch (e) {} }
    await Promise.all(Array.from(document.images).map((img) => img.complete
      ? Promise.resolve() : new Promise((r) => { img.onload = img.onerror = r; })));
  });
  await page.screenshot({ path: outPng, omitBackground: !opaque });
}

// Transparent lower-third + top hook overlay for a gameplay scene.
function sceneOverlay({ brand = true, hook = '', hook2 = '', accent = '#66FFAA', sub = '', tag = '' }) {
  const brandChip = brand ? `<div style="position:absolute;top:52px;left:0;width:100%;text-align:center">
    <span style="font-family:${FONT2};font-weight:800;letter-spacing:6px;font-size:30px;color:#fff;opacity:.9;text-shadow:0 3px 10px #000">BITOCHI GAMES</span></div>` : '';
  const tagChip = tag ? `<div style="position:absolute;top:360px;left:0;width:100%;text-align:center">
    <span style="display:inline-block;background:${accent};color:#04120a;font-family:${FONT2};font-weight:900;font-size:34px;letter-spacing:2px;padding:12px 26px;border-radius:40px;box-shadow:0 8px 24px rgba(0,0,0,.5)">${tag}</span></div>` : '';
  const hookBlock = (hook || hook2) ? `<div style="position:absolute;top:130px;left:0;width:100%;text-align:center;line-height:.92">
    <div class="stroke" style="font-size:118px;font-weight:900;color:#fff;text-transform:uppercase;text-shadow:0 8px 26px rgba(0,0,0,.85)">${hook}</div>
    ${hook2 ? `<div class="stroke" style="font-size:118px;font-weight:900;color:${accent};text-transform:uppercase;text-shadow:0 8px 26px rgba(0,0,0,.85)">${hook2}</div>` : ''}
  </div>` : '';
  const subPill = sub ? `<div style="position:absolute;bottom:360px;left:0;width:100%;text-align:center">
    <span style="display:inline-block;max-width:960px;background:rgba(6,8,14,.72);color:#fff;font-family:${FONT2};font-weight:700;font-size:46px;padding:18px 34px;border-radius:26px;box-shadow:0 8px 24px rgba(0,0,0,.5)">${sub}</span></div>` : '';
  const water = `<div style="position:absolute;bottom:150px;left:0;width:100%;text-align:center">
    <span style="font-family:${FONT2};font-weight:900;font-size:52px;color:#fff;text-shadow:0 4px 14px #000">bitochi<span style="color:${accent}">.com</span></span>
    <div style="font-family:${FONT2};font-weight:700;font-size:32px;color:#cfd8e6;margin-top:6px;text-shadow:0 3px 10px #000">Free on Garmin Connect IQ</div></div>`;
  return brandChip + hookBlock + tagChip + subPill + water;
}

// Opaque full-frame card (intro / CTA).
function card({ kicker = '', title = '', title2 = '', accent = '#66FFAA', chips = [], watchImg = null, note = '', big = '' }) {
  const bg = `background:radial-gradient(120% 90% at 50% 18%, ${accent}22 0%, #0a0d16 55%, #05060a 100%);`;
  const grid = `background-image:linear-gradient(#ffffff08 1px,transparent 1px),linear-gradient(90deg,#ffffff08 1px,transparent 1px);background-size:60px 60px;`;
  const wimg = watchImg ? `<div style="position:absolute;top:640px;left:0;width:100%;text-align:center">
    <img src="${watchImg}" style="width:760px;filter:drop-shadow(0 30px 60px rgba(0,0,0,.6)) drop-shadow(0 0 40px ${accent}55)"></div>` : '';
  const chipRow = chips.length ? `<div style="position:absolute;bottom:250px;left:0;width:100%;text-align:center">
    ${chips.map((c) => `<span style="display:inline-block;margin:8px 10px;background:#141a28;border:2px solid ${accent}66;color:#eaf0ff;font-family:${FONT2};font-weight:800;font-size:36px;padding:14px 26px;border-radius:40px">${c}</span>`).join('')}</div>` : '';
  const bigBlock = big ? `<div style="position:absolute;top:760px;left:0;width:100%;text-align:center">
    <div class="stroke" style="font-size:150px;font-weight:900;color:${accent};text-transform:uppercase;text-shadow:0 10px 30px rgba(0,0,0,.7)">${big}</div></div>` : '';
  return `<div style="position:absolute;inset:0;${bg}"></div><div style="position:absolute;inset:0;${grid}"></div>
    ${kicker ? `<div style="position:absolute;top:150px;left:0;width:100%;text-align:center"><span style="display:inline-block;background:${accent};color:#04120a;font-family:${FONT2};font-weight:900;font-size:40px;letter-spacing:3px;padding:14px 30px;border-radius:40px">${kicker}</span></div>` : ''}
    <div style="position:absolute;top:280px;left:0;width:100%;text-align:center;line-height:.95;padding:0 40px">
      <div class="stroke" style="font-size:112px;font-weight:900;color:#fff;text-transform:uppercase;text-shadow:0 8px 26px rgba(0,0,0,.7)">${title}</div>
      ${title2 ? `<div class="stroke" style="font-size:112px;font-weight:900;color:${accent};text-transform:uppercase">${title2}</div>` : ''}
    </div>
    ${bigBlock}${wimg}${chipRow}
    ${note ? `<div style="position:absolute;bottom:150px;left:0;width:100%;text-align:center"><span style="font-family:${FONT2};font-weight:700;font-size:40px;color:#dfe7f5;text-shadow:0 3px 10px #000">${note}</span></div>` : ''}`;
}

// ── ffmpeg clip renderers ───────────────────────────────────────────────────
// Gameplay scene: blurred hero bg (Ken Burns) + chroma-keyed floating watch + text overlay.
function clipScene(game, shotFile, textPng, dur, out, opts = {}) {
  const df = dfr(dur);
  const zdir = opts.zoomOut ? `1.16-0.0006*on` : `min(zoom+0.0006,1.16)`;
  const watchW = opts.watchW || 1010;
  const yoff = opts.yoff != null ? opts.yoff : -20;
  const eq = opts.calm ? 'eq=brightness=-0.16:saturation=1.05' : 'eq=brightness=-0.30:saturation=1.45';
  const blur = opts.calm ? 34 : 24;
  const graph =
    `[0:v]scale=1300:2311:force_original_aspect_ratio=increase,crop=1300:2311,boxblur=${blur}:2,${eq},` +
    `zoompan=z='${zdir}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${df}:s=${W}x${H}:fps=${FPS}[bg];` +
    `[1:v]colorkey=0xffffff:0.15:0.06,scale=${watchW}:-1[wch];` +
    `[bg][wch]overlay=x='(W-w)/2':y='(H-h)/2+${yoff}+16*sin(2*PI*t/2.6)':shortest=1[b1];` +
    `[b1][2:v]overlay=0:0:shortest=1,format=yuv420p[out]`;
  ff(['-loop', '1', '-t', String(dur), '-i', hero(game),
      '-loop', '1', '-t', String(dur), '-i', shotFile,
      '-loop', '1', '-t', String(dur), '-i', textPng,
      '-filter_complex', graph, '-map', '[out]', '-r', String(FPS),
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'veryfast', '-crf', '20', out]);
}

// Opaque card with slow zoom.
function clipCard(cardPng, dur, out) {
  const df = dfr(dur);
  const graph = `[0:v]scale=1230:2187,zoompan=z='min(zoom+0.0006,1.12)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${df}:s=${W}x${H}:fps=${FPS},format=yuv420p[out]`;
  ff(['-loop', '1', '-t', String(dur), '-i', cardPng, '-filter_complex', graph,
      '-map', '[out]', '-r', String(FPS), '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'veryfast', '-crf', '20', out]);
}

// Site frame (bitochi.com) as bg (cover + slow zoom) + text overlay.
function clipSite(siteImg, textPng, dur, out) {
  const df = dfr(dur);
  const graph =
    `[0:v]scale=1188:2112:force_original_aspect_ratio=increase,crop=1188:2112,eq=brightness=-0.05:saturation=1.1,` +
    `zoompan=z='min(zoom+0.0006,1.12)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${df}:s=${W}x${H}:fps=${FPS}[bg];` +
    `[bg][1:v]overlay=0:0:shortest=1,format=yuv420p[out]`;
  ff(['-loop', '1', '-t', String(dur), '-i', siteImg,
      '-loop', '1', '-t', String(dur), '-i', textPng,
      '-filter_complex', graph, '-map', '[out]', '-r', String(FPS),
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'veryfast', '-crf', '20', out]);
}

// ── Assembly: xfade chain + music ───────────────────────────────────────────
const TRANS = ['fade', 'wipeleft', 'slideup', 'fade', 'wiperight', 'slidedown', 'fade', 'circlecrop', 'fade', 'wipeup', 'fade'];

function assemble(clips, durs, music, out) {
  const n = clips.length;
  const total = durs.reduce((a, b) => a + b, 0) - (n - 1) * T;
  const inputs = [];
  clips.forEach((c) => { inputs.push('-i', c); });
  let fc = '';
  let cur = `[0:v]`;
  let cum = durs[0];
  for (let i = 1; i < n; i++) {
    const off = (cum - T).toFixed(3);
    const lbl = i === n - 1 ? '[vout]' : `[x${i}]`;
    const tr = TRANS[(i - 1) % TRANS.length];
    fc += `${cur}[${i}:v]xfade=transition=${tr}:duration=${T}:offset=${off}${lbl};`;
    cur = lbl;
    cum = cum + durs[i] - T;
  }
  if (n === 1) { fc = `[0:v]copy[vout];`; }
  // Music: loop bed, trim to total, gentle fades.
  const args = [...inputs, '-stream_loop', '-1', '-i', music,
    '-filter_complex',
    `${fc}[${n}:a]volume=0.55,afade=t=in:st=0:d=0.6,afade=t=out:st=${(total - 1.2).toFixed(3)}:d=1.2[aout]`,
    '-map', '[vout]', '-map', '[aout]', '-t', total.toFixed(3),
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'medium', '-crf', '19',
    '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', out];
  ff(args);
  return total;
}

// ── Video specs ─────────────────────────────────────────────────────────────
const NAME = {
  billiards: 'Pocket Billiards AI', fish: 'Fishing Game', drwal: 'Timber Rush',
  slotbandit: 'Slot Bandit', stacktower: 'Stack Tower', jumptower: 'Jump Tower',
  '8ball': 'Magic 8 Ball', checkers: 'Checkers Pro', blobs: 'Blobs', catapult: 'Catapult Siege',
};
const ACCENT = {
  billiards: '#66FFAA', fish: '#38b6ff', drwal: '#ff9a3c', slotbandit: '#ffd24a',
  stacktower: '#7ad1ff', jumptower: '#9b8cff', '8ball': '#b06bff', checkers: '#ff5d73',
  blobs: '#5df08a', catapult: '#ff7a45',
};

// Individual top-game videos: intro card, 3 gameplay scenes, site/leaderboard scene, CTA card.
function topGameVideo(game, hook, scenes) {
  const acc = ACCENT[game];
  const clips = [];
  clips.push({ type: 'card', dur: 2.6, card: { kicker: 'THIS RUNS ON A GARMIN WATCH', title: NAME[game], accent: acc, watchImg: shot(game, 0), note: 'real gameplay — no phone needed' } });
  scenes.forEach((s, i) => clips.push({ type: 'scene', game, shotIdx: i, dur: 2.9, zoomOut: i % 2 === 1, text: { hook: s.hook, hook2: s.hook2 || '', accent: acc, sub: s.sub, tag: s.tag || '' } }));
  clips.push({ type: 'site', dur: 2.8, text: { brand: false, hook: 'GLOBAL', hook2: 'LEADERBOARD', accent: acc, sub: 'Compete worldwide · daily challenges' } });
  clips.push({ type: 'card', dur: 2.8, card: { kicker: 'PLAY FREE TODAY', title: 'SEARCH', title2: `"${NAME[game]}"`, accent: acc, chips: ['Connect IQ Store', 'bitochi.com'], note: 'Works on most Garmin watches' } });
  return { id: game, music: game === 'slotbandit' ? 'bed_arcade' : 'bed_energetic', clips };
}

const VIDEOS = [
  topGameVideo('billiards', null, [
    { hook: 'REAL', hook2: 'PHYSICS', sub: 'True ball physics on your wrist', tag: 'AIM · POWER · POT' },
    { hook: 'BEAT', hook2: 'THE AI', sub: '3 difficulties + 8-ball, 9-ball, snooker', tag: 'VS AI OR FRIEND' },
    { hook: 'TIME', hook2: 'ATTACK', sub: 'Clear the rack against the clock', tag: 'ARCADE MODE' },
  ]),
  topGameVideo('drwal', null, [
    { hook: 'CHOP', hook2: 'FAST', sub: 'Swap sides, dodge the branches', tag: 'REFLEX ARCADE' },
    { hook: 'DONT', hook2: 'GET CRUSHED', sub: 'One wrong move and it is over', tag: 'HOW HIGH?' },
    { hook: 'DAILY', hook2: 'STREAKS', sub: 'Unlock axes · come back every day', tag: 'NEW: PROGRESSION' },
  ]),
  topGameVideo('fish', null, [
    { hook: 'CAST', hook2: 'REEL', sub: 'Time the bite, land the catch', tag: 'RELAXING' },
    { hook: 'FILL', hook2: 'THE FISHDEX', sub: 'Collect every species', tag: 'NEW: COLLECTION' },
    { hook: 'UPGRADE', hook2: 'YOUR GEAR', sub: 'Better rods, bigger catches', tag: 'PROGRESSION' },
  ]),
  topGameVideo('slotbandit', null, [
    { hook: 'SPIN', hook2: 'TO WIN', sub: 'Jackpots right on your watch', tag: 'CASINO' },
    { hook: 'DAILY', hook2: 'BONUS', sub: 'Free spins + login streaks', tag: 'NEW: META' },
    { hook: 'COLLECT', hook2: 'SYMBOLS', sub: 'Unlock machines as you play', tag: 'PROGRESSION' },
  ]),
  topGameVideo('stacktower', null, [
    { hook: 'DROP', hook2: 'STACK', sub: 'Perfect timing = perfect tower', tag: 'ONE TAP' },
    { hook: 'GO', hook2: 'SUPERFAST', sub: 'A blistering new speed mode', tag: 'NEW MODE' },
    { hook: 'BUILD', hook2: 'TO THE SKY', sub: 'How high can you climb?', tag: 'ENDLESS' },
  ]),
];

// Two "top 10" mix montages — fast highlight reels.
const TOP10 = ['billiards', 'drwal', 'fish', 'slotbandit', 'stacktower', 'jumptower', '8ball', 'checkers', 'blobs', 'catapult'];
function mixVideo(id, kicker, hooks, order) {
  const clips = [];
  clips.push({ type: 'card', dur: 2.6, card: { kicker, title: '10 GARMIN', title2: 'GAMES', accent: '#66d0ff', chips: ['Free', 'Global Leaderboards'], note: 'all on your watch — no phone' } });
  order.forEach((g, i) => clips.push({ type: 'scene', game: g, shotIdx: 0, dur: 2.3, zoomOut: i % 2 === 1, text: { hook: NAME[g].split(' ')[0].toUpperCase(), hook2: '', accent: ACCENT[g] || '#66d0ff', sub: hooks[g] || '', tag: '' } }));
  clips.push({ type: 'site', dur: 2.6, text: { brand: false, hook: 'ONE', hook2: 'LEADERBOARD', accent: '#66d0ff', sub: 'Compete with the world' } });
  clips.push({ type: 'card', dur: 2.8, card: { kicker: 'GET THEM FREE', title: 'bitochi', title2: '.com', accent: '#66d0ff', chips: ['Connect IQ Store'], note: 'Works on most Garmin watches' } });
  return { id, music: 'bed_arcade', clips };
}
const MIX_HOOKS = {
  billiards: 'Real pool physics', drwal: 'Frantic chop arcade', fish: 'Catch them all',
  slotbandit: 'Spin the jackpot', stacktower: 'Perfect timing', jumptower: 'Endless climb',
  '8ball': 'Ask & reveal', checkers: 'Beat the AI', blobs: 'Artillery mayhem', catapult: 'Siege warfare',
};
VIDEOS.push(mixVideo('mix_top10', 'TOP 10 · YOU NEED THESE', MIX_HOOKS, TOP10));
VIDEOS.push(mixVideo('mix_bestmoments', 'BEST MOMENTS', MIX_HOOKS, ['catapult', 'blobs', 'billiards', 'drwal', 'stacktower', 'fish', 'jumptower', 'slotbandit', 'checkers', '8ball']));

// Dedicated calm wellness video for the breath-training app (wide banner shots).
(function breathVideo() {
  const acc = '#7CE0C8';
  const g = 'breathtrainingsystem';
  const clips = [];
  clips.push({ type: 'card', dur: 2.8, card: { kicker: 'GARMIN CONNECT IQ', title: 'BREATH TRAINING', title2: 'SYSTEM PRO', accent: acc, note: 'CO2 · O2 · dry apnea training' } });
  const sc = [
    { shot: 0, hook: 'TRAIN', hook2: 'YOUR BREATH', sub: 'CO2 & O2 tables, guided holds', tag: 'APNEA COACH', watchW: 1050 },
    { shot: 1, hook: 'HOLD', hook2: 'LONGER', sub: 'Live timer + personal best tracking', tag: 'MEASURE', watchW: 980 },
    { shot: 2, hook: 'PICK A', hook2: 'PATH', sub: 'Wim Hof, Pranayama, endurance', tag: 'TRAINING PATHS', watchW: 1050 },
    { shot: 3, hook: 'READINESS', hook2: 'CHECK', sub: 'Breathe calmly, read your state', tag: 'SENSORS', watchW: 1060 },
  ];
  sc.forEach((s, i) => clips.push({ type: 'scene', game: g, shotIdx: s.shot, dur: 3.2, zoomOut: i % 2 === 1, watchW: s.watchW, calm: true, text: { hook: s.hook, hook2: s.hook2, accent: acc, sub: s.sub, tag: s.tag } }));
  clips.push({ type: 'card', dur: 3.0, card: { kicker: 'START TODAY', title: 'SEARCH', title2: '"BREATH TRAINING"', accent: acc, chips: ['Connect IQ Store', 'bitochi.com'], note: 'Works on most Garmin watches' } });
  VIDEOS.push({ id: 'breath', music: 'bed_calm', clips });
})();

// ── Build loop ──────────────────────────────────────────────────────────────
async function buildVideo(v) {
  const clipFiles = [];
  const durs = [];
  for (let i = 0; i < v.clips.length; i++) {
    const c = v.clips[i];
    const base = `${v.id}_${String(i).padStart(2, '0')}`;
    const clipOut = path.join(WORK, `${base}.mp4`);
    if (c.type === 'card') {
      const png = path.join(WORK, `${base}.png`);
      const cc = Object.assign({}, c.card);
      if (cc.watchImg) { cc.watchImg = toDataURI(keyedWatch(c.cardGame || v.id, cc.watchImg)); }
      await renderPNG(card(cc), png, true);
      clipCard(png, c.dur, clipOut);
    } else if (c.type === 'scene') {
      const png = path.join(WORK, `${base}.png`);
      await renderPNG(sceneOverlay(c.text), png, false);
      const sf = shot(c.game, c.shotIdx || 0);
      clipScene(c.game, sf, png, c.dur, clipOut, { zoomOut: c.zoomOut, yoff: c.yoff, watchW: c.watchW, calm: c.calm });
    } else if (c.type === 'site') {
      const png = path.join(WORK, `${base}.png`);
      await renderPNG(sceneOverlay(c.text), png, false);
      const siteImg = fs.existsSync(path.join(SITE, 'top.png')) ? path.join(SITE, 'top.png') : path.join(SITE, 'mid.png');
      clipSite(siteImg, png, c.dur, clipOut);
    }
    clipFiles.push(clipOut);
    durs.push(c.dur);
  }
  const music = path.join(AUDIO, `${v.music}.m4a`);
  const out = path.join(OUT, `${v.id}.mp4`);
  const total = assemble(clipFiles, durs, music, out);
  console.log(`✔ ${v.id}.mp4  (${total.toFixed(1)}s, ${v.clips.length} clips)`);
}

await initBrowser();
try {
  for (const v of VIDEOS) {
    if (onlyId && v.id !== onlyId) continue;
    await buildVideo(v);
  }
} finally {
  await shutBrowser();
}
console.log('done');
