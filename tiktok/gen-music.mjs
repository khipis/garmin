#!/usr/bin/env node
// Generates fully original, license-clean music beds with ffmpeg synthesis.
// Chiptune-style (on brand for pixel watch games) energetic loops + a calm
// ambient pad for the breathing app. No samples, no copyrighted material.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(HERE, "assets", "audio");
const TMP = path.join(OUT, "_tmp");
fs.mkdirSync(TMP, { recursive: true });

function ff(args) { execFileSync("ffmpeg", ["-y", "-loglevel", "error", ...args]); }

// Note frequencies (equal temperament).
const N = {
  C2: 65.41, E2: 82.41, F2: 87.31, G2: 98.0, A2: 110.0,
  C3: 130.81, D3: 146.83, E3: 164.81, F3: 174.61, G3: 196.0, A3: 220.0,
  C4: 261.63, D4: 293.66, E4: 329.63, F4: 349.23, G4: 392.0, A4: 440.0,
  C5: 523.25, D5: 587.33, E5: 659.25, F5: 698.46, G5: 783.99, A5: 880.0,
};

// One synth note → wav. Richer harmonics = chiptune-ish square-ish timbre.
function note(freq, dur, amp, file, square = false) {
  let expr;
  if (freq <= 0) {
    expr = "0"; // rest
  } else if (square) {
    // Pseudo-square: sum of odd harmonics → bright lead.
    expr = `${amp}*(sin(2*PI*${freq}*t)+0.5*sin(2*PI*3*${freq}*t)+0.28*sin(2*PI*5*${freq}*t))`;
  } else {
    expr = `${amp}*(sin(2*PI*${freq}*t)+0.28*sin(2*PI*2*${freq}*t))`;
  }
  const fadeOut = Math.max(0.02, Math.min(0.08, dur * 0.3));
  ff([
    "-f", "lavfi", "-i", `aevalsrc=${expr}:d=${dur}:s=44100`,
    "-af", `afade=t=in:st=0:d=0.008,afade=t=out:st=${(dur - fadeOut).toFixed(3)}:d=${fadeOut.toFixed(3)}`,
    "-ac", "1", file,
  ]);
}

function concatWavs(files, outFile) {
  const listFile = path.join(TMP, `list_${Date.now()}_${Math.random().toString(36).slice(2)}.txt`);
  fs.writeFileSync(listFile, files.map((f) => `file '${f}'`).join("\n"));
  ff(["-f", "concat", "-safe", "0", "-i", listFile, "-c", "copy", outFile]);
  fs.unlinkSync(listFile);
}

// Build a monophonic track from a pattern of [noteName|0, beats].
function track(pattern, beat, amp, outFile, square = false) {
  const files = [];
  pattern.forEach((p, i) => {
    const [nm, beats] = p;
    const f = nm === 0 ? 0 : N[nm];
    const dur = beats * beat;
    const file = path.join(TMP, `n_${path.basename(outFile, ".wav")}_${i}.wav`);
    note(f, dur, amp, file, square);
    files.push(file);
  });
  concatWavs(files, outFile);
}

// Punchy kick: pitch-drop sine with fast amplitude decay.
function kickPattern(beats, beat, outFile) {
  const files = [];
  for (let i = 0; i < beats; i++) {
    const file = path.join(TMP, `k_${path.basename(outFile, ".wav")}_${i}.wav`);
    ff([
      "-f", "lavfi", "-i",
      `aevalsrc=0.9*sin(2*PI*(45+70*exp(-26*t))*t)*exp(-11*t):d=${beat.toFixed(3)}:s=44100`,
      "-ac", "1", file,
    ]);
    files.push(file);
  }
  concatWavs(files, outFile);
}

function mix(inputs, weights, outFile, extraAf = "") {
  const args = [];
  inputs.forEach((f) => { args.push("-i", f); });
  let af = `amix=inputs=${inputs.length}:duration=longest:weights=${weights.join(" ")}:normalize=0`;
  // gentle master: soft limiter-ish via alimiter + light highpass to clean rumble
  af += ",alimiter=limit=0.95,highpass=f=30";
  if (extraAf) af += "," + extraAf;
  args.push("-filter_complex", af, "-ac", "2", "-ar", "44100", outFile);
  ff(args);
}

// ── ENERGETIC BED (128 BPM), ~15s loopable ──────────────────────────────────
function buildEnergetic(name, opts = {}) {
  const bpm = opts.bpm || 128;
  const beat = 60 / bpm; // seconds per quarter
  const eighth = beat / 2;
  const bars = opts.bars || 8; // 8 bars * 4 beats = 32 beats
  const beats = bars * 4;

  // Lead arpeggio (eighth notes) — C major pentatonic, catchy up/down.
  const arpSeq = opts.arp || ["C5", "E5", "G5", "A5", "G5", "E5", "D5", "C5"];
  const lead = [];
  for (let i = 0; i < beats * 2; i++) lead.push([arpSeq[i % arpSeq.length], 1]); // 1 eighth each
  const leadFile = path.join(TMP, `lead_${name}.wav`);
  track(lead, eighth, 0.16, leadFile, true);

  // Bass (half notes) — root movement I - vi - IV - V feel in C.
  const bassRoots = opts.bass || ["C3", "A2", "F2", "G2"];
  const bass = [];
  for (let i = 0; i < beats / 2; i++) bass.push([bassRoots[i % bassRoots.length], 2]);
  const bassFile = path.join(TMP, `bass_${name}.wav`);
  track(bass, beat, 0.34, bassFile, false);

  // Kick on every beat.
  const kickFile = path.join(TMP, `kick_${name}.wav`);
  kickPattern(beats, beat, kickFile);

  const out = path.join(OUT, `${name}.m4a`);
  mix([leadFile, bassFile, kickFile], [0.9, 1.0, 1.0], out);
  console.log("bed:", path.relative(HERE, out), `(${(beats * beat).toFixed(1)}s)`);
}

// ── CALM AMBIENT PAD (breathing) ~24s ───────────────────────────────────────
function buildCalm(name) {
  // Slow chord pad: Am7 → Cmaj → Fmaj → G, long soft notes with echo.
  const chords = [
    ["A3", "C4", "E4"], ["C4", "E4", "G4"], ["F3", "A3", "C4"], ["G3", "B3".replace("B3", "") || "D4", "D4"],
  ];
  // Simpler: three-voice pad, each voice a slow melodic line.
  const beat = 3.0; // very slow
  const v1 = [["A4", 1], ["C5", 1], ["A4", 1], ["G4", 1], ["A4", 1], ["E4", 1], ["G4", 1], ["A4", 1]];
  const v2 = [["E4", 2], ["G4", 2], ["F4", 2], ["D4", 2]];
  const v3 = [["A3", 2], ["C4", 2], ["A3", 2], ["G3", 2]];
  const f1 = path.join(TMP, `calm_v1.wav`); track(v1, beat, 0.16, f1, false);
  const f2 = path.join(TMP, `calm_v2.wav`); track(v2, beat, 0.14, f2, false);
  const f3 = path.join(TMP, `calm_v3.wav`); track(v3, beat, 0.16, f3, false);
  const out = path.join(OUT, `${name}.m4a`);
  mix([f1, f2, f3], [1.0, 0.9, 1.0], out, "aecho=0.8:0.8:250|420:0.4|0.25,lowpass=f=4500");
  console.log("bed:", path.relative(HERE, out));
}

// ── HAPPY / CHEERFUL BED — bright major bounce for idle/cozy games ─────────
function buildHappy(name, opts = {}) {
  const bpm = opts.bpm || 116;
  const beat = 60 / bpm;
  const eighth = beat / 2;
  const bars = opts.bars || 8;
  const beats = bars * 4;

  // Bright, bouncy major-scale arpeggio — the "cheerful" lead.
  const arpSeq = opts.arp || ["C5", "E5", "G5", "A5", "G5", "E5", "D5", "C5"];
  const lead = [];
  for (let i = 0; i < beats * 2; i++) lead.push([arpSeq[i % arpSeq.length], 1]);
  const leadFile = path.join(TMP, `lead_${name}.wav`);
  track(lead, eighth, 0.20, leadFile, true);

  // A second, higher sparkle layer offset by an eighth for a bell/twinkle feel.
  const bellSeq = opts.bell || ["E5", "G5", "C5", "D5", "C5", "G4", "A4", "G4"];
  const bell = [[0, 1]];
  for (let i = 0; i < beats * 2 - 1; i++) bell.push([bellSeq[i % bellSeq.length], 1]);
  const bellFile = path.join(TMP, `bell_${name}.wav`);
  track(bell, eighth, 0.10, bellFile, true);

  // Skipping root-fifth bass — quarter notes, playful not heavy.
  const bassSeq = opts.bass || ["C3", "G2", "C3", "G2", "F2", "C3", "F2", "G2"];
  const bass = [];
  for (let i = 0; i < beats; i++) bass.push([bassSeq[i % bassSeq.length], 1]);
  const bassFile = path.join(TMP, `bass_${name}.wav`);
  track(bass, beat, 0.30, bassFile, false);

  // Gentle kick on beats 1 & 3 only — keeps it light, not driving/aggressive.
  const kFiles = [];
  for (let i = 0; i < beats; i++) {
    const f = path.join(TMP, `k_${name}_${i}.wav`);
    if (i % 2 === 0) {
      ff(["-f", "lavfi", "-i", `aevalsrc=0.55*sin(2*PI*(45+70*exp(-26*t))*t)*exp(-11*t):d=${beat.toFixed(3)}:s=44100`, "-ac", "1", f]);
    } else {
      ff(["-f", "lavfi", "-i", `aevalsrc=0:d=${beat.toFixed(3)}:s=44100`, "-ac", "1", f]);
    }
    kFiles.push(f);
  }
  const kickFile = path.join(TMP, `kick_${name}.wav`);
  concatWavs(kFiles, kickFile);

  const out = path.join(OUT, `${name}.m4a`);
  mix([leadFile, bellFile, bassFile, kickFile], [1.0, 0.6, 0.8, 0.6], out);
  console.log("bed:", path.relative(HERE, out), `(${(beats * beat).toFixed(1)}s)`);
}

buildEnergetic("bed_energetic", { arp: ["C5", "E5", "G5", "A5", "G5", "E5", "D5", "C5"], bass: ["C3", "A2", "F2", "G2"] });
buildEnergetic("bed_arcade", { bpm: 140, arp: ["E5", "G5", "A5", "C5", "D5", "C5", "A5", "G5"], bass: ["A2", "F2", "C3", "G2"] });
buildCalm("bed_calm");
buildHappy("bed_happy");

// Cleanup tmp note files (keep folder).
for (const f of fs.readdirSync(TMP)) { try { fs.unlinkSync(path.join(TMP, f)); } catch {} }
console.log("done");
