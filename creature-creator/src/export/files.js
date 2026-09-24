// Turn an export result (body + pieces) into downloadable files.
import { pieceMatrix, slotHex } from '../core/creature.js';
import { hexToRgb } from '../core/paint.js';
import { writeGLB, srgbToLinear } from './glb.js';
import { writeOBJ, writeZip } from './obj.js';

export function safeName(name) {
  const s = (name || 'Creature').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Za-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');
  return s || 'Creature';
}

const ROUGH = { eyeWhite: 0.25, eye: 0.2, pupil: 0.15, highlight: 0.1, teeth: 0.35, claw: 0.45, mouth: 0.6, tongue: 0.5 };

function transformPiece(m, mat) {
  const P = m.positions, N = m.normals;
  const pos = new Float32Array(P.length), nor = new Float32Array(N.length);
  for (let i = 0; i < P.length; i += 3) {
    const x = P[i], y = P[i + 1], z = P[i + 2];
    pos[i] = mat[0] * x + mat[4] * y + mat[8] * z + mat[12];
    pos[i + 1] = mat[1] * x + mat[5] * y + mat[9] * z + mat[13];
    pos[i + 2] = mat[2] * x + mat[6] * y + mat[10] * z + mat[14];
    const a = N[i], b = N[i + 1], c = N[i + 2];
    const nx = mat[0] * a + mat[4] * b + mat[8] * c, ny = mat[1] * a + mat[5] * b + mat[9] * c, nz = mat[2] * a + mat[6] * b + mat[10] * c;
    const l = Math.hypot(nx, ny, nz) || 1;
    nor[i] = nx / l; nor[i + 1] = ny / l; nor[i + 2] = nz / l;
  }
  let idx = m.indices;
  const det = mat[0] * (mat[5] * mat[10] - mat[9] * mat[6]) - mat[4] * (mat[1] * mat[10] - mat[9] * mat[2]) + mat[8] * (mat[1] * mat[6] - mat[5] * mat[2]);
  if (det < 0) {
    idx = new Uint32Array(m.indices);
    for (let t = 0; t < idx.length; t += 3) { const s = idx[t + 1]; idx[t + 1] = idx[t + 2]; idx[t + 2] = s; }
  }
  return { positions: pos, normals: nor, indices: idx };
}

// res: worker export result; build: buildCreature() output used for the export
export function assembleExport(res, build, paint, opts) {
  const byKey = new Map(res.pieces.map((p) => [p.key, p]));
  const parts = [];
  const bodyColor = hexToRgb(paint.base);
  parts.push({ name: 'Corps', slot: 'base', color: bodyColor, positions: res.body.positions, normals: res.body.normals, indices: res.body.indices, joints: res.body.joints, weights: res.body.weights, tex: res.tex, check: res.body.check });
  for (const pc of build.pieces) {
    const m = byKey.get(pc.key);
    if (!m || !m.indices.length) continue;
    const w = transformPiece(m, pieceMatrix(pc));
    const nV = w.positions.length / 3;
    const joints = new Uint16Array(nV * 4), weights = new Float32Array(nV * 4);
    for (let i = 0; i < nV; i++) { joints[i * 4] = pc.bone; weights[i * 4] = 1; }
    parts.push(Object.assign(w, { name: pc.name, slot: pc.slot, color: hexToRgb(slotHex(paint, pc.slot, pc.color)), joints, weights, check: m.check }));
  }
  // ground + centre + scale to the requested height (studs)
  const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (const p of parts) for (let i = 0; i < p.positions.length; i += 3) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], p.positions[i + k]); mx[k] = Math.max(mx[k], p.positions[i + k]); }
  const s = opts.height / Math.max(1e-6, mx[1] - mn[1]);
  const off = [-(mn[0] + mx[0]) / 2, -mn[1], -(mn[2] + mx[2]) / 2];
  const apply = (v) => [(v[0] + off[0]) * s, (v[1] + off[1]) * s, (v[2] + off[2]) * s];
  for (const p of parts) {
    const q = new Float32Array(p.positions.length);
    for (let i = 0; i < q.length; i += 3) { const r = apply([p.positions[i], p.positions[i + 1], p.positions[i + 2]]); q[i] = r[0]; q[i + 1] = r[1]; q[i + 2] = r[2]; }
    p.positions = q;
  }
  const bones = build.bones.map((b) => Object.assign({}, b, { pos: apply(b.pos) }));
  const size = [0, 1, 2].map((k) => (mx[k] - mn[k]) * s);
  return { parts, bones, size };
}

// Split a textured mesh so every triangle corner has its own UV.
function splitForUV(p) {
  const I = p.indices, T = I.length / 3;
  const pos = new Float32Array(T * 9), nor = new Float32Array(T * 9), jn = new Uint16Array(T * 12), wt = new Float32Array(T * 12), idx = new Uint32Array(T * 3);
  for (let c = 0; c < T * 3; c++) {
    const v = I[c];
    for (let k = 0; k < 3; k++) { pos[c * 3 + k] = p.positions[v * 3 + k]; nor[c * 3 + k] = p.normals[v * 3 + k]; }
    for (let k = 0; k < 4; k++) { jn[c * 4 + k] = p.joints[v * 4 + k]; wt[c * 4 + k] = p.weights[v * 4 + k]; }
    idx[c] = c;
  }
  return { positions: pos, normals: nor, joints: jn, weights: wt, indices: idx, uvs: p.tex.uvs };
}

export function makeGLB(asm, name, rig, bodyPng) {
  const meshes = asm.parts.map((p) => {
    const lin = p.color.map(srgbToLinear);
    if (p.tex && bodyPng) return Object.assign(splitForUV(p), { name: p.name, color: lin, png: bodyPng, roughness: 0.7 });
    return { name: p.name, positions: p.positions, normals: p.normals, indices: p.indices, joints: p.joints, weights: p.weights, color: lin, roughness: ROUGH[p.slot] ?? 0.7 };
  });
  if (!rig) for (const m of meshes) { m.joints = null; m.weights = null; }
  return writeGLB({ name, meshes, bones: rig ? asm.bones : null });
}

export function makeOBJZip(asm, name, bodyPng) {
  const { obj, mtl } = writeOBJ({ name, objects: asm.parts.map((p) => ({ name: p.name, positions: p.positions, normals: p.normals, indices: p.indices, color: p.color, uvs: p.tex && bodyPng ? p.tex.uvs : null })), texture: bodyPng ? `${name}_Corps.png` : null });
  const files = [{ name: name + '.obj', data: obj }, { name: name + '.mtl', data: mtl }];
  if (bodyPng) files.push({ name: `${name}_Corps.png`, data: bodyPng });
  return writeZip(files);
}
