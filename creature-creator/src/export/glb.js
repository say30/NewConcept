// Minimal, dependency-free glTF 2.0 binary (.glb) writer.
// Several meshes (one per piece => one MeshPart each in Roblox), each with its
// own material (solid colour, or a texture), optionally sharing one skeleton.

export function writeGLB({ name, meshes, bones }) {
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

  const skinned = !!(bones && bones.length && meshes.some((m) => m.joints));
  const gltf = {
    asset: { version: '2.0', generator: 'Creature Creator (NewConcept)' },
    scene: 0,
    scenes: [{ name, nodes: [] }],
    nodes: [],
    meshes: [],
    materials: [],
    accessors,
    bufferViews,
    buffers: [],
  };
  const textures = [], images = [];

  for (const m of meshes) {
    const nV = m.positions.length / 3;
    if (!nV || !m.indices.length) continue;
    const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
    for (let i = 0; i < m.positions.length; i += 3)
      for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], m.positions[i + k]); mx[k] = Math.max(mx[k], m.positions[i + k]); }
    const attributes = {
      POSITION: addAccessor(m.positions, 'VEC3', 5126, nV, 34962, { min: mn, max: mx }),
      NORMAL: addAccessor(m.normals, 'VEC3', 5126, nV, 34962),
    };
    if (m.uvs) attributes.TEXCOORD_0 = addAccessor(m.uvs, 'VEC2', 5126, nV, 34962);
    if (skinned && m.joints) {
      attributes.JOINTS_0 = addAccessor(m.joints, 'VEC4', 5123, nV, 34962);
      attributes.WEIGHTS_0 = addAccessor(m.weights, 'VEC4', 5126, nV, 34962);
    }
    const idx = addAccessor(m.indices, 'SCALAR', 5125, m.indices.length, 34963);
    const mat = {
      name: m.name,
      pbrMetallicRoughness: { baseColorFactor: [...(m.color || [1, 1, 1]), 1], metallicFactor: 0, roughnessFactor: m.roughness ?? 0.7 },
    };
    if (m.png) {
      images.push({ name: m.name + 'Texture', bufferView: addView(m.png), mimeType: 'image/png' });
      textures.push({ source: images.length - 1, sampler: 0 });
      mat.pbrMetallicRoughness.baseColorTexture = { index: textures.length - 1 };
      mat.pbrMetallicRoughness.baseColorFactor = [1, 1, 1, 1];
    }
    gltf.materials.push(mat);
    gltf.meshes.push({ name: m.name, primitives: [{ attributes, indices: idx, material: gltf.materials.length - 1, mode: 4 }] });
    const node = { name: m.name, mesh: gltf.meshes.length - 1 };
    if (skinned && m.joints) node.skin = 0;
    gltf.nodes.push(node);
    gltf.scenes[0].nodes.push(gltf.nodes.length - 1);
  }
  if (images.length) {
    gltf.images = images;
    gltf.textures = textures;
    gltf.samplers = [{ magFilter: 9729, minFilter: 9987, wrapS: 33071, wrapT: 33071 }];
  }

  if (skinned) {
    const armature = { name: name + 'Armature', children: [] };
    gltf.nodes.push(armature);
    gltf.scenes[0].nodes.push(gltf.nodes.length - 1);
    const base = gltf.nodes.length;
    bones.forEach((b) => {
      const parent = b.parent >= 0 ? bones[b.parent].pos : [0, 0, 0];
      gltf.nodes.push({ name: b.name, translation: [b.pos[0] - parent[0], b.pos[1] - parent[1], b.pos[2] - parent[2]] });
    });
    bones.forEach((b, i) => {
      if (b.parent >= 0) {
        const pn = gltf.nodes[base + b.parent];
        (pn.children || (pn.children = [])).push(base + i);
      } else armature.children.push(base + i);
    });
    const ibm = new Float32Array(bones.length * 16);
    bones.forEach((b, i) => {
      ibm[i * 16] = 1; ibm[i * 16 + 5] = 1; ibm[i * 16 + 10] = 1; ibm[i * 16 + 15] = 1;
      ibm[i * 16 + 12] = -b.pos[0]; ibm[i * 16 + 13] = -b.pos[1]; ibm[i * 16 + 14] = -b.pos[2];
    });
    const ibmAcc = addAccessor(ibm, 'MAT4', 5126, bones.length);
    const rootBone = bones.findIndex((b) => b.parent < 0);
    gltf.skins = [{ name: name + 'Skin', inverseBindMatrices: ibmAcc, joints: bones.map((_, i) => base + i), skeleton: base + Math.max(0, rootBone) }];
  }

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
  dv.setUint32(0, 0x46546c67, true);
  dv.setUint32(4, 2, true);
  dv.setUint32(8, total, true);
  dv.setUint32(12, json.length, true);
  dv.setUint32(16, 0x4e4f534a, true);
  out.set(json, 20);
  let o = 20 + json.length;
  dv.setUint32(o, byteLength, true);
  dv.setUint32(o + 4, 0x004e4942, true);
  o += 8;
  for (const c of chunks) { out.set(c, o); o += c.length; }
  return out;
}

export function srgbToLinear(c) {
  return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}
