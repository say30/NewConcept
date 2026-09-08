#!/usr/bin/env node
// Etape 4 — genere le classeur : index classe + une fiche detaillee par jeu.
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const num = n => (n == null ? '—' : Number(n).toLocaleString('fr-FR'));
const compact = n => n == null ? '—' : n >= 1e9 ? (n / 1e9).toFixed(1) + ' Md' : n >= 1e6 ? (n / 1e6).toFixed(1) + ' M' : n >= 1e3 ? Math.round(n / 1e3) + ' k' : String(n);
const TOP = parseInt(process.env.TOP || '20', 10);

const tous = readData('classement.json');
// Les vignettes voyagent encodees dans la page : les images externes y sont bloquees.
let VIGN = {};
try { VIGN = readData('vignettes.json'); } catch (_) { console.warn('! vignettes.json absent'); }
const vignette = u => VIGN[u] || null;
const top = tous.slice(0, TOP);

// Medianes du corpus : elles servent de repere dans chaque fiche.
const med = k => { const v = tous.map(g => g.stats[k]).filter(x => typeof x === 'number').sort((a, b) => a - b); return v[Math.floor(v.length / 2)]; };
const M = { words: med('words'), media: med('media'), bullets: med('bullets'), purchases: med('purchases') };

const chipConcurrence = n => n === 0 ? ['inconnue', 'neutre']
  : n <= 2 ? [`${n} concurrent${n > 1 ? 's' : ''}`, 'libre']
  : n <= 4 ? [`${n} concurrents`, 'ouvert']
  : n <= 7 ? [`${n} concurrents`, 'charge']
  : [`${n >= 12 ? '12+' : n} concurrents`, 'sature'];

const barre = g => {
  const t = g.blocs.qualite + g.blocs.traction + g.blocs.marche;
  return `<div class="jauge" role="img" aria-label="score ${g.score} sur 100">
    <i style="width:${(g.blocs.qualite / t * 100).toFixed(1)}%" class="s-a"></i>
    <i style="width:${(g.blocs.traction / t * 100).toFixed(1)}%" class="s-b"></i>
    <i style="width:${(g.blocs.marche / t * 100).toFixed(1)}%" class="s-c"></i>
  </div>`;
};

const metrique = (val, ref, label) => {
  const r = ref ? val / ref : 1;
  const cls = r >= 2 ? 'haut' : r >= 1 ? 'moyen' : 'bas';
  return `<div class="met"><b class="${cls}">${num(val)}</b><span>${label}</span><em>médiane ${num(ref)}</em></div>`;
};

function fiche(g) {
  const [txtConc, clsConc] = chipConcurrence(g.variantesSolides);
  const retenus = g.roblox.filter(v => v.concurrent);
  const autres = g.roblox.filter(v => !v.concurrent && (v.visits || 0) > 500000);
  const vars = [...retenus, ...autres].slice(0, 6);

  const cartes = vars.map(v => `
    <a class="rbx" href="${esc(v.url || '#')}" target="_blank" rel="noopener">
      ${vignette(v.icon) ? `<img src="${vignette(v.icon)}" alt="Vignette de ${esc(v.name)}" loading="lazy" width="72" height="72">` : '<div class="ph" aria-hidden="true"></div>'}
      <div class="rbx-txt">
        <strong>${esc(v.name)}</strong>
        <span class="par">${esc(v.creator || 'créateur inconnu')}</span>
        <span class="chiffres">${v.concurrent ? '' : '<em class="voisin">voisin</em> '}<b>${compact(v.visits)}</b> visites · <b>${num(v.playing)}</b> en ligne${v.likeRatio != null ? ` · <b>${Math.round(v.likeRatio * 100)} %</b> d'avis positifs` : ''}</span>
      </div>
    </a>`).join('');

  const sous = [
    ['Longueur du texte', g.detailScores.longueur, 14],
    ['Structure', g.detailScores.structure, 10],
    ['Captures et vidéos', g.detailScores.medias, 12],
    ['Liste de contenu', g.detailScores.contenu_liste, 6],
    ['Avis et note', g.detailScores.preuve_sociale, 8],
    ['Ventes', g.detailScores.ventes, 14],
    ['Prix', g.detailScores.positionnement_prix, 6],
    ['Demande Roblox', g.detailScores.demande, 16],
    ['Créneau libre', g.detailScores.opportunite, 9],
    ['Genre encore vivant', g.detailScores.fraicheur, 5],
  ].map(([l, v, max]) => `<li><span>${l}</span><i><b style="width:${Math.round((v || 0) / max * 100)}%"></b></i><em>${(+(v || 0)).toFixed(1)}<small>/${max}</small></em></li>`).join('');

  return `
  <article class="fiche" id="jeu-${g.rang}">
    <div class="rail">
      <div class="rangnum">${String(g.rang).padStart(2, '0')}</div>
      <div class="scorebig">${g.score}<small>/100</small></div>
      ${barre(g)}
      <ul class="legende">
        <li><i class="s-a"></i>Annonce ${g.blocs.qualite}</li>
        <li><i class="s-b"></i>Traction ${g.blocs.traction}</li>
        <li><i class="s-c"></i>Marché ${g.blocs.marche}</li>
      </ul>
    </div>

    <div class="corps">
      <h2><a href="${esc(g.url)}" target="_blank" rel="noopener">${esc(g.titre)}</a></h2>
      ${g.tagline ? `<p class="accroche">${esc(g.tagline)}</p>` : ''}
      <p class="ligne-meta">
        <span class="prix">${g.prix ? '$' + g.prix.toFixed(2) : 'gratuit'}</span>
        ${g.promo ? `<span class="promo">${esc(g.promo)}</span>` : ''}
        <span>par ${esc(g.auteur || '—')}</span>
        <span>${num(g.stats.purchases)} vente${g.stats.purchases > 1 ? 's' : ''}</span>
        <span>${g.stats.reviews ? `${g.stats.rating.toFixed(2)} ★ sur ${g.stats.reviews} avis` : 'pas encore noté'}</span>
        <span class="chip ${clsConc}">${txtConc}</span>
      </p>

      <div class="metriques">
        ${metrique(g.stats.words, M.words, 'mots')}
        ${metrique(g.stats.media, M.media, 'captures')}
        ${metrique(g.stats.bullets, M.bullets, 'puces')}
        ${metrique(g.stats.purchases, M.purchases, 'ventes')}
      </div>

      ${g.description ? `<p class="desc">${esc(g.description.slice(0, 460))}${g.description.length > 460 ? '…' : ''}</p>` : ''}

      <details class="detail-score">
        <summary>Détail des points</summary>
        <ul class="sous">${sous}</ul>
      </details>

      <h3>Équivalents sur Roblox</h3>
      ${cartes ? `<div class="rbx-grille">${cartes}</div>`
        : `<p class="vide">Aucun jeu Roblox comparable au-dessus de 20 000 visites. Créneau vierge — ou titre trop atypique pour que la recherche le rapproche d'un jeu existant.</p>`}

      ${g.variantesSolides <= 3 ? `
      <h3>Variantes à développer</h3>
      <ul class="idees">${g.ideesVariantes.slice(0, 5).map(i => `<li>${esc(i)}</li>`).join('')}</ul>` : ''}
    </div>
  </article>`;
}

const html = `<title>Classeur Roblox BuiltByBit</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=Public+Sans:ital,wght@0,400;0,600;1,400&family=JetBrains+Mono:wght@500;700&display=swap">
<style>
:root{
  --fond:#eef1f0; --carte:#fdfdfc; --encre:#14191a; --doux:#5d6a6c; --trait:#d8dedd;
  --acc:#0f6e5c; --acc-doux:#d7e8e3; --chaud:#a8502c; --or:#7a6a1f;
  --a:#0f6e5c; --b:#4d8fa8; --c:#a8823a;
}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
  --fond:#0e1214; --carte:#161d1f; --encre:#e4eae9; --doux:#8a9698; --trait:#283234;
  --acc:#43bfa2; --acc-doux:#123c34; --chaud:#e08a5f; --or:#c8b25e;
  --a:#43bfa2; --b:#6fb3cd; --c:#c8a45e;
}}
:root[data-theme="dark"]{
  --fond:#0e1214; --carte:#161d1f; --encre:#e4eae9; --doux:#8a9698; --trait:#283234;
  --acc:#43bfa2; --acc-doux:#123c34; --chaud:#e08a5f; --or:#c8b25e;
  --a:#43bfa2; --b:#6fb3cd; --c:#c8a45e;
}
*{box-sizing:border-box}
body{background:var(--fond);color:var(--encre);margin:0;
  font-family:"Public Sans",ui-sans-serif,system-ui,-apple-system,"Segoe UI",sans-serif;
  font-size:15px;line-height:1.6}
.page{max-width:1120px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}
a:focus-visible,summary:focus-visible{outline:2px solid var(--acc);outline-offset:3px;border-radius:3px}

.entete{border-bottom:2px solid var(--encre);padding-bottom:22px;margin-bottom:34px}
h1{font-family:"Bricolage Grotesque",ui-sans-serif,sans-serif;font-weight:700;
  font-size:clamp(30px,5vw,46px);line-height:1.05;margin:0 0 10px;letter-spacing:-.02em;text-wrap:balance}
.chapeau{margin:0;max-width:62ch;color:var(--doux)}
.compteurs{display:flex;flex-wrap:wrap;gap:26px;margin-top:20px;
  font-family:"JetBrains Mono",ui-monospace,monospace;font-size:12px;
  text-transform:uppercase;letter-spacing:.07em;color:var(--doux)}
.compteurs b{display:block;font-size:21px;color:var(--encre);letter-spacing:-.01em}

h2{font-family:"Bricolage Grotesque",sans-serif;font-size:21px;margin:0 0 3px;
  line-height:1.2;letter-spacing:-.01em;text-wrap:balance}
h2 a{text-decoration:none;color:var(--encre)}
h2 a:hover{color:var(--acc);text-decoration:underline;text-underline-offset:3px}
h3{font-family:"JetBrains Mono",monospace;font-size:11px;font-weight:700;
  text-transform:uppercase;letter-spacing:.1em;color:var(--doux);
  margin:26px 0 11px;padding-bottom:6px;border-bottom:1px solid var(--trait)}

/* --- index --- */
.tableau{overflow-x:auto;margin-bottom:52px;border-block:1px solid var(--trait)}
table{width:100%;border-collapse:collapse;font-size:14px}
th{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
  letter-spacing:.09em;color:var(--doux);text-align:left;font-weight:700;
  padding:10px 12px;border-bottom:1px solid var(--trait);white-space:nowrap}
td{padding:9px 12px;border-bottom:1px solid var(--trait);vertical-align:middle}
tbody tr:hover{background:var(--carte)}
td.r,td.n{font-family:"JetBrains Mono",monospace;font-variant-numeric:tabular-nums}
td.r{color:var(--doux);font-size:12px}
td.n{font-weight:700}
td.j a{text-decoration:none;font-weight:600;color:var(--encre)}
td.j a:hover{color:var(--acc)}
.mini{width:118px}

/* --- jauge de score --- */
.jauge{display:flex;height:7px;border-radius:4px;overflow:hidden;background:var(--trait)}
.jauge i{display:block;height:100%}
.s-a{background:var(--a)}.s-b{background:var(--b)}.s-c{background:var(--c)}

/* --- fiches --- */
.fiche{display:grid;grid-template-columns:158px 1fr;gap:30px;
  background:var(--carte);border:1px solid var(--trait);border-radius:4px;
  padding:26px 28px;margin-bottom:20px}
@media(max-width:760px){.fiche{grid-template-columns:1fr;gap:18px}}
.rail{border-right:1px solid var(--trait);padding-right:24px}
@media(max-width:760px){.rail{border-right:0;border-bottom:1px solid var(--trait);padding:0 0 16px}}
.rangnum{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:46px;
  line-height:.9;color:var(--trait);letter-spacing:-.04em}
.scorebig{font-family:"JetBrains Mono",monospace;font-weight:700;font-size:29px;
  color:var(--acc);margin:6px 0 9px;font-variant-numeric:tabular-nums}
.scorebig small{font-size:12px;color:var(--doux);font-weight:500}
.legende{list-style:none;padding:0;margin:11px 0 0;font-size:11px;color:var(--doux);
  font-family:"JetBrains Mono",monospace;display:flex;flex-direction:column;gap:4px}
.legende i{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:7px}

.accroche{margin:0 0 9px;color:var(--doux);font-style:italic}
.ligne-meta{display:flex;flex-wrap:wrap;gap:8px 14px;align-items:center;margin:0 0 16px;
  font-size:13px;color:var(--doux)}
.prix{font-family:"JetBrains Mono",monospace;font-weight:700;color:var(--encre);font-size:15px}
.promo{background:var(--chaud);color:var(--carte);font-size:10px;font-weight:700;
  padding:2px 6px;border-radius:3px;letter-spacing:.05em}
.chip{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
  letter-spacing:.07em;padding:3px 8px;border-radius:3px;border:1px solid currentColor}
.chip.libre{color:var(--acc)}.chip.ouvert{color:var(--b)}
.chip.charge{color:var(--or)}.chip.sature{color:var(--chaud)}.chip.neutre{color:var(--doux)}

.metriques{display:grid;grid-template-columns:repeat(auto-fit,minmax(112px,1fr));
  gap:1px;background:var(--trait);border:1px solid var(--trait);border-radius:3px;overflow:hidden}
.met{background:var(--carte);padding:11px 13px;display:flex;flex-direction:column;gap:1px}
.met b{font-family:"JetBrains Mono",monospace;font-size:19px;font-variant-numeric:tabular-nums;line-height:1.1}
.met b.haut{color:var(--acc)}.met b.moyen{color:var(--encre)}.met b.bas{color:var(--doux)}
.met span{font-size:12px}
.met em{font-style:normal;font-size:10px;color:var(--doux);
  font-family:"JetBrains Mono",monospace;letter-spacing:.03em}

.desc{font-size:14px;color:var(--doux);margin:16px 0 0;max-width:68ch}

.detail-score{margin-top:16px;border-top:1px solid var(--trait);padding-top:12px}
summary{cursor:pointer;font-family:"JetBrains Mono",monospace;font-size:11px;
  text-transform:uppercase;letter-spacing:.09em;color:var(--doux)}
.sous{list-style:none;padding:0;margin:14px 0 0;display:grid;
  grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:7px 26px}
.sous li{display:grid;grid-template-columns:1fr 62px 46px;align-items:center;gap:9px;font-size:12.5px}
.sous i{display:block;height:5px;background:var(--trait);border-radius:3px;overflow:hidden}
.sous i b{display:block;height:100%;background:var(--acc)}
.sous em{font-style:normal;font-family:"JetBrains Mono",monospace;font-size:11px;
  text-align:right;font-variant-numeric:tabular-nums}
.sous small{color:var(--doux)}

.rbx-grille{display:grid;grid-template-columns:repeat(auto-fill,minmax(268px,1fr));gap:10px}
.rbx{display:flex;gap:11px;text-decoration:none;color:inherit;
  border:1px solid var(--trait);border-radius:3px;padding:9px;background:var(--fond)}
.rbx:hover{border-color:var(--acc)}
.rbx img,.ph{width:72px;height:72px;border-radius:3px;object-fit:cover;background:var(--trait);flex:none}
.rbx-txt{display:flex;flex-direction:column;gap:2px;min-width:0}
.rbx-txt strong{font-size:13.5px;line-height:1.25;overflow-wrap:anywhere}
.par{font-size:11.5px;color:var(--doux)}
.chiffres{font-size:11px;color:var(--doux);font-family:"JetBrains Mono",monospace;
  font-variant-numeric:tabular-nums;margin-top:3px}
.chiffres b{color:var(--encre);font-weight:700}
.voisin{font-style:normal;color:var(--doux);border:1px solid var(--trait);
  border-radius:2px;padding:0 4px;font-size:9px;letter-spacing:.06em;text-transform:uppercase}
.vide{font-size:13.5px;color:var(--doux);background:var(--fond);
  border-left:2px solid var(--acc);padding:11px 14px;margin:0}
.idees{margin:0;padding-left:19px;font-size:14px}
.idees li{margin-bottom:4px}

.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);
  font-size:13px;color:var(--doux);max-width:70ch}
.note h3{margin-top:22px}
@media (prefers-reduced-motion:reduce){*{transition:none!important;animation:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Classeur Roblox BuiltByBit</h1>
  <p class="chapeau">Les ${tous.length} jeux Roblox en vente dans la catégorie « Game&nbsp;Setups », mesurés puis classés sur la richesse réelle de leur annonce, leurs ventes et la place qui leur reste sur Roblox. Voici les ${top.length} premiers.</p>
  <div class="compteurs">
    <div><b>${num(tous.length)}</b>annonces analysées</div>
    <div><b>${num(M.words)}</b>mots · médiane</div>
    <div><b>${num(M.media)}</b>captures · médiane</div>
    <div><b>${num(M.purchases)}</b>ventes · médiane</div>
    <div><b>${top[0].score}</b>meilleur score</div>
  </div>
</header>

<div class="tableau">
<table>
<caption class="u-hide" hidden>Classement des ${top.length} meilleures annonces</caption>
<thead><tr><th>Rang</th><th>Jeu</th><th>Prix</th><th>Score</th><th class="mini">Composition</th><th>Ventes</th><th>Concurrence Roblox</th></tr></thead>
<tbody>
${top.map(g => { const [t, c] = chipConcurrence(g.variantesSolides); return `<tr>
<td class="r">${String(g.rang).padStart(2, '0')}</td>
<td class="j"><a href="#jeu-${g.rang}">${esc(g.titre)}</a></td>
<td class="n">${g.prix ? '$' + g.prix.toFixed(2) : '—'}</td>
<td class="n">${g.score.toFixed(1)}</td>
<td class="mini">${barre(g)}</td>
<td class="n">${num(g.stats.purchases)}</td>
<td><span class="chip ${c}">${t}</span></td></tr>`; }).join('')}
</tbody></table>
</div>

${top.map(fiche).join('')}

<section class="note">
  <h3>Comment lire ce classement</h3>
  <p>Chaque annonce vaut 100 points. <strong>L'annonce</strong> (50) mesure ce que le vendeur montre&nbsp;: longueur du texte, intertitres et puces, captures d'écran, présence d'une liste de contenu, avis et note. <strong>La traction</strong> (20) prend les ventes et le positionnement du prix. <strong>Le marché</strong> (30) vient de Roblox&nbsp;: audience du meilleur équivalent existant, nombre de concurrents crédibles, et date de dernière mise à jour de ces concurrents — un genre que plus personne n'entretient est un genre mort.</p>
  <p>Un concurrent n'est compté que si son titre est suffisamment proche <em>et</em> qu'il dépasse 100&nbsp;000 visites. « Créneau libre » veut donc dire : la demande est prouvée, mais peu de jeux crédibles l'occupent. C'est là que les idées de variantes sont proposées. Les jeux marqués <em>voisin</em> sont du même univers mais portent un titre trop éloigné pour être comptés — ils restent affichés parce qu'ils pèsent sur l'audience du créneau.</p>
  <h3>Ce que ce classement ne dit pas</h3>
  <p>La note mesure le <em>soin apporté à l'annonce</em>, pas la qualité du code livré — une annonce riche peut cacher un projet bâclé, et l'inverse existe aussi. Les ventes affichées par BuiltByBit sont souvent basses parce que la plupart de ces annonces sont récentes. Enfin, le rapprochement avec Roblox se fait sur le titre&nbsp;: un jeu au nom très générique ou très inventif peut être mal apparié — les vignettes sont là pour que tu vérifies d'un coup d'œil.</p>
  <p>Sources : catégorie 54 de BuiltByBit (65 pages), API publiques de Roblox pour les visites, joueurs connectés, avis et vignettes. Collecté le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}.</p>
</section>
</div>`;

const out = path.join(ROOT, 'classeur.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${top.length} fiches, ${Math.round(html.length / 1024)} Ko`);
