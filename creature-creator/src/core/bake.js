// Export pipeline: pick a voxel size that fits the triangle budget, mesh with
// the high-quality settings, then bake colours into a texture atlas.
//
// Atlas layout: every triangle gets half of a small square cell. Triangles are
// ordered along a Morton curve so that neighbouring cells are neighbours on the
// creature too (mip-maps then blend similar colours instead of random ones).

import { FieldModel, polygonize, refine, attributes, cleanDegenerate, repairNonManifold } from './mesher.js';
import { checkMesh } from './validate.js';
import { shade } from './paint.js';

export function exportMesh(prims, P, opts, progress = () => {}) {
  const budget = opts.budget ?? 15000;
  const probe = new FieldModel(prims, 0.05);
  const size = Math.max(...[0, 1, 2].map((i) => probe.mx[i] - probe.mn[i]));
  let h = size / 90;
  let best = null;
  // 1. find the voxel size (geometry only, fast)
  for (let it = 0; it < 7; it++) {
    progress(`Recherche de la résolution (${it + 1})…`, 0.05 + it * 0.03);
    const model = new FieldModel(prims, h);
    const m = polygonize(model);
    const T = m.indices.length / 3;
    if (T <= budget && (!best || T > best.T)) best = { h, T };
    const ratio = T / budget;
    if (ratio <= 1 && ratio > 0.9) break;
    h *= Math.sqrt(ratio / 0.95);
  }
  if (!best) best = { h, T: 0 };
  // 2. mesh (retry with a shifted grid if a rare ambiguous configuration shows up)
  const jitters = [[0, 0, 0], [0.5, 0.5, 0.5], [0.25, 0.6, 0.4], [0.7, 0.2, 0.55], [0.4, 0.3, 0.8], [0.15, 0.85, 0.3], [0.6, 0.7, 0.1], [0.33, 0.1, 0.66], [0.9, 0.45, 0.2], [0.05, 0.35, 0.95]];
  const hs = [1, 1, 1, 1, 1, 1.01, 1.02, 1.015, 1.025, 1.03];
  let chosen = null;
  for (let j = 0; j < jitters.length; j++) {
    progress('Génération du maillage étanche…', 0.3 + j * 0.015);
    const model = new FieldModel(prims, best.h * hs[j]);
    const mesh = polygonize(model, jitters[j]);
    cleanDegenerate(mesh);
    repairNonManifold(mesh);
    if (mesh.indices.length / 3 > budget) continue;
    const chk = checkMesh(mesh.indices, mesh.positions.length / 3);
    if (!chosen || chk.nonManifold < chosen.chk.nonManifold) chosen = { model, mesh, chk };
    if (chk.nonManifold === 0 && chk.boundary === 0) break;
  }
  if (!chosen) {
    const model = new FieldModel(prims, best.h * 1.1);
    const mesh = polygonize(model);
    cleanDegenerate(mesh);
    repairNonManifold(mesh);
    chosen = { model, mesh, chk: checkMesh(mesh.indices, mesh.positions.length / 3) };
  }
  const { model, mesh } = chosen;
  progress('Lissage de la surface…', 0.45);
  refine(model, mesh, 3, false);
  progress('Couleurs et poids des os…', 0.55);
  attributes(model, mesh, P, { bones: true, aoScale: opts.aoScale, keepAo: true });
  mesh.check = checkMesh(mesh.indices, mesh.positions.length / 3);
  mesh.cell = best.h;
  progress('Cuisson de la texture…', 0.65);
  const tex = bakeAtlas(model, mesh, P, opts.texSize ?? 1024, (f) => progress('Cuisson de la texture…', 0.65 + f * 0.3));
  return { mesh, tex };
}

function morton(x, y, z) {
  const spread = (v) => {
    v = Math.max(0, Math.min(1023, v | 0));
    v = (v | (v << 16)) & 0x030000ff;
    v = (v | (v << 8)) & 0x0300f00f;
    v = (v | (v << 4)) & 0x030c30c3;
    v = (v | (v << 2)) & 0x09249249;
    return v;
  };
  return spread(x) | (spread(y) << 1) | (spread(z) << 2);
}

export function bakeAtlas(model, mesh, P, texSize, progress = () => {}) {
  const I = mesh.indices, pos = mesh.positions, nor = mesh.normals, ao = mesh.ao;
  const T = I.length / 3;
  // order triangles along a Morton curve
  const mn = model.mn, ext = Math.max(...[0, 1, 2].map((i) => model.mx[i] - model.mn[i])) || 1;
  const keys = new Array(T);
  for (let t = 0; t < T; t++) {
    let cx = 0, cy = 0, cz = 0;
    for (let k = 0; k < 3; k++) {
      const v = I[t * 3 + k] * 3;
      cx += pos[v]; cy += pos[v + 1]; cz += pos[v + 2];
    }
    const q = (v, i) => ((v / 3 - mn[i]) / ext) * 1023;
    keys[t] = [morton(q(cx, 0), q(cy, 1), q(cz, 2)), t];
  }
  keys.sort((a, b) => a[0] - b[0]);

  const cells = Math.ceil(T / 2);
  let G = Math.ceil(Math.sqrt(cells));
  let s = Math.floor(texSize / G);
  while (s < 6 && texSize < 4096) { texSize *= 2; s = Math.floor(texSize / G); }
  const L = s - 4;
  const rgba = new Uint8ClampedArray(texSize * texSize * 4);
  const uvs = new Float32Array(T * 6);
  // background = mean base colour (avoids dark bleeding in mip-maps)
  const bg = P.base.map((v) => Math.round(v * 255));
  for (let i = 0; i < texSize * texSize; i++) {
    rgba[i * 4] = bg[0]; rgba[i * 4 + 1] = bg[1]; rgba[i * 4 + 2] = bg[2]; rgba[i * 4 + 3] = 255;
  }
  const A = [0, 0], B = [0, 0], C = [0, 0];
  for (let q = 0; q < T; q++) {
    if ((q & 1023) === 0) progress(q / T);
    const t = keys[q][1];
    const cell = q >> 1, half = q & 1;
    const px0 = (cell % G) * s, py0 = Math.floor(cell / G) * s;
    if (half === 0) {
      A[0] = px0 + 1; A[1] = py0 + 1; B[0] = px0 + 1 + L; B[1] = py0 + 1; C[0] = px0 + 1; C[1] = py0 + 1 + L;
    } else {
      A[0] = px0 + s - 1; A[1] = py0 + s - 1; B[0] = px0 + s - 1 - L; B[1] = py0 + s - 1; C[0] = px0 + s - 1; C[1] = py0 + s - 1 - L;
    }
    uvs[t * 6] = A[0] / texSize; uvs[t * 6 + 1] = A[1] / texSize;
    uvs[t * 6 + 2] = B[0] / texSize; uvs[t * 6 + 3] = B[1] / texSize;
    uvs[t * 6 + 4] = C[0] / texSize; uvs[t * 6 + 5] = C[1] / texSize;
    const ia = I[t * 3] * 3, ib = I[t * 3 + 1] * 3, ic = I[t * 3 + 2] * 3;
    // texels of this half cell
    for (let ly = 0; ly < s; ly++) {
      for (let lx = 0; lx < s; lx++) {
        const sum = lx + ly + 1; // (lx+.5)+(ly+.5)
        if (half === 0 ? sum > s - 1 : sum < s + 1) continue;
        // barycentric coordinates in the right isoceles triangle
        let u, v;
        if (half === 0) { u = (lx + 0.5 - 1) / L; v = (ly + 0.5 - 1) / L; }
        else { u = (s - 1 - (lx + 0.5)) / L; v = (s - 1 - (ly + 0.5)) / L; }
        u = Math.max(0, u); v = Math.max(0, v);
        if (u + v > 1) { const k = 1 / (u + v); u *= k; v *= k; }
        const w = 1 - u - v;
        const x = pos[ia] * w + pos[ib] * u + pos[ic] * v;
        const y = pos[ia + 1] * w + pos[ib + 1] * u + pos[ic + 1] * v;
        const z = pos[ia + 2] * w + pos[ib + 2] * u + pos[ic + 2] * v;
        let nx = nor[ia] * w + nor[ib] * u + nor[ic] * v;
        let ny = nor[ia + 1] * w + nor[ib + 1] * u + nor[ic + 1] * v;
        let nz = nor[ia + 2] * w + nor[ib + 2] * u + nor[ic + 2] * v;
        const nl = Math.hypot(nx, ny, nz) || 1;
        nx /= nl; ny /= nl; nz /= nl;
        const info = model.surfaceInfo(x, y, z, false);
        const mat = info.prim ? info.prim.mat : { kind: 'skin', slot: 'base' };
        const col = shade(P, mat, [x, y, z], [nx, ny, nz]);
        const a = ao ? ao[ia / 3] * w + ao[ib / 3] * u + ao[ic / 3] * v : 1;
        const o = ((py0 + ly) * texSize + px0 + lx) * 4;
        rgba[o] = toSrgb8(col[0] * a); rgba[o + 1] = toSrgb8(col[1] * a); rgba[o + 2] = toSrgb8(col[2] * a);
      }
    }
  }
  // the diagonal between the two triangles of a cell is sampled by bilinear
  // filtering from both sides: fill it with the average of its neighbours
  for (let cell = 0; cell < cells; cell++) {
    const px0 = (cell % G) * s, py0 = Math.floor(cell / G) * s;
    for (let ly = 0; ly < s; ly++) {
      const lx = s - 1 - ly;
      if (lx - 1 < 0 || lx + 1 >= s) continue;
      const o = ((py0 + ly) * texSize + px0 + lx) * 4;
      const a = o - 4, b = o + 4;
      for (let k = 0; k < 3; k++) rgba[o + k] = (rgba[a + k] + rgba[b + k]) >> 1;
    }
  }
  progress(1);
  return { rgba, size: texSize, uvs };
}

function toSrgb8(v) { return Math.round(Math.max(0, Math.min(1, v)) * 255); }

// Place the creature on the ground, centred, and scale it to a height in studs.
export function exportTransform(mesh, height) {
  const P = mesh.positions;
  const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < P.length; i += 3)
    for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], P[i + k]); mx[k] = Math.max(mx[k], P[i + k]); }
  const s = height / Math.max(1e-6, mx[1] - mn[1]);
  const off = [-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2];
  return { s, off, apply: (p) => [(p[0] + off[0]) * s, (p[1] + off[1]) * s, (p[2] + off[2]) * s], size: [0, 1, 2].map((k) => (mx[k] - mn[k]) * s) };
}
