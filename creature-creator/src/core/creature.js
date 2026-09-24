// Creature data model + conversion to SDF primitives and skeleton.
//
// Coordinate system (same as Roblox): Y up, creature faces -Z, +X is its right.
// The spine lives in the symmetry plane x = 0. Limbs and parts placed on the
// +X side are mirrored automatically when `mirror` is true.

import { T_SPHERE, T_CONE, T_ELL, T_BOX, T_TRI, T_PLANE, T_TORUS, T_GROUP, sub, add, scale, dot, cross, len, norm, lerp3 } from './sdf.js';
import { PARTS, LIMBS } from './parts.js';

export const FORWARD = [0, 0, -1];
export const UP = [0, 1, 0];
const SUB = 4; // spine subdivisions per segment

let _uid = 1;
export function uid(prefix = 'id') {
  return prefix + (Date.now().toString(36).slice(-4)) + (_uid++).toString(36);
}

export function defaultPaint() {
  return {
    base: '#4f9d69',
    secondary: '#2f5d3e',
    detail: '#e8d9b0',
    claw: '#f1e9d2',
    eye: '#d8a21c',
    eyeWhite: '#f4f1ea',
    pupil: '#111114',
    highlight: '#ffffff',
    mouth: '#5b1a24',
    tongue: '#e0607e',
    teeth: '#f2eee0',
    dark: '#231d1d',
    bellyColor: '#e9e2b8',
    bellyAmount: 0.55,
    pattern: 'spots',
    usePattern: false,
    patternScale: 0.22,
    patternAmount: 0.9,
    texture: 0.5,
    seed: 3,
  };
}

// ------------------------------------------------------------------ spine

export function spinePoint(spine, u) {
  const n = spine.length;
  u = Math.max(0, Math.min(n - 1, u));
  let i = Math.min(Math.floor(u), n - 2);
  const t = u - i;
  const p1 = spine[i].p, p2 = spine[i + 1].p;
  const p0 = i > 0 ? spine[i - 1].p : sub(scale(p1, 2), p2);
  const p3 = i + 2 < n ? spine[i + 2].p : sub(scale(p2, 2), p1);
  const t2 = t * t, t3 = t2 * t;
  const out = [0, 0, 0];
  for (let k = 0; k < 3; k++) {
    out[k] = 0.5 * (2 * p1[k] + (-p0[k] + p2[k]) * t + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2 + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3);
  }
  return out;
}

export function spineRadius(spine, u) {
  const n = spine.length;
  u = Math.max(0, Math.min(n - 1, u));
  const i = Math.min(Math.floor(u), n - 2);
  const t = u - i;
  return spine[i].r + (spine[i + 1].r - spine[i].r) * t;
}

export function spineFrame(spine, u) {
  const n = spine.length;
  const e = 0.02;
  const a = spinePoint(spine, Math.max(0, u - e));
  const b = spinePoint(spine, Math.min(n - 1, u + e));
  let z = sub(b, a);
  z[0] = 0;
  z = norm(z);
  const x = [1, 0, 0];
  const y = cross(z, x);
  return { o: spinePoint(spine, u), x, y, z, r: spineRadius(spine, u) };
}

// ------------------------------------------------------------------ limbs

export function limbRoot(creature, limb) {
  const f = spineFrame(creature.spine, limb.anchor.u);
  return fromFrame(f, limb.anchor.off, f.r);
}

export function limbJoints(creature, limb) {
  const root = limbRoot(creature, limb);
  return limb.joints.map((o) => add(root, o));
}

function limbSegFrame(joints, radii, u) {
  const m = joints.length - 1;
  const i = Math.max(0, Math.min(m - 1, Math.floor(u)));
  const t = Math.max(0, Math.min(1, u - i));
  const z = norm(sub(joints[i + 1], joints[i]));
  const ref = Math.abs(z[1]) < 0.9 ? UP : [0, 0, 1];
  const x = norm(cross(ref, z));
  const y = cross(z, x);
  return { o: lerp3(joints[i], joints[i + 1], t), x, y, z, r: radii[i] + (radii[i + 1] - radii[i]) * t };
}

export function limbRadii(limb) {
  return limb.radii.map((r) => r * (limb.thick ?? 1));
}

// ---------------------------------------------------------------- anchors

function fromFrame(f, off, r) {
  return [
    f.o[0] + (f.x[0] * off[0] + f.y[0] * off[1] + f.z[0] * off[2]) * r,
    f.o[1] + (f.x[1] * off[0] + f.y[1] * off[1] + f.z[1] * off[2]) * r,
    f.o[2] + (f.x[2] * off[0] + f.y[2] * off[1] + f.z[2] * off[2]) * r,
  ];
}

function toFrame(f, p, r) {
  const d = sub(p, f.o);
  return [dot(d, f.x) / r, dot(d, f.y) / r, dot(d, f.z) / r];
}

function dirToFrame(f, v) { return [dot(v, f.x), dot(v, f.y), dot(v, f.z)]; }
function dirFromFrame(f, v) {
  return [
    f.x[0] * v[0] + f.y[0] * v[1] + f.z[0] * v[2],
    f.x[1] * v[0] + f.y[1] * v[1] + f.z[1] * v[2],
    f.x[2] * v[0] + f.y[2] * v[1] + f.z[2] * v[2],
  ];
}

export function anchorFrame(creature, anchor) {
  if (anchor.kind === 'limb') {
    const limb = creature.limbs.find((l) => l.id === anchor.id);
    if (!limb) return null;
    return limbSegFrame(limbJoints(creature, limb), limbRadii(limb), anchor.u);
  }
  return spineFrame(creature.spine, anchor.u);
}

// Find nearest attachment (spine or limb segment) to a world point.
export function nearestAnchor(creature, p, excludeLimb) {
  let best = { kind: 'spine', u: 0, d: Infinity };
  const sp = creature.spine;
  const steps = (sp.length - 1) * 24;
  for (let s = 0; s <= steps; s++) {
    const u = (s / steps) * (sp.length - 1);
    const d = len(sub(p, spinePoint(sp, u))) - spineRadius(sp, u);
    if (d < best.d) best = { kind: 'spine', u, d };
  }
  for (const limb of creature.limbs) {
    if (limb.id === excludeLimb) continue;
    const J = limbJoints(creature, limb);
    const R = limbRadii(limb);
    for (let i = 0; i < J.length - 1; i++) {
      const ab = sub(J[i + 1], J[i]);
      const t = Math.max(0, Math.min(1, dot(sub(p, J[i]), ab) / (dot(ab, ab) || 1)));
      const d = len(sub(p, lerp3(J[i], J[i + 1], t))) - (R[i] + (R[i + 1] - R[i]) * t);
      if (d < best.d) best = { kind: 'limb', id: limb.id, u: i + t, d };
    }
  }
  return best;
}

// Build a local frame from a surface normal, preferring `hint` as local +Z.
export function frameFromNormal(n, hint = 'fwd') {
  const h1 = hint === 'up' ? UP : FORWARD;
  const h2 = hint === 'up' ? FORWARD : UP;
  let z = sub(h1, scale(n, dot(h1, n)));
  if (len(z) < 0.35) z = sub(h2, scale(n, dot(h2, n)));
  z = norm(z);
  const y = norm(n);
  const x = cross(y, z);
  return { x, y, z };
}

// Store a world placement (point + orientation) as an anchor-relative one.
export function makeAttachment(creature, p, axes, excludeLimb) {
  const a = nearestAnchor(creature, p, excludeLimb);
  const anchor = a.kind === 'limb' ? { kind: 'limb', id: a.id, u: a.u } : { kind: 'spine', u: a.u };
  const f = anchorFrame(creature, anchor);
  anchor.off = toFrame(f, p, f.r);
  anchor.rx = dirToFrame(f, axes.x);
  anchor.ry = dirToFrame(f, axes.y);
  anchor.rz = dirToFrame(f, axes.z);
  return anchor;
}

export function resolveAttachment(creature, anchor) {
  const f = anchorFrame(creature, anchor);
  if (!f) return null;
  return {
    o: fromFrame(f, anchor.off, f.r),
    x: norm(dirFromFrame(f, anchor.rx)),
    y: norm(dirFromFrame(f, anchor.ry)),
    z: norm(dirFromFrame(f, anchor.rz)),
  };
}

export function makeLimbAnchor(creature, rootWorld) {
  const a = nearestAnchor(creature, rootWorld, '*none*');
  const best = { u: a.kind === 'spine' ? a.u : 0 };
  // only spine anchors for limbs
  const sp = creature.spine;
  let bd = Infinity;
  const steps = (sp.length - 1) * 24;
  for (let s = 0; s <= steps; s++) {
    const u = (s / steps) * (sp.length - 1);
    const d = len(sub(rootWorld, spinePoint(sp, u))) - spineRadius(sp, u);
    if (d < bd) { bd = d; best.u = u; }
  }
  const f = spineFrame(sp, best.u);
  return { u: best.u, off: toFrame(f, rootWorld, f.r) };
}

// ------------------------------------------------------------ rotations

export function rotateAxes(ax, deg) {
  // apply local euler rotation (X then Y then Z, degrees) to frame axes
  let { x, y, z } = ax;
  const rot = (a, b, ang) => {
    const c = Math.cos(ang), s = Math.sin(ang);
    return [add(scale(a, c), scale(b, s)), add(scale(a, -s), scale(b, c))];
  };
  const r = deg.map((d) => (d * Math.PI) / 180);
  if (r[0]) [y, z] = rot(y, z, r[0]);
  if (r[1]) [z, x] = rot(z, x, r[1]);
  if (r[2]) [x, y] = rot(x, y, r[2]);
  return { x, y, z };
}

// ------------------------------------------------------------ colours

// Colour slots a piece can use. Each exported piece is one solid colour.
export const SLOTS = [
  ['base', 'Peau'], ['secondary', 'Secondaire'], ['detail', 'Détail'], ['claw', 'Griffes / os'],
  ['eyeWhite', 'Blanc des yeux'], ['eye', 'Iris'], ['pupil', 'Pupille'], ['highlight', 'Reflet'],
  ['mouth', 'Intérieur bouche'], ['tongue', 'Langue'], ['teeth', 'Dents'], ['dark', 'Nez / sombre'], ['custom', 'Personnalisée'],
];

export function slotHex(paint, slot, custom) {
  if (slot === 'custom') return custom || '#ffffff';
  const d = defaultPaint();
  return paint[slot] || d[slot] || paint.base;
}

// ------------------------------------------------------------ build ctx

// A part is built in its own local frame (+Y out of the surface, +Z forward
// or up, +X side). Primitives go either into named "pieces" (each piece is a
// separate mesh = a separate MeshPart in Roblox, with its own colour) or, with
// { body: true }, into the body field (carving a mouth, fused skin lumps).
export class Ctx {
  constructor(frame, s, base) {
    this.f = frame; this.s = s; this.base = base;
    this.body = [];
    this.pieces = new Map();
    this.fwd = norm([dot(FORWARD, frame.x), dot(FORWARD, frame.y), dot(FORWARD, frame.z)]);
    this.up = norm([dot(UP, frame.x), dot(UP, frame.y), dot(UP, frame.z)]);
    this.piece(base.mainPiece || 'Principal', base.slot || 'base');
  }
  getPiece(name, slot) {
    if (!this.pieces.has(name)) this.pieces.set(name, { name, slot: slot ?? this.base.slot ?? 'base', prims: [] });
    return this.pieces.get(name);
  }
  piece(name, slot) { this.cur = this.getPiece(name, slot); return this; }
  W(p) {
    const { o, x, y, z } = this.f, s = this.s;
    return [
      o[0] + (x[0] * p[0] + y[0] * p[1] + z[0] * p[2]) * s,
      o[1] + (x[1] * p[0] + y[1] * p[1] + z[1] * p[2]) * s,
      o[2] + (x[2] * p[0] + y[2] * p[1] + z[2] * p[2]) * s,
    ];
  }
  WD(v) {
    const { x, y, z } = this.f;
    return norm([x[0] * v[0] + y[0] * v[1] + z[0] * v[2], x[1] * v[0] + y[1] * v[1] + z[1] * v[2], x[2] * v[0] + y[2] * v[1] + z[2] * v[2]]);
  }
  emit(build, o = {}) {
    const toBody = !!o.body;
    const T = toBody ? { p: (q) => this.W(q), d: (v) => this.WD(v) } : { p: (q) => [q[0] * this.s, q[1] * this.s, q[2] * this.s], d: (v) => norm(v) };
    const pr = build(T);
    pr.k = (o.k ?? this.base.k ?? 0.02) * this.s;
    pr.op = o.op || 'add';
    if (toBody) {
      pr.owner = this.base.owner;
      pr.bw = this.base.bw;
      pr.mat = { kind: 'skin', slot: 'base' };
      this.body.push(pr);
    } else {
      const target = o.piece ? this.getPiece(o.piece, o.slot) : this.cur;
      target.prims.push(pr);
    }
    return pr;
  }
  sphere(c, r, o) { return this.emit((T) => ({ t: T_SPHERE, c: T.p(c), r: r * this.s }), o); }
  cone(a, b, ra, rb, o) { return this.emit((T) => ({ t: T_CONE, a: T.p(a), b: T.p(b), ra: ra * this.s, rb: rb * this.s }), o); }
  chain(pts, radii, o) { for (let i = 0; i < pts.length - 1; i++) this.cone(pts[i], pts[i + 1], radii[i], radii[i + 1], o); }
  ell(c, h, axes, o) {
    const A = axes ? orthoAxes(axes) : [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
    return this.emit((T) => ({ t: T_ELL, c: T.p(c), h: h.map((v) => v * this.s), m: A.flatMap((a) => T.d(a)) }), o);
  }
  box(c, h, rr, axes, o) {
    const A = axes ? orthoAxes(axes) : [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
    return this.emit((T) => ({ t: T_BOX, c: T.p(c), h: h.map((v) => v * this.s), rr: rr * this.s, m: A.flatMap((a) => T.d(a)) }), o);
  }
  // torus around local axis `axis`
  torus(c, R, r, axis = [0, 1, 0], o) {
    const A = orthoAxes([axis]);
    // orthoAxes puts `axis` first; the torus SDF wants it as the 2nd row (local Y)
    const rows = [A[1], A[0], A[2]];
    return this.emit((T) => ({ t: T_TORUS, c: T.p(c), h: [R * this.s, r * this.s], m: rows.flatMap((a) => T.d(a)) }), o);
  }
  tri(a, b, c, th, o) { return this.emit((T) => ({ t: T_TRI, a: T.p(a), b: T.p(b), c: T.p(c), th: th * this.s }), o); }
  // keep only the half-space on the side of `n` (use inside a piece)
  keep(pt, n, o = {}) { return this.emit((T) => ({ t: T_PLANE, o: T.p(pt), n: T.d([-n[0], -n[1], -n[2]]) }), Object.assign({ op: 'int', k: 0.008 }, o)); }
  // several primitives combined on their own (their cuts stay local), then
  // merged into the current piece as one shape
  group(fn, o = {}) {
    const save = this.cur;
    const tmp = { prims: [] };
    this.cur = tmp;
    fn();
    this.cur = save;
    const target = o.piece ? this.getPiece(o.piece, o.slot) : this.cur;
    target.prims.push({ t: T_GROUP, prims: tmp.prims, op: o.op || 'add', k: (o.k ?? 0.004) * this.s });
  }

  // An eye made of 4 separate pieces: white, iris, pupil, highlight.
  eye(c, r, opts = {}) {
    const look = opts.look ?? 0.55;
    const dir = opts.dir ? norm(opts.dir) : norm(add(scale([0, 1, 0], 1 - look), scale(this.fwd, look * 1.4)));
    let up = sub(this.up, scale(dir, dot(this.up, dir)));
    if (len(up) < 0.2) up = sub([0, 0, 1], scale(dir, dot([0, 0, 1], dir)));
    up = norm(up);
    const side = cross(dir, up);
    const at = (d, t) => add(c, scale(d, t));
    const irisA = Math.min(1.2, 0.95 * (opts.irisSize ?? 0.6));
    const pre = opts.prefix || '';
    this.sphere(c, r, { piece: pre + 'Blanc de l\'œil', slot: opts.whiteSlot || 'eyeWhite', k: 0.001 });
    if (irisA > 0.05) {
      this.sphere(c, r * 1.02, { piece: pre + 'Iris', slot: opts.irisSlot || 'eye', k: 0.001 });
      this.keep(at(dir, r * Math.cos(irisA)), dir, { piece: pre + 'Iris', slot: opts.irisSlot || 'eye', k: 0.002 });
    }
    const pa = irisA * (opts.pupil ?? 0.45);
    if (pa > 0.02) {
      const P = pre + 'Pupille';
      this.sphere(c, r * 1.04, { piece: P, slot: 'pupil', k: 0.001 });
      this.keep(at(dir, r * Math.cos(Math.min(1.3, opts.slit ? irisA * 0.98 : pa))), dir, { piece: P, slot: 'pupil', k: 0.002 });
      if (opts.slit) this.box(c, [r * Math.sin(pa) * 0.42, r * 1.3, r * 1.3], 0, [side, up], { piece: P, slot: 'pupil', op: 'int', k: 0.002 });
    }
    if (opts.highlight !== false) {
      const hd = norm(add(add(dir, scale(up, 0.55)), scale(side, 0.3)));
      const hs = r * 0.13 * (opts.highlightSize ?? 1);
      // a flat glossy spot lying on the eye surface
      this.ell(at(hd, r * 1.035), [hs, hs * 0.8, r * 0.03], [cross(hd, up), up], { piece: pre + 'Reflet', slot: 'highlight', k: 0.001 });
    }
  }
}

function orthoAxes(axes) {
  const a0 = norm(axes[0]);
  let a1 = axes[1] ? sub(axes[1], scale(a0, dot(axes[1], a0))) : null;
  if (!a1 || len(a1) < 1e-4) {
    const ref = Math.abs(a0[1]) < 0.9 ? [0, 1, 0] : [1, 0, 0];
    a1 = sub(ref, scale(a0, dot(ref, a0)));
  }
  a1 = norm(a1);
  const a2 = cross(a0, a1);
  return [a0, a1, a2];
}

// ---------------------------------------------------------- transforms

// local (part frame) primitive -> world primitive
export function xformPrim(p, f, mirror = false) {
  const q = JSON.parse(JSON.stringify(p));
  const pt = (v) => {
    const w = [f.o[0] + f.x[0] * v[0] + f.y[0] * v[1] + f.z[0] * v[2], f.o[1] + f.x[1] * v[0] + f.y[1] * v[1] + f.z[1] * v[2], f.o[2] + f.x[2] * v[0] + f.y[2] * v[1] + f.z[2] * v[2]];
    if (mirror) w[0] = -w[0];
    return w;
  };
  const dr = (v) => {
    const w = [f.x[0] * v[0] + f.y[0] * v[1] + f.z[0] * v[2], f.x[1] * v[0] + f.y[1] * v[1] + f.z[1] * v[2], f.x[2] * v[0] + f.y[2] * v[1] + f.z[2] * v[2]];
    if (mirror) w[0] = -w[0];
    return w;
  };
  if (q.prims) q.prims = q.prims.map((c) => xformPrim(c, f, mirror));
  for (const k of ['c', 'a', 'b', 'o']) if (Array.isArray(q[k])) q[k] = pt(q[k]);
  if (q.n) q.n = dr(q.n);
  if (q.m) {
    const m = [];
    for (let i = 0; i < 3; i++) m.push(...dr([q.m[i * 3], q.m[i * 3 + 1], q.m[i * 3 + 2]]));
    q.m = m;
  }
  return q;
}

export function mirrorPrim(p) {
  const q = JSON.parse(JSON.stringify(p));
  const fx = (v) => { if (Array.isArray(v)) v[0] = -v[0]; };
  if (q.prims) q.prims = q.prims.map((c) => mirrorPrim(c));
  fx(q.c); fx(q.a); fx(q.b); fx(q.o); fx(q.n);
  if (q.m) { q.m[0] = -q.m[0]; q.m[3] = -q.m[3]; q.m[6] = -q.m[6]; }
  q.mirrored = true;
  return q;
}

// 4x4 column-major matrix of a piece (local -> world)
export function pieceMatrix(pc) {
  const { o, x, y, z } = pc.frame;
  const m = [x[0], x[1], x[2], 0, y[0], y[1], y[2], 0, z[0], z[1], z[2], 0, o[0], o[1], o[2], 1];
  if (pc.mirror) { m[0] = -m[0]; m[4] = -m[4]; m[8] = -m[8]; m[12] = -m[12]; }
  return m;
}

// ---------------------------------------------------------------- build

export function isMirrored(obj, x) {
  return obj.mirror !== false && x > 0.03;
}

const PIECE_SIDE = { R: 'R', L: 'L', C: '' };

// Convert a creature to: body primitives (one fused, skinned mesh), separate
// pieces (one mesh each) and the skeleton.
export function buildCreature(creature) {
  const prims = [];
  const pieces = [];
  const bones = [];
  const sp = creature.spine;
  const n = sp.length;

  // ---- skeleton: spine
  const legLimbs = creature.limbs.filter((l) => {
    const J = limbJoints(creature, l);
    return J[J.length - 1][1] < J[0][1] - 0.2;
  });
  let rootIdx = Math.floor((n - 1) / 2);
  if (legLimbs.length) {
    const u = legLimbs.reduce((s, l) => s + l.anchor.u, 0) / legLimbs.length;
    rootIdx = Math.max(0, Math.min(n - 1, Math.round(u)));
  }
  const spineBone = [];
  for (let i = 0; i < n; i++) {
    spineBone[i] = bones.length;
    bones.push({ name: i === 0 ? 'Head' : i === rootIdx ? 'Root' : `Spine${i}`, parent: -1, pos: sp[i].p.slice(), kind: 'spine', index: i });
  }
  if (rootIdx === 0) bones[0].name = 'Root';
  for (let i = 0; i < n; i++) {
    if (i < rootIdx) bones[spineBone[i]].parent = spineBone[i + 1];
    else if (i > rootIdx) bones[spineBone[i]].parent = spineBone[i - 1];
  }
  const spineBW = (u) => {
    u = Math.max(0, Math.min(n - 1, u));
    const i = Math.floor(u), f = u - i;
    if (i >= n - 1) return [[spineBone[n - 1], 1]];
    return f < 1e-3 ? [[spineBone[i], 1]] : [[spineBone[i], 1 - f], [spineBone[i + 1], f]];
  };
  const mainBone = (bw) => bw.reduce((a, b) => (b[1] > a[1] ? b : a))[0];

  // collect the output of a part context
  const usedNames = new Map();
  const collect = (ctx, meta) => {
    const { owner, label, mirrored, bw, bwMirror, fuse, overrides, frame } = meta;
    const bodyStart = prims.length;
    for (const pr of ctx.body) prims.push(pr);
    if (mirrored) for (let i = bodyStart; i < prims.length && i < bodyStart + ctx.body.length; i++) {
      const q = mirrorPrim(prims[i]);
      q.bw = bwMirror;
      prims.push(q);
    }
    for (const pc of ctx.pieces.values()) {
      if (!pc.prims.length || !pc.prims.some((p) => p.op === 'add')) continue;
      const ov = (overrides && overrides[pc.name]) || {};
      const slot = ov.slot || pc.slot;
      if (fuse && slot === 'base') {
        // fused skin: goes into the body field
        // as one group so that its own cuts/intersections stay local
        for (const side of mirrored ? [false, true] : [false]) {
          const g = { t: T_GROUP, prims: pc.prims.map((p) => xformPrim(p, frame, side)), op: 'add', k: 0.035 * ctx.s, owner, bw: side ? bwMirror : bw, mat: { kind: 'skin', slot: 'base' } };
          if (side) g.mirrored = true;
          prims.push(g);
        }
        continue;
      }
      const key = hashStr(JSON.stringify(pc.prims));
      for (const side of mirrored ? ['R', 'L'] : ['C']) {
        const nm = `${label}${PIECE_SIDE[side] ? '_' + PIECE_SIDE[side] : ''}_${asciiName(pc.name)}`;
        const cnt = (usedNames.get(nm) || 0) + 1;
        usedNames.set(nm, cnt);
        const w = side === 'L' ? bwMirror : bw;
        pieces.push({
          id: `${owner}|${pc.name}|${side}`, key, owner, name: cnt > 1 ? `${nm}${cnt}` : nm, piece: pc.name,
          slot, color: ov.color || meta.color || null, prims: pc.prims, frame, mirror: side === 'L', bw: w, bone: mainBone(w),
        });
      }
    }
  };

  // ---- spine prims
  const blend = creature.body?.blend ?? 1;
  const mat = { kind: 'skin', slot: 'base' };
  for (let i = 0; i < n - 1; i++) {
    for (let s = 0; s < SUB; s++) {
      const u0 = i + s / SUB, u1 = i + (s + 1) / SUB;
      const ra = spineRadius(sp, u0), rb = spineRadius(sp, u1);
      prims.push({
        t: T_CONE, a: spinePoint(sp, u0), b: spinePoint(sp, u1), ra, rb,
        k: 0.25 * blend * Math.min(ra, rb), mat, op: 'add', owner: 'spine', bw: spineBW((u0 + u1) / 2),
      });
    }
  }

  // ---- limbs (fused into the body)
  const limbBones = {};
  const kindCount = {};
  for (const limb of creature.limbs) {
    const def = LIMBS[limb.kind] || LIMBS.leg;
    kindCount[def.bone] = (kindCount[def.bone] || 0) + 1;
    const J = limbJoints(creature, limb);
    const R = limbRadii(limb);
    const mirrored = isMirrored(limb, J[0][0]);
    const baseName = `${def.bone}${kindCount[def.bone]}`;
    const sides = mirrored ? [['_R', false], ['_L', true]] : [['', false]];
    limbBones[limb.id] = {};
    for (const [suffix, isMirror] of sides) {
      const parentBone = spineBone[Math.max(0, Math.min(n - 1, Math.round(limb.anchor.u)))];
      const ids = [];
      for (let j = 0; j < J.length - 1; j++) {
        const pos = isMirror ? [-J[j][0], J[j][1], J[j][2]] : J[j].slice();
        ids.push(bones.length);
        bones.push({ name: `${baseName}_${j + 1}${suffix}`, parent: j === 0 ? parentBone : ids[j - 1], pos, kind: 'limb', limb: limb.id, seg: j, mirror: isMirror });
      }
      if (limb.end && limb.end !== 'none') {
        const Jm = J[J.length - 1];
        const last = ids[ids.length - 1];
        ids.push(bones.length);
        bones.push({ name: `${baseName}_End${suffix}`, parent: last, pos: isMirror ? [-Jm[0], Jm[1], Jm[2]] : Jm.slice(), kind: 'limb', limb: limb.id, seg: J.length - 1, mirror: isMirror, end: true });
      }
      limbBones[limb.id][isMirror ? 'mirror' : 'main'] = ids;
    }
    const owner = 'limb:' + limb.id;
    const mainIds = limbBones[limb.id].main;
    const start = prims.length;
    for (let j = 0; j < J.length - 1; j++) {
      const k = j === 0 ? Math.max(R[0] * 0.9, 0.05) : Math.min(R[j], R[j + 1]) * 0.35;
      prims.push({ t: T_CONE, a: J[j], b: J[j + 1], ra: R[j], rb: R[j + 1], k, mat, op: 'add', owner, bw: [[mainIds[j], 1]] });
    }
    const end = prims.length;
    const mids = limbBones[limb.id].mirror;
    if (mirrored) {
      for (let i = start; i < end; i++) {
        const q = mirrorPrim(prims[i]);
        q.bw = prims[i].bw.map(([b, w]) => [mids[mainIds.indexOf(b)], w]);
        prims.push(q);
      }
    }
    // end part (hand / foot): skin fused, claws etc. as pieces
    if (limb.end && limb.end !== 'none' && PARTS[limb.end]) {
      const def2 = PARTS[limb.end];
      const Jm = J[J.length - 1], Jp = J[J.length - 2];
      const dir = norm(sub(Jm, Jp));
      let axes = def2.ground ? frameFromNormal([0, -1, 0], 'fwd') : frameFromNormal(dir, 'fwd');
      axes = rotateAxes(axes, limb.endRot || [0, 0, 0]);
      const frame = Object.assign({ o: Jm }, axes);
      const sc = (limb.endScale ?? 1) * (limb.thick ?? 1);
      const endBone = mainIds[mainIds.length - 1];
      const bw = [[endBone, 1]];
      const bwM = mirrored ? [[mids[mids.length - 1], 1]] : bw;
      const ctx = new Ctx(frame, sc, { owner, bw, slot: def2.slot || 'base', k: 0.03, mainPiece: def2.pieceName || def2.name });
      def2.build(ctx, Object.assign({}, def2.params || {}, limb.endParams || {}), { radius: R[R.length - 1] });
      collect(ctx, { owner, label: `${baseName}${asciiName(def2.name)}`, mirrored, bw, bwMirror: bwM, fuse: true, overrides: limb.endPieces, frame, color: null });
    }
  }

  // ---- parts
  for (const part of creature.parts) {
    const def = PARTS[part.type];
    if (!def) continue;
    const at = resolveAttachment(creature, part.anchor);
    if (!at) continue;
    const axes = rotateAxes(at, part.rot || [0, 0, 0]);
    const o = add(at.o, scale(axes.y, (part.lift || 0) * (part.scale || 1)));
    const frame = Object.assign({ o }, axes);
    let bw, bwMirror;
    if (part.anchor.kind === 'limb' && limbBones[part.anchor.id]) {
      const lb = limbBones[part.anchor.id];
      const seg = Math.max(0, Math.min(lb.main.length - 1, Math.floor(part.anchor.u)));
      bw = [[lb.main[seg], 1]];
      bwMirror = lb.mirror ? [[lb.mirror[seg], 1]] : bw;
    } else {
      const u = Math.round(part.anchor.u);
      bw = [[spineBone[Math.max(0, Math.min(n - 1, u))], 1]];
      bwMirror = bw;
    }
    const owner = 'part:' + part.id;
    const ctx = new Ctx(frame, part.scale || 1, { owner, bw: part.anchor.kind === 'limb' ? bw : spineBW(part.anchor.u), slot: part.slot || def.slot || 'base', k: def.k ?? 0.02, mainPiece: def.pieceName || def.name });
    def.build(ctx, Object.assign({}, def.params || {}, part.params || {}));
    const fuse = part.fuse ?? !!def.fuse;
    collect(ctx, { owner, label: asciiName(def.name), mirrored: isMirrored(part, o[0]), bw, bwMirror, fuse, overrides: part.pieces, frame, color: part.slot === 'custom' ? part.color : null });
  }

  // stable order: add, sub, int
  const rank = { add: 0, sub: 1, int: 2 };
  prims.forEach((p, i) => (p._i = i));
  prims.sort((a, b) => rank[a.op || 'add'] - rank[b.op || 'add'] || a._i - b._i);

  const head = sp[0].p, tail = sp[n - 1].p;
  const axis = norm(sub(tail, head));
  const upright = Math.abs(axis[1]) > 0.7;
  return { prims, pieces, bones, axis, bellyDir: upright ? [0, 0, -1] : [0, -1, 0] };
}

export function asciiName(s) {
  const t = String(s).replace(/œ/g, 'oe').replace(/Œ/g, 'Oe').replace(/æ/g, 'ae')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^A-Za-z0-9]+/g, ' ').trim();
  return t.split(' ').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join('') || 'Piece';
}

// World-space primitives of a piece (for picking / placement).
export function pieceWorldPrims(pc) {
  return pc.prims.map((p) => {
    const q = xformPrim(p, pc.frame, pc.mirror);
    q.owner = pc.owner;
    if (pc.mirror) q.mirrored = true;
    return q;
  });
}

export function hashStr(str) {
  let h1 = 0x811c9dc5, h2 = 0x01000193;
  for (let i = 0; i < str.length; i++) {
    const c = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ c, 16777619);
    h2 = Math.imul(h2 ^ c, 2246822519);
  }
  return (h1 >>> 0).toString(36) + (h2 >>> 0).toString(36) + str.length.toString(36);
}
