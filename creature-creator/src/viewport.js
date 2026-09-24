// Three.js viewport: creature preview, edit handles, camera and test animation.
import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

const srgbToLinear = (c) => (c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4));

export class Viewport {
  constructor(container) {
    this.container = container;
    const renderer = (this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true }));
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFShadowMap;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.05;
    container.appendChild(renderer.domElement);

    const scene = (this.scene = new THREE.Scene());
    const pmrem = new THREE.PMREMGenerator(renderer);
    scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
    scene.environmentIntensity = 0.55;

    this.camera = new THREE.PerspectiveCamera(40, 1, 0.05, 200);
    this.camera.position.set(4.5, 2.8, -5.5);

    const hemi = new THREE.HemisphereLight(0xdfe8ff, 0x4a3a30, 0.9);
    scene.add(hemi);
    const key = (this.key = new THREE.DirectionalLight(0xfff2e0, 2.2));
    key.position.set(4, 8, -3);
    key.castShadow = true;
    key.shadow.mapSize.set(2048, 2048);
    key.shadow.camera.left = -6; key.shadow.camera.right = 6;
    key.shadow.camera.top = 6; key.shadow.camera.bottom = -6;
    key.shadow.bias = -0.0005;
    key.shadow.normalBias = 0.02;
    key.shadow.radius = 4;
    scene.add(key);
    const rim = new THREE.DirectionalLight(0x9fb8ff, 0.9);
    rim.position.set(-5, 3, 6);
    scene.add(rim);

    // ground: soft disc + shadow catcher
    const disc = new THREE.Mesh(new THREE.CircleGeometry(6, 64), new THREE.MeshBasicMaterial({ map: radialTexture(), transparent: true, depthWrite: false }));
    disc.rotation.x = -Math.PI / 2;
    disc.position.y = -0.002;
    scene.add(disc);
    const shadow = new THREE.Mesh(new THREE.PlaneGeometry(16, 16), new THREE.ShadowMaterial({ opacity: 0.28 }));
    shadow.rotation.x = -Math.PI / 2;
    shadow.receiveShadow = true;
    scene.add(shadow);
    const grid = new THREE.PolarGridHelper(5, 16, 8, 64, 0x5a6285, 0x3c425c);
    grid.material.transparent = true;
    grid.material.opacity = 0.35;
    grid.position.y = 0.001;
    scene.add(grid);

    this.material = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.58, metalness: 0.0 });
    this.mesh = new THREE.Mesh(new THREE.BufferGeometry(), this.material);
    this.mesh.castShadow = true;
    this.mesh.receiveShadow = true;
    scene.add(this.mesh);

    this.handles = new THREE.Group();
    scene.add(this.handles);
    this.handleMeshes = [];
    this.showHandles = true;
    this.marker = new THREE.Mesh(new THREE.RingGeometry(0.05, 0.08, 32), new THREE.MeshBasicMaterial({ color: 0x37d6b5, depthTest: false, transparent: true, side: THREE.DoubleSide }));
    this.marker.renderOrder = 20;
    this.marker.visible = false;
    scene.add(this.marker);

    this.controls = null; // created by the app after its own listeners (order matters)
    this.raycaster = new THREE.Raycaster();
    this.lastT = performance.now();
    this.test = null;
    this.ownerSel = null;

    const ro = new ResizeObserver(() => this.resize());
    ro.observe(container);
    this.resize();
    renderer.setAnimationLoop(() => this.render());
  }

  initControls() {
    const c = (this.controls = new OrbitControls(this.camera, this.renderer.domElement));
    c.target.set(0, 1, 0);
    c.enableDamping = true;
    c.dampingFactor = 0.12;
    c.minDistance = 1;
    c.maxDistance = 40;
    c.maxPolarAngle = Math.PI * 0.49;
    c.mouseButtons = { LEFT: THREE.MOUSE.ROTATE, MIDDLE: THREE.MOUSE.DOLLY, RIGHT: THREE.MOUSE.PAN };
  }

  resize() {
    const w = this.container.clientWidth || 1, h = this.container.clientHeight || 1;
    this.renderer.setSize(w, h, false);
    this.renderer.domElement.style.width = w + 'px';
    this.renderer.domElement.style.height = h + 'px';
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
  }

  render() {
    const now = performance.now();
    const dt = Math.min(0.05, (now - this.lastT) / 1000);
    this.lastT = now;
    if (this.controls) this.controls.update();
    if (this.test) this.test.update(dt);
    this.renderer.render(this.scene, this.camera);
  }

  // ------------------------------------------------------------ mesh
  setMesh(data) {
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(data.positions, 3));
    g.setAttribute('normal', new THREE.BufferAttribute(data.normals, 3));
    const lin = new Float32Array(data.colors.length);
    for (let i = 0; i < lin.length; i++) lin[i] = srgbToLinear(Math.min(1, data.colors[i]));
    this.baseColors = lin;
    g.setAttribute('color', new THREE.BufferAttribute(lin.slice(), 3));
    g.setIndex(new THREE.BufferAttribute(data.indices, 1));
    g.computeBoundingSphere();
    g.computeBoundingBox();
    this.mesh.geometry.dispose();
    this.mesh.geometry = g;
    this.meshData = data;
    this.applyHighlight();
  }

  highlight(ownerKey) {
    this.ownerSel = ownerKey;
    this.applyHighlight();
  }

  applyHighlight() {
    const d = this.meshData;
    if (!d || !this.baseColors) return;
    const col = this.mesh.geometry.getAttribute('color');
    const arr = col.array;
    arr.set(this.baseColors);
    if (this.ownerSel) {
      const hit = d.ownerNames.map((n) => n.split('|')[0] === this.ownerSel);
      for (let i = 0; i < d.owners.length; i++) {
        if (!hit[d.owners[i]]) continue;
        arr[i * 3] = arr[i * 3] * 0.7 + 0.06;
        arr[i * 3 + 1] = arr[i * 3 + 1] * 0.7 + 0.16;
        arr[i * 3 + 2] = arr[i * 3 + 2] * 0.7 + 0.32;
      }
    }
    col.needsUpdate = true;
  }

  frame(box) {
    const b = box || this.mesh.geometry.boundingBox;
    if (!b) return;
    const c = new THREE.Vector3(), s = new THREE.Vector3();
    b.getCenter(c); b.getSize(s);
    const r = Math.max(s.x, s.y, s.z, 1);
    const dir = this.camera.position.clone().sub(this.controls.target).normalize();
    this.controls.target.copy(c);
    this.camera.position.copy(c).addScaledVector(dir, r * 2.1);
  }

  view(name) {
    const b = this.mesh.geometry.boundingBox;
    const c = new THREE.Vector3(0, 1, 0), s = new THREE.Vector3(3, 3, 3);
    if (b) { b.getCenter(c); b.getSize(s); }
    const r = Math.max(s.x, s.y, s.z, 1) * 2.2;
    const dirs = { front: [0, 0.15, -1], side: [1, 0.12, 0], top: [0.001, 1, -0.02], persp: [0.62, 0.42, -0.75] };
    const d = new THREE.Vector3(...dirs[name]).normalize();
    this.controls.target.copy(c);
    this.camera.position.copy(c).addScaledVector(d, r);
  }

  // ------------------------------------------------------------ picking
  ray(ev) {
    const rect = this.renderer.domElement.getBoundingClientRect();
    const ndc = new THREE.Vector2(((ev.clientX - rect.left) / rect.width) * 2 - 1, -((ev.clientY - rect.top) / rect.height) * 2 + 1);
    this.raycaster.setFromCamera(ndc, this.camera);
    const o = this.raycaster.ray.origin, d = this.raycaster.ray.direction;
    return { ro: [o.x, o.y, o.z], rd: [d.x, d.y, d.z], ray: this.raycaster.ray.clone() };
  }

  pickHandle(ev) {
    if (!this.showHandles || !this.handles.visible) return null;
    this.ray(ev);
    const hits = this.raycaster.intersectObjects(this.handleMeshes, false);
    return hits.length ? hits[0].object.userData : null;
  }

  // handles: [{pos, r, color, data, selected}]
  setHandles(list, rings = []) {
    for (const m of this.handleMeshes) { m.geometry.dispose(); m.material.dispose(); }
    this.handles.clear();
    this.handleMeshes = [];
    for (const h of list) {
      const m = new THREE.Mesh(new THREE.SphereGeometry(h.r, 16, 12), new THREE.MeshBasicMaterial({ color: h.color, transparent: true, opacity: h.selected ? 1 : 0.8, depthTest: false }));
      m.position.set(...h.pos);
      m.renderOrder = 10;
      m.userData = h.data;
      if (h.selected) {
        const ring = new THREE.Mesh(new THREE.SphereGeometry(h.r * 1.5, 16, 12), new THREE.MeshBasicMaterial({ color: 0xffffff, wireframe: true, transparent: true, opacity: 0.6, depthTest: false }));
        ring.renderOrder = 9;
        m.add(ring);
      }
      this.handles.add(m);
      this.handleMeshes.push(m);
    }
    for (const r of rings) {
      const m = new THREE.Mesh(new THREE.TorusGeometry(r.r, 0.008, 6, 48), new THREE.MeshBasicMaterial({ color: 0x37d6b5, transparent: true, opacity: 0.7, depthTest: false }));
      m.position.set(...r.pos);
      m.lookAt(r.pos[0] + r.axis[0], r.pos[1] + r.axis[1], r.pos[2] + r.axis[2]);
      m.renderOrder = 8;
      this.handles.add(m);
    }
    for (let i = 0; i < list.length; i++) {
      // draw lines between consecutive handles of the same chain
      const a = list[i], b = list[i + 1];
      if (!b || !a.chain || a.chain !== b.chain) continue;
      const g = new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(...a.pos), new THREE.Vector3(...b.pos)]);
      const l = new THREE.Line(g, new THREE.LineBasicMaterial({ color: a.color, transparent: true, opacity: 0.55, depthTest: false }));
      l.renderOrder = 8;
      this.handles.add(l);
    }
  }

  setMarker(p, n) {
    if (!p) { this.marker.visible = false; return; }
    this.marker.visible = true;
    this.marker.position.set(p[0] + n[0] * 0.01, p[1] + n[1] * 0.01, p[2] + n[2] * 0.01);
    this.marker.lookAt(p[0] + n[0], p[1] + n[1], p[2] + n[2]);
  }

  snapshot(size = 256) {
    this.renderer.render(this.scene, this.camera);
    const src = this.renderer.domElement;
    const c = document.createElement('canvas');
    c.width = c.height = size;
    const ctx = c.getContext('2d');
    const s = Math.min(src.width, src.height);
    ctx.fillStyle = '#2a2f45';
    ctx.fillRect(0, 0, size, size);
    ctx.drawImage(src, (src.width - s) / 2, (src.height - s) / 2, s, s, 0, 0, size, size);
    return c.toDataURL('image/jpeg', 0.8);
  }

  // ------------------------------------------------------------ test mode
  startTest(data, bones, info, mode) {
    this.stopTest();
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.BufferAttribute(data.positions, 3));
    g.setAttribute('normal', new THREE.BufferAttribute(data.normals, 3));
    g.setAttribute('color', new THREE.BufferAttribute(this.baseColors.slice(), 3));
    g.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(data.joints, 4));
    g.setAttribute('skinWeight', new THREE.Float32BufferAttribute(data.weights, 4));
    g.setIndex(new THREE.BufferAttribute(data.indices, 1));
    const skinned = new THREE.SkinnedMesh(g, this.material);
    skinned.castShadow = true;
    const B = bones.map((b) => {
      const o = new THREE.Bone();
      o.name = b.name;
      return o;
    });
    bones.forEach((b, i) => {
      if (b.parent >= 0) {
        const p = bones[b.parent].pos;
        B[i].position.set(b.pos[0] - p[0], b.pos[1] - p[1], b.pos[2] - p[2]);
        B[b.parent].add(B[i]);
      } else {
        B[i].position.set(...b.pos);
        skinned.add(B[i]);
      }
    });
    this.scene.add(skinned);
    skinned.updateMatrixWorld(true);
    skinned.bind(new THREE.Skeleton(B));
    this.mesh.visible = false;
    this.handles.visible = false;
    const rest = B.map((b) => b.position.clone());
    let t = 0;
    this.test = {
      mesh: skinned, mode, speed: 1,
      update: (dt) => {
        t += dt * this.test.speed;
        animate(B, rest, info, t, this.test.mode);
      },
    };
  }

  stopTest() {
    if (!this.test) return;
    this.scene.remove(this.test.mesh);
    this.test.mesh.geometry.dispose();
    this.test = null;
    this.mesh.visible = true;
    this.handles.visible = this.showHandles;
  }
}

function animate(B, rest, info, t, mode) {
  const w = mode === 'run' ? 9 : 5.5;
  const amp = mode === 'run' ? 1.35 : 1;
  for (let i = 0; i < B.length; i++) {
    const b = B[i], f = info[i];
    b.rotation.set(0, 0, 0);
    b.position.copy(rest[i]);
    if (!f) continue;
    const ph = f.phase || 0;
    const s = Math.sin(w * t + ph);
    if (mode === 'idle') {
      const br = Math.sin(t * 2.2);
      if (f.role === 'root') b.position.y += 0.015 * br;
      else if (f.role === 'neck') { b.rotation.y = 0.18 * Math.sin(t * 0.7) / Math.max(1, f.depth); b.rotation.x = 0.04 * br; }
      else if (f.role === 'tail') b.rotation.y = 0.12 * Math.sin(t * 1.3 - f.depth * 0.6);
      else if (f.role === 'wing' && f.seg === 0) b.rotation.z = 0.15 * Math.sin(t * 1.5) * f.side;
      else if (f.role === 'tentacle') b.rotation.z = 0.12 * Math.sin(t * 1.4 + f.seg * 0.8 + ph);
      else if (f.role === 'arm' && f.seg === 0) b.rotation.x = 0.05 * br;
      continue;
    }
    if (mode === 'dance') {
      const d = Math.sin(t * 6);
      if (f.role === 'root') { b.position.y += 0.06 * Math.abs(d); b.rotation.y = 0.25 * Math.sin(t * 3); }
      else if (f.role === 'neck') b.rotation.z = 0.2 * d / Math.max(1, f.depth);
      else if (f.role === 'tail') b.rotation.y = 0.35 * Math.sin(t * 6 - f.depth);
      else if (f.role === 'arm' && f.seg === 0) b.rotation.z = (0.9 + 0.5 * d) * f.side;
      else if (f.role === 'wing' && f.seg === 0) b.rotation.z = 0.6 * d * f.side;
      else if (f.role === 'leg' && f.seg === 0) b.rotation.x = 0.2 * Math.sin(t * 6 + ph);
      else if (f.role === 'tentacle' || f.role === 'insect') b.rotation.z = 0.3 * Math.sin(t * 6 + f.seg + ph) * f.side;
      continue;
    }
    switch (f.role) {
      case 'root':
        b.position.y += 0.03 * amp * Math.abs(Math.sin(w * t));
        b.rotation.z = 0.03 * Math.sin(w * t);
        break;
      case 'neck':
        b.rotation.x = 0.04 * Math.sin(2 * w * t);
        break;
      case 'tail':
        b.rotation.y = 0.12 * amp * Math.sin(w * t - f.depth * 0.7);
        break;
      case 'leg':
        if (f.seg === 0) b.rotation.x = 0.42 * amp * s;
        else if (f.seg === 1) b.rotation.x = -0.55 * amp * Math.max(0, Math.sin(w * t + ph + 1.3)) * f.bend;
        else b.rotation.x = 0.25 * amp * Math.max(0, -s);
        break;
      case 'arm':
        if (f.seg === 0) b.rotation.x = -0.45 * amp * s;
        else if (f.seg === 1) b.rotation.x = -0.25 - 0.15 * s;
        break;
      case 'insect':
        if (f.seg === 0) b.rotation.y = 0.35 * amp * s * f.side;
        else if (f.seg === 1) b.rotation.z = 0.2 * Math.max(0, Math.cos(w * t + ph)) * f.side;
        break;
      case 'tentacle':
        b.rotation.z = 0.25 * Math.sin(w * 0.6 * t + f.seg * 0.8 + ph);
        b.rotation.x = 0.15 * Math.cos(w * 0.6 * t + f.seg * 0.8 + ph);
        break;
      case 'wing':
        if (f.seg === 0) b.rotation.z = 0.5 * Math.sin(w * 1.2 * t) * f.side;
        break;
      case 'stalk':
        b.rotation.x = 0.1 * Math.sin(w * 0.5 * t + f.seg);
        break;
    }
  }
}

function radialTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const g = c.getContext('2d');
  const grd = g.createRadialGradient(128, 128, 10, 128, 128, 128);
  grd.addColorStop(0, 'rgba(120,130,175,0.55)');
  grd.addColorStop(0.7, 'rgba(90,100,140,0.25)');
  grd.addColorStop(1, 'rgba(60,70,100,0)');
  g.fillStyle = grd;
  g.fillRect(0, 0, 256, 256);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
