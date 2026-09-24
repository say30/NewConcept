// Heavy lifting off the UI thread: meshing for the live preview and export.
import { meshBody, meshPiece } from './core/pipeline.js';
import { bakeAtlas } from './core/bake.js';
import { checkMesh } from './core/validate.js';

function post(msg, bufs) { self.postMessage(msg, bufs); }

self.onmessage = (e) => {
  const msg = e.data;
  try {
    if (msg.type === 'preview') {
      const out = { type: 'preview', id: msg.id, pieces: [] };
      const bufs = [];
      if (msg.body) {
        const m = meshBody(msg.body.prims, msg.paint, { div: msg.div, aoScale: msg.aoScale });
        out.body = { positions: m.positions, normals: m.normals, colors: m.colors, indices: m.indices, owners: m.owners, ownerNames: m.ownerNames, joints: m.joints, weights: m.weights };
        bufs.push(m.positions.buffer, m.normals.buffer, m.colors.buffer, m.indices.buffer, m.owners.buffer, m.joints.buffer, m.weights.buffer);
      }
      for (const pc of msg.pieces) {
        const m = meshPiece(pc.prims, { quality: 'preview' });
        out.pieces.push({ key: pc.key, positions: m.positions, normals: m.normals, indices: m.indices });
        bufs.push(m.positions.buffer, m.normals.buffer, m.indices.buffer);
      }
      post(out, bufs);
    } else if (msg.type === 'export') {
      const { opts } = msg;
      const progress = (label, f) => post({ type: 'progress', id: msg.id, label, f });
      progress('Corps…', 0.05);
      const body = meshBody(msg.body.prims, msg.paint, { quality: 'export', budget: opts.budget, aoScale: opts.aoScale, progress: (l) => progress(l, 0.2) });
      let tex = null;
      if (opts.texture) {
        progress('Cuisson de la texture du corps…', 0.45);
        tex = bakeAtlas(body.model, body, msg.paint, opts.texSize, (f) => progress('Cuisson de la texture du corps…', 0.45 + f * 0.2));
      }
      const pieces = [];
      const n = msg.pieces.length;
      msg.pieces.forEach((pc, i) => {
        progress(`Pièces ${i + 1} / ${n}…`, 0.65 + (0.33 * i) / Math.max(1, n));
        const m = meshPiece(pc.prims, { quality: 'export', detail: opts.detail });
        pieces.push({ key: pc.key, positions: m.positions, normals: m.normals, indices: m.indices, check: checkMesh(m.indices, m.positions.length / 3) });
      });
      const out = {
        type: 'export', id: msg.id,
        body: { positions: body.positions, normals: body.normals, indices: body.indices, joints: body.joints, weights: body.weights, check: body.check },
        tex, pieces,
      };
      const bufs = [body.positions.buffer, body.normals.buffer, body.indices.buffer, body.joints.buffer, body.weights.buffer];
      if (tex) bufs.push(tex.rgba.buffer, tex.uvs.buffer);
      post(out, bufs);
    }
  } catch (err) {
    post({ type: 'error', id: msg.id, message: String((err && err.stack) || err) });
  }
};
