#!/usr/bin/env node
// Downloads real Connect IQ store screenshots (genuine in-app captures) for
// each configured game via the same public endpoint bitochi.com uses.
// Writes to assets/shots/<game>/NN.jpg and a manifest.json with store meta.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const API = "https://api.bitochi.com/ciq?app=";
const games = JSON.parse(fs.readFileSync(path.join(HERE, "games.json"), "utf8"));

async function getJson(url) {
  const c = new AbortController();
  const t = setTimeout(() => c.abort(), 20000);
  try {
    const r = await fetch(url, { signal: c.signal, cache: "no-store" });
    if (!r.ok) return null;
    return await r.json();
  } catch { return null; } finally { clearTimeout(t); }
}

async function download(url, dest) {
  const c = new AbortController();
  const t = setTimeout(() => c.abort(), 30000);
  try {
    const r = await fetch(url, { signal: c.signal });
    if (!r.ok) return false;
    const buf = Buffer.from(await r.arrayBuffer());
    fs.writeFileSync(dest, buf);
    return buf.length > 1000;
  } catch { return false; } finally { clearTimeout(t); }
}

const manifest = {};
for (const [slug, cfg] of Object.entries(games)) {
  let picked = null;
  for (const id of cfg.store) {
    const d = await getJson(API + id);
    if (d && Array.isArray(d.shots) && d.shots.length) { picked = { id, d }; break; }
    if (d && d.name && !picked) picked = { id, d }; // keep meta even without shots
  }
  const dir = path.join(HERE, "assets", "shots", slug);
  fs.mkdirSync(dir, { recursive: true });
  const rec = { slug, storeId: picked ? picked.id : cfg.store[0], name: null, downloads: 0, rating: 0, reviews: 0, shots: [] };
  if (picked) {
    const d = picked.d;
    rec.name = d.name || null; rec.downloads = d.downloads || 0;
    rec.rating = d.rating || 0; rec.reviews = d.reviews || 0;
    const shots = Array.isArray(d.shots) ? d.shots.filter(Boolean) : [];
    let i = 0;
    for (const url of shots) {
      const dest = path.join(dir, String(i).padStart(2, "0") + ".jpg");
      const ok = await download(url, dest);
      if (ok) { rec.shots.push(path.relative(HERE, dest)); i++; }
    }
  }
  manifest[slug] = rec;
  console.log(`${slug.padEnd(22)} store=${rec.storeId}  name=${rec.name || "?"}  shots=${rec.shots.length}`);
}
fs.writeFileSync(path.join(HERE, "assets", "shots", "manifest.json"), JSON.stringify(manifest, null, 2));
console.log("\nWrote assets/shots/manifest.json");
