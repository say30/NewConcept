// Random creature generator.
import { assemble } from './presets.js';

export const PALETTES = [
  { base: '#4f9d69', secondary: '#2f5d3e', detail: '#e8d9b0', eye: '#d8a21c', bellyColor: '#e9e2b8' },
  { base: '#d9a441', secondary: '#6b3f12', detail: '#3b2a1a', eye: '#4caf50', bellyColor: '#f4e6c6' },
  { base: '#8e2b2b', secondary: '#3a0f14', detail: '#d9c27a', eye: '#ffcc00', bellyColor: '#e8c070' },
  { base: '#7fb3d5', secondary: '#34607f', detail: '#f5d76e', eye: '#6a3fa0', bellyColor: '#d9ecf7' },
  { base: '#9b59b6', secondary: '#4a235a', detail: '#f1c40f', eye: '#2ecc71', bellyColor: '#e8daef' },
  { base: '#f48fb1', secondary: '#ad1457', detail: '#fff59d', eye: '#3949ab', bellyColor: '#fff1f6' },
  { base: '#26c6da', secondary: '#006064', detail: '#ffab40', eye: '#111111', bellyColor: '#e0f7fa' },
  { base: '#3d3d46', secondary: '#c62828', detail: '#111111', eye: '#ff5252', bellyColor: '#55555f' },
  { base: '#e67e22', secondary: '#2c3e50', detail: '#ecf0f1', eye: '#2980b9', bellyColor: '#fdebd0' },
  { base: '#95a5a6', secondary: '#34495e', detail: '#e74c3c', eye: '#f1c40f', bellyColor: '#ecf0f1' },
  { base: '#27ae60', secondary: '#f1c40f', detail: '#c0392b', eye: '#8e44ad', bellyColor: '#d5f5e3' },
  { base: '#1e3a5f', secondary: '#48c9b0', detail: '#f7dc6f', eye: '#48c9b0', bellyColor: '#aed6f1' },
  { base: '#f5f0e1', secondary: '#c9a66b', detail: '#5d4037', eye: '#795548', bellyColor: '#ffffff' },
  { base: '#212121', secondary: '#ff6f00', detail: '#ffd54f', eye: '#ff6f00', bellyColor: '#424242' },
];
export const PATTERN_KEYS = ['none', 'spots', 'leopard', 'stripes', 'tiger', 'giraffe', 'scales', 'back', 'camo'];

export function mulberry(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function randomPaint(rnd) {
  const pal = PALETTES[Math.floor(rnd() * PALETTES.length)];
  return Object.assign({}, pal, {
    pattern: PATTERN_KEYS[Math.floor(rnd() * PATTERN_KEYS.length)],
    patternScale: 0.14 + rnd() * 0.2,
    patternAmount: 0.5 + rnd() * 0.5,
    bellyAmount: 0.2 + rnd() * 0.6,
    seed: Math.floor(rnd() * 1000),
  });
}

export function randomCreature(seed = Math.floor(Math.random() * 1e9)) {
  const rnd = mulberry(seed);
  const R = (a, b) => a + (b - a) * rnd();
  const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
  const S = (y, z, r) => ({ p: [0, y, z], r });
  const kind = pick(['quad', 'quad', 'biped', 'biped', 'insect', 'serpent', 'flyer', 'blob']);
  const spec = { name: 'Créature ' + (seed % 1000), paint: randomPaint(rnd), limbs: [], parts: [] };
  let headDir = [0, 0, -1];
  let backDir = [0, 1, 0];
  let n;
  if (kind === 'quad' || kind === 'insect' || kind === 'serpent') {
    n = kind === 'serpent' ? 9 : Math.floor(R(5, 8.99));
    const y0 = kind === 'insect' ? R(0.6, 0.9) : kind === 'serpent' ? R(0.3, 0.45) : R(0.9, 1.5);
    const len = kind === 'serpent' ? R(3.5, 5) : R(2.2, 3.6);
    const bodyR = R(0.3, 0.55);
    spec.spine = [];
    for (let i = 0; i < n; i++) {
      const t = i / (n - 1);
      let r;
      if (kind === 'serpent') r = bodyR * 0.6 * (i === 0 ? 1.1 : 1 - 0.8 * t) + 0.03;
      else if (i === 0) r = R(0.25, 0.4);
      else if (i === 1) r = R(0.14, 0.24);
      else {
        const u = (i - 2) / Math.max(1, n - 3);
        r = u < 0.6 ? bodyR * (0.85 + 0.15 * Math.sin(u * Math.PI / 0.6)) * R(0.9, 1.1) : bodyR * (1 - (u - 0.6) / 0.4) * 0.6 + 0.05;
      }
      const wave = kind === 'serpent' ? Math.sin(t * Math.PI * 2) * 0.15 : 0;
      const lift = i === 0 ? R(0.1, 0.35) : i === n - 1 ? R(-0.1, 0.4) : 0;
      spec.spine.push(S(y0 + wave + lift, -len / 2 + t * len, r));
    }
  } else if (kind === 'biped') {
    const tall = R(1.9, 2.8);
    const w = R(0.28, 0.5);
    spec.spine = [S(tall, R(-0.1, 0.05), R(0.25, 0.36)), S(tall - 0.32, 0.02, 0.13), S(tall - 0.7, 0.02, w), S(tall - 1.1, 0, w * R(0.75, 1.05)), S(tall - 1.45, 0, w * 0.9)];
    n = 5; headDir = [0, 0, -1]; backDir = [0, 0.2, 1];
  } else if (kind === 'flyer') {
    spec.spine = [S(1.95, -0.55, 0.26), S(1.7, -0.4, 0.15), S(1.4, -0.15, R(0.3, 0.42)), S(1.25, 0.25, 0.3), S(1.25, 0.6, 0.12)];
    n = 5;
  } else {
    spec.spine = [S(R(0.85, 1.05), -0.2, R(0.45, 0.6)), S(0.7, 0.25, R(0.5, 0.65))];
    n = 2;
  }
  const P = spec.parts, L = spec.limbs;
  const feet = ['foot_paw', 'foot_hoof', 'foot_bird', 'foot_elephant', 'foot_webbed', 'foot_human', 'foot_boot'];
  const hands = ['hand_5', 'hand_claw3', 'hand_pincer', 'hand_paw', 'hand_scythe'];
  if (kind === 'quad') {
    L.push({ kind: 'leg', u: R(1.8, 2.3), dir: [0.75, -0.6, 0], end: pick(feet), thick: R(0.8, 1.4) });
    L.push({ kind: pick(['leg', 'leg_digi']), u: n - 3 + R(-0.3, 0.2), dir: [0.75, -0.6, 0], end: pick(feet), thick: R(0.8, 1.4) });
  } else if (kind === 'insect') {
    const k = Math.floor(R(2, 4.99));
    for (let i = 0; i < k; i++) L.push({ kind: 'leg_insect', u: 1.6 + i * (2.2 / k), dir: [1, -0.5, R(-0.3, 0.3)], thick: R(0.8, 1.2) });
  } else if (kind === 'biped') {
    L.push({ kind: 'arm', u: 1.85, dir: [1, 0.25, 0], end: pick(hands), thick: R(0.8, 1.6) });
    L.push({ kind: pick(['leg', 'leg_digi']), u: 3.8, dir: [0.55, -0.8, 0], end: pick(feet), thick: R(0.9, 1.5) });
  } else if (kind === 'flyer') {
    L.push({ kind: 'leg_digi', u: 2.9, dir: [0.6, -0.8, 0], end: 'foot_bird', thick: 0.6 });
  } else if (kind === 'blob') {
    L.push({ kind: 'leg', u: 0.8, dir: [0.5, -0.9, -0.2], end: pick(['foot_human', 'foot_paw', 'foot_boot']), joints: [[0, 0, 0], [0.03, -0.1, -0.03], [0.05, -0.2, 0]], radii: [0.12, 0.1, 0.09] });
    if (rnd() < 0.5) L.push({ kind: 'arm', u: 0.4, dir: [1, 0, 0], end: pick(hands), thick: 0.8 });
  } else if (kind === 'serpent' && rnd() < 0.5) {
    L.push({ kind: 'arm', u: 2, dir: [1, -0.3, 0], end: pick(hands), thick: 0.8 });
  }
  // eyes
  const eye = pick(['eye_round', 'eye_big', 'eye_reptile', 'eye_angry', 'eye_sleepy', 'eye_stalk', 'eye_insect', 'eye_cluster']);
  if (rnd() < 0.15) P.push({ type: eye === 'eye_insect' ? 'eye_big' : eye, u: 0.05, dir: [0, 0.35, -1], scale: R(1, 1.4) });
  else P.push({ type: eye, u: 0.08, dir: [R(0.35, 0.8), R(0.1, 0.5), -1], scale: R(0.7, 1.1) });
  if (rnd() < 0.2) P.push({ type: 'eye_round', u: 0.15, dir: [R(0.6, 0.9), R(0.5, 0.9), -0.4], scale: R(0.5, 0.7) });
  // mouth
  const mouth = pick(['mouth_smile', 'mouth_teeth', 'mouth_fangs', 'mouth_beak', 'mouth_bill', 'mouth_snout', 'mouth_pig', 'mouth_mandibles', 'mouth_tusks', 'mouth_trunk', 'mouth_sucker']);
  P.push({ type: mouth, u: 0, dir: [0, R(-0.4, 0), -1], scale: R(0.8, 1.2) });
  // horns / ears
  if (rnd() < 0.6) P.push({ type: pick(['horn_straight', 'horn_curved', 'horn_ram', 'horn_antler', 'horn_antenna', 'horn_unicorn', 'horn_crest']), u: 0.2, dir: [R(0.2, 0.6), 1, R(0, 0.4)], scale: R(0.8, 1.3) });
  if (rnd() < 0.5) P.push({ type: pick(['ear_pointy', 'ear_round', 'ear_long', 'ear_elephant', 'ear_fin']), u: 0.2, dir: [R(0.6, 1), R(0.3, 1), 0.2], scale: R(0.7, 1.2) });
  // back
  if (n > 3 && rnd() < 0.6) P.push({ type: pick(['spike_row', 'plate', 'fin_dorsal', 'mane', 'shell']), u: n * 0.5, dir: backDir, scale: R(0.8, 1.3) });
  if (rnd() < 0.35 && kind !== 'serpent') P.push({ type: pick(['wing_bat', 'wing_feather', 'wing_insect']), u: Math.min(n - 1, 2.3), dir: [0.5, 1, 0], scale: R(0.9, 1.5) });
  // tail tip
  if (n > 3 && rnd() < 0.6) P.push({ type: pick(['tail_club', 'tail_thagomizer', 'tail_fluff', 'tail_stinger', 'tail_fan', 'tail_leaf', 'fin_tail']), u: n - 1, dir: [0, 0.2, 1], scale: R(0.8, 1.3) });
  if (rnd() < 0.3) P.push({ type: pick(['bump', 'crystal', 'shoulder_pad']), u: R(1, n - 1), dir: [R(0.3, 1), R(0.2, 1), R(-0.5, 0.5)], scale: R(0.8, 1.4), slot: 'custom', color: pick(['#46d2ff', '#ff5ec4', '#ffe14d', '#7dff7a']) });
  void headDir;
  return assemble(spec);
}
