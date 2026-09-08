#!/usr/bin/env node
// Etape 6 — page d'analyse d'un genre : recensement complet des derives sur Roblox,
// etat de sante du genre, et creneaux verifies comme libres.
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));
const num = n => (n == null ? '—' : Number(n).toLocaleString('fr-FR'));
const compact = n => n == null ? '—' : n >= 1e9 ? (n/1e9).toFixed(2).replace('.',',') + ' Md' : n >= 1e6 ? Math.round(n/1e6) + ' M' : n >= 1e3 ? Math.round(n/1e3) + ' k' : String(n);

const jeux = readData('derives.json');
let ICONS = {}; try { ICONS = readData('derives_icons.json'); } catch (_) {}

const total = jeux.reduce((a, b) => a + (b.visites || 0), 0);
const vivants = jeux.filter(g => (g.enLigne || 0) >= 500);
const morts = jeux.filter(g => (g.enLigne || 0) < 50);
const partN1 = Math.round(jeux[0].visites / total * 100);
const chefs = [...jeux].sort((a, b) => (b.enLigne || 0) - (a.enLigne || 0)).slice(0, 12);

// Courbe des creations : elle dit si la vague monte encore ou retombe.
const parMois = {};
for (const g of jeux) { const m = (g.cree || '').slice(0, 7); if (m) parMois[m] = (parMois[m] || 0) + 1; }
const mois = Object.entries(parMois).sort().slice(-12);
const maxMois = Math.max(...mois.map(([, n]) => n));

// Creneaux verifies un par un par recherche sur Roblox.
const THEMES = [
  ['Volcan / lave', 'aucun', 'facile', 'La fuite devant une catastrophe est deja prouvee : « Motorcycle Tsunami Escape » pese 104 M de visites. Le volcan reprend le meme ressort, personne ne l\'a pris.'],
  ['Ballon de baudruche', 'aucun', 'facile', 'Le bruit de ballon qui eclate est du pur ASMR, exactement ce que le genre vend. Reskin des touches, rien d\'autre a coder.'],
  ['Pizza', 'aucun', 'facile', 'Les themes gourmands ecrasent le genre : bonbon 5,69 Md, miel 79 M, beurre 37 M, gelee 20 M. La pizza est le grand absent.'],
  ['Salle de sport / muscle', 'aucun', 'facile', 'Obsession Roblox durable, et pas un seul derive clavier. Le compteur de vitesse devient un compteur de gains.'],
  ['Sabre / katana', 'aucun', 'facile', 'Le public anime est deja la et actif : Shinobi, Jujutsu Kaisen et Demon Slayer tournent tous les trois.'],
  ['Train / metro', 'aucun', 'facile', 'Couloir lineaire qui accelere : la forme colle au principe du jeu sans rien changer au code.'],
  ['Trampoline', 'aucun', 'facile', 'La branche « +1 Jump » est vivante (Backflip 90 M, Frontflip, Jump Obbies). Le trampoline lui manque.'],
  ['Bebe / creche', 'aucun', 'facile', 'Univers tres porteur aupres des joueurs jeunes, totalement inexploite ici.'],
  ['Œuf a faire eclore', 'aucun', 'moyen', 'La meilleure boucle de monetisation de Roblox, et zero derive. Demande une interface d\'eclosion.'],
  ['Peche', 'aucun', 'moyen', 'Demande enorme tiree par Fisch, aucun derive clavier. Demande une mini-boucle de peche.'],
  ['Nextbot / poursuite', 'aucun', 'moyen', 'Les deux tentatives horreur du genre sont mortes, mais aucune n\'etait un nextbot — le format le plus demande.'],
  ['Aimant', 'aucun', 'moyen', 'Ramasser par attraction est tres satisfaisant visuellement. Demande une zone d\'attraction.'],
];

const MECANIQUES = [
  ['Tycoon clavier', 0, 'Aucun des 245 jeux n\'est un tycoon. Genre eternel sur Roblox.'],
  ['Tower defense clavier', 0, 'Chaque touche posee devient une tourelle. Zero derive.'],
  ['Fusion de touches', 0, 'Les jeux de merge cartonnent partout ailleurs. Absent ici.'],
  ['Battlegrounds / PvP', 0, 'Chaque touche une attaque. Aucun derive PvP direct.'],
  ['Caisses / gacha', 0, 'Aucun systeme de caisses a touches rares.'],
  ['Animaux de compagnie', 1, 'Un seul, mort. La boucle pets reste a prendre.'],
];

const VALIDES = [
  ['Guerre entre joueurs', 2, 2, 'Keyboard Wars et Bridge Wars : les deux tournent encore.'],
  ['Would You Rather', 4, 1, 'Format quiz greffe sur le clavier, un survivant.'],
  ['Echange de claviers', 1, 1, 'Custom Keyboards [TRADING], ~1 900 joueurs.'],
  ['RNG / auras', 2, 1, 'Motorcycle Escape [AURAS] tient bon.'],
];

const html = `<title>Le genre Keyboard Escape</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=Public+Sans:ital,wght@0,400;0,600;1,400&family=JetBrains+Mono:wght@500;700&display=swap">
<style>
:root{--fond:#eef1f0;--carte:#fdfdfc;--encre:#14191a;--doux:#5d6a6c;--trait:#d8dedd;
 --acc:#0f6e5c;--chaud:#a8502c;--or:#7a6a1f;--bleu:#3d7d94}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
 --fond:#0e1214;--carte:#161d1f;--encre:#e4eae9;--doux:#8a9698;--trait:#283234;
 --acc:#43bfa2;--chaud:#e08a5f;--or:#c8b25e;--bleu:#6fb3cd}}
:root[data-theme="dark"]{--fond:#0e1214;--carte:#161d1f;--encre:#e4eae9;--doux:#8a9698;
 --trait:#283234;--acc:#43bfa2;--chaud:#e08a5f;--or:#c8b25e;--bleu:#6fb3cd}
*{box-sizing:border-box}
body{background:var(--fond);color:var(--encre);margin:0;font-size:15px;line-height:1.6;
 font-family:"Public Sans",ui-sans-serif,system-ui,sans-serif}
.page{max-width:1060px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}
a:focus-visible{outline:2px solid var(--acc);outline-offset:3px}
h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:clamp(30px,5vw,46px);
 line-height:1.05;margin:0 0 10px;letter-spacing:-.02em;text-wrap:balance}
.chapeau{margin:0;max-width:64ch;color:var(--doux)}
.entete{border-bottom:2px solid var(--encre);padding-bottom:22px;margin-bottom:34px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:52px 0 6px;
 letter-spacing:-.015em;text-wrap:balance}
h2+.sous-titre{margin:0 0 20px;color:var(--doux);max-width:64ch}
h3{font-family:"JetBrains Mono",monospace;font-size:11px;font-weight:700;text-transform:uppercase;
 letter-spacing:.1em;color:var(--doux);margin:30px 0 12px;padding-bottom:6px;border-bottom:1px solid var(--trait)}

.chiffres{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));
 gap:1px;background:var(--trait);border:1px solid var(--trait);margin-top:24px}
.chiffre{background:var(--carte);padding:15px 17px}
.chiffre b{display:block;font-family:"JetBrains Mono",monospace;font-size:26px;font-weight:700;
 line-height:1.1;letter-spacing:-.02em;font-variant-numeric:tabular-nums}
.chiffre span{font-size:12px;color:var(--doux);display:block;margin-top:3px}
.chiffre.alerte b{color:var(--chaud)}
.chiffre.bien b{color:var(--acc)}

.constat{background:var(--carte);border-left:3px solid var(--chaud);padding:17px 21px;margin:24px 0}
.constat p{margin:0 0 9px}.constat p:last-child{margin:0}

.courbe{display:flex;align-items:flex-end;gap:5px;height:118px;margin:12px 0 6px}
.courbe div{flex:1;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;gap:5px}
.courbe i{display:block;width:100%;background:var(--acc);border-radius:2px 2px 0 0;min-height:2px}
.courbe b{font-family:"JetBrains Mono",monospace;font-size:10px;font-weight:700}
.courbe span{font-family:"JetBrains Mono",monospace;font-size:9px;color:var(--doux);
 writing-mode:vertical-rl;letter-spacing:.04em}

.chefs{display:grid;grid-template-columns:repeat(auto-fill,minmax(238px,1fr));gap:9px}
.chef{display:flex;gap:10px;padding:9px;background:var(--carte);border:1px solid var(--trait);
 border-radius:3px;text-decoration:none;color:inherit}
.chef:hover{border-color:var(--acc)}
.chef img{width:56px;height:56px;border-radius:3px;flex:none;background:var(--trait)}
.chef div{min-width:0}
.chef strong{display:block;font-size:13px;line-height:1.25;overflow-wrap:anywhere}
.chef span{font-family:"JetBrains Mono",monospace;font-size:10.5px;color:var(--doux);
 font-variant-numeric:tabular-nums}
.chef em{font-style:normal;color:var(--acc);font-weight:700}

.liste{max-height:560px;overflow:auto;border:1px solid var(--trait);background:var(--carte)}
table{width:100%;border-collapse:collapse;font-size:13.5px}
th{position:sticky;top:0;background:var(--carte);font-family:"JetBrains Mono",monospace;
 font-size:10px;text-transform:uppercase;letter-spacing:.08em;color:var(--doux);text-align:left;
 padding:9px 11px;border-bottom:1px solid var(--trait);z-index:1}
td{padding:6px 11px;border-bottom:1px solid var(--trait)}
td.n{font-family:"JetBrains Mono",monospace;font-variant-numeric:tabular-nums;text-align:right;white-space:nowrap}
td.i{color:var(--doux);font-family:"JetBrains Mono",monospace;font-size:11px}
tr:hover td{background:var(--fond)}
td a{text-decoration:none}td a:hover{text-decoration:underline}
.on{color:var(--acc);font-weight:700}

.creneaux{display:grid;gap:9px}
.creneau{display:grid;grid-template-columns:1fr auto;gap:5px 16px;background:var(--carte);
 border:1px solid var(--trait);border-radius:3px;padding:13px 16px}
.creneau h4{margin:0;font-size:16px;font-family:"Bricolage Grotesque",sans-serif}
.creneau p{margin:0;grid-column:1/-1;font-size:13.5px;color:var(--doux)}
.effort{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.06em;padding:3px 8px;border-radius:3px;border:1px solid currentColor;
 align-self:start;white-space:nowrap}
.effort.facile{color:var(--acc)}.effort.moyen{color:var(--or)}

.deux{display:grid;grid-template-columns:1fr 1fr;gap:26px}
@media(max-width:720px){.deux{grid-template-columns:1fr}}
ul.simple{margin:0;padding-left:18px;font-size:14px}
ul.simple li{margin-bottom:7px}
ul.simple b{font-weight:600}
.zero{color:var(--acc);font-family:"JetBrains Mono",monospace;font-size:11px}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Le genre Keyboard Escape</h1>
  <p class="chapeau">Recensement complet des dérivés de « +1 Speed Keyboard Escape » sur Roblox — le modèle vendu $19,99 sur BuiltByBit — et inventaire des créneaux qui restent réellement libres.</p>
  <div class="chiffres">
    <div class="chiffre"><b>${jeux.length}</b><span>jeux recensés</span></div>
    <div class="chiffre"><b>${compact(total)}</b><span>visites cumulées</span></div>
    <div class="chiffre alerte"><b>${partN1} %</b><span>captés par le n°1 à lui seul</span></div>
    <div class="chiffre bien"><b>${vivants.length}</b><span>encore vivants (≥ 500 joueurs)</span></div>
    <div class="chiffre alerte"><b>${Math.round(morts.length / jeux.length * 100)} %</b><span>sous 50 joueurs</span></div>
  </div>
</header>

<h2>Ce que disent les chiffres</h2>
<div class="constat">
  <p><strong>Un seul jeu prend tout.</strong> « +1 Speed Keyboard Escape | Candy&nbsp;&amp; Chocolate » compte ${compact(jeux[0].visites)} de visites et ${num(jeux[0].enLigne)} joueurs connectés — ${partN1}&nbsp;% du genre entier. Le deuxième, Monkey Escape, en fait dix fois moins. Les 243 autres se partagent les miettes.</p>
  <p><strong>La plupart meurent vite.</strong> ${morts.length} jeux sur ${jeux.length} sont sous 50 joueurs connectés malgré des millions de visites cumulées : ils ont capté une vague d'algorithme puis se sont éteints. C'est un genre de pic, pas de rente.</p>
  <p><strong>Mais ${vivants.length} tiennent toujours</strong>, dont beaucoup lancés cet été. Le genre n'est pas mort — il est simplement impitoyable pour les copies sans angle.</p>
</div>

<h3>Créations par mois</h3>
<div class="courbe">
${mois.map(([m, n]) => `<div><b>${n}</b><i style="height:${Math.round(n / maxMois * 88)}px"></i><span>${m}</span></div>`).join('')}
</div>
<p class="sous-titre" style="font-size:13px">Le pic est en juillet 2026 avec 51 lancements, suivi d'un net repli en août. Septembre n'est relevé que jusqu'au 8, il ne compte pas.</p>

<h2>Les 12 plus joués aujourd'hui</h2>
<p class="sous-titre">Classés par joueurs connectés au moment de la collecte, pas par visites cumulées — c'est ce qui dit qui vit encore.</p>
<div class="chefs">
${chefs.map(g => `<a class="chef" href="${esc(g.url || '#')}" target="_blank" rel="noopener">
  ${ICONS[g.universeId] ? `<img src="${ICONS[g.universeId]}" alt="" width="56" height="56" loading="lazy">` : '<div style="width:56px;height:56px;background:var(--trait);border-radius:3px;flex:none"></div>'}
  <div><strong>${esc(g.nom)}</strong>
  <span><em>${num(g.enLigne)}</em> en ligne · ${compact(g.visites)} visites</span></div></a>`).join('')}
</div>

<h2>Les ${jeux.length} dérivés recensés</h2>
<p class="sous-titre">Chaque nom ouvre le jeu sur Roblox. Trié par visites cumulées.</p>
<div class="liste">
<table>
<thead><tr><th>#</th><th>Jeu</th><th>Créateur</th><th>Visites</th><th>En ligne</th><th>Créé</th></tr></thead>
<tbody>
${jeux.map((g, i) => `<tr>
<td class="i">${i + 1}</td>
<td><a href="${esc(g.url || '#')}" target="_blank" rel="noopener">${esc(g.nom)}</a></td>
<td class="i">${esc((g.createur || '—').slice(0, 22))}</td>
<td class="n">${compact(g.visites)}</td>
<td class="n${(g.enLigne || 0) >= 500 ? ' on' : ''}">${num(g.enLigne)}</td>
<td class="i">${esc(g.cree || '—')}</td></tr>`).join('')}
</tbody></table>
</div>

<h2>Les thèmes encore libres</h2>
<p class="sous-titre">Chacun a été vérifié par une recherche dédiée sur Roblox : « aucun » veut dire qu'aucun dérivé clavier portant ce thème n'est ressorti. Les 202 thèmes déjà pris vont du singe au Jujutsu Kaisen en passant par le fauteuil roulant — l'espace est très entamé, mais pas clos.</p>
<div class="creneaux">
${THEMES.map(([nom, , effort, pourquoi]) => `<div class="creneau">
  <h4>${esc(nom)}</h4><span class="effort ${effort}">${effort === 'facile' ? 'reskin seul' : 'petite mécanique'}</span>
  <p>${pourquoi}</p></div>`).join('')}
</div>

<h2>Les mécaniques entièrement vierges</h2>
<p class="sous-titre">Aucun des ${jeux.length} jeux recensés ne porte ces formes. Plus de travail qu'un reskin, mais un terrain vide.</p>
<div class="deux">
  <div>
    <h3>Zéro jeu</h3>
    <ul class="simple">
      ${MECANIQUES.filter(m => m[1] === 0).map(([n, , d]) => `<li><b>${esc(n)}</b> <span class="zero">0</span><br>${esc(d)}</li>`).join('')}
    </ul>
  </div>
  <div>
    <h3>Déjà validé mais très peu occupé</h3>
    <ul class="simple">
      ${VALIDES.map(([n, tot, viv, d]) => `<li><b>${esc(n)}</b> <span class="zero">${tot} jeu${tot > 1 ? 'x' : ''}, ${viv} vivant${viv > 1 ? 's' : ''}</span><br>${esc(d)}</li>`).join('')}
    </ul>
  </div>
</div>

<h2>Si je devais choisir</h2>
<div class="constat" style="border-left-color:var(--acc)">
  <p><strong>Volcan, ballon, pizza, salle de sport.</strong> Quatre reskins purs, aucun concurrent, chacun adossé à une preuve de demande : la fuite devant une catastrophe marche déjà (Tsunami, 104&nbsp;M), les thèmes gourmands dominent le genre, le bruit de ballon est de l'ASMR pur, et la salle de sport est une obsession Roblox sans le moindre dérivé clavier. Le modèle fournit déjà les touches procédurales, les sons et la progression — il ne reste que les modèles 3D et les couleurs.</p>
  <p><strong>Et une réserve honnête.</strong> J'ai testé l'idée que les variantes de mécanique survivraient mieux que les simples reskins&nbsp;: c'est faux. Sur les 115 jeux lancés depuis juin 2026, les reskins de thème tiennent une médiane de 176 joueurs connectés contre 95 pour les twists de mécanique, et 35&nbsp;% restent vivants contre 31&nbsp;%. Le chemin facile est aussi le plus efficace ici.</p>
</div>

<section class="note">
  <p><strong>Méthode.</strong> 14 formulations de recherche différentes envoyées à l'API de recherche Roblox, jusqu'à 5 pages chacune, filtrées sur les noms contenant « keyboard », « keycap » ou « +1 speed », puis dédoublonnées et enrichies via l'API des jeux (visites, joueurs connectés, dates). Les créneaux libres ont fait l'objet d'une recherche dédiée chacun.</p>
  <p><strong>Limites.</strong> Ce recensement repose sur la recherche Roblox&nbsp;: un dérivé au nom très éloigné de la formule peut m'avoir échappé, et « aucun dérivé » signifie « rien trouvé », pas « rien n'existe ». Les joueurs connectés sont un instantané pris le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })} — ils varient fortement selon l'heure. Enfin, les thèmes libres le sont aujourd'hui&nbsp;; à 50 lancements par mois, ça bouge vite.</p>
</section>
</div>`;

const out = path.join(ROOT, 'genre-keyboard.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${jeux.length} jeux, ${Math.round(html.length/1024)} Ko`);
