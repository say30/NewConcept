// Ready-made creatures (templates). Each is described compactly and then
// "assembled" with the same placement logic the editor uses.

import { defaultPaint } from './creature.js';
import { hitFromSpine, createPart, createLimb, symmetricHit } from './edit.js';

const S = (y, z, r) => ({ p: [0, y, z], r });

export const PRESETS = {
  quadruped: {
    name: 'Quadrupède (félin)', icon: '🐆',
    spine: [S(1.4, -1.6, 0.33), S(1.3, -1.2, 0.22), S(1.18, -0.65, 0.44), S(1.12, 0, 0.4), S(1.18, 0.55, 0.38), S(1.25, 1.0, 0.15), S(1.4, 1.45, 0.1), S(1.6, 1.85, 0.07)],
    paint: { base: '#d9a441', secondary: '#6b3f12', detail: '#3b2a1a', eye: '#4caf50', bellyColor: '#f4e6c6', pattern: 'leopard', patternScale: 0.18 },
    limbs: [
      { kind: 'leg', u: 2.05, dir: [0.75, -0.6, 0], end: 'foot_paw' },
      { kind: 'leg_digi', u: 4.0, dir: [0.75, -0.6, 0], end: 'foot_paw' },
    ],
    parts: [
      { type: 'eye_round', u: 0.1, dir: [0.5, 0.35, -0.75], scale: 0.9, params: { look: 0.7 } },
      { type: 'mouth_snout', u: 0, dir: [0, -0.15, -1], scale: 1.1 },
      { type: 'mouth_fangs', u: 0.15, dir: [0, -0.8, -0.7], scale: 0.9 },
      { type: 'ear_pointy', u: 0.2, dir: [0.5, 0.85, 0.1], scale: 0.9 },
      { type: 'tail_fluff', u: 7, dir: [0, 0.3, 1], scale: 0.7 },
    ],
  },
  humanoid: {
    name: 'Humanoïde', icon: '🧍',
    spine: [S(2.62, 0, 0.3), S(2.28, 0.02, 0.13), S(1.92, 0.02, 0.36), S(1.5, 0, 0.3), S(1.15, 0, 0.31)],
    paint: { base: '#7fb3d5', secondary: '#34607f', detail: '#f5d76e', eye: '#6a3fa0', bellyColor: '#d9ecf7', bellyAmount: 0.45, pattern: 'back', patternScale: 0.3 },
    limbs: [
      { kind: 'arm', u: 1.85, dir: [1, 0.25, 0], end: 'hand_5' },
      { kind: 'leg', u: 3.85, dir: [0.55, -0.8, 0], end: 'foot_human', joints: [[0, 0, 0], [0.04, -0.47, -0.08], [0.06, -0.9, 0]], radii: [0.15, 0.11, 0.085] },
    ],
    parts: [
      { type: 'eye_big', u: 0.05, dir: [0.4, 0.15, -0.9], scale: 0.75 },
      { type: 'mouth_smile', u: 0.18, dir: [0, -0.45, -1], scale: 0.8 },
      { type: 'nose_round', u: 0.08, dir: [0, -0.05, -1], scale: 0.6 },
      { type: 'ear_pointy', u: 0.08, dir: [1, 0.35, 0.1], scale: 0.8, rot: [0, 0, -40] },
    ],
  },
  dragon: {
    name: 'Dragon', icon: '🐉',
    spine: [S(1.9, -2.05, 0.3), S(1.75, -1.6, 0.18), S(1.45, -1.15, 0.2), S(1.25, -0.6, 0.45), S(1.2, 0.05, 0.43), S(1.2, 0.65, 0.34), S(1.1, 1.2, 0.2), S(1.0, 1.75, 0.13), S(1.0, 2.3, 0.07)],
    paint: { base: '#8e2b2b', secondary: '#3a0f14', detail: '#d9c27a', eye: '#ffcc00', bellyColor: '#e8c070', bellyAmount: 0.7, pattern: 'scales', patternScale: 0.2 },
    limbs: [
      { kind: 'leg', u: 3.1, dir: [0.8, -0.6, 0], end: 'hand_claw3', endScale: 1.1 },
      { kind: 'leg_digi', u: 5.0, dir: [0.8, -0.6, 0], end: 'foot_bird', thick: 1.15 },
    ],
    parts: [
      { type: 'eye_reptile', u: 0.1, dir: [0.6, 0.5, -0.6], scale: 0.8 },
      { type: 'mouth_teeth', u: 0.0, dir: [0, -0.4, -1], scale: 1.1 },
      { type: 'horn_curved', u: 0.35, dir: [0.4, 1, 0.3], scale: 1.1, params: { length: 1.3, curve: 1 } },
      { type: 'wing_bat', u: 3.3, dir: [0.45, 1, 0], scale: 1.4 },
      { type: 'spike_row', u: 4.2, dir: [0, 1, 0], scale: 1, params: { count: 6, spacing: 1.4 } },
      { type: 'spike_row', u: 6.2, dir: [0, 1, 0], scale: 0.8, params: { count: 5 } },
      { type: 'tail_thagomizer', u: 8, dir: [0, 0.2, 1], scale: 1 },
    ],
  },
  insect: {
    name: 'Insecte', icon: '🐞',
    spine: [S(0.75, -1.05, 0.25), S(0.72, -0.62, 0.2), S(0.72, -0.25, 0.28), S(0.8, 0.35, 0.36), S(0.85, 0.85, 0.3), S(0.85, 1.15, 0.12)],
    paint: { base: '#2e7d32', secondary: '#0c3b10', detail: '#1b1b1b', eye: '#ff3b30', bellyColor: '#a5d66f', pattern: 'stripes', patternScale: 0.16, patternAmount: 0.7 },
    limbs: [
      { kind: 'leg_insect', u: 1.6, dir: [1, -0.6, -0.4] },
      { kind: 'leg_insect', u: 2.0, dir: [1, -0.6, 0] },
      { kind: 'leg_insect', u: 2.4, dir: [1, -0.6, 0.4] },
    ],
    parts: [
      { type: 'eye_insect', u: 0.1, dir: [0.8, 0.3, -0.5], scale: 1 },
      { type: 'mouth_mandibles', u: 0, dir: [0, -0.3, -1], scale: 1 },
      { type: 'horn_antenna', u: 0.15, dir: [0.35, 1, -0.25], scale: 1.2, params: { length: 1.4 } },
      { type: 'wing_insect', u: 2.6, dir: [0.35, 1, 0], scale: 1.1 },
    ],
  },
  bird: {
    name: 'Oiseau', icon: '🐦',
    spine: [S(1.95, -0.55, 0.26), S(1.7, -0.4, 0.15), S(1.4, -0.15, 0.36), S(1.25, 0.25, 0.3), S(1.25, 0.6, 0.12)],
    paint: { base: '#2f80ed', secondary: '#f2c94c', detail: '#f2994a', eye: '#222222', bellyColor: '#f2f2f2', bellyAmount: 0.8, pattern: 'back', patternScale: 0.3, patternAmount: 0.4 },
    limbs: [
      { kind: 'leg_digi', u: 2.9, dir: [0.6, -0.8, 0], end: 'foot_bird', thick: 0.6 },
    ],
    parts: [
      { type: 'eye_round', u: 0.1, dir: [0.8, 0.3, -0.5], scale: 0.8 },
      { type: 'mouth_beak', u: 0, dir: [0, 0, -1], scale: 1 },
      { type: 'wing_feather', u: 2.2, dir: [1, 0.3, 0], scale: 0.9 },
      { type: 'tail_fan', u: 4, dir: [0, 0.3, 1], scale: 1.1 },
      { type: 'horn_crest', u: 0.2, dir: [0, 1, 0.2], scale: 0.8 },
    ],
  },
  fish: {
    name: 'Créature marine', icon: '🐟',
    spine: [S(1.3, -1.2, 0.3), S(1.3, -0.7, 0.42), S(1.3, -0.1, 0.44), S(1.32, 0.5, 0.32), S(1.35, 1.0, 0.18), S(1.4, 1.4, 0.09)],
    paint: { base: '#26c6da', secondary: '#006064', detail: '#ffab40', eye: '#111111', bellyColor: '#e0f7fa', bellyAmount: 0.8, pattern: 'stripes', patternScale: 0.25 },
    limbs: [
      { kind: 'tentacle', u: 1.6, dir: [0.5, -1, 0], thick: 0.8 },
    ],
    parts: [
      { type: 'eye_big', u: 0.3, dir: [0.9, 0.3, -0.3], scale: 0.7 },
      { type: 'mouth_smile', u: 0, dir: [0, -0.2, -1], scale: 1 },
      { type: 'fin_dorsal', u: 2.2, dir: [0, 1, 0], scale: 1.3 },
      { type: 'fin_side', u: 1.4, dir: [1, -0.2, 0], scale: 1.2 },
      { type: 'fin_tail', u: 5, dir: [0, 0, 1], scale: 1.5 },
    ],
  },
  blob: {
    name: 'Petit mignon', icon: '🐣',
    spine: [S(0.95, -0.2, 0.55), S(0.7, 0.25, 0.6)],
    paint: { base: '#f48fb1', secondary: '#ad1457', detail: '#fff59d', eye: '#3949ab', bellyColor: '#fff1f6', bellyAmount: 0.6, pattern: 'spots', patternScale: 0.2, patternAmount: 0.5 },
    limbs: [
      { kind: 'leg', u: 0.8, dir: [0.5, -0.9, -0.2], end: 'foot_human', joints: [[0, 0, 0], [0.03, -0.1, -0.03], [0.05, -0.2, 0]], radii: [0.12, 0.1, 0.09] },
    ],
    parts: [
      { type: 'eye_big', u: 0.05, dir: [0.35, 0.35, -0.9], scale: 1 },
      { type: 'mouth_smile', u: 0.1, dir: [0, -0.1, -1], scale: 0.9 },
      { type: 'ear_long', u: 0.1, dir: [0.35, 1, 0], scale: 1.2 },
    ],
  },
  spider: {
    name: 'Araignée', icon: '🕷️',
    spine: [S(0.85, -0.55, 0.3), S(0.9, -0.15, 0.25), S(1.05, 0.45, 0.5)],
    paint: { base: '#3d3d46', secondary: '#c62828', detail: '#111111', eye: '#c62828', bellyColor: '#55555f', pattern: 'spots', patternScale: 0.25, patternAmount: 0.6 },
    limbs: [
      { kind: 'leg_insect', u: 0.7, dir: [1, -0.3, -0.5], thick: 0.9 },
      { kind: 'leg_insect', u: 0.95, dir: [1, -0.3, -0.15], thick: 0.9 },
      { kind: 'leg_insect', u: 1.2, dir: [1, -0.3, 0.15], thick: 0.9 },
      { kind: 'leg_insect', u: 1.4, dir: [1, -0.3, 0.45], thick: 0.9 },
    ],
    parts: [
      { type: 'eye_cluster', u: 0.05, dir: [0.35, 0.4, -0.85], scale: 1 },
      { type: 'eye_round', u: 0.1, dir: [0, 0.35, -1], scale: 0.7 },
      { type: 'mouth_mandibles', u: 0, dir: [0, -0.4, -1], scale: 0.8 },
    ],
  },
  golem: {
    name: 'Golem', icon: '🗿',
    spine: [S(2.7, -0.15, 0.28), S(2.45, -0.05, 0.22), S(2.0, 0, 0.55), S(1.45, 0.05, 0.42), S(1.1, 0.05, 0.38)],
    paint: { base: '#7a7f8a', secondary: '#4a4e57', detail: '#46d2ff', eye: '#46d2ff', bellyColor: '#9aa0aa', bellyAmount: 0.3, pattern: 'camo', patternScale: 0.35, patternAmount: 0.6, texture: 1 },
    limbs: [
      { kind: 'arm', u: 1.8, dir: [1, 0.3, 0], end: 'hand_paw', thick: 1.8, endScale: 1.6 },
      { kind: 'leg', u: 3.8, dir: [0.6, -0.8, 0], end: 'foot_elephant', thick: 1.5, joints: [[0, 0, 0], [0.05, -0.45, -0.08], [0.08, -0.88, 0]] },
    ],
    parts: [
      { type: 'eye_angry', u: 0.1, dir: [0.35, 0.2, -1], scale: 0.7, params: {} },
      { type: 'shoulder_pad', u: 1.75, dir: [0.9, 0.8, 0], scale: 1.4 },
      { type: 'crystal', u: 2.2, dir: [0.2, 0.3, 1], scale: 1.6, slot: 'custom', color: '#46d2ff' },
      { type: 'crystal', u: 2.0, dir: [0.7, 0.9, 0.5], scale: 1.1, slot: 'custom', color: '#46d2ff' },
      { type: 'mouth_teeth', u: 0.35, dir: [0, -0.3, -1], scale: 0.8, params: { teeth: 4 } },
    ],
  },
};

export function buildPreset(key) {
  return assemble(PRESETS[key]);
}

export function assemble(spec) {
  const creature = {
    version: 1,
    name: spec.name,
    spine: spec.spine.map((v) => ({ p: v.p.slice(), r: v.r })),
    body: { blend: 1 },
    limbs: [],
    parts: [],
    paint: Object.assign(defaultPaint(), spec.paint || {}),
  };
  for (const L of spec.limbs) {
    const hit = hitFromSpine(creature, L.u, L.dir);
    if (!hit) continue;
    const { p, n } = symmetricHit(hit.p, hit.n);
    const extra = {};
    for (const k of ['end', 'thick', 'endScale', 'joints', 'radii']) if (L[k] !== undefined) extra[k] = JSON.parse(JSON.stringify(L[k]));
    creature.limbs.push(createLimb(creature, L.kind, p, n, extra));
  }
  for (const Q of spec.parts) {
    const hit = hitFromSpine(creature, Q.u, Q.dir);
    if (!hit) continue;
    const { p, n } = symmetricHit(hit.p, hit.n);
    const extra = { scale: Q.scale ?? 1 };
    if (Q.params) extra.params = Object.assign({}, Q.params);
    if (Q.rot) extra.rot = Q.rot.slice();
    if (Q.slot) extra.slot = Q.slot;
    if (Q.color) extra.color = Q.color;
    creature.parts.push(createPart(creature, Q.type, p, n, extra));
  }
  return creature;
}
