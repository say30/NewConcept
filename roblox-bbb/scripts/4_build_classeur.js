#!/usr/bin/env node
// Etape 4 — genere le classeur HTML : un index classe + une fiche detaillee par jeu
// (liens cliquables BuiltByBit et Roblox, vignettes Roblox, sous-scores, idees de variantes).
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const num = n => (n == null ? '—' : Number(n).toLocaleString('fr-FR'));

const TOP = parseInt(process.env.TOP || '20', 10);

function fiche(g) {
  const vars = g.roblox.slice(0, 6).map(v => `
    <a class="var" href="${esc(v.url || '#')}" target="_blank" rel="noopener">
      ${v.icon ? `<img src="${esc(v.icon)}" alt="" loading="lazy">` : '<div class="ph"></div>'}
      <div class="vmeta">
        <strong>${esc(v.name)}</strong>
        <span>par ${esc(v.creator || '?')}</span>
        <span>${num(v.visits)} visites · ${num(v.playing)} en ligne · ${v.likeRatio != null ? Math.round(v.likeRatio * 100) + '% likes' : '—'}</span>
        <span class="sim">proximite titre ${Math.round(v.similarity * 100)}%</span>
      </div>
    </a>`).join('');

  const barres = Object.entries(g.detailScores).map(([k, v]) =>
    `<li><span>${esc(k.replace(/_/g, ' '))}</span><b>${(+v).toFixed(1)}</b></li>`).join('');

  return `
  <section class="fiche" id="jeu-${g.rang}">
    <header>
      <div class="rang">#${g.rang}</div>
      <div>
        <h2><a href="${esc(g.url)}" target="_blank" rel="noopener">${esc(g.titre)}</a></h2>
        <p class="tag">${esc(g.tagline)}</p>
        <p class="meta">${g.prix ? esc(g.prix) + ' ' + esc(g.devise) : 'gratuit'} · auteur ${esc(g.auteur)} ·
           ${num(g.stats.purchases)} ventes · ${g.stats.reviews} avis · ${g.stats.words} mots de description ·
           ${g.stats.media} medias · ${g.stats.changelog} mises a jour</p>
      </div>
      <div class="score"><b>${g.score}</b><span>/100</span></div>
    </header>

    <div class="grid">
      <div class="col">
        <h3>Detail des points</h3>
        <p class="blocs">Annonce ${g.blocs.qualite} · Traction ${g.blocs.traction} · Marche ${g.blocs.marche}</p>
        <ul class="barres">${barres}</ul>
        <h3>Genres detectes</h3>
        <p>${g.genres.length ? g.genres.map(x => `<code>${esc(x)}</code>`).join(' ') : '<em>non identifie</em>'}</p>
      </div>
      <div class="col">
        <h3>Description (extrait)</h3>
        <p class="desc">${esc(g.description.slice(0, 1200))}${g.description.length > 1200 ? '…' : ''}</p>
      </div>
    </div>

    <h3>Equivalents et variantes sur Roblox <small>(${g.variantesSolides} concurrent(s) credible(s))</small></h3>
    <div class="vars">${vars || '<em>aucun equivalent trouve — genre potentiellement libre</em>'}</div>

    ${g.variantesSolides <= 3 ? `<h3>Variantes a developper si tu l achetes</h3>
    <ul class="idees">${g.ideesVariantes.map(i => `<li>${esc(i)}</li>`).join('')}</ul>` : ''}
  </section>`;
}

const data = readData('classement.json');
const top = data.slice(0, TOP);

const html = `<title>Classeur Roblox BuiltByBit</title>
<style>
:root{--bg:#faf9f7;--card:#fff;--ink:#1c1c1a;--mut:#6b6b66;--line:#e5e3de;--acc:#c25a2b}
:root:not([data-theme="light"]){}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#16161a;--card:#1e1e23;--ink:#ece9e4;--mut:#9c9a94;--line:#33333a;--acc:#e8825a}}
:root[data-theme="dark"]{--bg:#16161a;--card:#1e1e23;--ink:#ece9e4;--mut:#9c9a94;--line:#33333a;--acc:#e8825a}
body{background:var(--bg);color:var(--ink);font:15px/1.55 ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;margin:0}
.wrap{max-width:1080px;margin:0 auto;padding:32px 20px 80px}
h1{font-size:28px;margin:0 0 4px}.sub{color:var(--mut);margin:0 0 28px}
table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:8px 10px;border-bottom:1px solid var(--line)}
th{color:var(--mut);font-weight:600}
.tblwrap{overflow-x:auto;background:var(--card);border:1px solid var(--line);border-radius:12px;padding:6px 4px;margin-bottom:40px}
a{color:var(--acc)}
.fiche{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:20px;margin-bottom:22px}
.fiche header{display:flex;gap:16px;align-items:flex-start}
.rang{font-size:22px;font-weight:700;color:var(--mut);min-width:48px}
.fiche h2{font-size:19px;margin:0 0 4px}.tag{margin:0;color:var(--mut)}
.meta{margin:6px 0 0;color:var(--mut);font-size:13px}
.score{margin-left:auto;text-align:right}.score b{font-size:26px;color:var(--acc)}.score span{color:var(--mut);font-size:13px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:24px;margin:18px 0}
@media(max-width:720px){.grid{grid-template-columns:1fr}}
h3{font-size:14px;text-transform:uppercase;letter-spacing:.04em;color:var(--mut);margin:18px 0 8px}
.barres{list-style:none;padding:0;margin:0;font-size:13px}
.barres li{display:flex;justify-content:space-between;border-bottom:1px dotted var(--line);padding:3px 0}
.desc{font-size:13px;color:var(--mut);margin:0}
.vars{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px}
.var{display:flex;gap:10px;text-decoration:none;color:inherit;border:1px solid var(--line);border-radius:10px;padding:8px}
.var img,.ph{width:64px;height:64px;border-radius:8px;object-fit:cover;background:var(--line);flex:none}
.vmeta{display:flex;flex-direction:column;font-size:12px;color:var(--mut);min-width:0}
.vmeta strong{color:var(--ink);font-size:13px}
.sim{color:var(--acc)}
.idees{font-size:14px}code{background:var(--line);padding:1px 6px;border-radius:5px;font-size:12px}
.blocs{font-size:13px;color:var(--mut);margin:0 0 8px}
</style>
<div class="wrap">
<h1>Classeur — jeux Roblox en vente sur BuiltByBit</h1>
<p class="sub">${data.length} annonces analysees · top ${top.length} classe par richesse de l annonce, traction commerciale et potentiel marche Roblox. Genere le ${new Date().toLocaleDateString('fr-FR')}.</p>
<div class="tblwrap"><table>
<thead><tr><th>#</th><th>Jeu</th><th>Prix</th><th>Score</th><th>Annonce</th><th>Traction</th><th>Marche</th><th>Concurrents Roblox</th></tr></thead>
<tbody>${top.map(g => `<tr>
<td>${g.rang}</td><td><a href="#jeu-${g.rang}">${esc(g.titre)}</a></td>
<td>${g.prix ? esc(g.prix) + ' ' + esc(g.devise) : 'gratuit'}</td><td><b>${g.score}</b></td>
<td>${g.blocs.qualite}</td><td>${g.blocs.traction}</td><td>${g.blocs.marche}</td><td>${g.variantesSolides}</td></tr>`).join('')}
</tbody></table></div>
${top.map(fiche).join('')}
</div>`;

const out = path.join(ROOT, 'classeur.html');
fs.writeFileSync(out, html);
console.log(`> ${out} ecrit (${top.length} fiches)`);
