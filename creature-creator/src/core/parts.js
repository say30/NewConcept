// Catalogue of parts. Every part is built in its own local frame:
//   +Y : out of the surface (along the limb for hands, down for feet)
//   +Z : "hint" direction (forward, or up for face parts)
//   +X : side
// Units are roughly world units at scale 1 (a typical head radius is ~0.35).
//
// A part is made of named pieces (c.piece(name, slot)); each piece becomes a
// separate mesh / MeshPart with its own colour. { body: true } targets the
// body instead (e.g. carving a mouth). Parts with `fuse: true` melt their skin
// coloured pieces into the body.

export const CATEGORIES = [
  ['limbs', 'Membres', '🦵'],
  ['shapes', 'Formes libres', '🔷'],
  ['eyes', 'Yeux', '👁️'],
  ['mouths', 'Bouches & nez', '👄'],
  ['horns', 'Cornes & antennes', '🦌'],
  ['ears', 'Oreilles', '👂'],
  ['hair', 'Poils & crêtes', '💈'],
  ['wings', 'Ailes & nageoires', '🪽'],
  ['tails', 'Bouts de queue', '🦂'],
  ['details', 'Détails & armures', '✨'],
  ['hands', 'Mains', '✋'],
  ['feet', 'Pieds', '🦶'],
];

const P = (x, y, z) => [x, y, z];
const TIP = 0.0015; // radius of sharp tips

function arc(n, f) {
  const pts = [];
  for (let i = 0; i <= n; i++) pts.push(f(i / n));
  return pts;
}
function taper(n, a, b, pow = 1) {
  const r = [];
  for (let i = 0; i <= n; i++) r.push(a + (b - a) * Math.pow(i / n, pow));
  return r;
}
const nrm = (v) => { const l = Math.hypot(v[0], v[1], v[2]) || 1; return [v[0] / l, v[1] / l, v[2] / l]; };
const lerp = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];

// smooth tube through control points (Catmull-Rom), radius r0 -> r1
function curve(c, ctrl, r0, r1, o = {}, n = 14, pow = 1) {
  const pts = [];
  const m = ctrl.length - 1;
  for (let i = 0; i <= n; i++) {
    const u = (i / n) * m, k = Math.min(m - 1, Math.floor(u)), t = u - k;
    const p0 = ctrl[Math.max(0, k - 1)], p1 = ctrl[k], p2 = ctrl[k + 1], p3 = ctrl[Math.min(m, k + 2)];
    const t2 = t * t, t3 = t2 * t;
    pts.push([0, 1, 2].map((j) => 0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2 + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)));
  }
  c.chain(pts, taper(n, r0, r1, pow), Object.assign({ k: 0.004 }, o));
}

// curved, sharp claw from `a` along `dir`, bending toward `bend`
function claw(c, a, dir, len, r, bend = [0, 0, -1], o = {}) {
  const d = nrm(dir);
  const pts = arc(4, (t) => [
    a[0] + d[0] * len * t + bend[0] * len * 0.35 * t * t,
    a[1] + d[1] * len * t + bend[1] * len * 0.35 * t * t,
    a[2] + d[2] * len * t + bend[2] * len * 0.35 * t * t,
  ]);
  c.chain(pts, taper(4, r, TIP, 0.8), Object.assign({ piece: 'Griffes', slot: 'claw', k: 0.003 }, o));
}

// mouth cavity carved into the body + a dark interior piece
function mouthCavity(c, W, D, H, y = 0) {
  c.ell(P(0, y, 0), [W, D, H], null, { body: true, op: 'sub', k: 0.02 });
  c.ell(P(0, y - D * 0.85, 0), [W * 0.96, D * 0.75, H * 0.95], null, { piece: 'Intérieur de la bouche', slot: 'mouth', k: 0.01 });
}

// generic eye parameters
const EYE_PARAMS = [['look', 'Regard vers l\'avant', 0, 1], ['iris', 'Taille iris', 0.2, 1.2], ['pupil', 'Pupille', 0.1, 0.95]];

export const PARTS = {
  // =============================================================== SHAPES
  shape_sphere: {
    name: 'Sphère', cat: 'shapes', icon: '⚪', hint: 'fwd', slot: 'secondary',
    params: { w: 1, h: 1, d: 1 },
    paramDefs: [['w', 'Largeur', 0.2, 4], ['h', 'Hauteur', 0.2, 4], ['d', 'Profondeur', 0.2, 4]],
    build(c, p) { c.ell(P(0, 0.1 * p.h, 0), [0.15 * p.w, 0.15 * p.h, 0.15 * p.d]); },
  },
  shape_hemisphere: {
    name: 'Dôme', cat: 'shapes', icon: '🌓', hint: 'fwd', slot: 'secondary',
    params: { w: 1, h: 1, d: 1 },
    paramDefs: [['w', 'Largeur', 0.2, 4], ['h', 'Hauteur', 0.2, 4], ['d', 'Profondeur', 0.2, 4]],
    build(c, p) {
      c.ell(P(0, -0.02, 0), [0.18 * p.w, 0.16 * p.h, 0.18 * p.d]);
      c.keep(P(0, -0.04, 0), [0, 1, 0]);
    },
  },
  shape_box: {
    name: 'Cube arrondi', cat: 'shapes', icon: '🟦', hint: 'fwd', slot: 'secondary',
    params: { w: 1, h: 1, d: 1, round: 0.3 },
    paramDefs: [['w', 'Largeur', 0.2, 4], ['h', 'Hauteur', 0.2, 4], ['d', 'Profondeur', 0.2, 4], ['round', 'Arrondi', 0, 1]],
    build(c, p) {
      const h = [0.13 * p.w, 0.13 * p.h, 0.13 * p.d];
      c.box(P(0, h[1] - 0.03, 0), h, Math.min(...h) * p.round);
    },
  },
  shape_cylinder: {
    name: 'Cylindre', cat: 'shapes', icon: '🥫', hint: 'fwd', slot: 'secondary',
    params: { r: 1, h: 1, round: 0.2 },
    paramDefs: [['r', 'Rayon', 0.2, 4], ['h', 'Hauteur', 0.2, 5], ['round', 'Arrondi', 0, 1]],
    build(c, p) {
      const R = 0.12 * p.r, H = 0.3 * p.h;
      c.cone(P(0, -0.1, 0), P(0, H + 0.1, 0), R, R, { k: 0 });
      c.keep(P(0, -0.03, 0), [0, 1, 0], { k: R * p.round * 0.5 });
      c.keep(P(0, H, 0), [0, -1, 0], { k: R * p.round * 0.5 });
    },
  },
  shape_cone: {
    name: 'Cône', cat: 'shapes', icon: '🔺', hint: 'fwd', slot: 'secondary',
    params: { r: 1, h: 1 },
    paramDefs: [['r', 'Rayon de base', 0.2, 4], ['h', 'Hauteur', 0.2, 5]],
    build(c, p) {
      c.cone(P(0, -0.1, 0), P(0, 0.35 * p.h, 0), 0.13 * p.r * (1 + 0.1 / (0.45 * p.h)), TIP, { k: 0 });
      c.keep(P(0, -0.03, 0), [0, 1, 0]);
    },
  },
  shape_capsule: {
    name: 'Capsule', cat: 'shapes', icon: '💊', hint: 'fwd', slot: 'secondary',
    params: { r: 1, h: 1, taper: 1 },
    paramDefs: [['r', 'Rayon', 0.2, 4], ['h', 'Longueur', 0.2, 5], ['taper', 'Bout (fin / gros)', 0.1, 2]],
    build(c, p) { c.cone(P(0, 0, 0), P(0, 0.35 * p.h, 0), 0.08 * p.r, 0.08 * p.r * p.taper); },
  },
  shape_torus: {
    name: 'Anneau (tore)', cat: 'shapes', icon: '🍩', hint: 'fwd', slot: 'secondary',
    params: { R: 1, r: 1 },
    paramDefs: [['R', 'Diamètre', 0.2, 4], ['r', 'Épaisseur', 0.2, 4]],
    build(c, p) { c.torus(P(0, 0.05, 0), 0.14 * p.R, 0.035 * p.r, [0, 0, 1]); },
  },
  shape_pyramid: {
    name: 'Pyramide', cat: 'shapes', icon: '🔼', hint: 'fwd', slot: 'secondary',
    params: { w: 1, h: 1 },
    paramDefs: [['w', 'Base', 0.2, 4], ['h', 'Hauteur', 0.2, 4]],
    build(c, p) {
      const W = 0.15 * p.w, H = 0.32 * p.h;
      c.box(P(0, H / 2 - 0.03, 0), [W, H / 2 + 0.03, W], 0, null, { k: 0 });
      for (const [x, z] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) c.keep(P(0, H - 0.03, 0), nrm([-x * H, -W, -z * H]), { k: 0.002 });
    },
  },
  shape_wedge: {
    name: 'Lame / aileron', cat: 'shapes', icon: '🔪', hint: 'fwd', slot: 'secondary',
    params: { w: 1, h: 1, t: 1 },
    paramDefs: [['w', 'Longueur', 0.2, 4], ['h', 'Hauteur', 0.2, 4], ['t', 'Épaisseur', 0.3, 4]],
    build(c, p) { c.tri(P(0, -0.04, 0.18 * p.w), P(0, -0.04, -0.18 * p.w), P(0, 0.34 * p.h, -0.14 * p.w), 0.012 * p.t, { k: 0 }); },
  },
  shape_star: {
    name: 'Étoile', cat: 'shapes', icon: '⭐', hint: 'fwd', slot: 'custom',
    params: { size: 1, t: 1 },
    paramDefs: [['size', 'Taille', 0.2, 4], ['t', 'Épaisseur', 0.3, 4]],
    build(c, p) {
      const R = 0.18 * p.size, th = 0.02 * p.t;
      for (let i = 0; i < 5; i++) {
        const a = (i / 5) * Math.PI * 2, a1 = a + Math.PI / 5, a2 = a - Math.PI / 5;
        const tip = P(Math.sin(a) * R, 0.2 * p.size + Math.cos(a) * R, 0);
        c.tri(P(0, 0.2 * p.size, 0), tip, P(Math.sin(a1) * R * 0.4, 0.2 * p.size + Math.cos(a1) * R * 0.4, 0), th, { k: 0 });
        c.tri(P(0, 0.2 * p.size, 0), tip, P(Math.sin(a2) * R * 0.4, 0.2 * p.size + Math.cos(a2) * R * 0.4, 0), th, { k: 0 });
      }
    },
  },

  // =============================================================== EYES
  eye_round: {
    name: 'Œil rond', cat: 'eyes', icon: '👁️', hint: 'up',
    params: { look: 0.55, iris: 0.6, pupil: 0.45 }, paramDefs: EYE_PARAMS,
    build(c, p) { c.eye(P(0, 0.02, 0), 0.1, { look: p.look, irisSize: p.iris, pupil: p.pupil }); },
  },
  eye_big: {
    name: 'Gros œil mignon', cat: 'eyes', icon: '🥺', hint: 'up',
    params: { look: 0.5, iris: 0.8, pupil: 0.55 }, paramDefs: EYE_PARAMS,
    build(c, p) {
      c.eye(P(0, 0.03, 0), 0.16, { look: p.look, irisSize: p.iris, pupil: p.pupil, highlightSize: 1.3 });
    },
  },
  eye_sparkle: {
    name: 'Œil étoilé (cartoon)', cat: 'eyes', icon: '🤩', hint: 'up',
    params: { look: 0.5, iris: 0.95, pupil: 0.5 }, paramDefs: EYE_PARAMS,
    build(c, p) {
      c.eye(P(0, 0.03, 0), 0.15, { look: p.look, irisSize: p.iris, pupil: p.pupil, highlightSize: 1.6 });
      // second small highlight
      const d = nrm([0.25, 1, -0.35]);
      c.sphere(P(d[0] * 0.152, 0.03 + d[1] * 0.152, d[2] * 0.152), 0.012, { piece: 'Reflet', slot: 'highlight', k: 0.001 });
    },
  },
  eye_cat: {
    name: 'Œil de chat', cat: 'eyes', icon: '🐈', hint: 'up',
    params: { look: 0.55, iris: 0.95, pupil: 0.35 }, paramDefs: EYE_PARAMS,
    build(c, p) { c.eye(P(0, 0.02, 0), 0.11, { look: p.look, irisSize: p.iris, pupil: p.pupil, slit: true }); },
  },
  eye_reptile: {
    name: 'Œil reptile', cat: 'eyes', icon: '🦎', hint: 'up',
    params: { look: 0.5, brow: 1 },
    paramDefs: [['look', 'Regard vers l\'avant', 0, 1], ['brow', 'Arcade', 0, 2]],
    build(c, p) {
      c.eye(P(0, 0.02, 0), 0.1, { look: p.look, irisSize: 1.0, pupil: 0.3, slit: true });
      if (p.brow > 0.05) c.ell(P(0, 0.035, 0.075), [0.13, 0.05 * p.brow, 0.05], [P(1, 0, 0), P(0, 1, 0.3)], { piece: 'Arcade', slot: 'base', k: 0.02 });
    },
  },
  eye_angry: {
    name: 'Œil féroce', cat: 'eyes', icon: '😠', hint: 'up',
    params: { look: 0.6, iris: 0.55, pupil: 0.35 }, paramDefs: EYE_PARAMS,
    build(c, p) {
      c.eye(P(0, 0.02, 0), 0.1, { look: p.look, irisSize: p.iris, pupil: p.pupil });
      c.ell(P(0, 0.06, 0.07), [0.15, 0.05, 0.045], [P(1, 0, -0.45), P(0, 1, 0)], { piece: 'Sourcil', slot: 'base', k: 0.02 });
    },
  },
  eye_sleepy: {
    name: 'Œil paupière', cat: 'eyes', icon: '😌', hint: 'up',
    params: { lid: 0.45, look: 0.5, iris: 0.7 },
    paramDefs: [['lid', 'Fermeture', 0, 1], ['look', 'Regard vers l\'avant', 0, 1], ['iris', 'Taille iris', 0.2, 1.2]],
    build(c, p) {
      c.eye(P(0, 0.02, 0), 0.12, { look: p.look, irisSize: p.iris, pupil: 0.5 });
      c.sphere(P(0, 0.02, 0), 0.128, { piece: 'Paupière', slot: 'base', k: 0.002 });
      c.keep(P(0, 0.02, 0.12 - 0.24 * p.lid), [0, 0.25, 1], { piece: 'Paupière' });
    },
  },
  eye_sad: {
    name: 'Œil triste', cat: 'eyes', icon: '🥹', hint: 'up',
    params: { look: 0.5, iris: 0.8 },
    paramDefs: [['look', 'Regard vers l\'avant', 0, 1], ['iris', 'Taille iris', 0.2, 1.2]],
    build(c, p) {
      c.eye(P(0, 0.02, 0), 0.12, { look: p.look, irisSize: p.iris, pupil: 0.55, highlightSize: 1.4 });
      c.sphere(P(0, 0.02, 0), 0.128, { piece: 'Paupière', slot: 'base', k: 0.002 });
      c.keep(P(0, 0.02, 0.05), nrm([0.5, 0.2, 1]), { piece: 'Paupière' });
    },
  },
  eye_cyclops: {
    name: 'Œil de cyclope', cat: 'eyes', icon: '🧿', hint: 'up',
    params: { look: 0.7, iris: 0.6, pupil: 0.45, lid: 0.25 },
    paramDefs: [...EYE_PARAMS, ['lid', 'Paupières', 0, 0.8]],
    build(c, p) {
      c.eye(P(0, 0.04, 0), 0.22, { look: p.look, irisSize: p.iris, pupil: p.pupil, highlightSize: 1.2 });
      c.sphere(P(0, 0.04, 0), 0.232, { piece: 'Paupières', slot: 'base', k: 0.002 });
      c.keep(P(0, 0.04, 0.23 - 0.2 * p.lid), [0, 0, 1], { piece: 'Paupières' });
      c.sphere(P(0, 0.04, 0), 0.232, { piece: 'Paupière basse', slot: 'base', k: 0.002 });
      c.keep(P(0, 0.04, -0.2 + 0.1 * p.lid), [0, 0, -1], { piece: 'Paupière basse' });
    },
  },
  eye_stalk: {
    name: 'Œil pédonculé', cat: 'eyes', icon: '🐌', hint: 'up',
    params: { length: 1, look: 0.9 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5], ['look', 'Regard vers l\'avant', 0, 1]],
    build(c, p) {
      const L = 0.32 * p.length;
      c.piece('Tige', 'base');
      c.cone(P(0, -0.03, 0), P(0, L, 0.05), 0.05, 0.03, { k: 0.02 });
      c.eye(P(0, L + 0.06, 0.06), 0.08, { look: p.look, irisSize: 0.65 });
    },
  },
  eye_insect: {
    name: 'Œil composé', cat: 'eyes', icon: '🪰', hint: 'up', slot: 'eye', pieceName: 'Œil composé',
    params: { bumps: 1 },
    paramDefs: [['bumps', 'Facettes', 0, 1]],
    build(c, p) {
      c.ell(P(0, 0.02, 0), [0.12, 0.09, 0.14]);
      if (p.bumps > 0.1) {
        for (let i = 0; i < 26; i++) {
          const a = i * 2.39996, t = (i + 0.5) / 26;
          const r = Math.sqrt(t) * 0.95;
          const x = Math.cos(a) * r * 0.12, z = Math.sin(a) * r * 0.14;
          const y = 0.02 + 0.09 * Math.sqrt(Math.max(0, 1 - r * r));
          c.sphere(P(x, y, z), 0.022 * p.bumps, { k: 0.004 });
        }
      }
    },
  },
  eye_cluster: {
    name: 'Grappe d\'yeux', cat: 'eyes', icon: '🕷️', hint: 'up',
    params: { count: 3 },
    paramDefs: [['count', 'Nombre', 2, 6, 1]],
    build(c, p) {
      const n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2 + 0.3;
        const r = n > 2 ? 0.08 : 0.06;
        c.eye(P(Math.cos(a) * r, 0.01, Math.sin(a) * r), 0.055 - 0.004 * n, { look: 0.6, irisSize: 1.1, pupil: 0.8 });
      }
    },
  },
  eye_robot: {
    name: 'Œil robot', cat: 'eyes', icon: '🤖', hint: 'up',
    params: { look: 0.6 },
    paramDefs: [['look', 'Regard vers l\'avant', 0, 1]],
    build(c, p) {
      c.torus(P(0, 0.03, 0), 0.1, 0.022, [0, 1, 0], { piece: 'Contour', slot: 'detail', k: 0.002 });
      c.eye(P(0, 0.0, 0), 0.105, { look: p.look * 0.2, irisSize: 0.9, pupil: 0.4, whiteSlot: 'dark' });
    },
  },
  eye_hollow: {
    name: 'Orbite lumineuse', cat: 'eyes', icon: '💀', hint: 'up',
    params: { glow: 1 },
    paramDefs: [['glow', 'Taille lueur', 0.3, 2]],
    build(c, p) {
      c.ell(P(0, 0, 0), [0.11, 0.07, 0.09], null, { body: true, op: 'sub', k: 0.02 });
      c.ell(P(0, -0.07, 0), [0.1, 0.05, 0.08], null, { piece: 'Orbite', slot: 'dark', k: 0.01 });
      c.sphere(P(0, -0.03, 0), 0.025 * p.glow, { piece: 'Lueur', slot: 'eye', k: 0.002 });
    },
  },

  // =============================================================== MOUTHS & NOSES
  mouth_smile: {
    name: 'Bouche', cat: 'mouths', icon: '🙂', hint: 'up',
    params: { width: 1, open: 1 },
    paramDefs: [['width', 'Largeur', 0.4, 2.5], ['open', 'Ouverture', 0.2, 3]],
    build(c, p) { mouthCavity(c, 0.2 * p.width, 0.08, 0.035 * p.open); },
  },
  mouth_tongue: {
    name: 'Bouche tirant la langue', cat: 'mouths', icon: '😛', hint: 'up',
    params: { width: 1, tongue: 1 },
    paramDefs: [['width', 'Largeur', 0.4, 2.5], ['tongue', 'Langue', 0.3, 2.5]],
    build(c, p) {
      mouthCavity(c, 0.18 * p.width, 0.08, 0.05);
      c.ell(P(0, 0.02 * p.tongue, -0.04), [0.07, 0.1 * p.tongue, 0.025], [P(1, 0, 0), P(0, 1, -0.5)], { piece: 'Langue', slot: 'tongue', k: 0.01 });
    },
  },
  mouth_teeth: {
    name: 'Mâchoire à dents', cat: 'mouths', icon: '🦷', hint: 'up',
    params: { width: 1, open: 1, teeth: 6, length: 1 },
    paramDefs: [['width', 'Largeur', 0.5, 2.5], ['open', 'Ouverture', 0.4, 3], ['teeth', 'Nombre de dents', 2, 14, 1], ['length', 'Longueur des dents', 0.3, 2]],
    build(c, p) {
      const W = 0.2 * p.width, H = 0.055 * p.open;
      mouthCavity(c, W, 0.1, H, -0.01);
      const n = Math.round(p.teeth);
      c.piece('Dents', 'teeth');
      for (let i = 0; i < n; i++) {
        const t = n === 1 ? 0.5 : i / (n - 1);
        const x = (t - 0.5) * 1.6 * W;
        const f = Math.sqrt(Math.max(0, 1 - (x / W) ** 2));
        const L = H * (0.75 + (i === 1 || i === n - 2 ? 0.45 : 0)) * p.length;
        c.cone(P(x, -0.035 * f, H * f + 0.01), P(x, -0.012 * f, H * f + 0.01 - L), 0.02, TIP, { k: 0.002 });
        c.cone(P(x, -0.035 * f, -H * f - 0.01), P(x, -0.012 * f, -H * f - 0.01 + L * 0.8), 0.018, TIP, { k: 0.002 });
      }
    },
  },
  mouth_fangs: {
    name: 'Crocs de vampire', cat: 'mouths', icon: '🧛', hint: 'up',
    params: { length: 1, width: 1 },
    paramDefs: [['length', 'Longueur des crocs', 0.4, 3], ['width', 'Largeur bouche', 0.4, 2.5]],
    build(c, p) {
      mouthCavity(c, 0.17 * p.width, 0.08, 0.03);
      c.piece('Crocs', 'teeth');
      for (const s of [-1, 1]) {
        const x = s * 0.09 * p.width;
        c.chain([P(x, -0.02, 0.05), P(x, 0.004, -0.02), P(x * 1.02, 0.008, -0.03 - 0.11 * p.length)], [0.024, 0.017, TIP], { k: 0.002 });
      }
    },
  },
  mouth_shark: {
    name: 'Gueule de requin', cat: 'mouths', icon: '🦈', hint: 'up',
    params: { width: 1, open: 1, teeth: 9 },
    paramDefs: [['width', 'Largeur', 0.5, 2.5], ['open', 'Ouverture', 0.4, 3], ['teeth', 'Dents par rangée', 4, 16, 1]],
    build(c, p) {
      const W = 0.22 * p.width, H = 0.07 * p.open;
      mouthCavity(c, W, 0.12, H, -0.01);
      c.piece('Dents', 'teeth');
      const n = Math.round(p.teeth);
      for (const row of [1, -1]) {
        for (let i = 0; i < n; i++) {
          const t = (i + 0.5) / n;
          const x = (t - 0.5) * 1.8 * W;
          const f = Math.sqrt(Math.max(0, 1 - (x / W) ** 2));
          const z0 = row * (H * f + 0.008);
          const L = H * 0.8 * (0.6 + 0.4 * f);
          const w = (1.6 * W) / n * 0.45;
          c.tri(P(x - w, -0.02 * f, z0), P(x + w, -0.02 * f, z0), P(x, -0.012 * f, z0 - row * L), 0.006, { k: 0.001 });
        }
      }
    },
  },
  mouth_beak: {
    name: 'Bec crochu', cat: 'mouths', icon: '🦅', hint: 'up', slot: 'detail', pieceName: 'Bec',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      curve(c, [P(0, -0.04, 0.02), P(0, 0.12 * L, 0.02), P(0, 0.24 * L, -0.01), P(0, 0.3 * L, -0.06), P(0, 0.29 * L, -0.12)], 0.12, TIP, { k: 0.02 }, 16, 0.75);
      c.piece('Bec inférieur', 'detail');
      curve(c, [P(0, -0.04, -0.07), P(0, 0.1 * L, -0.08), P(0, 0.2 * L, -0.085)], 0.085, TIP, { k: 0.02 }, 10, 0.8);
    },
  },
  mouth_parrot: {
    name: 'Bec de perroquet', cat: 'mouths', icon: '🦜', hint: 'up', slot: 'detail', pieceName: 'Bec',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      const up = arc(8, (t) => { const a = t * 2.2; return P(0, Math.sin(a) * 0.17 * s, 0.06 * s - (1 - Math.cos(a)) * 0.13 * s); });
      c.chain(up, taper(8, 0.13 * s, TIP, 0.9), { k: 0.02 });
      c.piece('Bec inférieur', 'dark');
      c.chain([P(0, -0.02, -0.09 * s), P(0, 0.09 * s, -0.1 * s), P(0, 0.12 * s, -0.08 * s)], [0.07 * s, 0.035 * s, TIP], { k: 0.02 });
    },
  },
  mouth_bill: {
    name: 'Bec de canard', cat: 'mouths', icon: '🦆', hint: 'up', slot: 'detail', pieceName: 'Bec',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      c.ell(P(0, 0.18 * L, 0), [0.14, 0.24 * L, 0.04], null, { k: 0.05 });
      c.ell(P(0, 0.16 * L, -0.065), [0.12, 0.22 * L, 0.03], null, { k: 0.02 });
      c.box(P(0, 0.2 * L, -0.035), [0.2, 0.3 * L, 0.006], 0.003, null, { op: 'sub', k: 0.004 });
    },
  },
  mouth_snout: {
    name: 'Museau', cat: 'mouths', icon: '🐶', hint: 'up', fuse: true, pieceName: 'Museau',
    params: { length: 1, nose: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5], ['nose', 'Taille truffe', 0.3, 2]],
    build(c, p) {
      const L = p.length, N = p.nose;
      c.ell(P(0, 0.12 * L, 0), [0.14, 0.18 * L, 0.12], null, { k: 0.08 });
      c.piece('Truffe', 'dark');
      c.ell(P(0, 0.285 * L, 0.045), [0.07 * N, 0.05 * N, 0.05 * N], null, { k: 0.01 });
      for (const s of [-1, 1]) c.sphere(P(s * 0.03 * N, 0.285 * L + 0.05 * N, 0.04), 0.017 * N, { op: 'sub', k: 0.008 });
      c.ell(P(0, 0.2 * L, -0.085), [0.11, 0.16 * L, 0.012], null, { body: true, op: 'sub', k: 0.01 });
    },
  },
  mouth_pig: {
    name: 'Groin', cat: 'mouths', icon: '🐷', hint: 'up', pieceName: 'Groin', slot: 'base',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.cone(P(0, -0.03, 0), P(0, 0.12 * s, 0), 0.1 * s, 0.09 * s, { k: 0.03 });
      for (const x of [-1, 1]) c.ell(P(x * 0.036 * s, 0.13 * s, 0), [0.022 * s, 0.05 * s, 0.032 * s], null, { op: 'sub', k: 0.006 });
    },
  },
  nose_round: {
    name: 'Nez rond', cat: 'mouths', icon: '🔴', hint: 'up', slot: 'dark', pieceName: 'Nez',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 3]],
    build(c, p) { c.sphere(P(0, 0.02, 0), 0.06 * p.size, { k: 0.02 }); },
  },
  nose_long: {
    name: 'Long nez', cat: 'mouths', icon: '🤥', hint: 'up', slot: 'base', pieceName: 'Nez',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) { c.chain([P(0, -0.02, 0), P(0, 0.12 * p.length, -0.01), P(0, 0.22 * p.length, -0.04)], [0.06, 0.04, 0.025], { k: 0.02 }); },
  },
  nose_cat: {
    name: 'Truffe de chat', cat: 'mouths', icon: '🐱', hint: 'up', slot: 'tongue', pieceName: 'Truffe',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const s = p.size;
      c.tri(P(-0.04 * s, 0.01, 0.02 * s), P(0.04 * s, 0.01, 0.02 * s), P(0, 0.01, -0.03 * s), 0.018 * s, { k: 0.005 });
    },
  },
  mouth_mandibles: {
    name: 'Mandibules', cat: 'mouths', icon: '🐜', hint: 'up', slot: 'detail', pieceName: 'Mandibules',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      for (const s of [-1, 1]) curve(c, [P(s * 0.07, -0.03, 0), P(s * 0.13, 0.12 * L, -0.02), P(s * 0.1, 0.24 * L, -0.03), P(s * 0.02, 0.3 * L, -0.03)], 0.045, TIP, {}, 16, 0.9);
    },
  },
  mouth_tusks: {
    name: 'Défenses', cat: 'mouths', icon: '🐗', hint: 'up', slot: 'claw', pieceName: 'Défenses',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 3]],
    build(c, p) {
      const L = p.length;
      for (const s of [-1, 1]) curve(c, [P(s * 0.1, -0.03, -0.04), P(s * 0.13, 0.12 * L, -0.12 * L), P(s * 0.16, 0.24 * L, -0.08 * L), P(s * 0.17, 0.3 * L, 0.05 * L)], 0.045, TIP, {}, 16, 0.9);
    },
  },
  mouth_walrus: {
    name: 'Défenses de morse', cat: 'mouths', icon: '🦭', hint: 'up', slot: 'claw', pieceName: 'Défenses',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 3]],
    build(c, p) {
      for (const s of [-1, 1]) curve(c, [P(s * 0.07, -0.02, -0.03), P(s * 0.075, 0.05, -0.2 * p.length), P(s * 0.07, 0.06, -0.38 * p.length)], 0.032, TIP, {}, 12, 0.9);
      mouthCavity(c, 0.13, 0.06, 0.022, 0);
    },
  },
  mouth_trunk: {
    name: 'Trompe', cat: 'mouths', icon: '🐘', hint: 'up', fuse: true, pieceName: 'Trompe',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      curve(c, [P(0, -0.02, 0), P(0, 0.15, -0.02 * L), P(0, 0.27, -0.1 * L), P(0, 0.33, -0.25 * L), P(0, 0.33, -0.4 * L), P(0, 0.3, -0.52 * L), P(0, 0.34, -0.6 * L)], 0.11, 0.05, { k: 0.02 }, 18);
      c.sphere(P(0, 0.37, -0.61 * L), 0.028, { op: 'sub', k: 0.01 });
    },
  },
  mouth_sucker: {
    name: 'Ventouse buccale', cat: 'mouths', icon: '🪱', hint: 'up', pieceName: 'Lèvre',
    params: {},
    build(c) {
      c.torus(P(0, 0.05, 0), 0.11, 0.04, [0, 1, 0], { k: 0.01 });
      mouthCavity(c, 0.1, 0.1, 0.1, 0.02);
      c.piece('Dents', 'teeth');
      for (let i = 0; i < 12; i++) {
        const a = (i / 12) * Math.PI * 2;
        const x = Math.cos(a), z = Math.sin(a);
        c.cone(P(x * 0.1, 0.06, z * 0.1), P(x * 0.055, 0.04, z * 0.055), 0.016, TIP, { k: 0.001 });
      }
    },
  },

  // =============================================================== HORNS
  horn_straight: {
    name: 'Corne droite', cat: 'horns', icon: '📍', hint: 'up', slot: 'detail', pieceName: 'Corne',
    params: { length: 1, thick: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['thick', 'Épaisseur', 0.4, 2]],
    build(c, p) { c.cone(P(0, -0.04, 0), P(0, 0.35 * p.length, 0), 0.07 * p.thick, TIP, { k: 0.02 }); },
  },
  horn_curved: {
    name: 'Corne courbée', cat: 'horns', icon: '🐂', hint: 'up', slot: 'detail', pieceName: 'Corne',
    params: { length: 1, curve: 1, thick: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['curve', 'Courbure', -2, 2.5], ['thick', 'Épaisseur', 0.4, 2]],
    build(c, p) {
      const R = 0.38 * p.length, A = 1.1 * p.curve;
      const pts = arc(10, (t) => {
        const a = t * A;
        if (Math.abs(A) < 1e-3) return P(0, R * t - 0.03, 0);
        const rr = R / A;
        return P(0, rr * Math.sin(a) - 0.03, -rr * (1 - Math.cos(a)));
      });
      c.chain(pts, taper(10, 0.075 * p.thick, TIP, 0.85), { k: 0.01 });
    },
  },
  horn_demon: {
    name: 'Corne de démon', cat: 'horns', icon: '😈', hint: 'up', slot: 'detail', pieceName: 'Corne',
    params: { length: 1, thick: 1, spread: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['thick', 'Épaisseur', 0.4, 2], ['spread', 'Écartement', -1, 2]],
    build(c, p) {
      const L = 0.4 * p.length;
      const pts = arc(10, (t) => P(-Math.sin(t * 1.6) * L * 0.35 * p.spread, -0.03 + t * L, -Math.sin(t * 2.6) * L * 0.18));
      c.chain(pts, taper(10, 0.08 * p.thick, TIP, 0.8), { k: 0.01 });
    },
  },
  horn_twisted: {
    name: 'Corne torsadée', cat: 'horns', icon: '🌀', hint: 'up', slot: 'detail', pieceName: 'Corne',
    params: { length: 1, thick: 1, turns: 2 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['thick', 'Épaisseur', 0.4, 2], ['turns', 'Tours', 0.5, 5]],
    build(c, p) {
      const L = 0.45 * p.length, N = 36, T = p.thick;
      for (const ph of [0, Math.PI]) {
        const pts = arc(N, (t) => {
          const a = t * p.turns * Math.PI * 2 + ph, rad = 0.038 * T * (1 - t);
          return P(Math.cos(a) * rad, -0.03 + t * L, Math.sin(a) * rad - t * t * L * 0.25);
        });
        c.chain(pts, taper(N, 0.04 * T, TIP, 0.9), { k: 0.004 });
      }
    },
  },
  horn_ram: {
    name: 'Corne de bélier', cat: 'horns', icon: '🐏', hint: 'up', slot: 'detail', pieceName: 'Corne',
    params: { size: 1, turns: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['turns', 'Enroulement', 0.4, 1.4]],
    build(c, p) {
      const N = 20, tot = 1.75 * Math.PI * p.turns;
      const pts = arc(N, (t) => {
        const th = t * tot, a = 0.2 * p.size * (1 - 0.25 * th / Math.PI);
        return P(-0.07 * t * p.size, a * Math.sin(th) - 0.02, -a * (1 - Math.cos(th)));
      });
      c.chain(pts, taper(N, 0.085 * p.size, 0.018 * p.size), { k: 0.01 });
      // growth rings
      c.piece('Anneaux', 'detail');
      for (let i = 2; i < N - 2; i += 3) c.sphere(pts[i], (0.085 * p.size + (0.018 - 0.085) * p.size * (i / N)) * 1.06, { k: 0.005 });
    },
  },
  horn_antler: {
    name: 'Bois de cerf', cat: 'horns', icon: '🦌', hint: 'up', slot: 'detail', pieceName: 'Bois',
    params: { size: 1, tines: 3 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['tines', 'Pointes', 1, 5, 1]],
    build(c, p) {
      const s = p.size;
      const B = arc(6, (t) => P(0.05 * s * t, -0.03 + 0.65 * s * t, -0.14 * s * Math.sin(t * 2.2)));
      c.chain(B, taper(6, 0.045, 0.012), { k: 0.01 });
      const n = Math.round(p.tines);
      for (let i = 0; i < n; i++) {
        const t = 0.3 + (0.6 * i) / Math.max(1, n - 1 || 1);
        const base = lerp(B[Math.floor(t * 6)], B[Math.min(6, Math.floor(t * 6) + 1)], (t * 6) % 1);
        const dir = i % 2 ? [0.4, 0.8, -0.5] : [0.1, 0.7, 0.7];
        const L = 0.2 * s * (1 - 0.3 * t);
        c.chain([base, P(base[0] + dir[0] * L * 0.5, base[1] + dir[1] * L * 0.5, base[2] + dir[2] * L * 0.5), P(base[0] + dir[0] * L, base[1] + dir[1] * L * 1.1, base[2] + dir[2] * L)], [0.026 * (1.2 - t), 0.016, TIP], { k: 0.01 });
      }
    },
  },
  horn_antenna: {
    name: 'Antenne', cat: 'horns', icon: '🐞', hint: 'up', slot: 'secondary', pieceName: 'Antenne',
    params: { length: 1, ball: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['ball', 'Boule', 0, 2]],
    build(c, p) {
      const L = p.length;
      c.chain([P(0, -0.03, 0), P(0, 0.25 * L, 0.08 * L), P(0, 0.42 * L, 0.2 * L)], [0.02, 0.014, p.ball > 0.05 ? 0.01 : TIP], { k: 0.01 });
      if (p.ball > 0.05) c.sphere(P(0, 0.44 * L, 0.22 * L), 0.04 * p.ball, { piece: 'Boule', slot: 'detail', k: 0.005 });
    },
  },
  horn_feeler: {
    name: 'Antenne plumeuse', cat: 'horns', icon: '🦋', hint: 'up', slot: 'secondary', pieceName: 'Antenne',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      const L = p.length;
      const B = arc(8, (t) => P(0, -0.03 + 0.45 * L * t, 0.15 * L * Math.sin(t * 2)));
      c.chain(B, taper(8, 0.018, 0.008), { k: 0.006 });
      for (let i = 2; i <= 8; i++) {
        const b = B[i];
        for (const s of [-1, 1]) c.cone(b, P(b[0] + s * 0.06 * L, b[1] + 0.02, b[2] - 0.02), 0.007, TIP, { k: 0.003 });
      }
    },
  },
  horn_crest: {
    name: 'Crête', cat: 'horns', icon: '🦖', hint: 'fwd', slot: 'secondary', pieceName: 'Crête',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) { c.ell(P(0, 0.05, -0.05), [0.025, 0.18 * p.size, 0.28 * p.size], [P(1, 0, 0), P(0, 1, -0.35)], { k: 0.02 }); },
  },
  horn_unicorn: {
    name: 'Corne de licorne', cat: 'horns', icon: '🦄', hint: 'up', slot: 'detail', pieceName: 'Corne',
    params: { length: 1, turns: 5 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['turns', 'Spirales', 2, 9]],
    build(c, p) {
      const L = 0.55 * p.length, tip = P(0, L - 0.03, 0.1 * p.length);
      c.cone(P(0, -0.03, 0), tip, 0.06, TIP, { k: 0.004 });
      // spiral ridge winding up the horn
      const N = 60;
      const pts = arc(N, (t) => {
        const a = t * p.turns * Math.PI * 2, r = 0.06 * (1 - t) * 0.98;
        const ax = lerp(P(0, -0.03, 0), tip, t);
        return P(ax[0] + Math.cos(a) * r, ax[1], ax[2] + Math.sin(a) * r);
      });
      c.chain(pts.slice(0, N - 4), taper(N - 5, 0.014, 0.004), { k: 0.004 });
    },
  },
  horn_rhino: {
    name: 'Corne de rhino', cat: 'horns', icon: '🦏', hint: 'up', slot: 'detail', pieceName: 'Corne',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      const L = p.length;
      c.chain(arc(6, (t) => P(0, -0.04 + 0.32 * L * t, -0.08 * L * t * t)), taper(6, 0.1, TIP, 0.7), { k: 0.01 });
    },
  },
  horn_nub: {
    name: 'Petites cornes', cat: 'horns', icon: '🦒', hint: 'up', slot: 'detail', pieceName: 'Ossicône',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      c.cone(P(0, -0.03, 0), P(0, 0.12 * p.length, 0), 0.035, 0.03, { k: 0.01 });
      c.sphere(P(0, 0.13 * p.length, 0), 0.045, { piece: 'Bout', slot: 'dark', k: 0.01 });
    },
  },

  // =============================================================== EARS
  ear_pointy: {
    name: 'Oreille pointue', cat: 'ears', icon: '🐱', hint: 'fwd', pieceName: 'Oreille',
    params: { size: 1, width: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['width', 'Largeur', 0.4, 2]],
    build(c, p) {
      const s = p.size, w = p.width;
      c.tri(P(-0.12 * s * w, -0.04, 0), P(0.12 * s * w, -0.04, 0), P(0, 0.34 * s, -0.03 * s), 0.03, { k: 0.02 });
      c.tri(P(-0.075 * s * w, 0.02, 0.025), P(0.075 * s * w, 0.02, 0.025), P(0, 0.25 * s, 0.0), 0.012, { piece: 'Intérieur', slot: 'secondary', k: 0.003 });
    },
  },
  ear_wolf: {
    name: 'Oreille de loup', cat: 'ears', icon: '🐺', hint: 'fwd', pieceName: 'Oreille',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.tri(P(-0.1 * s, -0.04, 0), P(0.1 * s, -0.04, -0.02), P(0.02 * s, 0.42 * s, -0.07 * s), 0.035, { k: 0.02 });
      c.tri(P(-0.06 * s, 0.03, 0.028), P(0.06 * s, 0.03, 0.015), P(0.015 * s, 0.3 * s, -0.035 * s), 0.012, { piece: 'Intérieur', slot: 'secondary', k: 0.003 });
      c.piece('Touffe', 'secondary');
      for (let i = 0; i < 4; i++) c.cone(P(0, 0.05 + i * 0.05 * s, 0.03), P((i - 1.5) * 0.02 * s, 0.1 + i * 0.06 * s, 0.07), 0.012, TIP, { k: 0.004 });
    },
  },
  ear_round: {
    name: 'Oreille ronde', cat: 'ears', icon: '🐭', hint: 'fwd', pieceName: 'Oreille',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.12 * s, 0), [0.15 * s, 0.15 * s, 0.035], null, { k: 0.03 });
      c.ell(P(0, 0.13 * s, 0.028), [0.105 * s, 0.105 * s, 0.014], null, { piece: 'Intérieur', slot: 'secondary', k: 0.003 });
    },
  },
  ear_long: {
    name: 'Oreille de lapin', cat: 'ears', icon: '🐰', hint: 'fwd', pieceName: 'Oreille',
    params: { size: 1, bend: 0 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['bend', 'Pliure', -1, 1]],
    build(c, p) {
      const s = p.size, b = p.bend;
      const ax = [P(1, 0, 0), P(0, 1, -0.5 * b)];
      c.ell(P(0, 0.3 * s, -0.08 * b * s), [0.08 * s, 0.32 * s, 0.03], ax, { k: 0.03 });
      c.ell(P(0, 0.3 * s, -0.08 * b * s + 0.024), [0.048 * s, 0.25 * s, 0.012], ax, { piece: 'Intérieur', slot: 'secondary', k: 0.003 });
    },
  },
  ear_droopy: {
    name: 'Oreille tombante', cat: 'ears', icon: '🐕', hint: 'fwd', pieceName: 'Oreille',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      const ax = [P(0.95, 0.3, 0), P(-0.3, 0.95, 0)];
      c.ell(P(0.01, 0.02, 0), [0.07 * s, 0.06 * s, 0.03], null, { k: 0.04 });
      c.ell(P(0.07 * s, -0.12 * s, 0.01), [0.09 * s, 0.2 * s, 0.028], ax, { k: 0.04 });
      c.ell(P(0.07 * s, -0.12 * s, 0.03), [0.06 * s, 0.15 * s, 0.012], ax, { piece: 'Intérieur', slot: 'secondary', k: 0.003 });
    },
  },
  ear_elephant: {
    name: 'Oreille d\'éléphant', cat: 'ears', icon: '🐘', hint: 'fwd', pieceName: 'Oreille',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.2 * s, 0), [0.3 * s, 0.22 * s, 0.03], null, { k: 0.03 });
      c.ell(P(0, 0.2 * s, 0.022), [0.24 * s, 0.17 * s, 0.012], null, { piece: 'Intérieur', slot: 'secondary', k: 0.003 });
    },
  },
  ear_bat: {
    name: 'Oreille de chauve-souris', cat: 'ears', icon: '🦇', hint: 'fwd', pieceName: 'Oreille',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.tri(P(-0.15 * s, -0.04, 0), P(0.13 * s, -0.04, 0), P(0.05 * s, 0.5 * s, -0.05 * s), 0.025, { k: 0.02 });
      c.piece('Nervures', 'secondary');
      for (const x of [-0.07, 0, 0.07]) c.cone(P(x * s, -0.02, 0.025), P(0.05 * s, 0.4 * s, -0.02 * s), 0.012, 0.004, { k: 0.003 });
    },
  },
  ear_fin: {
    name: 'Oreille nageoire', cat: 'ears', icon: '🧝', hint: 'fwd', slot: 'secondary', pieceName: 'Oreille',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      for (let i = 0; i < 3; i++) {
        const a = -0.3 + i * 0.35;
        c.cone(P(0, -0.02, 0.012), P(Math.sin(a) * 0.3 * s, Math.cos(a) * 0.3 * s, -0.008), 0.018, TIP, { piece: 'Rayons', slot: 'detail', k: 0.004 });
      }
      c.tri(P(0, -0.02, 0), P(Math.sin(-0.3) * 0.3 * s, Math.cos(-0.3) * 0.3 * s, -0.02), P(Math.sin(0.05) * 0.32 * s, Math.cos(0.05) * 0.32 * s, -0.02), 0.01, { k: 0.004 });
      c.tri(P(0, -0.02, 0), P(Math.sin(0.05) * 0.32 * s, Math.cos(0.05) * 0.32 * s, -0.02), P(Math.sin(0.4) * 0.3 * s, Math.cos(0.4) * 0.3 * s, -0.02), 0.01, { k: 0.004 });
    },
  },
  ear_human: {
    name: 'Oreille humaine', cat: 'ears', icon: '👂', hint: 'fwd', pieceName: 'Oreille', slot: 'base',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.02, 0), [0.03, 0.09 * s, 0.06 * s], [P(0, 0, 1), P(0, 1, 0)], { k: 0.02 });
      c.ell(P(0.02, 0.03, 0.01), [0.035, 0.07 * s, 0.045 * s], null, { op: 'sub', k: 0.01 });
    },
  },

  // =============================================================== HAIR & CRESTS
  hair_whiskers: {
    name: 'Moustaches', cat: 'hair', icon: '🐈', hint: 'up', slot: 'claw', pieceName: 'Moustaches',
    params: { length: 1, count: 3 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['count', 'Nombre', 1, 5, 1]],
    build(c, p) {
      const n = Math.round(p.count), L = 0.35 * p.length;
      for (let i = 0; i < n; i++) {
        const a = (i - (n - 1) / 2) * 0.25;
        c.chain([P(0, 0, 0), P(-Math.cos(a) * L * 0.5, 0.05, Math.sin(a) * L * 0.5), P(-Math.cos(a) * L, 0.05, Math.sin(a) * L - 0.03)], [0.007, 0.005, TIP], { k: 0.003 });
      }
    },
  },
  hair_brows: {
    name: 'Sourcils touffus', cat: 'hair', icon: '🤨', hint: 'up', slot: 'secondary', pieceName: 'Sourcil',
    params: { size: 1, angle: 0 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['angle', 'Angle', -1, 1]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.0, 0.02), [0.12 * s, 0.02, 0.025 * s], [P(1, 0, p.angle * 0.4), P(0, 1, 0)], { k: 0.01 });
      for (let i = 0; i < 7; i++) {
        const x = (i - 3) * 0.035 * s;
        const z = 0.02 + x * p.angle * 0.4;
        c.cone(P(x, 0.0, z), P(x * 1.25 + 0.015 * s, 0.035 * s, z + 0.05 * s), 0.02 * s, TIP, { k: 0.008 });
      }
    },
  },
  hair_mohawk: {
    name: 'Crête punk', cat: 'hair', icon: '🦔', hint: 'fwd', slot: 'secondary', pieceName: 'Crête',
    params: { count: 6, length: 1 },
    paramDefs: [['count', 'Nombre', 3, 12, 1], ['length', 'Hauteur', 0.3, 3]],
    build(c, p) {
      const n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const z = (0.5 - i / (n - 1)) * 0.07 * n;
        const h = (0.14 + 0.08 * Math.sin((i / (n - 1)) * Math.PI)) * p.length;
        c.tri(P(0, -0.03, z + 0.04), P(0, -0.03, z - 0.04), P(0, h, z - h * 0.4), 0.01, { k: 0.01 });
      }
    },
  },
  hair_tuft: {
    name: 'Mèche de cheveux', cat: 'hair', icon: '💇', hint: 'fwd', slot: 'secondary', pieceName: 'Mèche',
    params: { count: 5, length: 1 },
    paramDefs: [['count', 'Nombre', 1, 12, 1], ['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      const n = Math.round(p.count), L = 0.25 * p.length;
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2, r = 0.03;
        const x = Math.cos(a) * r, z = Math.sin(a) * r;
        c.chain([P(x, -0.02, z), P(x * 2, L * 0.6, z * 2 - 0.05), P(x * 3, L, z * 3 - 0.14 * p.length)], [0.03, 0.018, TIP], { k: 0.02 });
      }
    },
  },
  hair_beard: {
    name: 'Barbe', cat: 'hair', icon: '🧔', hint: 'up', slot: 'secondary', pieceName: 'Barbe',
    params: { length: 1, width: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['width', 'Largeur', 0.4, 2]],
    build(c, p) {
      const L = p.length, W = p.width;
      c.ell(P(0, 0.02, -0.04 * L), [0.14 * W, 0.06, 0.1 * L], null, { k: 0.04 });
      c.cone(P(0, 0.03, -0.1 * L), P(0, 0.05, -0.25 * L), 0.07 * W, TIP, { k: 0.04 });
    },
  },
  mane: {
    name: 'Crinière', cat: 'hair', icon: '🦁', hint: 'fwd', slot: 'secondary', pieceName: 'Crinière',
    params: { size: 1, length: 1 },
    paramDefs: [['size', 'Volume', 0.4, 2.5], ['length', 'Longueur', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      for (let i = 0; i < 9; i++) {
        const t = i / 8;
        const z = (0.3 - 0.6 * t) * p.length;
        c.cone(P(Math.sin(i * 2.3) * 0.04, -0.02, z), P(Math.sin(i * 2.3) * 0.08, (0.14 + 0.04 * Math.sin(i * 3.1)) * s, z - 0.12 * s), 0.07 * s, TIP, { k: 0.04 });
      }
    },
  },
  hair_fluff: {
    name: 'Touffe de poils', cat: 'hair', icon: '🐑', hint: 'fwd', slot: 'secondary', pieceName: 'Poils',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const s = p.size;
      for (let i = 0; i < 9; i++) {
        const a = i * 2.39996, r = Math.sqrt(i / 9) * 0.1 * s;
        c.sphere(P(Math.cos(a) * r, 0.02 + (0.06 - r * 0.3) * s, Math.sin(a) * r), 0.055 * s, { k: 0.03 });
      }
    },
  },

  // =============================================================== WINGS / FINS
  wing_bat: {
    name: 'Aile de chauve-souris', cat: 'wings', icon: '🦇', hint: 'fwd', spread: true, pieceName: 'Os de l\'aile',
    params: { size: 1, spread: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['spread', 'Ouverture', 0.3, 1.3]],
    build(c, p) {
      const s = p.size, e = p.spread;
      const O = P(0, 0, 0), E = P(0, 0.42 * s, 0.1 * s), W = P(0, 0.8 * s * e, 0.02 * s);
      const T1 = P(0, 1.25 * s * e, -0.12 * s), T2 = P(0, 1.02 * s * e, -0.55 * s), T3 = P(0, 0.68 * s * e, -0.8 * s), B = P(0, 0, -0.55 * s);
      c.chain([O, E, W], [0.06, 0.04, 0.03], { k: 0.02 });
      for (const T of [T1, T2, T3]) c.cone(W, T, 0.022, 0.006, { k: 0.01 });
      const mem = { piece: 'Membrane', slot: 'secondary', k: 0.004 };
      for (const [a, b, d] of [[W, T1, T2], [W, T2, T3], [W, T3, B], [W, B, O], [O, E, W]]) c.tri(a, b, d, 0.01, mem);
      claw(c, W, [0, 0.4, 1], 0.1 * s, 0.018, [0, -1, 0]);
    },
  },
  wing_dragon: {
    name: 'Aile de dragon', cat: 'wings', icon: '🐉', hint: 'fwd', spread: true, pieceName: 'Os de l\'aile',
    params: { size: 1, spread: 1, fingers: 4 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['spread', 'Ouverture', 0.3, 1.3], ['fingers', 'Doigts', 2, 6, 1]],
    build(c, p) {
      const s = p.size, e = p.spread, n = Math.round(p.fingers);
      const O = P(0, 0, 0), E = P(0, 0.5 * s, 0.15 * s), W = P(0, 0.95 * s * e, 0.05 * s), B = P(0, 0, -0.7 * s);
      c.chain([O, E, W], [0.075, 0.05, 0.035], { k: 0.02 });
      const tips = [];
      for (let i = 0; i < n; i++) {
        const a = (i / (n - 1)) * 1.45;
        tips.push(P(0, 0.95 * s * e + Math.cos(a) * 0.6 * s * e, 0.05 * s - Math.sin(a) * 1.0 * s));
      }
      for (const T of tips) c.chain([W, lerp(W, T, 0.5), T], [0.025, 0.017, TIP], { k: 0.008 });
      const mem = { piece: 'Membrane', slot: 'secondary', k: 0.004 };
      for (let i = 0; i < n - 1; i++) {
        const mid = lerp(lerp(tips[i], tips[i + 1], 0.5), W, 0.28); // scalloped edge
        c.tri(W, tips[i], mid, 0.01, mem);
        c.tri(W, mid, tips[i + 1], 0.01, mem);
      }
      c.tri(W, tips[n - 1], B, 0.01, mem);
      c.tri(W, B, O, 0.01, mem);
      c.tri(O, E, W, 0.01, mem);
      claw(c, W, [0, 0.3, 1], 0.14 * s, 0.025, [0, -1, 0]);
    },
  },
  wing_feather: {
    name: 'Aile à plumes', cat: 'wings', icon: '🪶', hint: 'fwd', spread: true, pieceName: 'Bras de l\'aile',
    params: { size: 1, spread: 1, feathers: 9 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['spread', 'Ouverture', 0.3, 1.3], ['feathers', 'Plumes', 4, 14, 1]],
    build(c, p) {
      const s = p.size, e = p.spread;
      c.chain([P(0, 0, 0), P(0, 0.4 * s * e, 0.08 * s), P(0, 0.85 * s * e, 0)], [0.07, 0.05, 0.035], { k: 0.03 });
      const N = Math.round(p.feathers);
      c.piece('Plumes', 'secondary');
      for (let i = 0; i < N; i++) {
        const t = i / (N - 1);
        const base = P(0, (0.1 + 0.75 * t) * s * e, 0.05 * s * (1 - t));
        const ang = (0.1 + 0.9 * t * t) * (Math.PI / 2) * 0.95;
        const dir = [0, Math.sin(ang), -Math.cos(ang)];
        const L = (0.3 + 0.25 * t) * s;
        const cc = [base[0], base[1] + dir[1] * L * 0.55, base[2] + dir[2] * L * 0.55];
        c.ell(cc, [0.012, L * 0.6, 0.07 * s], [P(1, 0, 0), dir], { k: 0.006 });
      }
      c.piece('Plumes de couverture', 'base');
      for (let i = 0; i < Math.max(3, N - 3); i++) {
        const t = i / Math.max(1, N - 4);
        c.ell(P(0.02, (0.12 + 0.6 * t) * s * e, -0.08 * s), [0.014, 0.1 * s, 0.05 * s], [P(1, 0, 0), P(0, 0.3, -1)], { k: 0.006 });
      }
    },
  },
  wing_angel: {
    name: 'Aile d\'ange', cat: 'wings', icon: '👼', hint: 'fwd', spread: true, slot: 'secondary', pieceName: 'Plumes',
    params: { size: 1.2 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      for (const [row, off] of [[0, 0], [1, 0.12]]) {
        const N = 10 - row * 3;
        for (let i = 0; i < N; i++) {
          const t = i / (N - 1);
          const base = P(0.02 * row, (0.05 + 0.8 * t) * s, off * s * (1 - t));
          const ang = (0.25 + 0.75 * t) * (Math.PI / 2);
          const dir = [0, Math.sin(ang) * 0.6, -Math.cos(ang)];
          const L = (0.55 - 0.2 * row - 0.2 * t) * s;
          c.ell([base[0], base[1] + dir[1] * L * 0.5, base[2] + dir[2] * L * 0.5], [0.012, L * 0.55, 0.06 * s], [P(1, 0, 0), dir], { piece: row ? 'Petites plumes' : 'Plumes', k: 0.006 });
        }
      }
    },
  },
  wing_insect: {
    name: 'Aile d\'insecte', cat: 'wings', icon: '🪰', hint: 'fwd', slot: 'secondary', spread: true, pieceName: 'Aile',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.4 * s, -0.12 * s), [0.01, 0.42 * s, 0.13 * s], [P(1, 0, 0), [0, 1, -0.3]], { k: 0.01 });
      c.ell(P(0, 0.22 * s, -0.3 * s), [0.01, 0.3 * s, 0.09 * s], [P(1, 0, 0), [0, 1, -1.1]], { k: 0.01 });
      c.piece('Nervures', 'dark');
      c.cone(P(0, 0, 0), P(0, 0.8 * s * 0.96, -0.36 * s), 0.012, 0.004, { k: 0.003 });
    },
  },
  wing_butterfly: {
    name: 'Aile de papillon', cat: 'wings', icon: '🦋', hint: 'fwd', slot: 'secondary', spread: true, pieceName: 'Aile',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.36 * s, 0.08 * s), [0.01, 0.36 * s, 0.26 * s], [P(1, 0, 0), [0, 1, 0.35]], { k: 0.01 });
      c.ell(P(0, 0.26 * s, -0.25 * s), [0.01, 0.26 * s, 0.2 * s], [P(1, 0, 0), [0, 1, -0.9]], { k: 0.01 });
      c.piece('Taches', 'detail');
      c.ell(P(0.012, 0.45 * s, 0.12 * s), [0.008, 0.08 * s, 0.08 * s], null, { k: 0.002 });
      c.ell(P(0.012, 0.28 * s, -0.3 * s), [0.008, 0.06 * s, 0.06 * s], null, { k: 0.002 });
      c.piece('Pupilles des taches', 'dark');
      c.ell(P(0.016, 0.45 * s, 0.12 * s), [0.008, 0.035 * s, 0.035 * s], null, { k: 0.002 });
    },
  },
  fin_dorsal: {
    name: 'Nageoire dorsale', cat: 'wings', icon: '🦈', hint: 'fwd', slot: 'secondary', pieceName: 'Nageoire',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      const tip = P(0, 0.45 * s, -0.42 * s);
      c.tri(P(0, -0.06, 0.18 * s), P(0, -0.06, -0.35 * s), tip, 0.018, { k: 0.01 });
      c.chain([P(0, -0.06, 0.18 * s), lerp(P(0, -0.06, 0.18 * s), tip, 0.5), tip], [0.032, 0.02, TIP], { k: 0.01 });
    },
  },
  fin_side: {
    name: 'Nageoire latérale', cat: 'wings', icon: '🐟', hint: 'fwd', slot: 'secondary', spread: true, pieceName: 'Nageoire',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.18 * s, -0.08 * s), [0.018, 0.22 * s, 0.09 * s], [P(1, 0, 0), P(0, 1, -0.5)], { k: 0.02 });
      c.piece('Rayons', 'detail');
      for (let i = 0; i < 4; i++) {
        const a = 0.25 + i * 0.12;
        c.cone(P(0.014, 0.02, -0.01), P(0.014, 0.02 + Math.cos(a) * 0.3 * s, -0.01 - Math.sin(a) * 0.3 * s), 0.008, 0.003, { k: 0.002 });
      }
    },
  },
  fin_tail: {
    name: 'Queue de poisson', cat: 'wings', icon: '🐠', hint: 'fwd', slot: 'secondary', pieceName: 'Nageoire',
    params: { size: 1, fork: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['fork', 'Fourche', 0, 1.5]],
    build(c, p) {
      const s = p.size, f = p.fork;
      const top = P(0, 0.4 * s, 0.34 * s), bot = P(0, 0.4 * s, -0.34 * s), notch = P(0, (0.4 - 0.22 * f) * s, 0);
      c.tri(P(0, -0.06, 0.07), top, notch, 0.016, { k: 0.008 });
      c.tri(P(0, -0.06, -0.07), bot, notch, 0.016, { k: 0.008 });
      c.tri(P(0, -0.06, 0.07), P(0, -0.06, -0.07), notch, 0.016, { k: 0.008 });
    },
  },

  // =============================================================== TAILS
  tail_club: {
    name: 'Massue', cat: 'tails', icon: '🔨', hint: 'fwd', slot: 'detail', pieceName: 'Massue',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.12 * s, 0), [0.17 * s, 0.14 * s, 0.14 * s], null, { k: 0.04 });
      for (const [x, z] of [[1, 0], [-1, 0], [0, 1], [0, -1], [0.7, 0.7], [-0.7, -0.7]]) c.cone(P(x * 0.12 * s, 0.12 * s, z * 0.1 * s), P(x * 0.24 * s, 0.15 * s, z * 0.2 * s), 0.04 * s, TIP, { piece: 'Piques', slot: 'claw', k: 0.004 });
    },
  },
  tail_thagomizer: {
    name: 'Pointes de stégo', cat: 'tails', icon: '🦕', hint: 'fwd', slot: 'claw', pieceName: 'Pointes',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      for (const sx of [-1, 1]) {
        c.cone(P(sx * 0.03, -0.02, 0.05), P(sx * 0.28 * s, 0.22 * s, 0.12 * s), 0.045, TIP, { k: 0.01 });
        c.cone(P(sx * 0.03, -0.02, -0.08), P(sx * 0.25 * s, 0.25 * s, -0.18 * s), 0.045, TIP, { k: 0.01 });
      }
    },
  },
  tail_fluff: {
    name: 'Touffe', cat: 'tails', icon: '🦊', hint: 'fwd', slot: 'secondary', pieceName: 'Touffe',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.14 * s, 0), [0.13 * s, 0.2 * s, 0.13 * s], null, { k: 0.04 });
      c.cone(P(0, 0.2 * s, 0), P(0, 0.42 * s, 0), 0.1 * s, TIP, { k: 0.06 });
    },
  },
  tail_pompom: {
    name: 'Pompon', cat: 'tails', icon: '🧶', hint: 'fwd', slot: 'secondary', pieceName: 'Pompon',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      for (let i = 0; i < 14; i++) {
        const a = i * 2.39996, y = 1 - (i / 13) * 2, r = Math.sqrt(1 - y * y);
        c.sphere(P(Math.cos(a) * r * 0.1 * s, 0.13 * s + y * 0.1 * s, Math.sin(a) * r * 0.1 * s), 0.055 * s, { k: 0.02 });
      }
    },
  },
  tail_spade: {
    name: 'Pointe de diable', cat: 'tails', icon: '♠️', hint: 'fwd', slot: 'detail', pieceName: 'Pointe',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.tri(P(0, 0, 0.12 * s), P(0, 0, -0.12 * s), P(0, 0.26 * s, 0), 0.02, { k: 0.004 });
      c.tri(P(0, 0, 0.12 * s), P(0, 0, -0.12 * s), P(0, 0.05 * s, 0), 0.02, { k: 0.004 });
      c.cone(P(0, -0.04, 0), P(0, 0.02, 0), 0.035, 0.03, { k: 0.01 });
    },
  },
  tail_stinger: {
    name: 'Dard de scorpion', cat: 'tails', icon: '🦂', hint: 'fwd', pieceName: 'Ampoule',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.08 * s, 0), [0.09 * s, 0.1 * s, 0.09 * s], null, { k: 0.03 });
      c.chain([P(0, 0.14 * s, 0), P(0, 0.26 * s, 0.08 * s), P(0, 0.3 * s, 0.22 * s)], [0.045, 0.022, TIP], { piece: 'Dard', slot: 'claw', k: 0.01 });
    },
  },
  tail_fan: {
    name: 'Éventail', cat: 'tails', icon: '🦚', hint: 'fwd', slot: 'secondary', pieceName: 'Plumes',
    params: { size: 1, count: 7 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['count', 'Plumes', 3, 13, 1]],
    build(c, p) {
      const s = p.size, n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const a = (i / (n - 1) - 0.5) * Math.PI * 0.85;
        const dir = [0, Math.cos(a), Math.sin(a)];
        c.ell([0, dir[1] * 0.25 * s, dir[2] * 0.25 * s], [0.013, 0.26 * s, 0.065 * s], [P(1, 0, 0), dir], { k: 0.01 });
        c.ell([0.012, dir[1] * 0.42 * s, dir[2] * 0.42 * s], [0.008, 0.05 * s, 0.035 * s], [P(1, 0, 0), dir], { piece: 'Ocelles', slot: 'detail', k: 0.002 });
      }
    },
  },
  tail_leaf: {
    name: 'Feuille caudale', cat: 'tails', icon: '🍃', hint: 'fwd', slot: 'secondary', pieceName: 'Feuille',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) { const s = p.size; c.ell(P(0, 0.22 * s, 0), [0.018, 0.26 * s, 0.15 * s], null, { k: 0.02 }); },
  },
  tail_beaver: {
    name: 'Queue de castor', cat: 'tails', icon: '🦫', hint: 'fwd', slot: 'dark', pieceName: 'Palette',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) { const s = p.size; c.ell(P(0, 0.2 * s, 0), [0.16 * s, 0.24 * s, 0.035], null, { k: 0.02 }); },
  },
  tail_rattle: {
    name: 'Crécelle', cat: 'tails', icon: '🐍', hint: 'fwd', slot: 'detail', pieceName: 'Crécelle',
    params: { size: 1, rings: 5 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['rings', 'Anneaux', 2, 9, 1]],
    build(c, p) {
      const s = p.size, n = Math.round(p.rings);
      for (let i = 0; i < n; i++) c.ell(P(0, (0.02 + i * 0.055) * s, 0), [0.07 * s * (1 - i * 0.06), 0.035 * s, 0.05 * s * (1 - i * 0.06)], null, { k: 0.008 });
    },
  },

  // =============================================================== DETAILS
  spike: {
    name: 'Pique', cat: 'details', icon: '🔺', hint: 'fwd', slot: 'claw', pieceName: 'Pique',
    params: { length: 1, thick: 1 },
    paramDefs: [['length', 'Longueur', 0.3, 3], ['thick', 'Épaisseur', 0.4, 2]],
    build(c, p) { c.cone(P(0, -0.03, 0), P(0, 0.22 * p.length, -0.05 * p.length), 0.06 * p.thick, TIP, { k: 0.01 }); },
  },
  spike_row: {
    name: 'Rangée de piques', cat: 'details', icon: '🦔', hint: 'fwd', slot: 'claw', pieceName: 'Piques',
    params: { count: 5, length: 1, spacing: 1 },
    paramDefs: [['count', 'Nombre', 2, 12, 1], ['length', 'Longueur', 0.3, 3], ['spacing', 'Espacement', 0.4, 2]],
    build(c, p) {
      const n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const t = n === 1 ? 0.5 : i / (n - 1);
        const z = (0.5 - t) * 0.12 * (n - 1) * p.spacing;
        const h = (0.12 + 0.1 * Math.sin(t * Math.PI)) * p.length;
        c.cone(P(0, -0.04, z), P(0, h, z - h * 0.35), 0.05, TIP, { k: 0.01 });
      }
    },
  },
  spike_cluster: {
    name: 'Bouquet de piques', cat: 'details', icon: '🌵', hint: 'fwd', slot: 'claw', pieceName: 'Piques',
    params: { count: 5, length: 1 },
    paramDefs: [['count', 'Nombre', 2, 9, 1], ['length', 'Longueur', 0.3, 3]],
    build(c, p) {
      const n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2, t = n === 1 ? 0 : 0.5;
        const d = nrm([Math.cos(a) * t, 1, Math.sin(a) * t]);
        c.cone(P(0, -0.03, 0), P(d[0] * 0.22 * p.length, d[1] * 0.22 * p.length, d[2] * 0.22 * p.length), 0.04, TIP, { k: 0.01 });
      }
    },
  },
  plate: {
    name: 'Plaque dorsale', cat: 'details', icon: '🔶', hint: 'fwd', slot: 'secondary', pieceName: 'Plaque',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const s = p.size;
      c.tri(P(0, -0.04, 0.14 * s), P(0, -0.04, -0.14 * s), P(0, 0.3 * s, -0.05 * s), 0.025, { k: 0.02 });
      c.ell(P(0, 0.06 * s, -0.01), [0.025, 0.1 * s, 0.13 * s], null, { k: 0.03 });
    },
  },
  plate_row: {
    name: 'Plaques de stégosaure', cat: 'details', icon: '🦕', hint: 'fwd', slot: 'secondary', pieceName: 'Plaques',
    params: { count: 5, size: 1 },
    paramDefs: [['count', 'Nombre', 2, 10, 1], ['size', 'Taille', 0.4, 3]],
    build(c, p) {
      const n = Math.round(p.count), s = p.size;
      for (let i = 0; i < n; i++) {
        const t = i / Math.max(1, n - 1);
        const z = (0.5 - t) * 0.16 * (n - 1) * s;
        const h = (0.16 + 0.12 * Math.sin(t * Math.PI)) * s;
        const x = (i % 2 ? 0.02 : -0.02);
        c.tri(P(x, -0.04, z + 0.08 * s), P(x, -0.04, z - 0.08 * s), P(x, h, z - 0.03 * s), 0.02, { k: 0.02 });
      }
    },
  },
  shell: {
    name: 'Carapace', cat: 'details', icon: '🐢', hint: 'fwd', slot: 'secondary', pieceName: 'Carapace',
    params: { size: 1, height: 1 },
    paramDefs: [['size', 'Taille', 0.4, 3], ['height', 'Hauteur', 0.3, 2]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, -0.02, 0), [0.45 * s, 0.22 * s * p.height, 0.55 * s], null, { k: 0.03 });
      c.piece('Écailles de carapace', 'detail');
      for (const [x, z] of [[0, 0], [0.22, 0.2], [-0.22, 0.2], [0.22, -0.2], [-0.22, -0.2], [0, 0.35], [0, -0.35]]) {
        const y = 0.2 * s * p.height * Math.sqrt(Math.max(0, 1 - (x / 0.45) ** 2 - (z / 0.55) ** 2)) - 0.02 + 0.005;
        c.ell(P(x * s, y, z * s), [0.1 * s, 0.03 * s, 0.1 * s], null, { k: 0.01 });
      }
    },
  },
  bump: {
    name: 'Bosse / verrue', cat: 'details', icon: '🟤', hint: 'fwd', fuse: true, pieceName: 'Bosse',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 4]],
    build(c, p) { c.sphere(P(0, 0, 0), 0.06 * p.size, { k: 0.03 }); },
  },
  warts: {
    name: 'Pustules', cat: 'details', icon: '🍄', hint: 'fwd', slot: 'secondary', pieceName: 'Pustules',
    params: { size: 1, count: 6 },
    paramDefs: [['size', 'Zone', 0.3, 3], ['count', 'Nombre', 2, 12, 1]],
    build(c, p) {
      const n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const a = i * 2.39996, r = Math.sqrt((i + 0.5) / n) * 0.14 * p.size;
        c.sphere(P(Math.cos(a) * r, -0.005, Math.sin(a) * r), 0.025 + 0.012 * ((i * 7) % 3), { k: 0.004 });
      }
    },
  },
  gills: {
    name: 'Branchies', cat: 'details', icon: '🐡', hint: 'up', pieceName: 'Branchies', slot: 'mouth',
    params: { count: 3, size: 1 },
    paramDefs: [['count', 'Fentes', 1, 6, 1], ['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const n = Math.round(p.count), s = p.size;
      for (let i = 0; i < n; i++) {
        const x = (i - (n - 1) / 2) * 0.05 * s;
        c.ell(P(x, 0, 0), [0.012 * s, 0.03, 0.1 * s], null, { body: true, op: 'sub', k: 0.01 });
        c.ell(P(x, -0.03, 0), [0.011 * s, 0.02, 0.095 * s], null, { k: 0.004 });
      }
    },
  },
  belly_scales: {
    name: 'Plaques ventrales', cat: 'details', icon: '🐊', hint: 'fwd', slot: 'detail', pieceName: 'Plaques',
    params: { count: 5, size: 1 },
    paramDefs: [['count', 'Nombre', 2, 12, 1], ['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const n = Math.round(p.count), s = p.size;
      for (let i = 0; i < n; i++) c.ell(P(0, -0.005, (i - (n - 1) / 2) * 0.12 * s), [0.16 * s, 0.028, 0.062 * s], null, { k: 0.004 });
    },
  },
  scale_row: {
    name: 'Écailles', cat: 'details', icon: '🐉', hint: 'fwd', slot: 'secondary', pieceName: 'Écailles',
    params: { count: 6, size: 1 },
    paramDefs: [['count', 'Nombre', 2, 14, 1], ['size', 'Taille', 0.3, 3]],
    build(c, p) {
      const n = Math.round(p.count), s = p.size;
      for (let i = 0; i < n; i++) {
        const z = (0.5 - i / Math.max(1, n - 1)) * 0.07 * (n - 1) * s;
        c.ell(P((i % 2) * 0.04 * s - 0.02 * s, 0.0, z), [0.05 * s, 0.018, 0.06 * s], [P(1, 0, 0), P(0, 1, 0.35)], { k: 0.003 });
      }
    },
  },
  crystal: {
    name: 'Cristaux', cat: 'details', icon: '💎', hint: 'fwd', slot: 'custom', pieceName: 'Cristal',
    params: { size: 1, count: 3 },
    paramDefs: [['size', 'Taille', 0.3, 3], ['count', 'Nombre', 1, 5, 1]],
    build(c, p) {
      const s = p.size, n = Math.round(p.count);
      for (let i = 0; i < n; i++) {
        const a = i * 2.4, lean = i ? 0.5 : 0;
        const d = nrm([Math.cos(a) * lean, 1, Math.sin(a) * lean]);
        const L = (i ? 0.2 : 0.32) * s, R = (i ? 0.045 : 0.07) * s;
        const b = P(d[0] * 0.03 - d[0] * 0.05, -0.05, d[2] * 0.03 - d[2] * 0.05);
        const body = L * 0.72;
        const mid = P(b[0] + d[0] * body / 2, b[1] + d[1] * body / 2, b[2] + d[2] * body / 2);
        const top = P(b[0] + d[0] * body, b[1] + d[1] * body, b[2] + d[2] * body);
        const tip = P(b[0] + d[0] * L, b[1] + d[1] * L, b[2] + d[2] * L);
        // hexagonal prism = intersection of 3 slabs, topped by a hexagonal point
        const e1 = nrm([d[1], -d[0], 0].map((v, k) => (k === 2 ? 0 : v)).some((v) => Math.abs(v) > 1e-3) ? [d[1], -d[0], 0] : [1, 0, 0]);
        const e2 = nrm([d[1] * e1[2] - d[2] * e1[1], d[2] * e1[0] - d[0] * e1[2], d[0] * e1[1] - d[1] * e1[0]]);
        c.group(() => {
          c.cone(mid, tip, R * 1.2, TIP, { k: 0 });
          c.cone(b, top, R * 1.2, R * 1.2, { k: 0 });
          for (let k = 0; k < 3; k++) {
            const ang = (k / 3) * Math.PI;
            const nk = [0, 1, 2].map((j) => e1[j] * Math.cos(ang) + e2[j] * Math.sin(ang));
            c.box(mid, [R * 0.866, L, R * 2], 0, [nk, d], { op: 'int', k: 0 });
          }
        }, { k: 0.002 });
      }
    },
  },
  shoulder_pad: {
    name: 'Épaulette / armure', cat: 'details', icon: '🛡️', hint: 'fwd', slot: 'detail', pieceName: 'Armure',
    params: { size: 1, spikes: 1 },
    paramDefs: [['size', 'Taille', 0.3, 3], ['spikes', 'Piques', 0, 3, 1]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.0, 0), [0.2 * s, 0.09 * s, 0.2 * s], null, { k: 0.01 });
      c.torus(P(0, -0.01, 0), 0.19 * s, 0.018 * s, [0, 1, 0], { piece: 'Rebord', slot: 'claw', k: 0.004 });
      for (let i = 0; i < Math.round(p.spikes); i++) {
        const z = (i - (Math.round(p.spikes) - 1) / 2) * 0.1 * s;
        c.cone(P(0, 0.05 * s, z), P(0, 0.22 * s, z - 0.05 * s), 0.04 * s, TIP, { piece: 'Piques', slot: 'claw', k: 0.004 });
      }
    },
  },
  ring: {
    name: 'Anneau / piercing', cat: 'details', icon: '💍', hint: 'fwd', slot: 'custom', pieceName: 'Anneau',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.3, 3]],
    build(c, p) { c.torus(P(0, 0.02, 0.06 * p.size), 0.06 * p.size, 0.012, [1, 0, 0], { k: 0.002 }); },
  },
  collar: {
    name: 'Collier à piques', cat: 'details', icon: '⛓️', hint: 'fwd', slot: 'dark', pieceName: 'Collier',
    params: { size: 1, spikes: 5 },
    paramDefs: [['size', 'Largeur', 0.3, 3], ['spikes', 'Piques', 0, 9, 1]],
    build(c, p) {
      const s = p.size, n = Math.round(p.spikes);
      c.box(P(0, 0, 0), [0.2 * s, 0.02, 0.04], 0.015, null, { k: 0.002 });
      for (let i = 0; i < n; i++) {
        const x = (i - (n - 1) / 2) * (0.36 * s / Math.max(1, n - 1 || 1));
        c.cone(P(x, 0.01, 0), P(x, 0.09, 0), 0.02, TIP, { piece: 'Piques', slot: 'claw', k: 0.002 });
      }
    },
  },

  // =============================================================== HANDS (limb ends)
  hand_5: {
    name: 'Main à 5 doigts', cat: 'hands', icon: '✋', end: true, pieceName: 'Main',
    params: { finger: 1, nails: 1 },
    paramDefs: [['finger', 'Longueur des doigts', 0.5, 2], ['nails', 'Ongles', 0, 1, 1]],
    build(c, p) {
      const F = p.finger;
      c.ell(P(0, 0.09, 0), [0.04, 0.1, 0.085], null, { k: 0.04 });
      for (let i = 0; i < 4; i++) {
        const z = -0.055 + i * 0.037;
        const L = (i === 1 || i === 2 ? 0.16 : 0.13) * F;
        const tip = P(0.03, 0.16 + L, z * 1.15);
        c.chain([P(0, 0.16, z), P(0.01, 0.16 + L * 0.55, z * 1.1), tip], [0.022, 0.019, 0.016], { k: 0.01 });
        if (p.nails) c.ell(P(0.042, 0.16 + L - 0.012, z * 1.15), [0.006, 0.014, 0.012], null, { piece: 'Ongles', slot: 'claw', k: 0.001 });
      }
      c.chain([P(0, 0.07, 0.06), P(0.03, 0.13, 0.12), P(0.05, 0.18, 0.15 * F)], [0.026, 0.021, 0.017], { k: 0.012 });
    },
  },
  hand_mitten: {
    name: 'Main cartoon', cat: 'hands', icon: '🧤', end: true, pieceName: 'Main',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.5, 2]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.1 * s, 0), [0.06 * s, 0.1 * s, 0.09 * s], null, { k: 0.03 });
      for (const z of [-0.05, 0, 0.05]) c.cone(P(0, 0.14 * s, z * s), P(0.01, 0.24 * s, z * s * 1.2), 0.03 * s, 0.028 * s, { k: 0.015 });
      c.cone(P(0, 0.08 * s, 0.07 * s), P(0.02, 0.15 * s, 0.14 * s), 0.03 * s, 0.026 * s, { k: 0.015 });
    },
  },
  hand_claw3: {
    name: 'Main à griffes', cat: 'hands', icon: '🐾', end: true, pieceName: 'Main',
    params: { finger: 1, claw: 1 },
    paramDefs: [['finger', 'Longueur des doigts', 0.5, 2], ['claw', 'Griffes', 0.3, 3]],
    build(c, p) {
      const F = p.finger;
      c.ell(P(0, 0.07, 0), [0.07, 0.09, 0.08], null, { k: 0.04 });
      for (const a of [-0.45, 0, 0.45]) {
        const d = [Math.sin(a) * 0.4, 1, Math.sin(a)];
        const b = P(d[0] * 0.05, 0.12, d[2] * 0.05), m = P(d[0] * 0.13 * F, 0.12 + 0.12 * F, d[2] * 0.12 * F);
        c.cone(b, m, 0.03, 0.022, { k: 0.012 });
        claw(c, m, [m[0] * 0.3, 1, m[2] * 0.3 + 0.3], 0.1 * p.claw, 0.02, [0, -0.3, 1]);
      }
    },
  },
  hand_4claw: {
    name: 'Main de monstre', cat: 'hands', icon: '👹', end: true, pieceName: 'Main',
    params: { finger: 1, claw: 1.4 },
    paramDefs: [['finger', 'Longueur des doigts', 0.5, 2], ['claw', 'Griffes', 0.3, 3]],
    build(c, p) {
      const F = p.finger;
      c.ell(P(0, 0.08, 0), [0.06, 0.11, 0.1], null, { k: 0.04 });
      for (let i = 0; i < 4; i++) {
        const z = -0.07 + i * 0.047;
        const b = P(0, 0.16, z), m = P(0.03, 0.16 + 0.1 * F, z * 1.2), e = P(0.07, 0.16 + 0.17 * F, z * 1.25);
        c.chain([b, m, e], [0.028, 0.024, 0.02], { k: 0.012 });
        claw(c, e, [0.6, 1, 0], 0.11 * p.claw, 0.02, [1, -0.2, 0]);
      }
      c.chain([P(0, 0.07, 0.08), P(0.03, 0.13, 0.14)], [0.03, 0.024], { k: 0.012 });
      claw(c, P(0.03, 0.13, 0.14), [0.5, 0.6, 0.6], 0.08 * p.claw, 0.018, [1, 0, 0]);
    },
  },
  hand_pincer: {
    name: 'Pince de crabe', cat: 'hands', icon: '🦀', end: true, pieceName: 'Pince', slot: 'secondary',
    params: { size: 1, open: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5], ['open', 'Ouverture', 0, 2]],
    build(c, p) {
      const s = p.size, o = p.open;
      c.ell(P(0, 0.15 * s, 0), [0.08 * s, 0.16 * s, 0.1 * s], null, { k: 0.02 });
      c.chain([P(0, 0.26 * s, 0.05 * s), P(0, 0.43 * s, (0.07 + 0.03 * o) * s), P(0, 0.52 * s, (-0.01 + 0.02 * o) * s)], [0.055 * s, 0.035 * s, TIP], { k: 0.01 });
      c.chain([P(0, 0.25 * s, -0.06 * s), P(0, 0.39 * s, (-0.09 - 0.04 * o) * s), P(0, 0.46 * s, (-0.04 - 0.04 * o) * s)], [0.045 * s, 0.03 * s, TIP], { piece: 'Doigt mobile', slot: 'secondary', k: 0.01 });
    },
  },
  hand_paw: {
    name: 'Patte ronde', cat: 'hands', icon: '🐻', end: true, pieceName: 'Patte',
    params: { claw: 1 },
    paramDefs: [['claw', 'Griffes', 0, 3]],
    build(c, p) {
      c.sphere(P(0, 0.06, 0.02), 0.09, { k: 0.04 });
      for (let i = 0; i < 4; i++) {
        const x = (i - 1.5) * 0.045;
        c.sphere(P(x, 0.12, 0.07), 0.035, { k: 0.015 });
        if (p.claw > 0.05) claw(c, P(x, 0.13, 0.09), [0, 0.6, 1], 0.06 * p.claw, 0.014, [0, -1, 0]);
      }
    },
  },
  hand_scythe: {
    name: 'Faux de mante', cat: 'hands', icon: '🗡️', end: true, slot: 'claw', pieceName: 'Lame',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.4, 2.5]],
    build(c, p) {
      const L = p.length;
      c.chain(arc(8, (t) => P(0, 0.5 * L * Math.sin(t * 1.6) / Math.sin(1.6), 0.28 * L * (1 - Math.cos(t * 1.6)))), taper(8, 0.05, TIP, 0.8), { k: 0.01 });
      c.piece('Dents de la lame', 'claw');
      for (let i = 1; i < 5; i++) c.cone(P(0, 0.08 * i * L, 0.01 * i * L), P(0, 0.08 * i * L - 0.01, 0.05 + 0.012 * i * L), 0.012, TIP, { k: 0.002 });
    },
  },
  hand_hook: {
    name: 'Crochet', cat: 'hands', icon: '🪝', end: true, slot: 'claw', pieceName: 'Crochet',
    params: { size: 1 },
    paramDefs: [['size', 'Taille', 0.4, 2.5]],
    build(c, p) {
      const s = p.size;
      c.cone(P(0, -0.02, 0), P(0, 0.08 * s, 0), 0.07 * s, 0.07 * s, { piece: 'Manchon', slot: 'dark', k: 0.004 });
      c.chain(arc(10, (t) => { const a = t * 3.6; return P(0, 0.08 * s + 0.1 * s * Math.sin(a) + (t < 0.01 ? 0 : 0.08 * s), 0.1 * s * (1 - Math.cos(a))); }), taper(10, 0.022 * s, TIP, 1.2), { k: 0.004 });
    },
  },
  hand_tentacle_sucker: {
    name: 'Ventouse', cat: 'hands', icon: '🐙', end: true, pieceName: 'Ventouse', slot: 'secondary',
    params: {},
    build(c) {
      c.cone(P(0, 0, 0), P(0, 0.07, 0), 0.06, 0.08, { k: 0.02 });
      c.sphere(P(0, 0.12, 0), 0.055, { op: 'sub', k: 0.01 });
    },
  },

  // =============================================================== FEET (limb ends, flat on ground)
  foot_paw: {
    name: 'Patte à coussinets', cat: 'feet', icon: '🐾', end: true, ground: true, pieceName: 'Pied',
    params: { toes: 4, claw: 1 },
    paramDefs: [['toes', 'Orteils', 2, 6, 1], ['claw', 'Griffes', 0, 3]],
    build(c, p) {
      c.ell(P(0, 0.02, 0.05), [0.11, 0.07, 0.13], null, { k: 0.04 });
      const n = Math.round(p.toes);
      for (let i = 0; i < n; i++) {
        const x = (i - (n - 1) / 2) * (0.2 / Math.max(1, n - 1)) * 1.2;
        c.sphere(P(x, 0.04, 0.16), 0.042, { k: 0.015 });
        if (p.claw > 0.05) claw(c, P(x, 0.045, 0.19), [0, -0.1, 1], 0.06 * p.claw, 0.016, [0, 1, 0]);
      }
    },
  },
  foot_hoof: {
    name: 'Sabot', cat: 'feet', icon: '🐴', end: true, ground: true, slot: 'dark', pieceName: 'Sabot',
    params: { split: 0 },
    paramDefs: [['split', 'Sabot fendu', 0, 1, 1]],
    build(c, p) {
      c.cone(P(0, -0.06, 0.01), P(0, 0.075, 0.03), 0.07, 0.095, { k: 0.01 });
      c.keep(P(0, 0.075, 0), [0, -1, 0], { k: 0.01 });
      if (p.split) c.box(P(0, 0.06, 0.1), [0.008, 0.05, 0.08], 0.004, null, { op: 'sub', k: 0.004 });
      c.torus(P(0, -0.02, 0.012), 0.072, 0.02, [0, 1, 0], { piece: 'Fanon', slot: 'secondary', k: 0.01 });
    },
  },
  foot_bird: {
    name: 'Serre d\'oiseau', cat: 'feet', icon: '🐔', end: true, ground: true, pieceName: 'Pied', slot: 'detail',
    params: { length: 1, claw: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2], ['claw', 'Griffes', 0, 3]],
    build(c, p) {
      const L = p.length;
      c.sphere(P(0, 0.05, 0), 0.05, { k: 0.02 });
      for (const a of [-0.5, 0, 0.5]) {
        const tip = P(Math.sin(a) * 0.22 * L, 0.08, Math.cos(a) * 0.22 * L);
        c.chain([P(0, 0.06, 0), lerp(P(0, 0.06, 0), tip, 0.5), tip], [0.03, 0.024, 0.018], { k: 0.01 });
        if (p.claw > 0.05) claw(c, tip, [Math.sin(a) * 0.5, 0.2, 1], 0.07 * p.claw, 0.016, [0, 1, 0]);
      }
      c.cone(P(0, 0.06, 0), P(0, 0.08, -0.12 * L), 0.028, 0.016, { k: 0.01 });
      if (p.claw > 0.05) claw(c, P(0, 0.08, -0.12 * L), [0, 0.2, -1], 0.05 * p.claw, 0.014, [0, 1, 0]);
    },
  },
  foot_raptor: {
    name: 'Patte de raptor', cat: 'feet', icon: '🦖', end: true, ground: true, pieceName: 'Pied',
    params: { length: 1, claw: 1.4 },
    paramDefs: [['length', 'Longueur', 0.5, 2], ['claw', 'Griffe tueuse', 0.3, 3]],
    build(c, p) {
      const L = p.length;
      c.ell(P(0, 0.06, 0.02), [0.07, 0.06, 0.09], null, { k: 0.03 });
      for (const a of [-0.3, 0.3]) {
        const tip = P(Math.sin(a) * 0.2 * L, 0.06, Math.cos(a) * 0.22 * L);
        c.chain([P(0, 0.07, 0.05), tip], [0.035, 0.026], { k: 0.01 });
        claw(c, tip, [Math.sin(a) * 0.4, 0.1, 1], 0.07, 0.02, [0, 1, 0]);
      }
      // raised sickle claw on the inner toe
      c.chain([P(0.04, 0.08, 0.05), P(0.06, 0.13, 0.13 * L)], [0.03, 0.024], { k: 0.01 });
      claw(c, P(0.06, 0.13, 0.13 * L), [0, 0.8, 1], 0.13 * p.claw, 0.024, [0, -1, 0.3]);
    },
  },
  foot_monster: {
    name: 'Pied de monstre', cat: 'feet', icon: '👣', end: true, ground: true, pieceName: 'Pied',
    params: { size: 1, claw: 1 },
    paramDefs: [['size', 'Taille', 0.5, 2], ['claw', 'Griffes', 0, 3]],
    build(c, p) {
      const s = p.size;
      c.ell(P(0, 0.05 * s, 0.04 * s), [0.13 * s, 0.08 * s, 0.15 * s], null, { k: 0.04 });
      c.keep(P(0, -0.005, 0), [0, 1, 0], { k: 0.02 });
      for (const x of [-0.08, 0, 0.08]) {
        c.ell(P(x * s, 0.045 * s, 0.17 * s), [0.04 * s, 0.045 * s, 0.05 * s], null, { k: 0.02 });
        if (p.claw > 0.05) claw(c, P(x * s, 0.04 * s, 0.21 * s), [x * 2, 0, 1], 0.07 * s * p.claw, 0.024 * s, [0, 1, 0]);
      }
    },
  },
  foot_human: {
    name: 'Pied humain', cat: 'feet', icon: '🦶', end: true, ground: true, pieceName: 'Pied',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2]],
    build(c, p) {
      const L = p.length;
      c.ell(P(0, 0.04, 0.06 * L), [0.075, 0.055, 0.15 * L], null, { k: 0.03 });
      c.keep(P(0, -0.005, 0), [0, 1, 0], { k: 0.015 });
    },
  },
  foot_boot: {
    name: 'Botte', cat: 'feet', icon: '🥾', end: true, ground: true, slot: 'detail', pieceName: 'Botte',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2]],
    build(c, p) {
      const L = p.length;
      c.cone(P(0, -0.14, 0), P(0, 0.03, 0), 0.085, 0.09, { k: 0.01 });
      c.box(P(0, 0.05, 0.06 * L), [0.085, 0.045, 0.16 * L], 0.04, null, { k: 0.03 });
      c.box(P(0, 0.09, 0.06 * L), [0.092, 0.012, 0.168 * L], 0.008, null, { piece: 'Semelle', slot: 'dark', k: 0.004 });
      c.torus(P(0, -0.13, 0), 0.088, 0.014, [0, 1, 0], { piece: 'Revers', slot: 'secondary', k: 0.004 });
    },
  },
  foot_elephant: {
    name: 'Pied d\'éléphant', cat: 'feet', icon: '🐘', end: true, ground: true, pieceName: 'Pied',
    params: {},
    build(c) {
      c.cone(P(0, -0.03, 0), P(0, 0.075, 0), 0.12, 0.14, { k: 0.03 });
      c.keep(P(0, 0.075, 0), [0, -1, 0], { k: 0.02 });
      for (const a of [-0.5, 0, 0.5]) c.ell(P(Math.sin(a) * 0.135, 0.045, Math.cos(a) * 0.135), [0.035, 0.028, 0.018], [P(Math.cos(a), 0, -Math.sin(a)), P(0, 1, 0)], { piece: 'Ongles', slot: 'claw', k: 0.003 });
    },
  },
  foot_webbed: {
    name: 'Pied palmé', cat: 'feet', icon: '🐸', end: true, ground: true, pieceName: 'Pied',
    params: { length: 1 },
    paramDefs: [['length', 'Longueur', 0.5, 2]],
    build(c, p) {
      const L = p.length;
      c.sphere(P(0, 0.05, 0), 0.05, { k: 0.02 });
      const tips = [-0.55, 0, 0.55].map((a) => P(Math.sin(a) * 0.24 * L, 0.08, Math.cos(a) * 0.24 * L));
      for (const t of tips) c.cone(P(0, 0.06, 0), t, 0.028, 0.02, { k: 0.01 });
      c.piece('Palmure', 'secondary');
      c.tri(P(0, 0.08, 0.02), tips[0], tips[1], 0.009, { k: 0.004 });
      c.tri(P(0, 0.08, 0.02), tips[1], tips[2], 0.009, { k: 0.004 });
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
  leg_thick: {
    name: 'Jambe massive', icon: '🦣', bone: 'Leg', end: 'foot_elephant',
    make(h) {
      return { joints: [[0, 0, 0], [0.05, -h * 0.5, -0.05], [0.07, -h + 0.08, 0]], radii: [0.22, 0.17, 0.14] };
    },
  },
  arm: {
    name: 'Bras', icon: '💪', bone: 'Arm', end: 'hand_5',
    make() {
      return { joints: [[0, 0, 0], [0.28, -0.3, 0.05], [0.33, -0.65, -0.05]], radii: [0.1, 0.075, 0.06] };
    },
  },
  arm_long: {
    name: 'Long bras (gorille)', icon: '🦍', bone: 'Arm', end: 'hand_4claw',
    make(h) {
      return { joints: [[0, 0, 0], [0.3, -0.45, 0.05], [0.4, -Math.max(0.9, h - 0.15), -0.1]], radii: [0.14, 0.11, 0.09] };
    },
  },
  leg_insect: {
    name: 'Patte d\'insecte', icon: '🦗', bone: 'Leg', end: 'none',
    make(h) {
      return { joints: [[0, 0, 0], [0.3, 0.2, 0], [0.62, 0.05, 0], [0.8, -h + 0.02, 0]], radii: [0.065, 0.05, 0.035, 0.008] };
    },
  },
  tentacle: {
    name: 'Tentacule', icon: '🐙', bone: 'Tentacle', end: 'none',
    make() {
      const joints = [], radii = [];
      for (let i = 0; i <= 6; i++) {
        joints.push([0.14 * i, -0.1 * i + 0.03 * Math.sin(i * 1.2), 0.06 * Math.sin(i * 1.3)]);
        radii.push(0.11 * (1 - i / 7) + 0.008);
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
