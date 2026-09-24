// Minimal, dependency-free glTF 2.0 binary (.glb) writer:
// one textured mesh, optionally skinned to a bone hierarchy.

export function writeGLB({ name, positions, normals, uvs, indices, joints, weights, bones, png }) {
  const chunks = [];
  let byteLength = 0;
  const bufferViews = [];
  const accessors = [];

  function addView(typed, target) {
    const pad = (4 - (byteLength % 4)) % 4;
    if (pad) { chunks.push(new Uint8Array(pad)); byteLength += pad; }
    const bytes = new Uint8Array(typed.buffer, typed.byteOffset, typed.byteLength);
    chunks.push(bytes);
    const view = { buffer: 0, byteOffset: byteLength, byteLength: bytes.byteLength };
    if (target) view.target = target;
    byteLength += bytes.byteLength;
    bufferViews.push(view);
    return bufferViews.length - 1;
  }
  function addAccessor(typed, type, componentType, count, target, extra = {}) {
    const bv = addView(typed, target);
    accessors.push(Object.assign({ bufferView: bv, componentType, count, type }, extra));
    return accessors.length - 1;
  }

  const nV = positions.length / 3;
  const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
  for (let i = 0; i < positions.length; i += 3)
    for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], positions[i + k]); mx[k] = Math.max(mx[k], positions[i + k]); }

  const attributes = {
    POSITION: addAccessor(positions, 'VEC3', 5126, nV, 34962, { min: mn, max: mx }),
    NORMAL: addAccessor(normals, 'VEC3', 5126, nV, 34962),
    TEXCOORD_0: addAccessor(uvs, 'VEC2', 5126, nV, 34962),
  };
  const skinned = bones && bones.length && joints && weights;
  if (skinned) {
    attributes.JOINTS_0 = addAccessor(joints, 'VEC4', 5123, nV, 34962);
    attributes.WEIGHTS_0 = addAccessor(weights, 'VEC4', 5126, nV, 34962);
  }
  const idxAcc = addAccessor(indices, 'SCALAR', 5125, indices.length, 34963);
  const imgView = addView(png);

  // node 0: the skinned mesh, node 1: armature root (skinned meshes must be
  // scene roots in glTF; bones live under the armature)
  const nodes = [];
  nodes.push({ name: name + 'Mesh', mesh: 0 });
  const root = { name, children: [] };
  nodes.push(root);
  const gltf = {
    asset: { version: '2.0', generator: 'Creature Creator (NewConcept)' },
    scene: 0,
    scenes: [{ name, nodes: [0, 1] }],
    nodes,
    meshes: [{ name: name + 'Mesh', primitives: [{ attributes, indices: idxAcc, material: 0, mode: 4 }] }],
    materials: [{
      name: name + 'Material',
      pbrMetallicRoughness: { baseColorTexture: { index: 0 }, metallicFactor: 0, roughnessFactor: 0.8 },
      doubleSided: false,
    }],
    textures: [{ source: 0, sampler: 0 }],
    images: [{ name: name + 'Texture', bufferView: imgView, mimeType: 'image/png' }],
    samplers: [{ magFilter: 9729, minFilter: 9987, wrapS: 33071, wrapT: 33071 }],
    accessors,
    bufferViews,
    buffers: [],
  };

  if (skinned) {
    const base = nodes.length;
    bones.forEach((b) => {
      const parent = b.parent >= 0 ? bones[b.parent].pos : [0, 0, 0];
      nodes.push({ name: b.name, translation: [b.pos[0] - parent[0], b.pos[1] - parent[1], b.pos[2] - parent[2]] });
    });
    bones.forEach((b, i) => {
      if (b.parent >= 0) {
        const pn = nodes[base + b.parent];
        (pn.children || (pn.children = [])).push(base + i);
      } else root.children.push(base + i);
    });
    const ibm = new Float32Array(bones.length * 16);
    bones.forEach((b, i) => {
      ibm[i * 16] = 1; ibm[i * 16 + 5] = 1; ibm[i * 16 + 10] = 1; ibm[i * 16 + 15] = 1;
      ibm[i * 16 + 12] = -b.pos[0]; ibm[i * 16 + 13] = -b.pos[1]; ibm[i * 16 + 14] = -b.pos[2];
    });
    const ibmAcc = addAccessor(ibm, 'MAT4', 5126, bones.length);
    const rootBone = bones.findIndex((b) => b.parent < 0);
    gltf.skins = [{ name: name + 'Skin', inverseBindMatrices: ibmAcc, joints: bones.map((_, i) => base + i), skeleton: base + Math.max(0, rootBone) }];
    nodes[0].skin = 0;
  }

  if (!root.children.length) delete root.children;
  const pad = (4 - (byteLength % 4)) % 4;
  if (pad) { chunks.push(new Uint8Array(pad)); byteLength += pad; }
  gltf.buffers.push({ byteLength });

  let json = new TextEncoder().encode(JSON.stringify(gltf));
  const jpad = (4 - (json.length % 4)) % 4;
  if (jpad) {
    const j2 = new Uint8Array(json.length + jpad);
    j2.set(json);
    j2.fill(0x20, json.length);
    json = j2;
  }
  const total = 12 + 8 + json.length + 8 + byteLength;
  const out = new Uint8Array(total);
  const dv = new DataView(out.buffer);
  dv.setUint32(0, 0x46546c67, true); // glTF
  dv.setUint32(4, 2, true);
  dv.setUint32(8, total, true);
  dv.setUint32(12, json.length, true);
  dv.setUint32(16, 0x4e4f534a, true); // JSON
  out.set(json, 20);
  let o = 20 + json.length;
  dv.setUint32(o, byteLength, true);
  dv.setUint32(o + 4, 0x004e4942, true); // BIN
  o += 8;
  for (const c of chunks) { out.set(c, o); o += c.length; }
  return out;
}
