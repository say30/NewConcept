// Turn an export result (mesh + baked atlas) into downloadable files.
import { exportTransform } from '../core/bake.js';
import { writeGLB } from './glb.js';
import { writeOBJ, writeZip } from './obj.js';

export function safeName(name) {
  const s = (name || 'Creature').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Za-z0-9_]+/g, '_').replace(/^_+|_+$/g, '');
  return s || 'Creature';
}

export function prepareExport(res, bones, opts) {
  const { mesh, tex } = res;
  const X = exportTransform(mesh, opts.height);
  const nV = mesh.positions.length / 3;
  const pos = new Float32Array(nV * 3);
  for (let i = 0; i < nV; i++) {
    const p = X.apply([mesh.positions[i * 3], mesh.positions[i * 3 + 1], mesh.positions[i * 3 + 2]]);
    pos[i * 3] = p[0]; pos[i * 3 + 1] = p[1]; pos[i * 3 + 2] = p[2];
  }
  const bonesX = bones.map((b) => Object.assign({}, b, { pos: X.apply(b.pos) }));
  return { X, pos, bonesX, mesh, tex };
}

export function makeGLB(prep, name, png, rig) {
  const { pos, mesh, tex, bonesX } = prep;
  const I = mesh.indices, T = I.length / 3;
  const sp = new Float32Array(T * 9), sn = new Float32Array(T * 9);
  const sj = new Uint16Array(T * 12), sw = new Float32Array(T * 12);
  const si = new Uint32Array(T * 3);
  for (let c = 0; c < T * 3; c++) {
    const v = I[c];
    for (let k = 0; k < 3; k++) { sp[c * 3 + k] = pos[v * 3 + k]; sn[c * 3 + k] = mesh.normals[v * 3 + k]; }
    for (let k = 0; k < 4; k++) { sj[c * 4 + k] = mesh.joints[v * 4 + k]; sw[c * 4 + k] = mesh.weights[v * 4 + k]; }
    si[c] = c;
  }
  return writeGLB({
    name, positions: sp, normals: sn, uvs: tex.uvs, indices: si,
    joints: rig ? sj : null, weights: rig ? sw : null, bones: rig ? bonesX : null, png,
  });
}

export function makeOBJZip(prep, name, png) {
  const { pos, mesh, tex } = prep;
  const { obj, mtl } = writeOBJ({ name, positions: pos, normals: mesh.normals, cornerUVs: tex.uvs, indices: mesh.indices });
  return writeZip([
    { name: name + '.obj', data: obj },
    { name: name + '.mtl', data: mtl },
    { name: name + '.png', data: png },
  ]);
}
