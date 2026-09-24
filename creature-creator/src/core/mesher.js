// Voxel field + Naive Surface Nets polygonizer.
//
// Surface Nets is the dual of the voxel grid: every grid edge whose endpoints
// have different signs produces exactly one quad, so every mesh edge is shared
// by an even number of faces. The resulting surface is always closed
// (no holes), which is exactly what Roblox needs for a clean MeshPart.

import { prepPrim, primDist, fieldAt, smin, smax, UNSET } from './sdf.js';
import { shade } from './paint.js';

export class FieldModel {
  constructor(primsIn, h, opts = {}) {
    this.h = h;
    const minR = opts.minThickness ?? 0.9 * h;
    this.prims = primsIn.map((p) => prepPrim(p, minR));
    let kmax = 0;
    const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
    for (const p of this.prims) {
      kmax = Math.max(kmax, p.k || 0);
      if (p.sub) continue;
      for (let i = 0; i < 3; i++) {
        mn[i] = Math.min(mn[i], p.box.mn[i]);
        mx[i] = Math.max(mx[i], p.box.mx[i]);
      }
    }
    if (!isFinite(mn[0])) { mn.fill(-1); mx.fill(1); }
    this.kmax = kmax;
    this.mn = mn; this.mx = mx;
    this._buildBuckets();
  }

  margin(p) { return 3 * this.h + (p.k || 0) + this.kmax * 0.25; }

  _buildBuckets() {
    const B = Math.max(this.h * 6, 0.05);
    const pad = 4 * this.h + this.kmax;
    this.bo = this.mn.map((v) => v - pad);
    this.bs = B;
    this.bn = [0, 1, 2].map((i) => Math.max(1, Math.ceil((this.mx[i] - this.mn[i] + 2 * pad) / B)));
    const [bx, by, bz] = this.bn;
    this.buckets = new Array(bx * by * bz);
    for (let i = 0; i < this.buckets.length; i++) this.buckets[i] = [];
    this.prims.forEach((p, idx) => {
      const m = this.margin(p) + 0.5 * B;
      const lo = [0, 1, 2].map((i) => Math.max(0, Math.floor((p.box.mn[i] - m - this.bo[i]) / B)));
      const hi = [0, 1, 2].map((i) => Math.min(this.bn[i] - 1, Math.floor((p.box.mx[i] + m - this.bo[i]) / B)));
      for (let z = lo[2]; z <= hi[2]; z++)
        for (let y = lo[1]; y <= hi[1]; y++)
          for (let x = lo[0]; x <= hi[0]; x++) this.buckets[x + bx * (y + by * z)].push(idx);
    });
    this.empty = [];
  }

  list(x, y, z) {
    const B = this.bs;
    const i = Math.floor((x - this.bo[0]) / B), j = Math.floor((y - this.bo[1]) / B), k = Math.floor((z - this.bo[2]) / B);
    if (i < 0 || j < 0 || k < 0 || i >= this.bn[0] || j >= this.bn[1] || k >= this.bn[2]) return this.empty;
    return this.buckets[i + this.bn[0] * (j + this.bn[1] * k)];
  }

  field(x, y, z) {
    const l = this.list(x, y, z);
    if (!l.length) return 4 * this.h;
    const f = fieldAt(this.prims, x, y, z, l);
    return f >= UNSET ? 4 * this.h : f;
  }

  grad(x, y, z, e = this.h * 0.25) {
    const gx = this.field(x + e, y, z) - this.field(x - e, y, z);
    const gy = this.field(x, y + e, z) - this.field(x, y - e, z);
    const gz = this.field(x, y, z + e) - this.field(x, y, z - e);
    return [gx / (2 * e), gy / (2 * e), gz / (2 * e)];
  }

  // Dominant material / owner, plus smooth bone weights.
  surfaceInfo(x, y, z, wantBones) {
    const l = this.list(x, y, z);
    let minAd = Infinity;
    const ds = new Float64Array(l.length);
    for (let i = 0; i < l.length; i++) {
      const d = Math.abs(primDist(this.prims[l[i]], x, y, z));
      ds[i] = d;
      if (d < minAd) minAd = d;
    }
    let best = -1, bestW = -1;
    const bones = wantBones ? new Map() : null;
    let bsum = 0;
    for (let i = 0; i < l.length; i++) {
      const p = this.prims[l[i]];
      const k = p.k || 0;
      const rel = ds[i] - minAd;
      const wc = Math.exp(-rel / (0.12 * k + 0.25 * this.h + 1e-4)) * (p.layer === 2 ? 1.5 : 1);
      if (wc > bestW) { bestW = wc; best = l[i]; }
      if (bones && p.bw) {
        const wb = Math.exp(-rel / Math.max(0.6 * k, 0.05));
        if (wb < 1e-3) continue;
        for (const [b, w] of p.bw) {
          bones.set(b, (bones.get(b) || 0) + wb * w);
          bsum += wb * w;
        }
      }
    }
    const pr = best >= 0 ? this.prims[best] : null;
    let bw = null;
    if (bones) {
      bw = [...bones.entries()].sort((a, b) => b[1] - a[1]).slice(0, 4);
      const s = bw.reduce((a, b) => a + b[1], 0) || 1;
      bw = bw.map(([b, w]) => [b, w / s]);
      void bsum;
    }
    return { prim: pr, bw };
  }

  ao(x, y, z, n, scale) {
    const d1 = 0.12 * scale, d2 = 0.35 * scale;
    const f1 = this.field(x + n[0] * d1, y + n[1] * d1, z + n[2] * d1) / d1;
    const f2 = this.field(x + n[0] * d2, y + n[1] * d2, z + n[2] * d2) / d2;
    const a = Math.max(0, Math.min(1, 0.5 * (f1 + f2)));
    return 0.5 + 0.5 * Math.pow(a, 0.8);
  }

  colorAt(P, x, y, z, n, aoScale) {
    const info = this.surfaceInfo(x, y, z, false);
    const mat = info.prim ? info.prim.mat : { kind: 'skin', slot: 'base' };
    const c = shade(P, mat, [x, y, z], n);
    const a = aoScale > 0 ? this.ao(x, y, z, n, aoScale) : 1;
    return [c[0] * a, c[1] * a, c[2] * a];
  }
}

// --------------------------------------------------------------- polygonize

const EDGES = [
  [0, 1], [2, 3], [4, 5], [6, 7],
  [0, 2], [1, 3], [4, 6], [5, 7],
  [0, 4], [1, 5], [2, 6], [3, 7],
];
const EDGE_OF = new Map(EDGES.map(([a, b], i) => [a * 8 + b, i]));
const edgeIndex = (a, b) => EDGE_OF.get(Math.min(a, b) * 8 + Math.max(a, b));

// For every corner sign configuration, group the crossing edges into surface
// patches (one output vertex per patch). Ambiguous faces are always resolved
// the same way ("inside corners separated"), and since the decision only
// depends on the 4 corner signs of the face, both cells sharing the face agree.
// This keeps the output a proper 2-manifold (dual marching cubes).
const PATCH = (() => {
  const faces = [];
  for (let a = 0; a < 3; a++) {
    const b = (a + 1) % 3, c = (a + 2) % 3;
    for (let s = 0; s < 2; s++) {
      const cyc = [[0, 0], [1, 0], [1, 1], [0, 1]].map(([u, v]) => (s << a) | (u << b) | (v << c));
      faces.push(cyc);
    }
  }
  const table = [];
  for (let mask = 0; mask < 256; mask++) {
    const parent = [...Array(12).keys()];
    const find = (x) => (parent[x] === x ? x : (parent[x] = find(parent[x])));
    const unite = (x, y) => { parent[find(x)] = find(y); };
    const inside = (c) => (mask >> c) & 1;
    const crossing = (e) => inside(EDGES[e][0]) !== inside(EDGES[e][1]);
    for (const cyc of faces) {
      const fe = [0, 1, 2, 3].map((i) => edgeIndex(cyc[i], cyc[(i + 1) % 4]));
      const cr = fe.filter(crossing);
      if (cr.length === 2) unite(cr[0], cr[1]);
      else if (cr.length === 4) {
        for (let i = 0; i < 4; i++) {
          if (!inside(cyc[i])) continue;
          unite(fe[(i + 3) % 4], fe[i]); // the two face edges touching this inside corner
        }
      }
    }
    const comp = new Int8Array(12).fill(-1);
    const ids = new Map();
    for (let e = 0; e < 12; e++) {
      if (!crossing(e)) continue;
      const r = find(e);
      if (!ids.has(r)) ids.set(r, ids.size);
      comp[e] = ids.get(r);
    }
    table.push({ comp, n: ids.size });
  }
  return table;
})();

export function polygonize(model, jitter = [0, 0, 0], maxCells = 14e6) {
  const h = model.h;
  const pad = 3 * h + 0.3 * model.kmax;
  const o = model.mn.map((v, i) => v - pad - jitter[i] * h);
  const dims = [0, 1, 2].map((i) => Math.ceil((model.mx[i] + pad - o[i]) / h) + 1);
  const [nx, ny, nz] = dims;
  const N = nx * ny * nz;
  if (N > maxCells) throw new Error('grid too large: ' + N);
  const F = new Float32Array(N).fill(UNSET);

  // splat primitives (in order: add, sub, post-add)
  for (const p of model.prims) {
    const m = model.margin(p);
    const lo = [0, 1, 2].map((i) => Math.max(0, Math.floor((p.box.mn[i] - m - o[i]) / h)));
    const hi = [0, 1, 2].map((i) => Math.min(dims[i] - 1, Math.ceil((p.box.mx[i] + m - o[i]) / h)));
    const k = p.k || 0;
    for (let z = lo[2]; z <= hi[2]; z++) {
      const wz = o[2] + z * h;
      for (let y = lo[1]; y <= hi[1]; y++) {
        const wy = o[1] + y * h;
        let idx = lo[0] + nx * (y + ny * z);
        for (let x = lo[0]; x <= hi[0]; x++, idx++) {
          const d = primDist(p, o[0] + x * h, wy, wz);
          const f = F[idx];
          if (!p.sub) F[idx] = f >= UNSET ? d : smin(f, d, k);
          else if (f < UNSET) F[idx] = smax(f, -d, k);
        }
      }
    }
  }
  // the outer shell of the grid must be outside
  for (let z = 0; z < nz; z++)
    for (let y = 0; y < ny; y++)
      for (let x = 0; x < nx; x++)
        if (x === 0 || y === 0 || z === 0 || x === nx - 1 || y === ny - 1 || z === nz - 1) {
          const idx = x + nx * (y + ny * z);
          if (F[idx] < h) F[idx] = h;
        }

  // one vertex per surface patch in each cell
  const cellBase = new Int32Array(N).fill(-1);
  const cellMask = new Uint8Array(N);
  const pos = [];
  const cellOf = [];
  const off = [0, 1, nx, nx + 1, nx * ny, nx * ny + 1, nx * ny + nx, nx * ny + nx + 1];
  const v = new Float64Array(8);
  const acc = new Float64Array(16);
  for (let z = 0; z < nz - 1; z++)
    for (let y = 0; y < ny - 1; y++) {
      let idx = nx * (y + ny * z);
      for (let x = 0; x < nx - 1; x++, idx++) {
        let mask = 0;
        for (let c = 0; c < 8; c++) {
          v[c] = F[idx + off[c]];
          if (v[c] < 0) mask |= 1 << c;
        }
        if (mask === 0 || mask === 255) continue;
        const P = PATCH[mask];
        acc.fill(0);
        for (let e = 0; e < 12; e++) {
          const ci = P.comp[e];
          if (ci < 0) continue;
          const [a, b] = EDGES[e];
          const t = v[a] / (v[a] - v[b]);
          const ax = a & 1, ay = (a >> 1) & 1, az = (a >> 2) & 1;
          const bx = b & 1, by = (b >> 1) & 1, bz = (b >> 2) & 1;
          acc[ci * 4] += ax + (bx - ax) * t;
          acc[ci * 4 + 1] += ay + (by - ay) * t;
          acc[ci * 4 + 2] += az + (bz - az) * t;
          acc[ci * 4 + 3]++;
        }
        cellBase[idx] = pos.length / 3;
        cellMask[idx] = mask;
        for (let ci = 0; ci < P.n; ci++) {
          const n = acc[ci * 4 + 3];
          pos.push(o[0] + (x + acc[ci * 4] / n) * h, o[1] + (y + acc[ci * 4 + 1] / n) * h, o[2] + (z + acc[ci * 4 + 2] / n) * h);
          cellOf.push(x, y, z);
        }
      }
    }

  // quads for every sign-changing grid edge
  const idxs = [];
  const quad = (a, b, c, d, flip) => {
    if (a < 0 || b < 0 || c < 0 || d < 0) return;
    if (flip) { const t = b; b = d; d = t; }
    const d1 = dist2(pos, a, c), d2 = dist2(pos, b, d);
    if (d1 <= d2) idxs.push(a, b, c, a, c, d);
    else idxs.push(a, b, d, b, c, d);
  };
  const stride = [1, nx, nx * ny];
  // local edge index inside a neighbouring cell, per axis and (db, dc) offset
  const LOCAL = [0, 1, 2].map((a) => {
    const b = (a + 1) % 3, c = (a + 2) % 3;
    return [[-1, -1], [0, -1], [0, 0], [-1, 0]].map(([db, dc]) => {
      const corner = ((db === -1 ? 1 : 0) << b) | ((dc === -1 ? 1 : 0) << c);
      return { e: edgeIndex(corner, corner | (1 << a)), off: db * stride[b] + dc * stride[c] };
    });
  });
  const vert = (cell, e) => {
    const base = cellBase[cell];
    if (base < 0) return -1;
    return base + PATCH[cellMask[cell]].comp[e];
  };
  for (let z = 1; z < nz - 1; z++)
    for (let y = 1; y < ny - 1; y++) {
      let idx = 1 + nx * (y + ny * z);
      for (let x = 1; x < nx - 1; x++, idx++) {
        const f0 = F[idx] < 0;
        for (let a = 0; a < 3; a++) {
          if (f0 === F[idx + stride[a]] < 0) continue;
          const L = LOCAL[a];
          quad(vert(idx + L[0].off, L[0].e), vert(idx + L[1].off, L[1].e), vert(idx + L[2].off, L[2].e), vert(idx + L[3].off, L[3].e), !f0);
        }
      }
    }

  return {
    positions: new Float32Array(pos),
    indices: new Uint32Array(idxs),
    cellOf: new Int32Array(cellOf),
    origin: o,
    h,
  };
}

function dist2(p, a, b) {
  const x = p[a * 3] - p[b * 3], y = p[a * 3 + 1] - p[b * 3 + 1], z = p[a * 3 + 2] - p[b * 3 + 2];
  return x * x + y * y + z * z;
}

// Move vertices onto the exact iso-surface and compute smooth normals.
// fast: one projection step with forward differences, normal reused.
export function refine(model, mesh, iters = 2, fast = false) {
  const { positions: P, cellOf, origin: o, h } = mesh;
  const nV = P.length / 3;
  const normals = new Float32Array(P.length);
  const e = h * 0.3;
  for (let i = 0; i < nV; i++) {
    let x = P[i * 3], y = P[i * 3 + 1], z = P[i * 3 + 2];
    const cx = o[0] + cellOf[i * 3] * h, cy = o[1] + cellOf[i * 3 + 1] * h, cz = o[2] + cellOf[i * 3 + 2] * h;
    let g = [0, 1, 0];
    for (let it = 0; it < iters; it++) {
      const f = model.field(x, y, z);
      if (fast) {
        g = [(model.field(x + e, y, z) - f) / e, (model.field(x, y + e, z) - f) / e, (model.field(x, y, z + e) - f) / e];
      } else g = model.grad(x, y, z);
      const g2 = g[0] * g[0] + g[1] * g[1] + g[2] * g[2];
      if (g2 < 1e-10) break;
      const s = f / g2;
      x -= g[0] * s; y -= g[1] * s; z -= g[2] * s;
      const lo = -0.35 * h, hi = 1.35 * h;
      x = Math.min(cx + hi, Math.max(cx + lo, x));
      y = Math.min(cy + hi, Math.max(cy + lo, y));
      z = Math.min(cz + hi, Math.max(cz + lo, z));
    }
    P[i * 3] = x; P[i * 3 + 1] = y; P[i * 3 + 2] = z;
    if (!fast) g = model.grad(x, y, z, h * 0.5);
    const l = Math.hypot(g[0], g[1], g[2]) || 1;
    normals[i * 3] = g[0] / l; normals[i * 3 + 1] = g[1] / l; normals[i * 3 + 2] = g[2] / l;
  }
  mesh.normals = normals;
  return mesh;
}

// Colours, owners and bone weights per vertex.
export function attributes(model, mesh, P, opts = {}) {
  const pos = mesh.positions, nor = mesh.normals;
  const nV = pos.length / 3;
  const colors = new Float32Array(nV * 3);
  const owners = new Uint16Array(nV);
  const ownerNames = [];
  const ownerIdx = new Map();
  const wantBones = !!opts.bones;
  const joints = wantBones ? new Uint16Array(nV * 4) : null;
  const weights = wantBones ? new Float32Array(nV * 4) : null;
  const aoArr = opts.keepAo ? new Float32Array(nV) : null;
  for (let i = 0; i < nV; i++) {
    const x = pos[i * 3], y = pos[i * 3 + 1], z = pos[i * 3 + 2];
    const n = [nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2]];
    const info = model.surfaceInfo(x, y, z, wantBones);
    const mat = info.prim ? info.prim.mat : { kind: 'skin', slot: 'base' };
    const c = shade(P, mat, [x, y, z], n);
    const a = opts.aoScale > 0 ? model.ao(x, y, z, n, opts.aoScale) : 1;
    if (aoArr) aoArr[i] = a;
    colors[i * 3] = c[0] * a; colors[i * 3 + 1] = c[1] * a; colors[i * 3 + 2] = c[2] * a;
    const on = info.prim ? info.prim.owner + (info.prim.mirrored ? '|m' : '') : 'spine';
    let oi = ownerIdx.get(on);
    if (oi === undefined) { oi = ownerNames.length; ownerNames.push(on); ownerIdx.set(on, oi); }
    owners[i] = oi;
    if (wantBones) {
      const bw = info.bw && info.bw.length ? info.bw : [[0, 1]];
      for (let j = 0; j < 4; j++) {
        joints[i * 4 + j] = bw[j] ? bw[j][0] : 0;
        weights[i * 4 + j] = bw[j] ? bw[j][1] : 0;
      }
    }
  }
  Object.assign(mesh, { colors, owners, ownerNames, joints, weights, ao: aoArr });
  return mesh;
}

// Full pipeline for a given cell size.
export function buildMesh(prims, P, h, opts = {}) {
  const model = new FieldModel(prims, h, opts);
  const mesh = polygonize(model, opts.jitter);
  repairNonManifold(mesh);
  refine(model, mesh, opts.iters ?? 2, !!opts.fast);
  cleanDegenerate(mesh);
  attributes(model, mesh, P, opts);
  mesh.model = model;
  return mesh;
}

// Remove zero-area triangles (does not open holes: a collapsed triangle has
// its two remaining edges coincident, and the neighbours already close them).
export function cleanDegenerate(mesh) {
  const I = mesh.indices, P = mesh.positions;
  const out = [];
  for (let t = 0; t < I.length; t += 3) {
    const a = I[t], b = I[t + 1], c = I[t + 2];
    if (a === b || b === c || a === c) continue;
    out.push(a, b, c);
  }
  mesh.indices = new Uint32Array(out);
  void P;
  return mesh;
}

// Split vertices shared by two surface sheets (the rare "tunnel" voxel
// configuration where one mesh edge ends up with 4 faces). Faces around such a
// vertex are grouped by manifold-edge connectivity and each extra group gets
// its own copy of the vertex. Positions are unchanged, so this never opens a
// hole; it only makes every edge shared by exactly two triangles.
export function repairNonManifold(mesh) {
  const I = mesh.indices;
  let nV = mesh.positions.length / 3;
  const key = (a, b) => (a < b ? a * nV + b : b * nV + a);
  const edgeCount = new Map();
  for (let t = 0; t < I.length; t += 3)
    for (let e = 0; e < 3; e++) {
      const k = key(I[t + e], I[t + ((e + 1) % 3)]);
      edgeCount.set(k, (edgeCount.get(k) || 0) + 1);
    }
  const bad = new Set();
  for (const [k, c] of edgeCount) if (c > 2) { bad.add(Math.floor(k / nV)); bad.add(k % nV); }
  if (!bad.size) return 0;
  const facesOf = new Map();
  for (let t = 0; t < I.length / 3; t++)
    for (let e = 0; e < 3; e++) {
      const v = I[t * 3 + e];
      if (bad.has(v)) (facesOf.get(v) || facesOf.set(v, []).get(v)).push(t);
    }
  const extraPos = [], extraCell = [];
  let split = 0;
  const K0 = nV;
  for (const [u, faces] of facesOf) {
    const parent = faces.map((_, i) => i);
    const find = (x) => (parent[x] === x ? x : (parent[x] = find(parent[x])));
    const byEdge = new Map();
    faces.forEach((t, i) => {
      for (let e = 0; e < 3; e++) {
        const w = I[t * 3 + e];
        if (w === u) continue;
        const k = u < w ? u * K0 + w : w * K0 + u;
        if (edgeCount.get(k) !== 2) continue;
        if (byEdge.has(k)) parent[find(i)] = find(byEdge.get(k));
        else byEdge.set(k, i);
      }
    });
    const groups = new Map();
    faces.forEach((t, i) => {
      const r = find(i);
      (groups.get(r) || groups.set(r, []).get(r)).push(t);
    });
    if (groups.size < 2) continue;
    let first = true;
    for (const g of groups.values()) {
      if (first) { first = false; continue; }
      const nu = nV++;
      extraPos.push(mesh.positions[u * 3], mesh.positions[u * 3 + 1], mesh.positions[u * 3 + 2]);
      extraCell.push(mesh.cellOf[u * 3], mesh.cellOf[u * 3 + 1], mesh.cellOf[u * 3 + 2]);
      for (const t of g) for (let e = 0; e < 3; e++) if (I[t * 3 + e] === u) I[t * 3 + e] = nu;
      split++;
    }
  }
  if (split) {
    const P = new Float32Array(mesh.positions.length + extraPos.length);
    P.set(mesh.positions); P.set(extraPos, mesh.positions.length);
    const C = new Int32Array(mesh.cellOf.length + extraCell.length);
    C.set(mesh.cellOf); C.set(extraCell, mesh.cellOf.length);
    mesh.positions = P;
    mesh.cellOf = C;
  }
  return split;
}
