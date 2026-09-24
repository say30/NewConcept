// Editing helpers shared by the UI and the presets: ray tracing against the
// creature field, placing parts and limbs.

import { buildCreature, frameFromNormal, makeAttachment, makeLimbAnchor, spineFrame, uid } from './creature.js';
import { FieldModel } from './mesher.js';
import { PARTS, LIMBS } from './parts.js';
import { norm, sub, scale, add, dot } from './sdf.js';

export function makeModel(prims, skipOwner) {
  const list = skipOwner ? prims.filter((p) => p.owner !== skipOwner) : prims;
  if (!list.length) return null;
  return new FieldModel(list, 0.02, { minThickness: 0 });
}

export function trace(model, ro, rd, maxT = 60) {
  if (!model) return null;
  // ray / bounds intersection
  let t0 = 0, t1 = maxT;
  const pad = 0.2;
  for (let i = 0; i < 3; i++) {
    const inv = 1 / (rd[i] || 1e-12);
    let a = (model.mn[i] - pad - ro[i]) * inv, b = (model.mx[i] + pad - ro[i]) * inv;
    if (a > b) [a, b] = [b, a];
    t0 = Math.max(t0, a); t1 = Math.min(t1, b);
  }
  if (t0 > t1) return null;
  let t = t0;
  for (let s = 0; s < 300 && t < t1; s++) {
    const p = [ro[0] + rd[0] * t, ro[1] + rd[1] * t, ro[2] + rd[2] * t];
    const f = model.field(p[0], p[1], p[2]);
    if (f < 0.0015) {
      const n = norm(model.grad(p[0], p[1], p[2], 0.005));
      return { t, p, n };
    }
    t += Math.max(f * 0.8, 0.002);
  }
  return null;
}

export function ownerAt(model, p) {
  const info = model.surfaceInfo(p[0], p[1], p[2], false);
  if (!info.prim) return null;
  return { owner: info.prim.owner, mirrored: !!info.prim.mirrored };
}

// Normalise a surface hit for symmetric placement: parts go on the +X side,
// and points close to the middle snap onto the symmetry plane.
export function symmetricHit(p, n, snap = 0.05) {
  p = p.slice(); n = n.slice();
  let flipped = false;
  if (p[0] < 0) { p[0] = -p[0]; n[0] = -n[0]; flipped = true; }
  if (p[0] < snap) { p[0] = 0; n[0] = 0; n = norm(n); }
  return { p, n, flipped };
}

export function createPart(creature, type, p, n, extra = {}) {
  const def = PARTS[type];
  const axes = frameFromNormal(n, def.hint || 'fwd');
  if (def.spread && !extra.rot) {
    // wings: roll the part around its forward axis so it opens sideways
    const d = norm([p[0] > 0.01 ? 1 : 0.0001, 0.45, 0]);
    const dx = dot(d, axes.x), dy = dot(d, axes.y);
    extra = Object.assign({}, extra, { rot: [0, 0, (Math.atan2(-dx, dy) * 180) / Math.PI] });
  }
  return Object.assign({
    id: uid('p'), type,
    anchor: makeAttachment(creature, p, axes),
    scale: 1, rot: [0, 0, 0], lift: 0, mirror: true, params: {}, slot: null, color: '#ffffff',
  }, extra);
}

export function createLimb(creature, kind, p, n, extra = {}) {
  const def = LIMBS[kind];
  const probe = def.make(1);
  const r0 = probe.radii[0] * (extra.thick ?? 1);
  const root = sub(p, scale(n, r0 * 0.45));
  const h = Math.max(0.35, root[1]);
  const m = def.make(h);
  return Object.assign({
    id: uid('l'), kind,
    anchor: makeLimbAnchor(creature, root),
    joints: m.joints, radii: m.radii, thick: 1,
    end: def.end, endScale: 1, endRot: [0, 0, 0], endParams: {}, mirror: true, slot: 'base',
  }, extra);
}

// Trace from outside toward the spine at param u along world direction dir.
export function hitFromSpine(creature, u, dir, onlySpine = true) {
  const { prims } = buildCreature(creature);
  const model = makeModel(onlySpine ? prims.filter((q) => q.owner === 'spine') : prims);
  const f = spineFrame(creature.spine, u);
  const d = norm(dir);
  const ro = add(f.o, scale(d, f.r * 4 + 1));
  return trace(model, ro, scale(d, -1));
}
