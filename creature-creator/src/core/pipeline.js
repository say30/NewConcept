// Meshing of the body and of every separate piece.
//
// Each piece is meshed on its own grid, sized to the piece, so small parts
// (teeth, pupils, claws) get a very fine resolution and stay sharp. Export
// meshes are generated at high resolution and then simplified with a quadric
// error metric (sharp tips and rims are preserved, flat areas are reduced).

import { FieldModel, polygonize, refine, attributes, cleanDegenerate, repairNonManifold } from './mesher.js';
import { decimate } from './decimate.js';
import { checkMesh } from './validate.js';

function extent(model) {
  return Math.max(...[0, 1, 2].map((i) => model.mx[i] - model.mn[i]));
}

function smoothNormals(model, pos, h) {
  const n = new Float32Array(pos.length);
  for (let i = 0; i < pos.length; i += 3) {
    const g = model.grad(pos[i], pos[i + 1], pos[i + 2], h);
    const l = Math.hypot(g[0], g[1], g[2]) || 1;
    n[i] = g[0] / l; n[i + 1] = g[1] / l; n[i + 2] = g[2] / l;
  }
  return n;
}

// A closed mesh of one piece, in its local frame.
export function meshPiece(prims, { quality = 'preview', detail = 1 } = {}) {
  const probe = new FieldModel(prims, 0.01, { minThickness: 0 });
  const size = Math.max(extent(probe), 0.01);
  const N = quality === 'export' ? Math.round(120 * Math.sqrt(detail)) : 56;
  const h = Math.max(size / N, 0.0012);
  // thin sheets (membranes, fins) must stay at least ~1.6 voxels thick
  const model = new FieldModel(prims, h, { minThickness: 0.8 * h });
  let mesh = polygonize(model, [0, 0, 0], 8e6);
  cleanDegenerate(mesh);
  repairNonManifold(mesh);
  refine(model, mesh, quality === 'export' ? 3 : 2, false);
  if (mesh.indices.length) {
    // error driven (sharp details keep their triangles), then capped
    const exp = quality === 'export';
    const tol = exp ? (size * 0.005) / detail : size * 0.008;
    const cap = exp ? Math.round(1200 * detail) : 900;
    let d = decimate(mesh.positions, mesh.indices, { maxError: tol * tol, weighted: false, targetTris: 40 });
    if (d.indices.length / 3 > cap) d = decimate(d.positions, d.indices, { weighted: false, targetTris: cap });
    mesh = { positions: d.positions, indices: d.indices };
  }
  const normals = smoothNormals(model, mesh.positions, h * 0.35);
  return { positions: mesh.positions, normals, indices: mesh.indices, size };
}

// The body (spine + limbs + fused skin), with colours and bone weights.
export function meshBody(prims, paint, { quality = 'preview', div = 90, budget = 10000, aoScale = 0.3, progress = () => {} } = {}) {
  const probe = new FieldModel(prims, 0.05, { minThickness: 0 });
  const size = extent(probe);
  if (quality !== 'export') {
    let h = Math.max(size / div, 0.006);
    let model = new FieldModel(prims, h);
    let mesh = polygonize(model);
    const T = mesh.indices.length / 3;
    const cap = div > 100 ? 60000 : 30000;
    if (T > cap) {
      h *= Math.sqrt(T / (cap * 0.85));
      model = new FieldModel(prims, h);
      mesh = polygonize(model);
    }
    cleanDegenerate(mesh);
    repairNonManifold(mesh);
    refine(model, mesh, div > 100 ? 2 : 1, div <= 100);
    attributes(model, mesh, paint, { bones: true, aoScale });
    return mesh;
  }
  // export: fine grid, then quadric simplification to the triangle budget
  const h = Math.max(size / 180, 0.004);
  const model = new FieldModel(prims, h);
  progress('Maillage fin du corps…');
  let mesh = polygonize(model, [0, 0, 0], 3e7);
  cleanDegenerate(mesh);
  repairNonManifold(mesh);
  refine(model, mesh, 2, false);
  progress('Simplification intelligente…');
  const d = decimate(mesh.positions, mesh.indices, { targetTris: budget });
  const out = { positions: d.positions, indices: d.indices };
  out.normals = smoothNormals(model, out.positions, h * 0.5);
  progress('Poids des os…');
  attributes(model, out, paint, { bones: true, aoScale, keepAo: true });
  out.check = checkMesh(out.indices, out.positions.length / 3);
  out.model = model;
  return out;
}
