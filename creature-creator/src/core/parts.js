// Catalogue of parts. Every part is built in its own local frame:
//   +Y : out of the surface (or along the limb for hands, down for feet)
//   +Z : "hint" direction (forward, or up for face parts)
//   +X : side
// Units are roughly world units at scale 1 (a typical head radius is ~0.35).

export const CATEGORIES = [
  ['limbs', 'Membres', '🦵'],
  ['eyes', 'Yeux', '👁️'],
  ['mouths', 'Bouches & nez', '👄'],
  ['horns', 'Cornes & antennes', '🦌'],
  ['ears', 'Oreilles', '👂'],
  ['wings', 'Ailes & nageoires', '🪽'],
  ['tails', 'Bouts de queue', '🦂'],
  ['details', 'Détails & armures', '✨'],
  ['hands', 'Mains', '✋'],
  ['feet', 'Pieds', '🦶'],
];

const P = (x, y, z) => [x, y, z];

function arc(n, f) {
  const pts = [];
  for (let i = 0; i <= n; i++) pts.push(f(i / n));
  return pts;
}
function taper(n, a, b) {
  const r = [];
  for (let i = 0; i <= n; i++) r.push(a + (b - a) * (i / n));
  return r;
}

export const PARTS = {
  // ------------------------------------------------------------- EYES
  eye_round: {
    name: 'Œil rond', cat: 'eyes', icon: '👁️', hint: 'up',
    params: { look: 0.55, iris: 0.6, pupil: 0.45 },
    paramDefs: [['look', 'Regard vers l\'avant', 0, 1], ['iris', 'Taille iris', 0.3, 1], ['pupil', 'Pupille', 0.1, 0.9]],
    build(c, p) { c.eye(P(0, 0.02, 0), 0.1, { look: p.look, irisSize: p.iris, pupil: p.pupil }); },
  },
  eye_big: {
    name: 'Gros œil mignon', cat: 'eyes', icon: '🥺', hint: 'up',
    params: { look: 0.5, iris: 0.8, pupil: 0.55 },
    paramDefs: [['look', 'Regard vers l\'avant', 0, 1], ['iris', 'Taille iris', 0.3, 1], ['pupil', 'Pupille', 0.1, 0.9]],
    build(c, p) { c.eye(P(0, 0.03, 0), 0.16, { look: p.look, irisSize: p.iris, pupil: p.pupil }); },
  },
  eye_reptile: {
    name: 'Œil reptile', cat: 'eyes', icon: '🦎', hint: 'up',
    params: { look: 0.5, brow: 1 },
    paramDefs: [['look', 'Regard vers l\'avant', 0, 1], ['brow', 'Arcade', 0, 2]],
    build(c, p) {
      c.eye(P(0, 0.02, 0), 0.1, { look: p.look, irisSize: 0.85, pupil: 0.5, slit: true, iris: [0.9, 0.7, 0.1] });
      if (p.brow > 0.05) c.ell(P(0, 0.03, 0.08), [0.13, 0.05 * p.brow, 0.05], null, { k: 0.04 });
    },
  },
  eye_angry: {
    name: 'Œil féroce', cat: 'eyes', icon: '😠', hint: 'up',
    params: { look: 0.6 },
    paramDefs: [['look', 'Regard vers l\'avant', 0, 1]],
    build(c, p) {
      c.eye(P(0, 0.02, 0), 0.1, { look: p.look, irisSize: 0.55, pupil: 0.35, iris: [0.85, 0.12, 0.08] });
      c.ell(P(0, 0.05, 0.07), [0.14, 0.06, 0.05], [P(1, 0, -0.35), P(0, 1, 0)], { k: 0.04 });
    },
  },
  eye_sleepy: {
    name: 'Œil paupière', cat: 'eyes', icon: '😌', hint: 'up',
    params: { lid: 0.5, look: 0.5 },
    paramDefs: [['lid', 'Fermeture', 0, 1], ['look', 'Regard vers l\'avant', 0, 1]],
    build(c, p) {
      c.eye(P(0, 0.02, 0), 0.12, { look: p.look, irisSize: 0.7, pupil: 0.5 });
      c.ell(P(0, 0.02, 0.02 + 0.1 * (1 - p.lid)), [0.135, 0.135, 0.1], null, { k: 0.015, layer: 2 });
    },
  },
  eye_stalk: {
    name: 'Œil pédonculé', cat: 'eyes', icon: '🐌', hint: 'up',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = 0.32 * p.length;
      c.cone(P(0, -0.02, 0), P(0, L, 0.05), 0.05, 0.03, { k: 0.05 });
      c.eye(P(0, L + 0.06, 0.06), 0.08, { look: 0.9, irisSize: 0.65 });
    },
  },
  eye_insect: {
    name: 'Œil composé', cat: 'eyes', icon: '🪰', hint: 'up',
    params: {},
    build(c) { c.ell(P(0, 0.02, 0), [0.12, 0.09, 0.14], null, { k: 0.015, layer: 2, mat: { kind: 'compound', color: [0.55, 0.08, 0.06] } }); },
  },
  eye_cluster: {
    name: 'Grappe d\'yeux', cat: 'eyes', icon: '🕷️', hint: 'up',
    params: {},
    build(c) {
      c.eye(P(-0.07, 0.01, -0.03), 0.055, { look: 0.6, irisSize: 0.9, pupil: 0.7, iris: [0.1, 0.1, 0.1] });
      c.eye(P(0.07, 0.01, -0.03), 0.055, { look: 0.6, irisSize: 0.9, pupil: 0.7, iris: [0.1, 0.1, 0.1] });
      c.eye(P(0, 0.01, 0.07), 0.065, { look: 0.6, irisSize: 0.9, pupil: 0.7, iris: [0.1, 0.1, 0.1] });
    },
  },

  // ------------------------------------------------------------- MOUTHS
  mouth_smile: {
    name: 'Bouche', cat: 'mouths', icon: '🙂', hint: 'up',
    params: { width: 1, open: 1 },
    paramDefs: [['width', 'Largeur', 0.4, 2], ['open', 'Ouverture', 0.2, 2.5]],
    build(c, p) {
      c.ell(P(0, 0, 0), [0.2 * p.width, 0.08, 0.035 * p.open], [P(1, 0, 0), P(0, 1, 0)], { sub: true, slot: 'mouth', k: 0.03 });
    },
  },
  mouth_teeth: {
    name: 'Mâchoire à dents', cat: 'mouths', icon: '🦷', hint: 'up',
    params: { width: 1, open: 1, teeth: 6 },
    paramDefs: [['width', 'Largeur', 0.5, 2], ['open', 'Ouverture', 0.4, 2.5], ['teeth', 'Nombre de dents', 2, 12, 1]],
    build(c, p) {
      const W = 0.2 * p.width, H = 0.055 * p.open;
      c.ell(P(0, -0.01, 0), [W, 0.1, H], null, { sub: true, slot: 'mouth', k: 0.03 });
      const n = Math.round(p.teeth);
      for (let i = 0; i < n; i++) {
        const x = (n === 1 ? 0 : (i / (n - 1) - 0.5) * 1.6) * W;
        const f = 1 - Math.abs(x) / W;
        const lenT = (0.5 + 0.5 * (i === 1 || i === n - 2 ? 1.5 : 1)) * H;
        c.cone(P(x, -0.03 * f, H * 0.9), P(x, -0.02 * f, H * 0.9 - lenT), 0.02, 0.003, { slot: 'teeth', k: 0.006, layer: 2 });
        c.cone(P(x, -0.03 * f, -H * 0.9), P(x, -0.02 * f, -H * 0.9 + lenT * 0.8), 0.018, 0.003, { slot: 'teeth', k: 0.006, layer: 2 });
      }
    },
  },
  mouth_fangs: {
    name: 'Crocs', cat: 'mouths', icon: '🧛', hint: 'up',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur des crocs', 0.4, 2.5]],
    build(c, p) {
      c.ell(P(0, -0.01, 0), [0.18, 0.08, 0.035], null, { sub: true, slot: 'mouth', k: 0.03 });
      for (const s of [-1, 1]) c.cone(P(s * 0.1, 0.0, 0.03), P(s * 0.1, 0.02, -0.03 - 0.12 * p.length), 0.028, 0.003, { slot: 'teeth', k: 0.01, layer: 2 });
    },
  },
  mouth_beak: {
    name: 'Bec crochu', cat: 'mouths', icon: '🦅', hint: 'up', slot: 'detail',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      c.chain([P(0, -0.02, 0.02), P(0, 0.18 * L, 0.0), P(0, 0.3 * L, -0.05), P(0, 0.31 * L, -0.11)], [0.12, 0.07, 0.025, 0.006], { k: 0.04 });
      c.cone(P(0, -0.02, -0.08), P(0, 0.2 * L, -0.1), 0.085, 0.01, { k: 0.03 });
    },
  },
  mouth_bill: {
    name: 'Bec de canard', cat: 'mouths', icon: '🦆', hint: 'up', slot: 'detail',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      c.ell(P(0, 0.18 * L, 0), [0.14, 0.24 * L, 0.04], null, { k: 0.05 });
      c.ell(P(0, 0.16 * L, -0.065), [0.12, 0.22 * L, 0.03], null, { k: 0.02 });
    },
  },
  mouth_snout: {
    name: 'Museau', cat: 'mouths', icon: '🐶', hint: 'up',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      c.ell(P(0, 0.12 * L, 0), [0.14, 0.18 * L, 0.12], null, { k: 0.08 });
      c.ell(P(0, 0.29 * L, 0.04), [0.07, 0.05, 0.05], null, { slot: 'dark', k: 0.02 });
      for (const s of [-1, 1]) c.sphere(P(s * 0.03, 0.33 * L, 0.035), 0.018, { sub: true, slot: 'dark', k: 0.01 });
      c.ell(P(0, 0.2 * L, -0.08), [0.11, 0.14 * L, 0.012], null, { sub: true, slot: 'mouth', k: 0.01 });
    },
  },
  mouth_pig: {
    name: 'Groin', cat: 'mouths', icon: '🐷', hint: 'up',
    params: {},
    build(c) {
      c.cone(P(0, -0.02, 0), P(0, 0.12, 0), 0.1, 0.09, { k: 0.05 });
      for (const s of [-1, 1]) c.ell(P(s * 0.035, 0.21, 0), [0.022, 0.03, 0.035], null, { sub: true, slot: 'dark', k: 0.01 });
    },
  },
  nose_round: {
    name: 'Nez rond', cat: 'mouths', icon: '🔴', hint: 'up', slot: 'dark',
    params: {},
    build(c) { c.sphere(P(0, 0.02, 0), 0.06, { k: 0.02 }); },
  },
  mouth_mandibles: {
    name: 'Mandibules', cat: 'mouths', icon: '🐜', hint: 'up', slot: 'detail',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      for (const s of [-1, 1])
        c.chain([P(s * 0.07, 0, 0), P(s * 0.13, 0.12 * L, -0.02), P(s * 0.1, 0.24 * L, -0.03), P(s * 0.02, 0.3 * L, -0.03)], [0.045, 0.035, 0.022, 0.006], { k: 0.03 });
    },
  },
  mouth_tusks: {
    name: 'Défenses', cat: 'mouths', icon: '🐗', hint: 'up', slot: 'claw',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      for (const s of [-1, 1])
        c.chain([P(s * 0.1, 0, -0.04), P(s * 0.13, 0.12 * L, -0.12 * L), P(s * 0.16, 0.24 * L, -0.08 * L), P(s * 0.17, 0.3 * L, 0.04 * L)], [0.045, 0.036, 0.022, 0.006], { k: 0.02 });
    },
  },
  mouth_trunk: {
    name: 'Trompe', cat: 'mouths', icon: '🐘', hint: 'up',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      const pts = [P(0, 0, 0), P(0, 0.15, -0.02 * L), P(0, 0.27, -0.1 * L), P(0, 0.33, -0.25 * L), P(0, 0.33, -0.4 * L), P(0, 0.3, -0.52 * L), P(0, 0.33, -0.6 * L)];
      c.chain(pts, [0.11, 0.09, 0.075, 0.065, 0.055, 0.05, 0.05], { k: 0.04 });
      c.sphere(P(0, 0.36, -0.62 * L), 0.028, { sub: true, slot: 'dark', k: 0.01 });
    },
  },
  mouth_sucker: {
    name: 'Ventouse buccale', cat: 'mouths', icon: '🪱', hint: 'up',
    params: {},
    build(c) {
      c.cone(P(0, -0.02, 0), P(0, 0.08, 0), 0.15, 0.14, { k: 0.05 });
      c.sphere(P(0, 0.14, 0), 0.1, { sub: true, slot: 'mouth', k: 0.03 });
      for (let i = 0; i < 10; i++) {
        const a = (i / 10) * Math.PI * 2;
        const x = Math.cos(a), z = Math.sin(a);
        c.cone(P(x * 0.1, 0.07, z * 0.1), P(x * 0.05, 0.05, z * 0.05), 0.018, 0.003, { slot: 'teeth', k: 0.005, layer: 2 });
      }
    },
  },

  // ------------------------------------------------------------- HORNS
  horn_straight: {
    name: 'Corne droite', cat: 'horns', icon: '📍', hint: 'up', slot: 'detail',
    params: { length: 1, thick: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['thick', 'Épaisseur', 0.4, 2]],
    build(c, p) { c.cone(P(0, -0.03, 0), P(0, 0.35 * p.length, 0), 0.07 * p.thick, 0.006, { k: 0.04 }); },
  },
  horn_curved: {
    name: 'Corne courbée', cat: 'horns', icon: '🐂', hint: 'up', slot: 'detail',
    params: { length: 1, curve: 1, thick: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['curve', 'Courbure', -2, 2.5], ['thick', 'Épaisseur', 0.4, 2]],
    build(c, p) {
      const R = 0.35 * p.length, A = 1.1 * p.curve;
      const pts = arc(7, (t) => {
        const a = t * A;
        if (Math.abs(A) < 1e-3) return P(0, R * t, 0);
        const rr = R / A;
        return P(0, rr * Math.sin(a), -rr * (1 - Math.cos(a)));
      });
      c.chain(pts, taper(7, 0.075 * p.thick, 0.006), { k: 0.03 });
    },
  },
  horn_ram: {
    name: 'Corne de bélier', cat: 'horns', icon: '🐏', hint: 'up', slot: 'detail',
    params: { size: 1, turns: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['turns', 'Enroulement', 0.4, 1.4]],
    build(c, p) {
      const N = 16, tot = 1.75 * Math.PI * p.turns;
      const pts = arc(N, (t) => {
        const th = t * tot, a = 0.2 * p.size * (1 - 0.25 * th / Math.PI);
        return P(0.06 * t * p.size, a * Math.sin(th), -a * (1 - Math.cos(th)));
      });
      c.chain(pts, taper(N, 0.085 * p.size, 0.02 * p.size), { k: 0.02 });
    },
  },
  horn_antler: {
    name: 'Bois de cerf', cat: 'horns', icon: '🦌', hint: 'up', slot: 'detail',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      const B = [P(0, -0.02, 0), P(0, 0.25 * s, -0.05 * s), P(0.05 * s, 0.45 * s, -0.12 * s), P(0.08 * s, 0.62 * s, -0.08 * s)];
      c.chain(B, [0.045, 0.036, 0.028, 0.012], { k: 0.02 });
      c.cone(B[1], P(0, 0.36 * s, 0.1 * s), 0.028, 0.008, { k: 0.015 });
      c.cone(B[2], P(0.03 * s, 0.6 * s, -0.24 * s), 0.024, 0.008, { k: 0.015 });
      c.cone(B[2], P(0.18 * s, 0.56 * s, -0.02 * s), 0.022, 0.008, { k: 0.015 });
    },
  },
  horn_antenna: {
    name: 'Antenne', cat: 'horns', icon: '🐞', hint: 'up', slot: 'secondary',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      const L = p.length;
      c.chain([P(0, -0.02, 0), P(0, 0.25 * L, 0.08 * L), P(0, 0.42 * L, 0.2 * L)], [0.022, 0.016, 0.012], { k: 0.02 });
      c.sphere(P(0, 0.44 * L, 0.22 * L), 0.045, { k: 0.015, slot: 'detail' });
    },
  },
  horn_crest: {
    name: 'Crête', cat: 'horns', icon: '🦖', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) { c.ell(P(0, 0.06, -0.05), [0.025, 0.18 * p.size, 0.28 * p.size], [P(1, 0, 0), P(0, 1, -0.35)], { k: 0.04 }); },
  },
  horn_unicorn: {
    name: 'Corne de licorne', cat: 'horns', icon: '🦄', hint: 'up', slot: 'detail',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      const L = p.length;
      c.cone(P(0, -0.03, 0), P(0, 0.55 * L, 0.1 * L), 0.065, 0.004, { k: 0.03 });
      for (let i = 1; i < 8; i++) {
        const t = i / 8;
        c.cone(P(0, 0.55 * L * t, 0.1 * L * t), P(0, 0.55 * L * (t + 0.03), 0.1 * L * (t + 0.03)), 0.067 * (1 - t) + 0.008, 0.067 * (1 - t), { k: 0.01 });
      }
    },
  },
  horn_rhino: {
    name: 'Corne de rhino', cat: 'horns', icon: '🦏', hint: 'up', slot: 'detail',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      const L = p.length;
      c.chain([P(0, -0.03, 0), P(0, 0.14 * L, 0.02 * L), P(0, 0.3 * L, -0.06 * L)], [0.1, 0.055, 0.005], { k: 0.05 });
    },
  },

  // ------------------------------------------------------------- EARS
  ear_pointy: {
    name: 'Oreille pointue', cat: 'ears', icon: '🐱', hint: 'fwd',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.tri(P(-0.12 * s, -0.03, 0), P(0.12 * s, -0.03, 0), P(0, 0.34 * s, -0.03 * s), 0.035, { k: 0.05 });
      c.tri(P(-0.07 * s, 0.03, 0.03), P(0.07 * s, 0.03, 0.03), P(0, 0.25 * s, 0.01), 0.015, { sub: true, slot: 'secondary', k: 0.012 });
    },
  },
  ear_round: {
    name: 'Oreille ronde', cat: 'ears', icon: '🐭', hint: 'fwd',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.13 * s, 0), [0.15 * s, 0.15 * s, 0.035], null, { k: 0.05 });
      c.ell(P(0, 0.14 * s, 0.035), [0.1 * s, 0.1 * s, 0.02], null, { sub: true, slot: 'secondary', k: 0.015 });
    },
  },
  ear_long: {
    name: 'Oreille de lapin', cat: 'ears', icon: '🐰', hint: 'fwd',
    params: { size: 1, bend: 0 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['bend', 'Pliure', -1, 1]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.3 * s, -0.08 * p.bend * s), [0.08 * s, 0.32 * s, 0.03], [P(1, 0, 0), P(0, 1, -0.5 * p.bend)], { k: 0.05 });
      c.ell(P(0, 0.3 * s, -0.08 * p.bend * s + 0.03), [0.045 * s, 0.24 * s, 0.018], [P(1, 0, 0), P(0, 1, -0.5 * p.bend)], { sub: true, slot: 'secondary', k: 0.01 });
    },
  },
  ear_elephant: {
    name: 'Oreille d\'éléphant', cat: 'ears', icon: '🐘', hint: 'fwd',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.2 * s, 0), [0.3 * s, 0.22 * s, 0.03], null, { k: 0.05 });
    },
  },
  ear_fin: {
    name: 'Oreille nageoire', cat: 'ears', icon: '🧝', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.tri(P(-0.08 * s, -0.02, 0), P(0.08 * s, -0.02, 0), P(0.2 * s, 0.35 * s, -0.02), 0.018, { k: 0.04 });
      c.cone(P(0.08 * s, -0.02, 0), P(0.2 * s, 0.35 * s, -0.02), 0.025, 0.01, { k: 0.02 });
    },
  },

  // ------------------------------------------------------------- WINGS / FINS
  wing_bat: {
    name: 'Aile de chauve-souris', cat: 'wings', icon: '🦇', hint: 'fwd', spread: true,
    params: { size: 1, spread: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['spread', 'Ouverture', 0.3, 1.3]],
    build(c, p) {
      const s = p.size, e = p.spread;
      const O = P(0, 0, 0), E = P(0, 0.42 * s, 0.1 * s), W = P(0, 0.8 * s * e, 0.02 * s);
      const T1 = P(0, 1.25 * s * e, -0.12 * s), T2 = P(0, 1.02 * s * e, -0.55 * s), T3 = P(0, 0.68 * s * e, -0.8 * s), B = P(0, 0, -0.55 * s);
      c.chain([O, E, W], [0.06, 0.04, 0.03], { k: 0.05 });
      for (const T of [T1, T2, T3]) c.cone(W, T, 0.022, 0.008, { k: 0.015 });
      const mem = { slot: 'secondary', k: 0.01 };
      c.tri(W, T1, T2, 0.012, mem);
      c.tri(W, T2, T3, 0.012, mem);
      c.tri(W, T3, B, 0.012, mem);
      c.tri(W, B, O, 0.012, mem);
      c.tri(O, E, W, 0.012, mem);
      c.cone(W, P(0, 0.86 * s * e, 0.12 * s), 0.02, 0.004, { slot: 'claw', k: 0.01 });
    },
  },
  wing_feather: {
    name: 'Aile à plumes', cat: 'wings', icon: '🪶', hint: 'fwd', spread: true,
    params: { size: 1, spread: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['spread', 'Ouverture', 0.3, 1.3]],
    build(c, p) {
      const s = p.size, e = p.spread;
      c.chain([P(0, 0, 0), P(0, 0.4 * s * e, 0.08 * s), P(0, 0.85 * s * e, 0)], [0.07, 0.05, 0.035], { k: 0.05 });
      const N = 8;
      for (let i = 0; i < N; i++) {
        const t = i / (N - 1);
        const base = P(0, (0.1 + 0.75 * t) * s * e, 0.05 * s * (1 - t));
        const ang = (0.1 + 0.9 * t * t) * (Math.PI / 2) * 0.95;
        const dir = [0, Math.sin(ang), -Math.cos(ang)];
        const L = (0.3 + 0.25 * t) * s;
        const cc = [base[0], base[1] + dir[1] * L * 0.55, base[2] + dir[2] * L * 0.55];
        c.ell(cc, [0.015, L * 0.6, 0.075 * s], [P(1, 0, 0), dir], { slot: 'secondary', k: 0.02 });
      }
    },
  },
  wing_insect: {
    name: 'Aile d\'insecte', cat: 'wings', icon: '🦋', hint: 'fwd', slot: 'secondary', spread: true,
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      const d1 = [0, 1, -0.3], d2 = [0, 1, -1.1];
      c.ell(P(0, 0.4 * s, -0.12 * s), [0.018, 0.42 * s, 0.13 * s], [P(1, 0, 0), d1], { k: 0.02 });
      c.ell(P(0, 0.22 * s, -0.3 * s), [0.018, 0.3 * s, 0.09 * s], [P(1, 0, 0), d2], { k: 0.02 });
    },
  },
  fin_dorsal: {
    name: 'Nageoire dorsale', cat: 'wings', icon: '🦈', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.tri(P(0, -0.05, 0.18 * s), P(0, -0.05, -0.35 * s), P(0, 0.45 * s, -0.42 * s), 0.02, { k: 0.05 });
      c.cone(P(0, -0.05, 0.18 * s), P(0, 0.45 * s, -0.42 * s), 0.035, 0.012, { k: 0.03 });
    },
  },
  fin_side: {
    name: 'Nageoire latérale', cat: 'wings', icon: '🐟', hint: 'fwd', slot: 'secondary', spread: true,
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.18 * s, -0.08 * s), [0.02, 0.22 * s, 0.09 * s], [P(1, 0, 0), P(0, 1, -0.5)], { k: 0.04 });
    },
  },
  fin_tail: {
    name: 'Queue de poisson', cat: 'wings', icon: '🐠', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.tri(P(0, -0.05, 0.06), P(0, -0.05, -0.06), P(0, 0.38 * s, 0.32 * s), 0.02, { k: 0.04 });
      c.tri(P(0, -0.05, 0.06), P(0, -0.05, -0.06), P(0, 0.38 * s, -0.32 * s), 0.02, { k: 0.04 });
      c.tri(P(0, 0.38 * s, 0.32 * s), P(0, 0.38 * s, -0.32 * s), P(0, 0.22 * s, 0), 0.02, { k: 0.02 });
    },
  },

  // ------------------------------------------------------------- TAILS
  tail_club: {
    name: 'Massue', cat: 'tails', icon: '🔨', hint: 'fwd',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.12 * s, 0), [0.17 * s, 0.14 * s, 0.14 * s], null, { k: 0.06, slot: 'detail' });
      for (const [x, z] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) c.cone(P(x * 0.12 * s, 0.12 * s, z * 0.1 * s), P(x * 0.24 * s, 0.14 * s, z * 0.2 * s), 0.04 * s, 0.004, { slot: 'claw', k: 0.02 });
    },
  },
  tail_thagomizer: {
    name: 'Pointes de stégo', cat: 'tails', icon: '🦕', hint: 'fwd', slot: 'claw',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      for (const sx of [-1, 1]) {
        c.cone(P(sx * 0.03, 0.0, 0.05), P(sx * 0.28 * s, 0.22 * s, 0.12 * s), 0.045, 0.004, { k: 0.02 });
        c.cone(P(sx * 0.03, 0.0, -0.08), P(sx * 0.25 * s, 0.25 * s, -0.18 * s), 0.045, 0.004, { k: 0.02 });
      }
    },
  },
  tail_fluff: {
    name: 'Touffe', cat: 'tails', icon: '🦊', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.15 * s, 0), [0.14 * s, 0.22 * s, 0.14 * s], null, { k: 0.08 });
      c.sphere(P(0, 0.34 * s, 0), 0.07 * s, { k: 0.06 });
    },
  },
  tail_stinger: {
    name: 'Dard de scorpion', cat: 'tails', icon: '🦂', hint: 'fwd',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.08 * s, 0), [0.09 * s, 0.1 * s, 0.09 * s], null, { k: 0.05 });
      c.chain([P(0, 0.14 * s, 0), P(0, 0.26 * s, 0.08 * s), P(0, 0.3 * s, 0.22 * s)], [0.05, 0.025, 0.004], { slot: 'claw', k: 0.02 });
    },
  },
  tail_fan: {
    name: 'Éventail', cat: 'tails', icon: '🦚', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      for (let i = 0; i < 7; i++) {
        const a = (i / 6 - 0.5) * Math.PI * 0.8;
        const dir = [0, Math.cos(a), Math.sin(a)];
        c.ell([0, dir[1] * 0.25 * s, dir[2] * 0.25 * s], [0.015, 0.26 * s, 0.07 * s], [P(1, 0, 0), dir], { k: 0.03 });
      }
    },
  },
  tail_leaf: {
    name: 'Feuille caudale', cat: 'tails', icon: '🍃', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) { const s = p.size; c.ell(P(0, 0.22 * s, 0), [0.02, 0.26 * s, 0.15 * s], null, { k: 0.05 }); },
  },

  // ------------------------------------------------------------- DETAILS
  spike: {
    name: 'Pique', cat: 'details', icon: '🔺', hint: 'fwd', slot: 'claw',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) { c.cone(P(0, -0.02, 0), P(0, 0.22 * p.length, -0.05 * p.length), 0.06, 0.004, { k: 0.03 }); },
  },
  spike_row: {
    name: 'Rangée de piques', cat: 'details', icon: '🦔', hint: 'fwd', slot: 'claw',
    params: { count: 5, length: 1, spacing: 1 },
    paramDefs: [['count', 'Nombre', 2, 10, 1], ['length', 'Longueur', 0.3, 3], ['spacing', 'Espacement', 0.4, 2]],
    build(c, p) {
      const n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const t = n === 1 ? 0.5 : i / (n - 1);
        const z = (0.5 - t) * 0.12 * (n - 1) * p.spacing;
        const h = (0.12 + 0.1 * Math.sin(t * Math.PI)) * p.length;
        c.cone(P(0, -0.03, z), P(0, h, z - h * 0.35), 0.05, 0.004, { k: 0.03 });
      }
    },
  },
  plate: {
    name: 'Plaque dorsale', cat: 'details', icon: '🔶', hint: 'fwd', slot: 'secondary',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.14 * s, -0.02), [0.025, 0.2 * s, 0.14 * s], [P(1, 0, 0), P(0, 1, -0.25)], { k: 0.04 });
    },
  },
  shell: {
    name: 'Carapace', cat: 'details', icon: '🐢', hint: 'fwd', slot: 'secondary',
    params: { size: 1, height: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['height', 'Hauteur', 0.3, 2]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, -0.02, 0), [0.45 * s, 0.22 * s * p.height, 0.55 * s], null, { k: 0.05 });
      for (const [x, z] of [[0, 0], [0.22, 0.2], [-0.22, 0.2], [0.22, -0.2], [-0.22, -0.2], [0, 0.35], [0, -0.35]]) {
        c.ell(P(x * s, 0.18 * s * p.height - Math.hypot(x, z) * 0.25 * s * p.height, z * s), [0.11 * s, 0.035 * s, 0.11 * s], null, { k: 0.03, slot: 'detail' });
      }
    },
  },
  bump: {
    name: 'Bosse / verrue', cat: 'details', icon: '🟤', hint: 'fwd',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 4]],
    build(c, p) { c.sphere(P(0, 0, 0), 0.06 * p.size, { k: 0.04 }); },
  },
  mane: {
    name: 'Crinière', cat: 'details', icon: '🦁', hint: 'fwd', slot: 'secondary',
    params: { size: 1, length: 1 },
    paramDefs: [['size', 'Volume', 0.4, 2.5], ['length', 'Longueur', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      for (let i = 0; i < 7; i++) {
        const t = i / 6;
        c.sphere(P(Math.sin(i * 2.3) * 0.05, 0.02 + 0.03 * Math.cos(i * 1.7), (0.3 - 0.6 * t) * p.length), (0.1 + 0.03 * Math.sin(i * 3.1)) * s, { k: 0.08 });
      }
    },
  },
  crystal: {
    name: 'Cristal', cat: 'details', icon: '💎', hint: 'fwd', slot: 'custom',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const s = p.size;
      c.cone(P(0, 0.1 * s, 0), P(0, 0.34 * s, 0), 0.08 * s, 0.004, { k: 0.005 });
      c.cone(P(0, 0.1 * s, 0), P(0, -0.04, 0), 0.08 * s, 0.03, { k: 0.02 });
      c.cone(P(0.07 * s, 0.05 * s, 0.03 * s), P(0.16 * s, 0.2 * s, 0.06 * s), 0.045 * s, 0.004, { k: 0.01 });
    },
  },
  shoulder_pad: {
    name: 'Épaulette / armure', cat: 'details', icon: '🛡️', hint: 'fwd', slot: 'detail',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.0, 0), [0.2 * s, 0.09 * s, 0.2 * s], null, { k: 0.02 });
      c.cone(P(0, 0.05 * s, 0), P(0, 0.2 * s, -0.05 * s), 0.05 * s, 0.004, { k: 0.015, slot: 'claw' });
    },
  },
  belly_scales: {
    name: 'Plaques ventrales', cat: 'details', icon: '🐊', hint: 'fwd', slot: 'detail',
    params: { count: 5, size: 1 },
    paramDefs: [['count', 'Nombre', 2, 10, 1], ['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const n = Math.round(p.count), s = p.size;
      for (let i = 0; i < n; i++) c.ell(P(0, 0, (i - (n - 1) / 2) * 0.12 * s), [0.16 * s, 0.03, 0.065 * s], null, { k: 0.02 });
    },
  },

  // ------------------------------------------------------------- HANDS (limb ends)
  hand_5: {
    name: 'Main à 5 doigts', cat: 'hands', icon: '✋', end: true,
    params: { finger: 1 },
    paramDefs: [['finger', 'Longueur des doigts', 0.5, 2]],
    build(c, p) {
      const F = p.finger;
      c.ell(P(0, 0.09, 0), [0.04, 0.1, 0.085], null, { k: 0.05 });
      for (let i = 0; i < 4; i++) {
        const z = -0.055 + i * 0.037;
        const L = (i === 1 || i === 2 ? 0.16 : 0.13) * F;
        c.chain([P(0, 0.16, z), P(0.01, 0.16 + L * 0.55, z * 1.1), P(0.03, 0.16 + L, z * 1.15)], [0.022, 0.019, 0.016], { k: 0.012 });
      }
      c.chain([P(0, 0.07, 0.06), P(0.03, 0.13, 0.12), P(0.05, 0.18, 0.15 * F)], [0.026, 0.021, 0.017], { k: 0.015 });
    },
  },
  hand_claw3: {
    name: 'Main à griffes', cat: 'hands', icon: '🐾', end: true,
    params: { finger: 1 },
    paramDefs: [['finger', 'Longueur des doigts', 0.5, 2]],
    build(c, p) {
      const F = p.finger;
      c.ell(P(0, 0.07, 0), [0.07, 0.09, 0.08], null, { k: 0.05 });
      for (const a of [-0.45, 0, 0.45]) {
        const d = [Math.sin(a) * 0.4, 1, Math.sin(a)];
        const b = P(d[0] * 0.05, 0.12, d[2] * 0.05), m = P(d[0] * 0.13 * F, 0.12 + 0.12 * F, d[2] * 0.12 * F);
        c.cone(b, m, 0.03, 0.022, { k: 0.015 });
        c.chain([m, P(m[0] * 1.2, m[1] + 0.08 * F, m[2] * 1.15 + 0.04), P(m[0] * 1.25, m[1] + 0.1 * F, m[2] * 1.2 + 0.1)], [0.022, 0.012, 0.003], { slot: 'claw', k: 0.008 });
      }
    },
  },
  hand_pincer: {
    name: 'Pince de crabe', cat: 'hands', icon: '🦀', end: true,
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.15 * s, 0), [0.08 * s, 0.16 * s, 0.1 * s], null, { k: 0.05 });
      c.chain([P(0, 0.26 * s, 0.05 * s), P(0, 0.43 * s, 0.07 * s), P(0, 0.52 * s, -0.01 * s)], [0.055 * s, 0.035 * s, 0.006], { k: 0.02 });
      c.chain([P(0, 0.25 * s, -0.06 * s), P(0, 0.39 * s, -0.09 * s), P(0, 0.46 * s, -0.04 * s)], [0.045 * s, 0.03 * s, 0.006], { k: 0.02 });
    },
  },
  hand_paw: {
    name: 'Patte ronde', cat: 'hands', icon: '🐻', end: true,
    params: {},
    build(c) {
      c.sphere(P(0, 0.06, 0.02), 0.09, { k: 0.05 });
      for (let i = 0; i < 4; i++) {
        const x = (i - 1.5) * 0.045;
        c.sphere(P(x, 0.12, 0.07), 0.035, { k: 0.02 });
        c.cone(P(x, 0.13, 0.1), P(x, 0.17, 0.13), 0.015, 0.003, { slot: 'claw', k: 0.008 });
      }
    },
  },
  hand_scythe: {
    name: 'Faux de mante', cat: 'hands', icon: '🗡️', end: true, slot: 'claw',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      c.chain([P(0, 0, 0), P(0, 0.22 * L, 0.02), P(0, 0.4 * L, 0.1 * L), P(0, 0.46 * L, 0.24 * L)], [0.05, 0.035, 0.02, 0.004], { k: 0.02 });
    },
  },
  hand_tentacle_sucker: {
    name: 'Ventouse', cat: 'hands', icon: '🐙', end: true,
    params: {},
    build(c) {
      c.cone(P(0, 0, 0), P(0, 0.07, 0), 0.06, 0.08, { k: 0.03 });
      c.sphere(P(0, 0.12, 0), 0.055, { sub: true, slot: 'secondary', k: 0.02 });
    },
  },

  // ------------------------------------------------------------- FEET (limb ends, flat on ground)
  foot_paw: {
    name: 'Patte à coussinets', cat: 'feet', icon: '🐾', end: true, ground: true,
    params: { toes: 4 },
    paramDefs: [['toes', 'Orteils', 2, 6, 1]],
    build(c, p) {
      c.ell(P(0, 0.02, 0.05), [0.11, 0.07, 0.13], null, { k: 0.05 });
      const n = Math.round(p.toes);
      for (let i = 0; i < n; i++) {
        const x = (i - (n - 1) / 2) * (0.2 / Math.max(1, n - 1)) * 1.2;
        c.sphere(P(x, 0.04, 0.16), 0.042, { k: 0.02 });
        c.cone(P(x, 0.03, 0.19), P(x, 0.05, 0.25), 0.02, 0.003, { slot: 'claw', k: 0.008 });
      }
    },
  },
  foot_hoof: {
    name: 'Sabot', cat: 'feet', icon: '🐴', end: true, ground: true, slot: 'dark',
    params: {},
    build(c) {
      c.cone(P(0, -0.04, 0.01), P(0, 0.07, 0.03), 0.07, 0.095, { k: 0.03 });
      c.box(P(0, 0.08, 0.1), [0.008, 0.05, 0.08], 0.004, null, { sub: true, k: 0.005 });
    },
  },
  foot_bird: {
    name: 'Serre d\'oiseau', cat: 'feet', icon: '🐔', end: true, ground: true,
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2]],
    build(c, p) {
      const L = p.length;
      c.sphere(P(0, 0.05, 0), 0.05, { k: 0.03 });
      for (const a of [-0.5, 0, 0.5]) {
        const tip = P(Math.sin(a) * 0.22 * L, 0.08, Math.cos(a) * 0.22 * L);
        c.cone(P(0, 0.06, 0), tip, 0.03, 0.018, { k: 0.015 });
        c.cone(tip, P(tip[0] * 1.2, 0.1, tip[2] * 1.2), 0.016, 0.003, { slot: 'claw', k: 0.006 });
      }
      c.cone(P(0, 0.06, 0), P(0, 0.08, -0.12 * L), 0.028, 0.012, { k: 0.015 });
    },
  },
  foot_human: {
    name: 'Pied humain', cat: 'feet', icon: '🦶', end: true, ground: true,
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2]],
    build(c, p) {
      const L = p.length;
      c.ell(P(0, 0.035, 0.06 * L), [0.075, 0.05, 0.15 * L], null, { k: 0.05 });
    },
  },
  foot_boot: {
    name: 'Botte', cat: 'feet', icon: '🥾', end: true, ground: true, slot: 'detail',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2]],
    build(c, p) {
      const L = p.length;
      c.cone(P(0, -0.08, 0), P(0, 0.02, 0), 0.085, 0.09, { k: 0.02 });
      c.box(P(0, 0.05, 0.06 * L), [0.085, 0.045, 0.16 * L], 0.04, null, { k: 0.04 });
      c.box(P(0, 0.095, 0.06 * L), [0.09, 0.01, 0.165 * L], 0.008, null, { k: 0.01, slot: 'dark' });
    },
  },
  foot_elephant: {
    name: 'Pied d\'éléphant', cat: 'feet', icon: '🐘', end: true, ground: true,
    params: {},
    build(c) {
      c.cone(P(0, -0.03, 0), P(0, 0.07, 0), 0.12, 0.14, { k: 0.04 });
      for (const a of [-0.5, 0, 0.5]) c.ell(P(Math.sin(a) * 0.13, 0.05, Math.cos(a) * 0.13), [0.035, 0.025, 0.02], [P(Math.cos(a), 0, -Math.sin(a)), P(0, 1, 0)], { slot: 'claw', k: 0.01 });
    },
  },
  foot_webbed: {
    name: 'Pied palmé', cat: 'feet', icon: '🐸', end: true, ground: true,
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2]],
    build(c, p) {
      const L = p.length;
      c.sphere(P(0, 0.05, 0), 0.05, { k: 0.03 });
      const tips = [-0.55, 0, 0.55].map((a) => P(Math.sin(a) * 0.24 * L, 0.08, Math.cos(a) * 0.24 * L));
      for (const t of tips) c.cone(P(0, 0.06, 0), t, 0.028, 0.016, { k: 0.015 });
      c.tri(P(0, 0.08, 0.02), tips[0], tips[1], 0.01, { slot: 'secondary', k: 0.01 });
      c.tri(P(0, 0.08, 0.02), tips[1], tips[2], 0.01, { slot: 'secondary', k: 0.01 });
    },
  },
};

// Limb templates. joints: offsets relative to the root joint, computed for a
// root at height h above the ground. radii per joint.
export const LIMBS = {
  leg: {
    name: 'Jambe', icon: '🦵', bone: 'Leg', end: 'foot_paw',
    make(h) {
      return { joints: [[0, 0, 0], [0.06, -h * 0.5, -0.1], [0.1, -h + 0.1, 0]], radii: [0.15, 0.11, 0.08] };
    },
  },
  leg_digi: {
    name: 'Patte arrière (digitigrade)', icon: '🐕', bone: 'Leg', end: 'foot_paw',
    make(h) {
      return { joints: [[0, 0, 0], [0.06, -h * 0.35, -0.16], [0.1, -h * 0.7, 0.14], [0.1, -h + 0.1, 0.02]], radii: [0.17, 0.12, 0.08, 0.065] };
    },
  },
  arm: {
    name: 'Bras', icon: '💪', bone: 'Arm', end: 'hand_5',
    make() {
      return { joints: [[0, 0, 0], [0.28, -0.3, 0.05], [0.33, -0.65, -0.05]], radii: [0.1, 0.075, 0.06] };
    },
  },
  leg_insect: {
    name: 'Patte d\'insecte', icon: '🦗', bone: 'Leg', end: 'none',
    make(h) {
      return { joints: [[0, 0, 0], [0.3, 0.2, 0], [0.62, 0.05, 0], [0.8, -h + 0.02, 0]], radii: [0.065, 0.05, 0.035, 0.012] };
    },
  },
  tentacle: {
    name: 'Tentacule', icon: '🐙', bone: 'Tentacle', end: 'none',
    make() {
      const joints = [], radii = [];
      for (let i = 0; i <= 6; i++) {
        joints.push([0.14 * i, -0.1 * i + 0.03 * Math.sin(i * 1.2), 0.06 * Math.sin(i * 1.3)]);
        radii.push(0.11 * (1 - i / 7) + 0.012);
      }
      return { joints, radii };
    },
  },
  wing_arm: {
    name: 'Bras-aile (ptérodactyle)', icon: '🦅', bone: 'Wing', end: 'hand_claw3',
    make() {
      return { joints: [[0, 0, 0], [0.4, 0.15, 0.05], [0.85, 0.05, 0.1]], radii: [0.09, 0.06, 0.045] };
    },
  },
  neck: {
    name: 'Cou / tige libre', icon: '🦒', bone: 'Stalk', end: 'none',
    make() {
      return { joints: [[0, 0, 0], [0, 0.3, -0.1], [0, 0.55, -0.15]], radii: [0.12, 0.09, 0.08] };
    },
  },
};
