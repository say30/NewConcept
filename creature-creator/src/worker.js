// Heavy lifting off the UI thread: meshing for the live preview and export.
import { FieldModel, buildMesh } from './core/mesher.js';
import { exportMesh } from './core/bake.js';

self.onmessage = (e) => {
  const msg = e.data;
  try {
    if (msg.type === 'preview') {
      const probe = new FieldModel(msg.prims, 0.05, { minThickness: 0 });
      const size = Math.max(...[0, 1, 2].map((i) => probe.mx[i] - probe.mn[i]));
      const h = Math.max(size / msg.div, 0.008);
      const mesh = buildMesh(msg.prims, msg.paint, h, { fast: true, iters: 1, bones: true, aoScale: msg.aoScale });
      const out = {
        type: 'preview', id: msg.id,
        positions: mesh.positions, normals: mesh.normals, colors: mesh.colors, indices: mesh.indices,
        owners: mesh.owners, ownerNames: mesh.ownerNames, joints: mesh.joints, weights: mesh.weights,
      };
      self.postMessage(out, [out.positions.buffer, out.normals.buffer, out.colors.buffer, out.indices.buffer, out.owners.buffer, out.joints.buffer, out.weights.buffer]);
    } else if (msg.type === 'export') {
      const res = exportMesh(msg.prims, msg.paint, msg.opts, (label, f) => self.postMessage({ type: 'progress', id: msg.id, label, f }));
      const m = res.mesh;
      const out = {
        type: 'export', id: msg.id,
        mesh: { positions: m.positions, normals: m.normals, indices: m.indices, joints: m.joints, weights: m.weights, check: m.check, cell: m.cell },
        tex: res.tex,
      };
      self.postMessage(out, [m.positions.buffer, m.normals.buffer, m.indices.buffer, m.joints.buffer, m.weights.buffer, res.tex.rgba.buffer, res.tex.uvs.buffer]);
    }
  } catch (err) {
    self.postMessage({ type: 'error', id: msg.id, message: String(err && err.stack || err) });
  }
};
