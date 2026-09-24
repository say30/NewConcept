import { Viewport } from './viewport.js';
import { buildCreature, defaultPaint, limbJoints, limbRoot, limbRadii, spineFrame, spinePoint, spineRadius, makeAttachment, makeLimbAnchor, frameFromNormal, isMirrored, uid, resolveAttachment } from './core/creature.js';
import { PARTS, LIMBS, CATEGORIES } from './core/parts.js';
import { PRESETS, buildPreset } from './core/presets.js';
import { randomCreature, randomPaint, PALETTES } from './core/random.js';
import { resolvePaint, PATTERNS } from './core/paint.js';
import { makeModel, trace, ownerAt, symmetricHit, createPart, createLimb } from './core/edit.js';
import { sub, scale, norm, len } from './core/sdf.js';
import { prepareExport, makeGLB, makeOBJZip, safeName } from './export/files.js';
import MeshWorker from './worker.js?worker&inline';

const $ = (s) => document.querySelector(s);
const el = (tag, attrs = {}, ...kids) => {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === 'class') e.className = v;
    else if (k.startsWith('on')) e.addEventListener(k.slice(2), v);
    else if (k === 'html') e.innerHTML = v;
    else if (v !== undefined && v !== null && v !== false) e.setAttribute(k, v === true ? '' : v);
  }
  for (const k of kids.flat()) if (k !== null && k !== undefined && k !== false) e.append(k.nodeType ? k : document.createTextNode(k));
  return e;
};

// ================================================================ state
const store = {
  get(k) { try { return localStorage.getItem(k); } catch { return null; } },
  set(k, v) { try { localStorage.setItem(k, v); return true; } catch { return false; } },
};

let creature;
let build;
let mode = 'build';
let sel = null; // {type:'spine', vert} | {type:'limb', id, joint} | {type:'part', id}
let placing = null; // {kind:'part'|'limb'|'end', type}
let history = [], future = [];
let lastSaved = '';
let category = 'limbs';
let testMode = 'walk';

function normalizeCreature(c) {
  if (!c || !Array.isArray(c.spine) || c.spine.length < 2) throw new Error('Fichier de créature invalide');
  c.version = 1;
  c.name = c.name || 'Ma créature';
  c.body = Object.assign({ blend: 1 }, c.body || {});
  c.limbs = (c.limbs || []).filter((l) => LIMBS[l.kind] && l.anchor && Array.isArray(l.joints));
  c.parts = (c.parts || []).filter((p) => PARTS[p.type] && p.anchor);
  c.paint = Object.assign(defaultPaint(), c.paint || {});
  for (const v of c.spine) { v.p = [0, +v.p[1] || 0, +v.p[2] || 0]; v.r = Math.max(0.03, +v.r || 0.2); }
  return c;
}

function snapshot() { return JSON.stringify(creature); }

function commit() {
  const s = snapshot();
  if (s === lastSaved) return;
  history.push(lastSaved);
  if (history.length > 100) history.shift();
  future = [];
  lastSaved = s;
  store.set('cc.current', s);
  updateUndo();
}

function loadCreature(c, resetHistory = true) {
  creature = normalizeCreature(c);
  sel = null;
  placing = null;
  if (resetHistory) { history = []; future = []; }
  lastSaved = snapshot();
  store.set('cc.current', lastSaved);
  $('#name').value = creature.name;
  changed({ commit: false });
  renderLeft();
  updateUndo();
  setTimeout(() => viewport.frame(), 350);
}

function undo() {
  if (!history.length) return;
  future.push(lastSaved);
  lastSaved = history.pop();
  creature = JSON.parse(lastSaved);
  store.set('cc.current', lastSaved);
  validateSel();
  $('#name').value = creature.name;
  changed({ commit: false });
  renderLeft();
  updateUndo();
}
function redo() {
  if (!future.length) return;
  history.push(lastSaved);
  lastSaved = future.pop();
  creature = JSON.parse(lastSaved);
  store.set('cc.current', lastSaved);
  validateSel();
  $('#name').value = creature.name;
  changed({ commit: false });
  renderLeft();
  updateUndo();
}
function updateUndo() {
  $('#btn-undo').disabled = !history.length;
  $('#btn-redo').disabled = !future.length;
}
function validateSel() {
  if (!sel) return;
  if (sel.type === 'part' && !creature.parts.find((p) => p.id === sel.id)) sel = null;
  else if (sel.type === 'limb' && !creature.limbs.find((l) => l.id === sel.id)) sel = null;
  else if (sel.type === 'spine' && sel.vert >= creature.spine.length) sel = null;
}

// ================================================================ viewport + worker
const viewport = new Viewport($('#viewport'));
const canvas = viewport.renderer.domElement;
const worker = new MeshWorker();
let wBusy = false, wPending = null, reqId = 0, needFull = false;
const inflight = new Map();
let lastMesh = null;
let exportJob = null;

function aoScale() {
  return creature.spine.reduce((s, v) => s + v.r, 0) / creature.spine.length;
}

function requestPreview(fast) {
  wPending = { fast };
  if (!fast) needFull = false; else needFull = true;
  pump();
}

function pump() {
  if (wBusy || !wPending) return;
  const { fast } = wPending;
  wPending = null;
  wBusy = true;
  $('#busy').classList.add('on');
  const id = ++reqId;
  inflight.set(id, { bones: build.bones, fast });
  worker.postMessage({ type: 'preview', id, prims: build.prims, paint: resolvePaint(creature.paint, build), div: fast ? 52 : 84, aoScale: aoScale() });
}

worker.onmessage = (e) => {
  const m = e.data;
  if (m.type === 'preview') {
    const info = inflight.get(m.id);
    inflight.delete(m.id);
    wBusy = false;
    viewport.setMesh(m);
    lastMesh = { data: m, bones: info.bones };
    $('#stats').textContent = `Aperçu ${(m.indices.length / 3).toLocaleString('fr-FR')} △ · ${creature.parts.length} pièces · ${creature.limbs.length} membres`;
    if (!first.framed) { first.framed = true; viewport.frame(); }
    if (!wPending && needFull && !drag) requestPreview(false);
    if (!wPending) $('#busy').classList.remove('on');
    pump();
    if (mode === 'test') startTest();
  } else if (m.type === 'progress') {
    if (exportJob) exportJob.progress(m.label, m.f);
  } else if (m.type === 'export') {
    if (exportJob) exportJob.done(m);
  } else if (m.type === 'error') {
    console.error(m.message);
    wBusy = false;
    $('#busy').classList.remove('on');
    if (exportJob && exportJob.id === m.id) exportJob.fail(m.message);
    else toast('Erreur de génération : ' + m.message.split('\n')[0], true);
    pump();
  }
};
const first = { framed: false };

let pickCache = new Map();
function pickModel(skip = '') {
  if (!pickCache.has(skip)) pickCache.set(skip, makeModel(build.prims, skip || undefined));
  return pickCache.get(skip);
}

function changed({ commit: doCommit = true, fast = false, inspector = true } = {}) {
  build = buildCreature(creature);
  pickCache = new Map();
  updateHandles();
  requestPreview(fast);
  if (doCommit) commit();
  if (inspector) renderRight();
  viewport.highlight(sel && sel.type !== 'spine' ? `${sel.type}:${sel.id}` : null);
  updateHint();
}

// ================================================================ handles
const COL = { vert: 0xffd166, vertSel: 0xffffff, joint: 0x37d6b5, root: 0x8b6cff };

function updateHandles() {
  if (!creature) return;
  const list = [], rings = [];
  const sp = creature.spine;
  sp.forEach((v, i) => {
    const s = sel && sel.type === 'spine' && sel.vert === i;
    list.push({ pos: v.p, r: 0.055, color: s ? COL.vertSel : COL.vert, data: { type: 'vert', i }, selected: s, chain: 'spine' });
    if (s) {
      const f = spineFrame(sp, i);
      rings.push({ pos: v.p, r: v.r, axis: f.z });
    }
  });
  for (const limb of creature.limbs) {
    const J = limbJoints(creature, limb);
    const mir = isMirrored(limb, J[0][0]);
    const isSel = sel && sel.type === 'limb' && sel.id === limb.id;
    for (const side of mir ? [false, true] : [false]) {
      J.forEach((p, j) => {
        const pos = side ? [-p[0], p[1], p[2]] : p;
        const s = isSel && sel.joint === j;
        list.push({ pos, r: j === 0 ? 0.05 : 0.045, color: s ? 0xffffff : j === 0 ? COL.root : COL.joint, data: { type: 'joint', limb: limb.id, j, mirror: side }, selected: s, chain: limb.id + side });
      });
    }
  }
  viewport.setHandles(mode === 'build' ? list : [], mode === 'build' ? rings : []);
}

// ================================================================ interaction
let drag = null;
let wheelTimer = null;

function traceEvent(ev, skip) {
  const { ro, rd } = viewport.ray(ev);
  return trace(pickModel(skip), ro, rd);
}

function ownerFromHit(hit) {
  const o = ownerAt(pickModel(), hit.p);
  if (!o) return null;
  const [type, id] = o.owner.split(':');
  return { type, id, mirrored: o.mirrored };
}

function nearestVert(p) {
  let best = 0, bd = Infinity;
  creature.spine.forEach((v, i) => {
    const d = len(sub(p, v.p));
    if (d < bd) { bd = d; best = i; }
  });
  return best;
}

canvas.addEventListener('pointerdown', (ev) => {
  if (ev.button !== 0 || mode === 'test') return;
  const block = () => { viewport.controls.enabled = false; };
  if (placing) {
    const hit = traceEvent(ev);
    if (hit) { doPlace(hit, ev.shiftKey); block(); drag = { kind: 'none' }; }
    return;
  }
  if (mode === 'build') {
    const h = viewport.pickHandle(ev);
    if (h) {
      block();
      canvas.setPointerCapture(ev.pointerId);
      if (h.type === 'vert') { sel = { type: 'spine', vert: h.i }; drag = { kind: 'vert', i: h.i, moved: false }; }
      else {
        sel = { type: 'limb', id: h.limb, joint: h.j };
        drag = { kind: 'joint', limb: h.limb, j: h.j, mirror: h.mirror, moved: false };
        if (h.j === 0) drag.skipModel = pickModel('limb:' + h.limb);
      }
      changed({ commit: false });
      return;
    }
  }
  const hit = traceEvent(ev);
  if (!hit) { drag = { kind: 'deselect', x: ev.clientX, y: ev.clientY }; return; }
  const o = ownerFromHit(hit);
  if (!o) return;
  if (o.type === 'part') {
    sel = { type: 'part', id: o.id };
    if (mode === 'build') {
      block();
      canvas.setPointerCapture(ev.pointerId);
      drag = { kind: 'part', id: o.id, x: ev.clientX, y: ev.clientY, moved: false, skipModel: pickModel('part:' + o.id) };
    }
  } else if (o.type === 'limb') sel = { type: 'limb', id: o.id, joint: null };
  else sel = { type: 'spine', vert: nearestVert(hit.p) };
  changed({ commit: false });
});

canvas.addEventListener('pointermove', (ev) => {
  if (placing && !drag) {
    const hit = traceEvent(ev);
    viewport.setMarker(hit && hit.p, hit && hit.n);
    return;
  }
  if (!drag) return;
  if (drag.kind === 'vert') {
    const { ro, rd } = viewport.ray(ev);
    let p;
    if (Math.abs(rd[0]) > 0.15) {
      const t = -ro[0] / rd[0];
      p = [0, ro[1] + rd[1] * t, ro[2] + rd[2] * t];
    } else p = planeHit(ro, rd, creature.spine[drag.i].p);
    if (!p) return;
    creature.spine[drag.i].p = [0, Math.max(0.05, p[1]), p[2]];
    drag.moved = true;
    changed({ commit: false, fast: true, inspector: false });
  } else if (drag.kind === 'joint') {
    const limb = creature.limbs.find((l) => l.id === drag.limb);
    if (!limb) return;
    if (drag.j === 0) {
      const { ro, rd } = viewport.ray(ev);
      const hit = trace(drag.skipModel, ro, rd);
      if (!hit) return;
      let { p, n } = hit;
      if (drag.mirror) { p = [-p[0], p[1], p[2]]; n = [-n[0], n[1], n[2]]; }
      const r0 = limbRadii(limb)[0];
      limb.anchor = makeLimbAnchor(creature, sub(p, scale(n, r0 * 0.45)));
    } else {
      const J = limbJoints(creature, limb);
      const cur = drag.mirror ? [-J[drag.j][0], J[drag.j][1], J[drag.j][2]] : J[drag.j];
      const { ro, rd } = viewport.ray(ev);
      let q = planeHit(ro, rd, cur);
      if (!q) return;
      if (drag.mirror) q = [-q[0], q[1], q[2]];
      q[1] = Math.max(0.01, q[1]);
      const root = limbRoot(creature, limb);
      limb.joints[drag.j] = sub(q, root);
    }
    drag.moved = true;
    changed({ commit: false, fast: true, inspector: false });
  } else if (drag.kind === 'part') {
    if (!drag.moved && Math.hypot(ev.clientX - drag.x, ev.clientY - drag.y) < 4) return;
    const part = creature.parts.find((p) => p.id === drag.id);
    if (!part) return;
    const { ro, rd } = viewport.ray(ev);
    const hit = trace(drag.skipModel, ro, rd);
    if (!hit) return;
    let p = hit.p, n = hit.n;
    if (part.mirror !== false) ({ p, n } = symmetricHit(p, n));
    part.anchor = makeAttachment(creature, p, frameFromNormal(n, PARTS[part.type].hint || 'fwd'));
    drag.moved = true;
    changed({ commit: false, fast: true, inspector: false });
  }
});

function endDrag(ev) {
  if (!drag) return;
  const d = drag;
  drag = null;
  viewport.controls.enabled = true;
  if (d.kind === 'deselect') {
    if (Math.hypot(ev.clientX - d.x, ev.clientY - d.y) < 5) { sel = null; changed({ commit: false }); }
    return;
  }
  if (d.moved) changed({ commit: true });
  else if (needFull) requestPreview(false);
}
canvas.addEventListener('pointerup', endDrag);
canvas.addEventListener('pointercancel', endDrag);

function planeHit(ro, rd, through) {
  const cam = viewport.camera.getWorldDirection(new viewport.camera.position.constructor());
  const n = [cam.x, cam.y, cam.z];
  const denom = n[0] * rd[0] + n[1] * rd[1] + n[2] * rd[2];
  if (Math.abs(denom) < 1e-6) return null;
  const t = (n[0] * (through[0] - ro[0]) + n[1] * (through[1] - ro[1]) + n[2] * (through[2] - ro[2])) / denom;
  if (t < 0) return null;
  return [ro[0] + rd[0] * t, ro[1] + rd[1] * t, ro[2] + rd[2] * t];
}

canvas.addEventListener('wheel', (ev) => {
  if (mode !== 'build' || placing) return;
  const k = ev.deltaY > 0 ? 0.94 : 1 / 0.94;
  let done = false;
  const h = viewport.pickHandle(ev);
  if (h && h.type === 'vert') {
    const v = creature.spine[h.i];
    v.r = Math.min(2, Math.max(0.03, v.r * k));
    sel = { type: 'spine', vert: h.i };
    done = true;
  } else if (h && h.type === 'joint') {
    const limb = creature.limbs.find((l) => l.id === h.limb);
    limb.radii[h.j] = Math.min(1, Math.max(0.01, limb.radii[h.j] * k));
    sel = { type: 'limb', id: limb.id, joint: h.j };
    done = true;
  } else {
    const hit = traceEvent(ev);
    const o = hit && ownerFromHit(hit);
    if (o && o.type === 'part') {
      const part = creature.parts.find((p) => p.id === o.id);
      part.scale = Math.min(5, Math.max(0.15, (part.scale || 1) * k));
      sel = { type: 'part', id: part.id };
      done = true;
    } else if (o && o.type === 'limb') {
      const limb = creature.limbs.find((l) => l.id === o.id);
      limb.thick = Math.min(3, Math.max(0.3, (limb.thick || 1) * k));
      sel = { type: 'limb', id: limb.id, joint: null };
      done = true;
    }
  }
  if (!done) return;
  ev.preventDefault();
  ev.stopImmediatePropagation();
  changed({ commit: false, fast: true });
  clearTimeout(wheelTimer);
  wheelTimer = setTimeout(() => { commit(); requestPreview(false); }, 400);
}, { passive: false });

viewport.initControls();

// ---------------------------------------------------------------- placing
function startPlacing(kind, type) {
  placing = { kind, type };
  $('#stage').classList.add('placing');
  updateHint();
  renderLeft();
}
function stopPlacing() {
  placing = null;
  $('#stage').classList.remove('placing');
  viewport.setMarker(null);
  updateHint();
  renderLeft();
}

function doPlace(hit, keep = false) {
  const { p, n } = symmetricHit(hit.p, hit.n);
  if (placing.kind === 'part') {
    const part = createPart(creature, placing.type, p, n);
    creature.parts.push(part);
    sel = { type: 'part', id: part.id };
  } else if (placing.kind === 'limb') {
    const limb = createLimb(creature, placing.type, p, n);
    creature.limbs.push(limb);
    sel = { type: 'limb', id: limb.id, joint: null };
  } else if (placing.kind === 'end') {
    const limb = nearestLimbEnd(p);
    if (!limb) { toast('Place d\'abord un membre (jambe, bras…) pour y mettre une main ou un pied.', true); return; }
    limb.end = placing.type;
    sel = { type: 'limb', id: limb.id, joint: null };
  }
  if (!keep) stopPlacing();
  changed();
}

function nearestLimbEnd(p) {
  let best = null, bd = Infinity;
  for (const l of creature.limbs) {
    const J = limbJoints(creature, l);
    const e = J[J.length - 1];
    const d = len(sub(p, e));
    if (d < bd) { bd = d; best = l; }
  }
  return best;
}

// ================================================================ panels
function renderLeft() {
  const left = $('#left');
  left.innerHTML = '';
  if (mode === 'build') left.append(catalogPanel());
  else if (mode === 'paint') left.append(paintPanel());
  else left.append(testPanel());
}

function catalogPanel() {
  const wrap = el('div');
  const cats = el('div', { class: 'cats' });
  for (const [key, label, icon] of CATEGORIES) {
    cats.append(el('button', { class: key === category ? 'active' : '', onclick: () => { category = key; renderLeft(); } }, `${icon} ${label}`));
  }
  const grid = el('div', { class: 'grid' });
  const items = category === 'limbs'
    ? Object.entries(LIMBS).map(([k, d]) => ({ kind: 'limb', type: k, name: d.name, icon: d.icon }))
    : Object.entries(PARTS).filter(([, d]) => d.cat === category).map(([k, d]) => ({ kind: d.end ? 'end' : 'part', type: k, name: d.name, icon: d.icon }));
  for (const it of items) {
    const active = placing && placing.type === it.type;
    const card = el('button', { class: 'card' + (active ? ' active' : ''), title: it.name }, el('span', { class: 'ic' }, it.icon), it.name);
    card.addEventListener('pointerdown', (ev) => {
      if (ev.button !== 0) return;
      ev.preventDefault();
      if (it.kind === 'end' && sel && sel.type === 'limb') {
        const limb = creature.limbs.find((l) => l.id === sel.id);
        limb.end = it.type;
        changed();
        toast(`${it.name} ajouté(e) au membre sélectionné.`);
        return;
      }
      if (placing && placing.type === it.type) { stopPlacing(); return; }
      startPlacing(it.kind, it.type);
      catalogDrag = { x: ev.clientX, y: ev.clientY };
    });
    grid.append(card);
  }
  const head = el('div', { class: 'panel' },
    el('h3', {}, 'Pièces'),
    el('p', { class: 'small' }, category === 'hands' || category === 'feet'
      ? 'Sélectionne un membre puis clique une main/un pied, ou glisse-le sur l\'extrémité d\'un membre.'
      : 'Clique une pièce puis clique sur la créature (ou glisse-la directement). Maj+clic pour en poser plusieurs.'),
    cats, grid);
  wrap.append(head);
  wrap.append(el('div', { class: 'panel' },
    el('h3', {}, 'Corps'),
    el('div', { class: 'btns' },
      el('button', { onclick: () => spineOp('head') }, '＋ Vertèbre (tête)'),
      el('button', { onclick: () => spineOp('tail') }, '＋ Vertèbre (queue)')),
    el('div', { class: 'btns' },
      el('button', { onclick: () => scaleAll(1 / 1.1) }, '➖ Plus petit'),
      el('button', { onclick: () => scaleAll(1.1) }, '➕ Plus grand')),
    el('p', { class: 'small' }, 'Astuce : molette sur une vertèbre (jaune) pour la grossir, glisse-la pour sculpter le dos.')));
  return wrap;
}

let catalogDrag = null;
window.addEventListener('pointerup', (ev) => {
  if (!catalogDrag) return;
  const moved = Math.hypot(ev.clientX - catalogDrag.x, ev.clientY - catalogDrag.y) > 8;
  catalogDrag = null;
  if (!moved || !placing) return;
  if (document.elementFromPoint(ev.clientX, ev.clientY) === canvas) {
    const hit = traceEvent(ev);
    if (hit) doPlace(hit);
  }
});
window.addEventListener('pointermove', (ev) => {
  if (!catalogDrag || !placing) return;
  if (document.elementFromPoint(ev.clientX, ev.clientY) === canvas) {
    const hit = traceEvent(ev);
    viewport.setMarker(hit && hit.p, hit && hit.n);
  }
});

// ---------------------------------------------------------------- widgets
function slider(label, value, min, max, step, onInput, fmt = (v) => (+v).toFixed(2)) {
  const val = el('span', { class: 'val' }, fmt(value));
  const input = el('input', { type: 'range', min, max, step, value });
  input.addEventListener('input', () => { val.textContent = fmt(input.value); onInput(+input.value); changed({ commit: false, fast: true, inspector: false }); });
  input.addEventListener('change', () => { commit(); requestPreview(false); });
  return el('div', { class: 'row' }, el('label', {}, label), input, val);
}
function selectRow(label, options, value, onChange) {
  const s = el('select', {}, ...options.map(([v, t]) => el('option', { value: v, selected: v === value }, t)));
  s.addEventListener('change', () => { onChange(s.value); changed(); });
  return el('div', { class: 'row' }, el('label', {}, label), s);
}
function colorRow(label, value, onInput) {
  const c = el('input', { type: 'color', value });
  c.addEventListener('input', () => { onInput(c.value); changed({ commit: false, fast: true, inspector: false }); });
  c.addEventListener('change', () => { commit(); requestPreview(false); });
  return el('div', { class: 'row' }, el('label', {}, label), c);
}
function checkRow(label, value, onChange) {
  const c = el('input', { type: 'checkbox', checked: value });
  c.addEventListener('change', () => { onChange(c.checked); changed(); });
  return el('div', { class: 'row' }, el('label', {}, label), c);
}
const SLOTS = [['base', 'Peau (motif)'], ['secondary', 'Secondaire'], ['detail', 'Détail'], ['claw', 'Griffes / os'], ['custom', 'Personnalisée']];

// ---------------------------------------------------------------- inspector
function renderRight() {
  const right = $('#right');
  right.innerHTML = '';
  if (!sel) { right.append(emptyInspector()); return; }
  if (sel.type === 'spine') right.append(spineInspector());
  else if (sel.type === 'limb') right.append(limbInspector());
  else if (sel.type === 'part') right.append(partInspector());
}

function emptyInspector() {
  return el('div', {},
    el('div', { class: 'panel' },
      el('h3', {}, 'Créature'),
      slider('Fusion des formes', creature.body.blend, 0.2, 2.5, 0.05, (v) => (creature.body.blend = v)),
      el('p', { class: 'small' }, 'Plus la fusion est forte, plus les pièces se fondent en douceur dans le corps.')),
    el('div', { class: 'empty', html: `
      <b>Comment ça marche</b>
      <ul>
        <li><b>Clic</b> sur une pièce / un membre : le sélectionner.</li>
        <li><b>Glisser</b> une pièce : la déplacer sur la peau.</li>
        <li><b>Molette</b> sur une pièce, un os ou une articulation : taille.</li>
        <li><b>Clic-glisser dans le vide</b> : tourner la caméra. Clic droit : déplacer.</li>
        <li>Tout est <b>symétrique</b> automatiquement (désactivable par pièce).</li>
      </ul>
      <b>Raccourcis</b>
      <ul>
        <li><kbd>Suppr</kbd> supprimer · <kbd>D</kbd> dupliquer · <kbd>M</kbd> symétrie</li>
        <li><kbd>Ctrl</kbd>+<kbd>Z</kbd> annuler · <kbd>Ctrl</kbd>+<kbd>Y</kbd> rétablir · <kbd>Échap</kbd> annuler la pose</li>
      </ul>` }));
}

function spineInspector() {
  const i = sel.vert;
  const v = creature.spine[i];
  const n = creature.spine.length;
  return el('div', {},
    el('div', { class: 'panel' },
      el('h2', {}, i === 0 ? '🦴 Tête' : i === n - 1 ? '🦴 Bout de queue' : `🦴 Vertèbre ${i + 1}/${n}`),
      el('p', { class: 'small' }, 'Glisse la sphère jaune pour déplacer, molette pour l\'épaisseur.'),
      slider('Épaisseur', v.r, 0.03, 1.5, 0.01, (x) => (v.r = x)),
      slider('Hauteur', v.p[1], 0.05, 5, 0.01, (x) => (v.p[1] = x)),
      slider('Avant / arrière', v.p[2], -5, 5, 0.01, (x) => (v.p[2] = x)),
      el('div', { class: 'btns' },
        el('button', { onclick: () => spineOp('insert', i), disabled: i === n - 1 }, '＋ Insérer après'),
        el('button', { class: 'danger', onclick: () => spineOp('remove', i), disabled: n <= 2 }, '🗑 Retirer'))),
    el('div', { class: 'panel' },
      el('h3', {}, 'Colonne vertébrale'),
      el('div', { class: 'btns' },
        el('button', { onclick: () => spineOp('head') }, '＋ Tête'),
        el('button', { onclick: () => spineOp('tail') }, '＋ Queue')),
      slider('Fusion des formes', creature.body.blend, 0.2, 2.5, 0.05, (x) => (creature.body.blend = x))));
}

function remapAnchors(f) {
  for (const p of creature.parts) if (p.anchor.kind !== 'limb') p.anchor.u = f(p.anchor.u);
  for (const l of creature.limbs) l.anchor.u = f(l.anchor.u);
}

function spineOp(op, i) {
  const sp = creature.spine;
  const n = sp.length;
  if (op === 'head') {
    const d = norm(sub(sp[0].p, sp[1].p));
    const L = Math.max(0.2, len(sub(sp[0].p, sp[1].p)));
    sp.unshift({ p: [0, sp[0].p[1] + d[1] * L, sp[0].p[2] + d[2] * L], r: sp[0].r * 0.85 });
    remapAnchors((u) => u + 1);
    sel = { type: 'spine', vert: 0 };
  } else if (op === 'tail') {
    const d = norm(sub(sp[n - 1].p, sp[n - 2].p));
    const L = Math.max(0.2, len(sub(sp[n - 1].p, sp[n - 2].p)));
    sp.push({ p: [0, Math.max(0.05, sp[n - 1].p[1] + d[1] * L), sp[n - 1].p[2] + d[2] * L], r: Math.max(0.03, sp[n - 1].r * 0.7) });
    sel = { type: 'spine', vert: n };
  } else if (op === 'insert') {
    const p = spinePoint(sp, i + 0.5), r = spineRadius(sp, i + 0.5);
    sp.splice(i + 1, 0, { p: [0, p[1], p[2]], r });
    remapAnchors((u) => (u <= i ? u : u <= i + 1 ? i + 2 * (u - i) : u + 1));
    sel = { type: 'spine', vert: i + 1 };
  } else if (op === 'remove') {
    if (n <= 2) return;
    sp.splice(i, 1);
    remapAnchors((u) => {
      if (u <= i - 1) return u;
      if (u >= i + 1) return u - 1;
      return i === 0 ? 0 : Math.min(n - 2, i - 1 + (u - (i - 1)) / 2);
    });
    sel = null;
  }
  changed();
}

function scaleAll(s) {
  for (const v of creature.spine) { v.p = [0, v.p[1] * s, v.p[2] * s]; v.r *= s; }
  for (const l of creature.limbs) {
    l.joints = l.joints.map((j) => j.map((c) => c * s));
    l.radii = l.radii.map((r) => r * s);
    l.endScale = (l.endScale ?? 1) * s;
  }
  for (const p of creature.parts) p.scale = (p.scale || 1) * s;
  changed();
  setTimeout(() => viewport.frame(), 300);
}

function paramSliders(def, params) {
  return (def.paramDefs || []).map(([key, label, min, max, step]) =>
    slider(label, params[key] ?? def.params[key], min, max, step || 0.01, (v) => (params[key] = v)));
}

function limbInspector() {
  const limb = creature.limbs.find((l) => l.id === sel.id);
  if (!limb) return el('div');
  const def = LIMBS[limb.kind];
  const j = sel.joint;
  const ends = [['none', '— Aucune —'], ...Object.entries(PARTS).filter(([, d]) => d.end).map(([k, d]) => [k, `${d.icon} ${d.name}`])];
  const endDef = PARTS[limb.end];
  limb.endParams = limb.endParams || {};
  const box = el('div', {},
    el('div', { class: 'panel' },
      el('h2', {}, `${def.icon} ${def.name}`),
      el('p', { class: 'small' }, 'Glisse les sphères vertes (articulations) ; la violette déplace l\'attache sur le corps.'),
      slider('Épaisseur', limb.thick ?? 1, 0.3, 3, 0.01, (v) => (limb.thick = v)),
      j !== null && j !== undefined ? slider(`Rayon articulation ${j + 1}`, limb.radii[j], 0.01, 0.6, 0.005, (v) => (limb.radii[j] = v)) : null,
      el('div', { class: 'row' }, el('label', {}, 'Articulations'),
        el('button', { onclick: () => limbJointOp(limb, -1), disabled: limb.joints.length <= 2 }, '−'),
        el('span', {}, String(limb.joints.length)),
        el('button', { onclick: () => limbJointOp(limb, 1), disabled: limb.joints.length >= 10 }, '＋')),
      checkRow('Symétrique', limb.mirror !== false, (v) => (limb.mirror = v)),
      selectRow('Couleur', SLOTS, limb.slot || 'base', (v) => (limb.slot = v)),
      limb.slot === 'custom' ? colorRow('Teinte', limb.color || '#ffffff', (v) => (limb.color = v)) : null),
    el('div', { class: 'panel' },
      el('h3', {}, 'Extrémité (main / pied)'),
      selectRow('Type', ends, limb.end || 'none', (v) => (limb.end = v)),
      endDef ? slider('Taille', limb.endScale ?? 1, 0.3, 3, 0.01, (v) => (limb.endScale = v)) : null,
      endDef ? slider('Rotation', (limb.endRot || [0, 0, 0])[1], -180, 180, 1, (v) => { limb.endRot = limb.endRot || [0, 0, 0]; limb.endRot[1] = v; }, (v) => `${Math.round(v)}°`) : null,
      endDef ? slider('Inclinaison', (limb.endRot || [0, 0, 0])[0], -90, 90, 1, (v) => { limb.endRot = limb.endRot || [0, 0, 0]; limb.endRot[0] = v; }, (v) => `${Math.round(v)}°`) : null,
      ...(endDef ? paramSliders(endDef, limb.endParams) : []),
      endDef ? selectRow('Couleur', [['', 'Par défaut'], ...SLOTS], limb.endSlot || '', (v) => (limb.endSlot = v || null)) : null,
      endDef && limb.endSlot === 'custom' ? colorRow('Teinte', limb.endColor || '#ffffff', (v) => (limb.endColor = v)) : null),
    el('div', { class: 'panel btns' },
      el('button', { onclick: () => duplicate() }, '⧉ Dupliquer'),
      el('button', { class: 'danger', onclick: () => removeSel() }, '🗑 Supprimer')));
  return box;
}

function limbJointOp(limb, d) {
  if (d > 0) {
    const J = limb.joints, n = J.length;
    const dir = sub(J[n - 1], J[n - 2]);
    J.push([J[n - 1][0] + dir[0] * 0.8, Math.max(0.02 - limbRoot(creature, limb)[1], J[n - 1][1] + dir[1] * 0.8), J[n - 1][2] + dir[2] * 0.8]);
    limb.radii.push(limb.radii[n - 1] * 0.85);
  } else if (limb.joints.length > 2) {
    limb.joints.pop();
    limb.radii.pop();
  }
  changed();
}

function partInspector() {
  const part = creature.parts.find((p) => p.id === sel.id);
  if (!part) return el('div');
  const def = PARTS[part.type];
  part.params = part.params || {};
  part.rot = part.rot || [0, 0, 0];
  const deg = (v) => `${Math.round(v)}°`;
  return el('div', {},
    el('div', { class: 'panel' },
      el('h2', {}, `${def.icon} ${def.name}`),
      el('p', { class: 'small' }, 'Glisse la pièce sur la créature pour la déplacer. Molette : taille.'),
      slider('Taille', part.scale || 1, 0.15, 5, 0.01, (v) => (part.scale = v)),
      slider('Enfoncement', part.lift || 0, -0.3, 0.3, 0.005, (v) => (part.lift = v)),
      slider('Rotation X', part.rot[0], -180, 180, 1, (v) => (part.rot[0] = v), deg),
      slider('Rotation Y', part.rot[1], -180, 180, 1, (v) => (part.rot[1] = v), deg),
      slider('Rotation Z', part.rot[2], -180, 180, 1, (v) => (part.rot[2] = v), deg),
      ...paramSliders(def, part.params),
      checkRow('Symétrique', part.mirror !== false, (v) => (part.mirror = v)),
      selectRow('Couleur', [['', 'Par défaut'], ...SLOTS], part.slot || '', (v) => (part.slot = v || null)),
      part.slot === 'custom' ? colorRow('Teinte', part.color || '#ffffff', (v) => (part.color = v)) : null),
    el('div', { class: 'panel btns' },
      el('button', { onclick: () => { part.rot = [0, 0, 0]; part.lift = 0; changed(); } }, '↺ Réinitialiser'),
      el('button', { onclick: () => duplicate() }, '⧉ Dupliquer'),
      el('button', { class: 'danger', onclick: () => removeSel() }, '🗑 Supprimer')));
}

function duplicate() {
  if (!sel) return;
  if (sel.type === 'part') {
    const p = creature.parts.find((q) => q.id === sel.id);
    const c = JSON.parse(JSON.stringify(p));
    c.id = uid('p');
    const maxU = c.anchor.kind === 'limb' ? (creature.limbs.find((l) => l.id === c.anchor.id)?.joints.length ?? 2) - 1 : creature.spine.length - 1;
    c.anchor.u = Math.min(maxU, c.anchor.u + 0.35);
    if (c.anchor.u === p.anchor.u) c.anchor.u = Math.max(0, c.anchor.u - 0.35);
    creature.parts.push(c);
    sel = { type: 'part', id: c.id };
  } else if (sel.type === 'limb') {
    const l = creature.limbs.find((q) => q.id === sel.id);
    const c = JSON.parse(JSON.stringify(l));
    c.id = uid('l');
    c.anchor.u = Math.min(creature.spine.length - 1, c.anchor.u + 0.6);
    if (c.anchor.u === l.anchor.u) c.anchor.u = Math.max(0, c.anchor.u - 0.6);
    creature.limbs.push(c);
    sel = { type: 'limb', id: c.id, joint: null };
  } else return;
  changed();
}

function removeSel() {
  if (!sel) return;
  if (sel.type === 'part') creature.parts = creature.parts.filter((p) => p.id !== sel.id);
  else if (sel.type === 'limb') {
    creature.limbs = creature.limbs.filter((l) => l.id !== sel.id);
    creature.parts = creature.parts.filter((p) => !(p.anchor.kind === 'limb' && p.anchor.id === sel.id));
  } else if (sel.type === 'spine') { spineOp('remove', sel.vert); return; }
  sel = null;
  changed();
}

function toggleMirror() {
  if (!sel || sel.type === 'spine') return;
  const o = sel.type === 'part' ? creature.parts.find((p) => p.id === sel.id) : creature.limbs.find((l) => l.id === sel.id);
  o.mirror = o.mirror === false;
  changed();
  toast(o.mirror ? 'Symétrie activée' : 'Symétrie désactivée');
}

// ---------------------------------------------------------------- paint
function paintPanel() {
  const P = creature.paint;
  const set = (k) => (v) => (P[k] = v);
  const colorCell = (label, key) => {
    const c = el('input', { type: 'color', value: P[key] });
    c.addEventListener('input', () => { P[key] = c.value; changed({ commit: false, fast: true, inspector: false }); });
    c.addEventListener('change', () => { commit(); requestPreview(false); });
    return el('label', {}, c, label);
  };
  const pats = el('div', { class: 'patterns' }, ...PATTERNS.map(([k, name]) =>
    el('button', { class: P.pattern === k ? 'active' : '', onclick: () => { P.pattern = k; changed(); renderLeft(); } }, name)));
  const sw = el('div', { class: 'swatches' }, ...PALETTES.map((pal) =>
    el('button', { class: 'swatch', title: 'Appliquer cette palette', onclick: () => { Object.assign(P, pal); changed(); renderLeft(); } },
      el('span', { style: `background:${pal.base}` }), el('span', { style: `background:${pal.secondary}` }), el('span', { style: `background:${pal.detail}` }))));
  return el('div', {},
    el('div', { class: 'panel' }, el('h3', {}, 'Palettes'), sw,
      el('div', { class: 'btns' }, el('button', { onclick: () => { Object.assign(P, randomPaint(Math.random)); changed(); renderLeft(); } }, '🎲 Peinture aléatoire'))),
    el('div', { class: 'panel' }, el('h3', {}, 'Couleurs'),
      el('div', { class: 'colors' },
        colorCell('Principale', 'base'), colorCell('Secondaire', 'secondary'),
        colorCell('Détail', 'detail'), colorCell('Griffes / os', 'claw'),
        colorCell('Ventre', 'bellyColor'), colorCell('Yeux', 'eye')),
      slider('Ventre clair', P.bellyAmount, 0, 1, 0.01, set('bellyAmount'))),
    el('div', { class: 'panel' }, el('h3', {}, 'Motif'), pats,
      slider('Taille du motif', P.patternScale, 0.05, 0.8, 0.005, set('patternScale')),
      slider('Intensité', P.patternAmount, 0, 1, 0.01, set('patternAmount')),
      slider('Grain de peau', P.texture ?? 0.5, 0, 2, 0.01, set('texture')),
      el('div', { class: 'btns' }, el('button', { onclick: () => { P.seed = Math.floor(Math.random() * 1000); changed(); } }, '🔀 Varier le motif'))),
    el('div', { class: 'panel' }, el('p', { class: 'small' }, 'Astuce : clique une pièce pour changer sa couleur (Principale, Secondaire, Détail, Griffes, ou une teinte personnalisée) dans le panneau de droite.')));
}

// ---------------------------------------------------------------- test
function animInfo(bones) {
  const info = [];
  const rootB = bones.find((b) => b.parent < 0);
  const rootIdx = rootB ? rootB.index : 0;
  const legIds = creature.limbs.filter((l) => l.kind === 'leg' || l.kind === 'leg_digi' || l.kind === 'leg_insect').sort((a, b) => a.anchor.u - b.anchor.u).map((l) => l.id);
  bones.forEach((b, i) => {
    if (b.kind === 'spine') {
      if (b.index === rootIdx) info[i] = { role: 'root' };
      else if (b.index < rootIdx) info[i] = { role: 'neck', depth: rootIdx - b.index };
      else info[i] = { role: 'tail', depth: b.index - rootIdx };
      return;
    }
    const limb = creature.limbs.find((l) => l.id === b.limb);
    if (!limb || b.end) return;
    const roleOf = { leg: 'leg', leg_digi: 'leg', arm: 'arm', leg_insect: 'insect', tentacle: 'tentacle', wing_arm: 'wing', neck: 'stalk' };
    const pairIdx = Math.max(0, legIds.indexOf(limb.id));
    const side = b.mirror ? -1 : 1;
    const phase = (pairIdx % 2) * Math.PI + (b.mirror ? Math.PI : 0);
    info[i] = { role: roleOf[limb.kind] || 'leg', seg: b.seg, side, phase, bend: limb.kind === 'leg_digi' ? -1 : 1 };
  });
  return info;
}

function startTest() {
  if (!lastMesh || !lastMesh.data.joints) return;
  viewport.startTest(lastMesh.data, lastMesh.bones, animInfo(lastMesh.bones), testMode);
}

function testPanel() {
  const modes = [['walk', '🚶 Marche'], ['run', '🏃 Course'], ['idle', '😌 Repos'], ['dance', '💃 Danse']];
  const nb = build ? build.bones.length : 0;
  return el('div', {},
    el('div', { class: 'panel' },
      el('h3', {}, 'Animation de test'),
      el('div', { class: 'patterns' }, ...modes.map(([k, t]) => el('button', { class: testMode === k ? 'active' : '', onclick: () => { testMode = k; if (viewport.test) viewport.test.mode = k; renderLeft(); } }, t))),
      el('div', { class: 'row' }, el('label', {}, 'Vitesse'), (() => {
        const i = el('input', { type: 'range', min: 0.2, max: 2, step: 0.05, value: viewport.test ? viewport.test.speed : 1 });
        i.addEventListener('input', () => { if (viewport.test) viewport.test.speed = +i.value; });
        return i;
      })())),
    el('div', { class: 'panel' },
      el('h3', {}, 'Squelette'),
      el('p', { class: 'small', html: `Ta créature a <b>${nb} os</b>. Ce squelette et les poids de peau sont exportés dans le fichier <b>.glb</b> : dans Roblox tu obtiens un MeshPart avec des <b>Bones</b>, animables avec l'éditeur d'animation.` }),
      el('p', { class: 'small' }, 'Cette animation sert juste à vérifier que la peau suit bien les os ; elle n\'est pas exportée.')));
}

// ================================================================ modes, hints
function setMode(m) {
  if (m === mode) return;
  if (placing) stopPlacing();
  mode = m;
  document.querySelectorAll('#modes button').forEach((b) => b.classList.toggle('active', b.dataset.mode === m));
  if (m === 'test') startTest(); else viewport.stopTest();
  updateHandles();
  renderLeft();
  renderRight();
  updateHint();
}

function updateHint() {
  const h = $('#hint');
  let t;
  if (placing) {
    const name = placing.kind === 'limb' ? LIMBS[placing.type].name : PARTS[placing.type].name;
    t = `Clique sur la créature pour poser : <b>${name}</b> · <kbd>Échap</kbd> pour annuler`;
  } else if (mode === 'paint') t = 'Choisis couleurs et motif à gauche · clique une pièce pour changer sa couleur';
  else if (mode === 'test') t = 'Aperçu animé du squelette qui sera exporté · fais tourner la caméra librement';
  else if (sel && sel.type === 'spine') t = '<b>Glisse</b> la vertèbre pour sculpter · <b>molette</b> dessus pour l\'épaisseur';
  else if (sel && sel.type === 'limb') t = '<b>Glisse</b> les articulations · <b>molette</b> dessus pour leur épaisseur';
  else if (sel && sel.type === 'part') t = '<b>Glisse</b> la pièce sur la peau · <b>molette</b> pour la taille · <kbd>Suppr</kbd> pour l\'enlever';
  else t = 'Choisis une pièce à gauche et pose-la sur la créature · glisse les sphères jaunes pour modeler le corps';
  h.innerHTML = t;
}

// ================================================================ modals
function openModal(content) {
  const card = $('#modal-card');
  card.innerHTML = '';
  card.append(el('button', { class: 'close', onclick: closeModal }, '✕'), content);
  $('#modal').classList.remove('hidden');
}
function closeModal() {
  $('#modal').classList.add('hidden');
  if (exportJob) exportJob.cancelled = true;
}
$('#modal').addEventListener('pointerdown', (e) => { if (e.target.id === 'modal') closeModal(); });

function newModal() {
  const blank = () => loadCreature({ name: 'Ma créature', spine: [{ p: [0, 1.3, -0.9], r: 0.32 }, { p: [0, 1.2, -0.4], r: 0.22 }, { p: [0, 1.15, 0.2], r: 0.45 }, { p: [0, 1.2, 0.8], r: 0.3 }, { p: [0, 1.3, 1.3], r: 0.1 }], limbs: [], parts: [], paint: defaultPaint() });
  openModal(el('div', {},
    el('h2', {}, 'Nouvelle créature'),
    el('p', { class: 'small' }, 'Pars d\'un modèle puis modifie-le librement (la créature actuelle reste dans l\'historique : Ctrl+Z).'),
    el('div', { class: 'templates' },
      ...Object.entries(PRESETS).map(([k, p]) => el('button', { onclick: () => { closeModal(); pushAndLoad(buildPreset(k)); } }, el('span', { class: 'ic' }, p.icon), p.name)),
      el('button', { onclick: () => { closeModal(); pushAndLoad(null, blank); } }, el('span', { class: 'ic' }, '🥚'), 'Corps vierge'))));
}

function pushAndLoad(c, fn) {
  const prev = lastSaved;
  if (fn) fn(); else loadCreature(c, false);
  history.push(prev);
  future = [];
  updateUndo();
}

// ---------------------------------------------------------------- export
function exportModal() {
  const opts = { height: +(store.get('cc.height') || 6), budget: +(store.get('cc.budget') || 12000), texSize: +(store.get('cc.tex') || 1024), rig: store.get('cc.rig') !== '0' };
  const nameIn = el('input', { value: safeName(creature.name) });
  const heightIn = el('input', { type: 'number', min: 0.5, max: 200, step: 0.5, value: opts.height });
  const budgetVal = el('span', { class: 'val' }, String(opts.budget));
  const budgetIn = el('input', { type: 'range', min: 1000, max: 20000, step: 500, value: opts.budget });
  budgetIn.addEventListener('input', () => (budgetVal.textContent = budgetIn.value));
  const texIn = el('select', {}, el('option', { value: 512, selected: opts.texSize === 512 }, '512 × 512 (léger)'), el('option', { value: 1024, selected: opts.texSize === 1024 }, '1024 × 1024 (net)'));
  const rigIn = el('input', { type: 'checkbox', checked: opts.rig });
  const bar = el('div', {});
  const progressText = el('div', { class: 'small' });
  const progress = el('div', { class: 'progress hidden' }, bar);
  const result = el('div');
  const go = el('button', { class: 'primary' }, '⚙️ Générer le modèle');
  go.addEventListener('click', () => {
    const o = { height: Math.max(0.5, +heightIn.value || 6), budget: +budgetIn.value, texSize: +texIn.value, rig: rigIn.checked };
    store.set('cc.height', o.height); store.set('cc.budget', o.budget); store.set('cc.tex', o.texSize); store.set('cc.rig', o.rig ? '1' : '0');
    go.disabled = true;
    result.innerHTML = '';
    progress.classList.remove('hidden');
    runExport(o, safeName(nameIn.value), {
      progress: (label, f) => { bar.style.width = `${Math.round(f * 100)}%`; progressText.textContent = label; },
      done: (files, rep) => {
        go.disabled = false;
        bar.style.width = '100%';
        progressText.textContent = 'Terminé ✔';
        result.append(files, rep);
      },
      fail: (msg) => { go.disabled = false; progressText.textContent = 'Erreur : ' + msg.split('\n')[0]; },
    });
  });
  openModal(el('div', {},
    el('h2', {}, '⬇️ Exporter pour Roblox'),
    el('p', { class: 'small' }, 'Le modèle est reconstruit en un seul maillage fermé (aucun trou, aucune face interne), avec une texture peinte et, si tu veux, un squelette.'),
    el('div', { class: 'row' }, el('label', {}, 'Nom'), nameIn),
    el('div', { class: 'row' }, el('label', {}, 'Hauteur (studs)'), heightIn),
    el('div', { class: 'row' }, el('label', {}, 'Triangles max'), budgetIn, budgetVal),
    el('p', { class: 'small' }, 'Roblox accepte jusqu\'à 20 000 triangles par MeshPart. 8 000 – 12 000 est un bon compromis beauté / performances.'),
    el('div', { class: 'row' }, el('label', {}, 'Texture'), texIn),
    el('div', { class: 'row' }, el('label', {}, 'Squelette (os)'), rigIn, el('span', { class: 'small' }, 'pour animer la créature')),
    el('div', { class: 'btns' }, go),
    progress, progressText, result,
    el('h3', {}, 'Importer dans Roblox Studio'),
    el('ol', { class: 'steps', html: `
      <li>Onglet <b>Accueil</b> (ou Avatar) → <b>Importer 3D</b>, puis choisis le fichier <b>.glb</b>.</li>
      <li>Dans les réglages d'import : <b>File Geometry → Scale Unit : Stud</b> (le modèle est déjà à la bonne taille en studs).</li>
      <li>Laisse la texture activée (elle est intégrée au .glb). Clique <b>Import</b>.</li>
      <li>Avec squelette : le modèle arrive avec ses <b>Bones</b> ; ajoute un <b>AnimationController</b> + <b>Animator</b> (ou utilise l'éditeur d'animation) pour l'animer.</li>
      <li>Sans squelette : c'est un <b>MeshPart</b> classique, pense à l'ancrer (<b>Anchored</b>) si c'est un décor.</li>
      <li>Format <b>OBJ</b> (zip) : dézippe et importe le .obj, la texture .png est à côté.</li>`
    })));
}

function runExport(o, name, ui) {
  const b = buildCreature(creature);
  const id = ++reqId;
  exportJob = {
    id,
    progress: ui.progress,
    done: async (m) => {
      const job = exportJob;
      exportJob = null;
      if (job.cancelled) return;
      try {
        const png = await rgbaToPng(m.tex.rgba, m.tex.size);
        const res = { mesh: m.mesh, tex: m.tex };
        const prep = prepareExport(res, b.bones, { height: o.height });
        const glb = makeGLB(prep, name, png, o.rig);
        const zip = makeOBJZip(prep, name, png);
        const ch = m.mesh.check;
        const texUrl = URL.createObjectURL(new Blob([png], { type: 'image/png' }));
        const files = el('div', { class: 'btns' },
          el('button', { class: 'primary', onclick: () => download(glb, `${name}.glb`, 'model/gltf-binary') }, `⬇️ ${name}.glb ${o.rig ? '(avec squelette)' : '(statique)'} · ${(glb.length / 1048576).toFixed(1)} Mo`),
          el('button', { onclick: () => download(zip, `${name}_obj.zip`, 'application/zip') }, `⬇️ OBJ + texture (.zip)`),
          el('button', { onclick: () => download(png, `${name}_texture.png`, 'image/png') }, '🖼 Texture seule'));
        const sz = prep.X.size.map((v) => v.toFixed(1)).join(' × ');
        const watertight = ch.boundary === 0;
        const rep = el('div', { class: 'report', html: `
          <div>Triangles</div><div><b>${ch.triangles.toLocaleString('fr-FR')}</b> / ${o.budget.toLocaleString('fr-FR')}</div>
          <div>Trous (bords ouverts)</div><div class="${watertight ? 'ok' : 'warn'}">${watertight ? '0 — maillage fermé ✔' : ch.boundary + ' ⚠'}</div>
          <div>Arêtes non-manifold</div><div class="${ch.nonManifold ? 'warn' : 'ok'}">${ch.nonManifold ? ch.nonManifold + ' (sans trou, invisible)' : '0 ✔'}</div>
          <div>Taille (L × H × P)</div><div>${sz} studs</div>
          <div>Os</div><div>${o.rig ? b.bones.length : '—'}</div>
          <div>Texture</div><div><img class="tex-preview" src="${texUrl}" alt="texture" /></div>` });
        ui.done(files, rep);
      } catch (err) {
        console.error(err);
        ui.fail(String(err));
      }
    },
    fail: (msg) => { exportJob = null; ui.fail(msg); },
  };
  worker.postMessage({ type: 'export', id, prims: b.prims, paint: resolvePaint(creature.paint, b), opts: { budget: o.budget, texSize: o.texSize, aoScale: aoScale() } });
}

function rgbaToPng(rgba, size) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  c.getContext('2d').putImageData(new ImageData(new Uint8ClampedArray(rgba), size, size), 0, 0);
  return new Promise((res, rej) => c.toBlob((b) => (b ? b.arrayBuffer().then((a) => res(new Uint8Array(a))) : rej(new Error('PNG'))), 'image/png'));
}

function download(bytes, filename, type) {
  const url = URL.createObjectURL(new Blob([bytes], { type }));
  const a = el('a', { href: url, download: filename });
  document.body.append(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 30000);
}

// ---------------------------------------------------------------- gallery
function readGallery() {
  try { return JSON.parse(store.get('cc.gallery') || '[]'); } catch { return []; }
}
function galleryModal() {
  const list = readGallery();
  const grid = el('div', { class: 'gallery' });
  const render = () => {
    grid.innerHTML = '';
    const items = readGallery();
    if (!items.length) grid.append(el('p', { class: 'small' }, 'Ta collection est vide.'));
    for (const it of items) {
      grid.append(el('div', { class: 'item' },
        el('img', { src: it.thumb, alt: it.name, title: 'Ouvrir', onclick: () => { closeModal(); pushAndLoad(JSON.parse(it.data)); } }),
        el('div', { class: 'meta' }, el('span', {}, it.name),
          el('button', { title: 'Supprimer', onclick: () => { store.set('cc.gallery', JSON.stringify(readGallery().filter((x) => x.id !== it.id))); render(); } }, '🗑'))));
    }
  };
  render();
  void list;
  openModal(el('div', {},
    el('h2', {}, '📚 Ma collection'),
    el('p', { class: 'small' }, 'Sauvegardée dans ce navigateur. Utilise « Fichier .json » pour garder une copie ou la partager.'),
    el('div', { class: 'btns' },
      el('button', { class: 'primary', onclick: () => {
        const items = readGallery();
        items.unshift({ id: uid('g'), name: creature.name, thumb: viewport.snapshot(200), data: snapshot(), date: Date.now() });
        if (!store.set('cc.gallery', JSON.stringify(items.slice(0, 60)))) toast('Stockage du navigateur plein ou indisponible.', true);
        render();
      } }, '💾 Ajouter la créature actuelle'),
      el('button', { onclick: () => download(new TextEncoder().encode(snapshot()), `${safeName(creature.name)}.json`, 'application/json') }, '⬇️ Fichier .json'),
      el('button', { onclick: () => $('#file-input').click() }, '📂 Ouvrir un .json')),
    grid));
}

$('#file-input').addEventListener('change', async (e) => {
  const f = e.target.files[0];
  e.target.value = '';
  if (!f) return;
  try {
    const c = JSON.parse(await f.text());
    closeModal();
    pushAndLoad(c);
    toast(`« ${creature.name} » chargée.`);
  } catch (err) {
    toast('Impossible de lire ce fichier : ' + err.message, true);
  }
});

// ---------------------------------------------------------------- toasts
function toast(msg, err = false) {
  const t = el('div', { class: 'toast' + (err ? ' err' : '') }, msg);
  $('#toasts').append(t);
  setTimeout(() => t.remove(), 3500);
}

// ================================================================ wiring
document.querySelectorAll('#modes button').forEach((b) => b.addEventListener('click', () => setMode(b.dataset.mode)));
document.querySelectorAll('.viewbar [data-view]').forEach((b) => b.addEventListener('click', () => viewport.view(b.dataset.view)));
$('#toggle-handles').addEventListener('click', (e) => {
  viewport.showHandles = !viewport.showHandles;
  viewport.handles.visible = viewport.showHandles && !viewport.test;
  e.currentTarget.classList.toggle('on', viewport.showHandles);
});
$('#btn-new').addEventListener('click', newModal);
$('#btn-random').addEventListener('click', () => { pushAndLoad(randomCreature()); });
$('#btn-undo').addEventListener('click', undo);
$('#btn-redo').addEventListener('click', redo);
$('#btn-gallery').addEventListener('click', galleryModal);
$('#btn-export').addEventListener('click', exportModal);
$('#name').addEventListener('input', (e) => { creature.name = e.target.value || 'Ma créature'; });
$('#name').addEventListener('change', () => commit());

window.addEventListener('keydown', (e) => {
  if (e.target.matches('input, select, textarea')) return;
  const k = e.key.toLowerCase();
  if ((e.ctrlKey || e.metaKey) && k === 'z' && !e.shiftKey) { e.preventDefault(); undo(); }
  else if ((e.ctrlKey || e.metaKey) && (k === 'y' || (k === 'z' && e.shiftKey))) { e.preventDefault(); redo(); }
  else if (k === 'escape') { if (!$('#modal').classList.contains('hidden')) closeModal(); else if (placing) stopPlacing(); else { sel = null; changed({ commit: false }); } }
  else if ((k === 'delete' || k === 'backspace') && sel && mode === 'build') { e.preventDefault(); removeSel(); }
  else if (k === 'd' && !e.ctrlKey && !e.metaKey && sel && mode === 'build') duplicate();
  else if (k === 'm' && sel && mode === 'build') toggleMirror();
});

// ================================================================ boot
let initial = null;
try {
  const saved = store.get('cc.current');
  if (saved) initial = normalizeCreature(JSON.parse(saved));
} catch { initial = null; }
loadCreature(initial || buildPreset('quadruped'));
renderLeft();

// debug / automation hook
window.creatureApp = { get creature() { return creature; }, loadCreature, buildPreset, setMode, resolveAttachment };
