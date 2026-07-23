#!/usr/bin/env node
// ═══════════════════════════════════════════════════════════════════════════
// build2.mjs — Bitochi TikTok engine v2: REAL animated gameplay.
//
// Renders vertical 1080x1920 promos where the watch actually PLAYS each game
// (procedural gameplay in engine/arcade.js), advanced by a fixed timestep so
// capture is deterministic + smooth regardless of machine load. Each frame is
// screenshotted via headless Chromium; ffmpeg encodes + adds a music bed.
//
//   node build2.mjs             → build every video
//   node build2.mjs stacktower  → build one by id
// ═══════════════════════════════════════════════════════════════════════════
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const A = (p) => path.join(HERE, p);
const PLAYER = 'file://' + A('engine/player.html');
const AUDIO = A('assets/audio');
const WORK = A('scenes/_v2');
const OUT = A('out');
fs.mkdirSync(WORK, { recursive: true });
fs.mkdirSync(OUT, { recursive: true });

const W = 1080, H = 1920, FPS = 30;
const onlyIds = new Set(process.argv.slice(2));
function ff(args) { execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...args]); }

const NAME = {
  billiards: 'Pocket Billiards', drwal: 'Drwal', fish: 'Fishing Game',
  slotbandit: 'Slot Bandit', stacktower: 'Stack Tower', jumptower: 'Jump Tower',
  eightball: 'Magic 8 Ball', checkers: 'Checkers Pro', blobs: 'Blobs', catapult: 'Catapult Siege',
  sniperscope: 'Sniper Scope', gemmatch: 'Gem Match 3', pets: 'Pixel Pet', skijump: 'Ski Jump',
  creatures: 'Creatures', island: 'Island Life', mines: 'Mines', spacecolony: 'Space Colony',
};
const ACCENT = {
  billiards: '#66FFAA', drwal: '#ff9a3c', fish: '#38b6ff', slotbandit: '#ffd24a',
  stacktower: '#7ad1ff', jumptower: '#9b8cff', eightball: '#b06bff', checkers: '#ff5d73',
  blobs: '#5df08a', catapult: '#ff7a45', breath: '#7CE0C8',
  sniperscope: '#8be08b', gemmatch: '#c07bff', pets: '#ff9ecb', skijump: '#7ad1ff',
  creatures: '#ff9a3c', island: '#38b6ff', mines: '#ffd24a', spacecolony: '#9b8cff',
};

// Games whose shots are already circular product-crops (black corners) — do NOT
// chroma-key them (keying white would punch holes through clouds/text/UI).
const RAW_SHOTS = new Set(['creatures', 'island', 'mines', 'spacecolony']);

// ── real-screenshot "proof" scene: authenticity beat using actual device shots ─
function keyedShot(game, idx) {
  const dir = A(`assets/shots/${game}`);
  if (!fs.existsSync(dir)) return null;
  const files = fs.readdirSync(dir).filter((f) => /\.(jpe?g|png)$/i.test(f)).sort();
  if (!files.length) return null;
  const shotFile = path.join(dir, files[idx % files.length]);
  if (RAW_SHOTS.has(game)) return shotFile; // already a clean circular watch crop
  const out = path.join(WORK, `key_${game}_${idx}.png`);
  if (!fs.existsSync(out)) {
    try { ff(['-i', shotFile, '-vf', 'colorkey=0xffffff:0.15:0.06', out]); } catch (e) { return null; }
  }
  return out;
}
function toDataURI(file) { return `data:image/png;base64,${fs.readFileSync(file).toString('base64')}`; }
function proofImagesFor(games) {
  // games: array of { game, idx } pairs, one real shot each, in order
  const out = [];
  for (const g of games) { const f = keyedShot(g.game, g.idx || 0); if (f) out.push(toDataURI(f)); }
  return out;
}
function proofScene(game, accent, sub, n) {
  const games = []; for (let i = 0; i < (n || 2); i++) games.push({ game, idx: i });
  const images = proofImagesFor(games);
  if (!images.length) return null;
  return { type: 'proof', dur: images.length > 1 ? 2.6 : 1.9, images, text: { accent, sub: sub || 'Real screenshots \u2014 actual watch gameplay' } };
}
function proofSceneMulti(games, accent, sub) {
  const images = proofImagesFor(games.map((g) => ({ game: g, idx: 0 })));
  if (!images.length) return null;
  return { type: 'proof', dur: images.length * 1.15, images, text: { accent, sub: sub || 'Real screenshots \u2014 actual watch gameplay' } };
}

// Load every real screenshot for a game as data-URIs (chroma-keyed when possible).
function allShotURIs(game) {
  const dir = A(`assets/shots/${game}`);
  if (!fs.existsSync(dir)) return [];
  const files = fs.readdirSync(dir).filter((f) => /\.(jpe?g|png)$/i.test(f)).sort();
  return files.map((_, idx) => {
    const keyed = keyedShot(game, idx);
    return toDataURI(keyed || path.join(dir, files[idx]));
  });
}

// ── individual top-game video ───────────────────────────────────────────────
function topGame(game, storeName, beats, music) {
  const acc = ACCENT[game];
  const scenes = [];
  scenes.push({ type: 'card', dur: 2.2, card: { kicker: 'RUNS ON YOUR GARMIN WATCH', title: storeName.toUpperCase(), accent: acc, game, note: 'real gameplay — no phone needed' } });
  beats.forEach((b) => scenes.push({ type: 'play', game, dur: 2.6, text: { accent: acc, hook: b.hook, hook2: b.hook2, sub: b.sub, tag: b.tag } }));
  scenes.push({ type: 'site', dur: 2.6, text: { accent: acc, sub: 'bitochi.com — 60+ games, one leaderboard' } });
  const proof = proofScene(game, acc, 'Real screenshots — actual watch gameplay');
  if (proof) scenes.push(proof);
  scenes.push({ type: 'card', dur: 2.6, card: { kicker: 'PLAY FREE TODAY', title: 'SEARCH', title2: '"' + storeName + '"', accent: acc, chips: ['60+ GAMES', 'IQ STORE', 'bitochi.com'], note: 'Works on most Garmin watches' } });
  return { id: game, music: music || 'bed_energetic', scenes };
}

// Idle / screenshot-driven video: floating REAL watch captures + hooks (no arcade.js).
// shots[0] is always the full "overview" frame (whole colony / mine / island /
// creature world) — we lead and close on it so the best gameplay is unmissable.
function shotTopGame(game, storeName, beats, music) {
  const acc = ACCENT[game];
  const shots = allShotURIs(game);
  if (!shots.length) throw new Error(`no screenshots for ${game} — stage assets/shots/${game}/ first`);
  const overview = shots[0];
  const scenes = [];
  scenes.push({
    type: 'card', dur: 2.0,
    images: [overview],
    card: { kicker: 'NEW IDLE GAME ON GARMIN', title: storeName.toUpperCase(), accent: acc, images: [overview], note: 'real gameplay — grows while you live' },
  });
  // Hero overview beat first — held longer so the whole world is the star.
  scenes.push({
    type: 'proof', dur: 3.4, images: [overview],
    text: { accent: acc, hook: beats[0].hook, hook2: beats[0].hook2, sub: beats[0].sub, tag: beats[0].tag },
  });
  // Remaining beats each cycle a couple of real frames.
  beats.slice(1).forEach((b, i) => {
    const a = shots[(i + 1) % shots.length];
    const bb = shots[(i + 2) % shots.length];
    scenes.push({
      type: 'proof', dur: 2.8, images: [a, bb],
      text: { accent: acc, hook: b.hook, hook2: b.hook2, sub: b.sub, tag: b.tag },
    });
  });
  scenes.push({ type: 'site', dur: 2.4, text: { accent: acc, sub: 'bitochi.com — global idle leaderboards' } });
  // Closing montage across every real frame (overview leads again).
  scenes.push({ type: 'proof', dur: shots.length * 1.0, images: shots, text: { accent: acc, sub: 'Real screenshots — actual watch gameplay' } });
  scenes.push({ type: 'card', dur: 2.6, card: { kicker: 'PLAY FREE TODAY', title: 'SEARCH', title2: '"' + storeName + '"', accent: acc, chips: ['IDLE', 'IQ STORE', 'bitochi.com'], note: 'Works on most Garmin watches' } });
  return { id: game, music: music || 'bed_arcade', scenes };
}

const VIDEOS = [];

VIDEOS.push(topGame('billiards', 'Pocket Billiards', [
  { hook: 'REAL', hook2: 'PHYSICS', sub: 'True ball physics on your wrist', tag: 'AIM · POWER · POT' },
  { hook: 'BEAT', hook2: 'THE AI', sub: '8-ball, 9-ball & snooker', tag: 'VS AI OR FRIEND' },
  { hook: 'CLEAR', hook2: 'THE RACK', sub: 'Sink every ball to win', tag: 'ARCADE MODE' },
]));
VIDEOS.push(topGame('drwal', 'Drwal', [
  { hook: 'CHOP', hook2: 'FAST', sub: 'Swap sides, dodge branches', tag: 'REFLEX ARCADE' },
  { hook: 'DON\u2019T', hook2: 'GET CRUSHED', sub: 'One wrong move and it\u2019s over', tag: 'HOW HIGH?' },
  { hook: 'DAILY', hook2: 'STREAKS', sub: 'Unlock axes, climb the ranks', tag: 'NEW: PROGRESSION' },
], 'bed_arcade'));
VIDEOS.push(topGame('fish', 'Fishing Game', [
  { hook: 'CAST', hook2: '& REEL', sub: 'Time the bite, land the catch', tag: 'RELAXING' },
  { hook: 'CATCH', hook2: 'THEM ALL', sub: 'Fill the Fishdex collection', tag: 'NEW: COLLECTION' },
  { hook: 'UPGRADE', hook2: 'YOUR GEAR', sub: 'Better rods, bigger fish', tag: 'PROGRESSION' },
]));
VIDEOS.push(topGame('slotbandit', 'Slot Bandit', [
  { hook: 'SPIN', hook2: 'TO WIN', sub: 'Jackpots right on your watch', tag: 'CASINO' },
  { hook: 'DAILY', hook2: 'BONUS', sub: 'Free spins + login streaks', tag: 'NEW: META' },
  { hook: 'HIT', hook2: 'THE JACKPOT', sub: 'Line up the 7s', tag: 'BIG WINS' },
], 'bed_arcade'));
VIDEOS.push(topGame('stacktower', 'Stack Tower', [
  { hook: 'DROP', hook2: '& STACK', sub: 'Perfect timing = perfect tower', tag: 'ONE TAP' },
  { hook: 'GO', hook2: 'SUPERFAST', sub: 'A blistering new speed mode', tag: 'NEW MODE' },
  { hook: 'BUILD', hook2: 'TO THE SKY', sub: 'How high can you climb?', tag: 'ENDLESS' },
]));
VIDEOS.push(topGame('sniperscope', 'Sniper Scope', [
  { hook: 'HOLD', hook2: 'YOUR BREATH', sub: 'Steady the scope, line up the shot', tag: 'PRECISION' },
  { hook: 'FIVE', hook2: 'ROUNDS', sub: 'Score big before time runs out', tag: 'ELITE MISSION' },
  { hook: 'NAIL', hook2: 'THE SHOT', sub: 'Wind, breathing, timing — all matter', tag: 'SKILL BASED' },
], 'bed_arcade'));
VIDEOS.push(topGame('gemmatch', 'Gem Match 3', [
  { hook: 'SWAP', hook2: '& MATCH', sub: 'Line up 3+ gems to clear the board', tag: 'CLASSIC PUZZLE' },
  { hook: 'CHAIN', hook2: 'COMBOS', sub: 'Cascades score huge multipliers', tag: 'CASCADE BONUS' },
  { hook: 'BEAT', hook2: 'YOUR BEST', sub: 'Climb the global puzzle leaderboard', tag: 'DAILY BOARD' },
]));
VIDEOS.push(topGame('pets', 'Pixel Pet', [
  { hook: 'RAISE', hook2: 'YOUR PET', sub: 'Feed, play & watch it grow on your wrist', tag: 'VIRTUAL PET' },
  { hook: 'CUTE', hook2: '& CUDDLY', sub: 'A living pixel companion, always with you', tag: 'ADORABLE' },
  { hook: 'NEVER', hook2: 'LET IT DOWN', sub: 'Keep it happy every single day', tag: 'DAILY CARE' },
], 'bed_calm'));
VIDEOS.push(topGame('skijump', 'Ski Jump Classic', [
  { hook: 'LAUNCH', hook2: '& SOAR', sub: 'Nail the takeoff, fly for distance', tag: 'WINTER SPORT' },
  { hook: 'STICK', hook2: 'THE LANDING', sub: 'Balance in the air or wipe out', tag: 'PHYSICS' },
  { hook: 'CHASE', hook2: 'THE RECORD', sub: 'Every meter counts on the leaderboard', tag: 'GLOBAL RANKS' },
], 'bed_energetic'));

// ── four new idle games (real simulator screenshots in the watch bezel) ──────
VIDEOS.push(shotTopGame('creatures', 'Creatures', [
  { hook: 'HATCH', hook2: 'YOUR PET', sub: 'A one-of-a-kind creature from DNA', tag: 'IDLE EVOLUTION' },
  { hook: 'FEED', hook2: '& TRAIN', sub: 'It grows even while you are away', tag: 'OFFLINE PROGRESS' },
  { hook: 'EVOLVE', hook2: 'RARE FORMS', sub: 'Climb the rarity leaderboard', tag: 'GLOBAL RANKS' },
], 'bed_happy'));
VIDEOS.push(shotTopGame('island', 'Island Life', [
  { hook: 'BUILD', hook2: 'PARADISE', sub: 'Turn an empty island into a kingdom', tag: 'COZY IDLE' },
  { hook: 'EARN', hook2: 'OFFLINE', sub: 'Coins, visitors & wonders while away', tag: 'UP TO 24H' },
  { hook: 'MOST', hook2: 'BEAUTIFUL', sub: 'Compete on global island boards', tag: 'LEADERBOARDS' },
], 'bed_happy'));
VIDEOS.push(shotTopGame('mines', 'Bitochi Mines', [
  { hook: 'DIG', hook2: 'DEEPER', sub: 'Idle mining that never stops', tag: 'TYCOON' },
  { hook: 'FIND', hook2: 'LEGENDS', sub: 'Ores, artifacts & mythic treasures', tag: 'DISCOVERY' },
  { hook: 'RICHEST', hook2: 'MINER', sub: 'How deep can you go?', tag: 'GLOBAL RANKS' },
], 'bed_happy'));
VIDEOS.push(shotTopGame('spacecolony', 'Space Colony', [
  { hook: 'COLONIZE', hook2: 'A PLANET', sub: 'Build humanity\'s first outpost', tag: 'SCI-FI IDLE' },
  { hook: 'RESEARCH', hook2: '& EXPAND', sub: 'Resources tick while you live', tag: '24H OFFLINE' },
  { hook: 'GALACTIC', hook2: 'EMPIRE', sub: 'Largest colony on the leaderboard', tag: 'CIV LEVEL' },
], 'bed_happy'));

// ── two "top 10" mix montages ───────────────────────────────────────────────
const MIX = ['billiards', 'drwal', 'fish', 'slotbandit', 'stacktower', 'jumptower', 'eightball', 'checkers', 'blobs', 'catapult'];
const MIX_HOOK = {
  billiards: 'Real pool physics', drwal: 'Frantic chop arcade', fish: 'Catch them all',
  slotbandit: 'Spin the jackpot', stacktower: 'Perfect timing', jumptower: 'Endless climb',
  eightball: 'Ask & reveal', checkers: 'Beat the AI', blobs: 'Artillery mayhem', catapult: 'Siege warfare',
  sniperscope: 'Hold, aim, fire', pets: 'Raise a pixel pet', skijump: 'Launch & soar', gemmatch: 'Match & cascade',
  creatures: 'Hatch & evolve', island: 'Build a paradise', mines: 'Dig for legends', spacecolony: 'Colonize a planet',
};
function mix(id, kicker, order, opts) {
  opts = opts || {};
  const n = order.length;
  const scenes = [];
  scenes.push({ type: 'card', dur: 2.2, card: { kicker, title: opts.title || (n + ' GARMIN'), title2: opts.title2 || 'GAMES', accent: '#66d0ff', chips: ['Free', '60+ Games', 'Leaderboards'], note: opts.note || 'all on your watch — no phone' } });
  order.forEach((g) => {
    if (opts.shots) {
      const all = allShotURIs(g);
      const imgs = [all[0], all[1]].filter(Boolean); // overview first, then one more
      scenes.push({
        type: 'proof', dur: opts.beatDur || 2.0, images: imgs.length ? imgs : all.slice(0, 1),
        text: { accent: ACCENT[g] || '#66d0ff', hook: NAME[g].split(' ')[0].toUpperCase(), sub: MIX_HOOK[g], tag: 'NEW IDLE' },
      });
    } else {
      scenes.push({ type: 'play', game: g, dur: opts.beatDur || 1.5, watchR: 470, watchCy: 760, text: { accent: ACCENT[g] || '#66d0ff', hook: NAME[g].split(' ')[0].toUpperCase(), sub: MIX_HOOK[g] } });
    }
  });
  scenes.push({ type: 'site', dur: 2.2, text: { accent: '#66d0ff', sub: 'bitochi.com — 60+ games in one place' } });
  const proof = proofSceneMulti(order.slice(0, 4), '#66d0ff', 'Real screenshots — actual watch gameplay');
  if (proof) scenes.push(proof);
  scenes.push({ type: 'card', dur: 2.6, card: { kicker: 'GET THEM FREE', title: 'bitochi', title2: '.com', accent: '#66d0ff', chips: ['60+ GAMES', 'IQ STORE'], note: 'The Garmin games platform' } });
  return { id, music: opts.music || 'bed_arcade', scenes };
}
VIDEOS.push(mix('mix_top10', 'TOP 10 · YOU NEED THESE', MIX));
VIDEOS.push(mix('mix_bestmoments', 'BEST MOMENTS', ['catapult', 'blobs', 'billiards', 'drwal', 'stacktower', 'fish', 'jumptower', 'slotbandit', 'checkers', 'eightball']));
VIDEOS.push(mix('mix_newgames', 'JUST ADDED', ['sniperscope', 'pets', 'skijump', 'gemmatch'], {
  title: 'NEW ON', title2: 'BITOCHI', note: 'Part of 60+ free Garmin games',
}));
VIDEOS.push(mix('mix_idle', 'NEW IDLE GAMES', ['creatures', 'island', 'mines', 'spacecolony'], {
  title: 'IDLE ON', title2: 'YOUR WATCH', note: 'Grow while you live · free on Connect IQ',
  shots: true, beatDur: 2.0, music: 'bed_happy',
}));

// ── breath training (calm) ──────────────────────────────────────────────────
{
  const breathScenes = [
    { type: 'card', dur: 2.6, card: { kicker: 'GARMIN CONNECT IQ', title: 'BREATH TRAINING', title2: 'SYSTEM PRO', accent: ACCENT.breath, note: 'CO2 · O2 · dry apnea training' } },
    { type: 'play', game: 'breath', dur: 3.4, text: { accent: ACCENT.breath, hook: 'TRAIN', hook2: 'YOUR BREATH', sub: 'Guided CO2 & O2 tables', tag: 'APNEA COACH' } },
    { type: 'play', game: 'breath', dur: 3.4, text: { accent: ACCENT.breath, hook: 'HOLD', hook2: 'LONGER', sub: 'Live timer + personal bests', tag: 'MEASURE' } },
    { type: 'play', game: 'breath', dur: 3.4, text: { accent: ACCENT.breath, hook: 'BREATHE', hook2: '& RELAX', sub: 'Lower stress, focus deeper', tag: 'WELLNESS' } },
  ];
  const breathProof = proofScene('breathtrainingsystem', ACCENT.breath, 'Real screenshots — actual watch app');
  if (breathProof) breathScenes.push(breathProof);
  breathScenes.push({ type: 'card', dur: 2.8, card: { kicker: 'START TODAY', title: 'SEARCH', title2: '"BREATH TRAINING"', accent: ACCENT.breath, chips: ['60+ GAMES', 'IQ STORE', 'bitochi.com'], note: 'Also home to 60+ free Garmin games' } });
  VIDEOS.push({ id: 'breath', music: 'bed_calm', scenes: breathScenes });
}

// ── render one video: capture frames then encode + music ─────────────────────
async function buildVideo(browser, v) {
  const total = v.scenes.reduce((a, s) => a + s.dur, 0);
  const nFrames = Math.round(total * FPS);
  const frameDir = path.join(WORK, v.id);
  fs.rmSync(frameDir, { recursive: true, force: true }); fs.mkdirSync(frameDir, { recursive: true });

  const ctx = await browser.newContext({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  await page.addInitScript((spec) => { window.SPEC = spec; }, { scenes: v.scenes });
  await page.goto(PLAYER, { waitUntil: 'load' });
  await page.waitForFunction(() => window.__ready === true, { timeout: 15000 });
  await page.evaluate(() => window.__reset && window.__reset());

  const dt = 1 / FPS;
  for (let f = 0; f < nFrames; f++) {
    await page.evaluate((d) => window.__step(d), dt);
    await page.screenshot({ path: path.join(frameDir, `f_${String(f).padStart(5, '0')}.png`), clip: { x: 0, y: 0, width: W, height: H } });
  }
  await ctx.close();

  const music = path.join(AUDIO, `${v.music}.m4a`);
  const out = path.join(OUT, `${v.id}.mp4`);
  ff([
    '-framerate', String(FPS), '-i', path.join(frameDir, 'f_%05d.png'),
    '-stream_loop', '-1', '-i', music,
    '-filter_complex', `[1:a]volume=0.6,afade=t=in:st=0:d=0.5,afade=t=out:st=${(total - 1.0).toFixed(3)}:d=1.0[a]`,
    '-map', '0:v', '-map', '[a]', '-t', total.toFixed(3),
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-preset', 'medium', '-crf', '19',
    '-r', String(FPS), '-c:a', 'aac', '-b:a', '160k', '-movflags', '+faststart', out,
  ]);
  // keep only the mp4; drop frames to save space
  fs.rmSync(frameDir, { recursive: true, force: true });
  console.log(`\u2714 ${v.id}.mp4  (${total.toFixed(1)}s, ${v.scenes.length} scenes, ${nFrames} frames)`);
}

const browser = await chromium.launch({ args: ['--force-color-profile=srgb'] });
try {
  for (const v of VIDEOS) { if (onlyIds.size && !onlyIds.has(v.id)) continue; await buildVideo(browser, v); }
} finally { await browser.close(); }
console.log('done');
