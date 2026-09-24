// Creature data model + conversion to SDF primitives and skeleton.
//
// Coordinate system (same as Roblox): Y up, creature faces -Z, +X is its right.
// The spine lives in the symmetry plane x = 0. Limbs and parts placed on the
// +X side are mirrored automatically when `mirror` is true.

import { T_SPHERE, T_CONE, T_ELL, T_BOX, T_TRI, sub, add, scale, dot, cross, len, norm, lerp3 } from './sdf.js';
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
    bellyColor: '#e9e2b8',
    bellyAmount: 0.55,
    pattern: 'spots',
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

// ------------------------------------------------------------ build ctx

// Emits primitives in part-local coordinates.
export class Ctx {
  constructor(out, o, axes, s, base) {
    this.out = out; this.o = o; this.ax = axes; this.s = s; this.base = base;
  }
  w(p) {
    const { x, y, z } = this.ax, s = this.s;
    return [
      this.o[0] + (x[0] * p[0] + y[0] * p[1] + z[0] * p[2]) * s,
      this.o[1] + (x[1] * p[0] + y[1] * p[1] + z[1] * p[2]) * s,
      this.o[2] + (x[2] * p[0] + y[2] * p[1] + z[2] * p[2]) * s,
    ];
  }
  d(v) {
    const { x, y, z } = this.ax;
    return norm([
      x[0] * v[0] + y[0] * v[1] + z[0] * v[2],
      x[1] * v[0] + y[1] * v[1] + z[1] * v[2],
      x[2] * v[0] + y[2] * v[1] + z[2] * v[2],
    ]);
  }
  push(pr, o = {}) {
    pr.k = (o.k ?? this.base.k) * this.s;
    pr.mat = this.mat(o);
    pr.sub = !!o.sub;
    pr.layer = o.sub ? 1 : o.layer ?? 0;
    pr.owner = this.base.owner;
    pr.bw = this.base.bw;
    this.out.push(pr);
    return pr;
  }
  mat(o) {
    if (o.mat) return o.mat;
    const slot = o.slot ?? this.base.slot ?? 'base';
    if (slot === 'mouth') return { kind: 'fixed', color: [0.35, 0.06, 0.08] };
    if (slot === 'teeth') return { kind: 'fixed', color: [0.97, 0.96, 0.9] };
    if (slot === 'dark') return { kind: 'fixed', color: [0.08, 0.06, 0.06] };
    if (slot === 'custom') return { kind: 'skin', slot: 'custom', color: this.base.color || [1, 1, 1] };
    return { kind: 'skin', slot };
  }
  sphere(c, r, o) { return this.push({ t: T_SPHERE, c: this.w(c), r: r * this.s }, o); }
  cone(a, b, ra, rb, o) { return this.push({ t: T_CONE, a: this.w(a), b: this.w(b), ra: ra * this.s, rb: rb * this.s }, o); }
  chain(pts, radii, o) {
    for (let i = 0; i < pts.length - 1; i++) this.cone(pts[i], pts[i + 1], radii[i], radii[i + 1], o);
  }
  // axes: optional local axes [a0,a1,a2] (part-local vectors) for radii h
  ell(c, h, axes, o) {
    const A = axes ? orthoAxes(axes) : [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
    const m = [];
    for (const a of A) m.push(...this.d(a));
    return this.push({ t: T_ELL, c: this.w(c), h: h.map((v) => v * this.s), m }, o);
  }
  box(c, h, rr, axes, o) {
    const A = axes ? orthoAxes(axes) : [[1, 0, 0], [0, 1, 0], [0, 0, 1]];
    const m = [];
    for (const a of A) m.push(...this.d(a));
    return this.push({ t: T_BOX, c: this.w(c), h: h.map((v) => v * this.s), rr: rr * this.s, m }, o);
  }
  tri(a, b, c, th, o) { return this.push({ t: T_TRI, a: this.w(a), b: this.w(b), c: this.w(c), th: th * this.s }, o); }
  eye(c, r, opts = {}) {
    const wc = this.w(c);
    const n = this.ax.y;
    const look = opts.look ?? 0.55;
    let dir = opts.dir ? this.d(opts.dir) : norm(add(scale(n, 1 - look), scale(FORWARD, look * 1.4)));
    let up = sub(UP, scale(dir, dot(UP, dir)));
    if (len(up) < 0.2) up = sub([0, 0, 1], scale(dir, dot([0, 0, 1], dir)));
    up = norm(up);
    const mat = { kind: 'eye', c: wc, dir, up, irisSize: opts.irisSize ?? 0.6, pupil: opts.pupil ?? 0.45, slit: !!opts.slit, iris: opts.iris };
    return this.push({ t: T_SPHERE, c: wc, r: r * this.s }, { k: opts.k ?? 0.012, mat, layer: 2 });
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

// ---------------------------------------------------------- mirror prims

export function mirrorPrim(p) {
  const q = JSON.parse(JSON.stringify(p));
  const fx = (v) => { if (v) v[0] = -v[0]; };
  fx(q.c); fx(q.a); fx(q.b);
  if (q.m) { q.m[0] = -q.m[0]; q.m[3] = -q.m[3]; q.m[6] = -q.m[6]; }
  if (q.mat && q.mat.kind === 'eye') { fx(q.mat.c); fx(q.mat.dir); fx(q.mat.up); }
  q.mirrored = true;
  return q;
}

// ---------------------------------------------------------------- build

export function isMirrored(obj, x) {
  return obj.mirror !== false && x > 0.03;
}

// Convert a creature to primitives + skeleton.
export function buildCreature(creature) {
  const prims = [];
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

  // ---- spine prims
  const blend = creature.body?.blend ?? 1;
  const mat = { kind: 'skin', slot: 'base' };
  for (let i = 0; i < n - 1; i++) {
    for (let s = 0; s < SUB; s++) {
      const u0 = i + s / SUB, u1 = i + (s + 1) / SUB;
      const ra = spineRadius(sp, u0), rb = spineRadius(sp, u1);
      prims.push({
        t: T_CONE, a: spinePoint(sp, u0), b: spinePoint(sp, u1), ra, rb,
        k: 0.25 * blend * Math.min(ra, rb), mat, sub: false, layer: 0, owner: 'spine', bw: spineBW((u0 + u1) / 2),
      });
    }
  }

  // ---- limbs
  const limbBones = {}; // id -> {main:[...], mirror:[...]}
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
    const start = prims.length;
    const owner = 'limb:' + limb.id;
    const lmat = limb.slot === 'custom' ? { kind: 'skin', slot: 'custom', color: hexRgb(limb.color) } : { kind: 'skin', slot: limb.slot || 'base' };
    const mainIds = limbBones[limb.id].main;
    for (let j = 0; j < J.length - 1; j++) {
      const k = j === 0 ? Math.max(R[0] * 0.9, 0.05) : Math.min(R[j], R[j + 1]) * 0.35;
      prims.push({ t: T_CONE, a: J[j], b: J[j + 1], ra: R[j], rb: R[j + 1], k, mat: lmat, sub: false, layer: 0, owner, bw: [[mainIds[j], 1]] });
    }
    // end part (hand / foot)
    if (limb.end && limb.end !== 'none' && PARTS[limb.end]) {
      const def2 = PARTS[limb.end];
      const Jm = J[J.length - 1], Jp = J[J.length - 2];
      const dir = norm(sub(Jm, Jp));
      let axes;
      if (def2.ground) axes = frameFromNormal([0, -1, 0], 'fwd');
      else axes = frameFromNormal(dir, 'fwd');
      axes = rotateAxes(axes, limb.endRot || [0, 0, 0]);
      const s = (limb.endScale ?? 1) * (limb.thick ?? 1);
      const base = { owner, bw: [[mainIds[mainIds.length - 1], 1]], slot: def2.slot || 'base', k: 0.03 };
      if (limb.endSlot) { base.slot = limb.endSlot; base.color = hexRgb(limb.endColor); }
      const ctx = new Ctx(prims, Jm, axes, s, base);
      def2.build(ctx, Object.assign({}, def2.params || {}, limb.endParams || {}), { radius: R[R.length - 1] });
    }
    if (mirrored) {
      const mids = limbBones[limb.id].mirror;
      const end = prims.length;
      for (let i = start; i < end; i++) {
        const q = mirrorPrim(prims[i]);
        q.bw = prims[i].bw.map(([b, w]) => [mids[mainIds.indexOf(b)], w]);
        prims.push(q);
      }
    }
  }

  // ---- parts
  for (const part of creature.parts) {
    const def = PARTS[part.type];
    if (!def) continue;
    const at = resolveAttachment(creature, part.anchor);
    if (!at) continue;
    let axes = rotateAxes(at, part.rot || [0, 0, 0]);
    const o = add(at.o, scale(axes.y, (part.lift || 0) * (part.scale || 1)));
    let bw, bwMirror;
    if (part.anchor.kind === 'limb' && limbBones[part.anchor.id]) {
      const lb = limbBones[part.anchor.id];
      const seg = Math.max(0, Math.min(lb.main.length - 1, Math.floor(part.anchor.u)));
      bw = [[lb.main[seg], 1]];
      bwMirror = lb.mirror ? [[lb.mirror[seg], 1]] : bw;
    } else {
      bw = spineBW(part.anchor.u);
      bwMirror = bw;
    }
    const base = { owner: 'part:' + part.id, bw, slot: part.slot || def.slot || 'base', color: hexRgb(part.color), k: def.k ?? 0.03 };
    const start = prims.length;
    const ctx = new Ctx(prims, o, axes, part.scale || 1, base);
    def.build(ctx, Object.assign({}, def.params || {}, part.params || {}));
    if (isMirrored(part, o[0])) {
      const end = prims.length;
      for (let i = start; i < end; i++) {
        const q = mirrorPrim(prims[i]);
        q.bw = bwMirror;
        prims.push(q);
      }
    }
  }

  // stable order: additive (layer 0), subtractive (layer 1), post-add (layer 2)
  prims.forEach((p, i) => (p._i = i));
  prims.sort((a, b) => a.layer - b.layer || a._i - b._i);

  // paint helpers: main axis + belly direction
  const head = sp[0].p, tail = sp[n - 1].p;
  const axis = norm(sub(tail, head));
  const upright = Math.abs(axis[1]) > 0.7;
  return { prims, bones, axis, bellyDir: upright ? [0, 0, -1] : [0, -1, 0] };
}

function hexRgb(hex) {
  if (!hex) return null;
  const n = parseInt(hex.replace('#', ''), 16);
  return [((n >> 16) & 255) / 255, ((n >> 8) & 255) / 255, (n & 255) / 255];
}
