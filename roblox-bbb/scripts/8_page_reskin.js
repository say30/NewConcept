#!/usr/bin/env node
// Etape 8 — dossier de reskin, revu apres description precise de la boucle par le
// joueur : couloir a paliers, mur de durete doux, butin a rapporter, inventaire limite.
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));
const num = n => Number(n).toLocaleString('fr-FR');
const R = readData('refs.json');

const ref = (cle, note) => {
  const r = R[cle]; if (!r) return '';
  return `<a class="ref" href="https://www.roblox.com/games/${r.place}/" target="_blank" rel="noopener">
    ${r.icone ? `<img src="${r.icone}" alt="" width="34" height="34" loading="lazy">` : ''}
    <span><strong>${esc(r.nom)}</strong><em>${num(r.joueurs)} joueurs · ${esc(note)}</em></span></a>`;
};

// Les six exigences que la boucle reelle impose a un theme.
const CRIT = ['Bloque un couloir', 'Repousse', 'Durcit en profondeur', 'Butin au bout',
              'Deux objets en main', 'Rien a modeliser'];

const IDEES = [
  {
    nom: 'Les lianes', titre: '+1 Cut Vines', rang: 1, fort: true,
    pitch: 'Un sentier de jungle étranglé par la végétation. Machette à la main, tu ouvres un passage vers un temple. Au fond de chaque section, des idoles posées sur des socles.',
    notes: [3,3,3,3,3,3],
    pourquoi: 'C\'est le seul thème qui coche les six cases sans forcer. La jungle bloque un chemin par nature, elle repousse vite, elle s\'épaissit à mesure qu\'on s\'enfonce, et le butin au bout d\'un couloir de temple est la fiction d\'aventure la plus évidente qui soit. Une idole en or, c\'est lourd : deux dans les bras, pas trois. Ta limite d\'inventaire arrête d\'être une contrainte de jeu, elle devient logique.',
    mondes: ['Le sentier', 'La jungle dense', 'Le marais', 'Les ruines', 'Le temple', 'Le cœur du temple'],
    dessiner: 'Les lianes sont des cylindres verts, le temple des blocs gris. Rien à modéliser, et les outils s\'échelonnent tout seuls : serpe, machette, sabre, tronçonneuse.',
    risque: 'Le thème jungle est visuellement chargé. Il faut soigner la lisibilité, sinon on ne voit plus où on coupe.',
  },
  {
    nom: 'Les toiles d\'araignée', titre: '+1 Sweep', rang: 2,
    pitch: 'Un manoir abandonné, couloir après couloir, tapissé de toiles. Tu balaies pour avancer et tu récupères ce que les araignées avaient emballé.',
    notes: [3,3,3,3,2,3],
    pourquoi: 'Une toile qui barre un couloir, c\'est l\'image même de l\'obstacle. Les araignées retissent pendant que tu es parti : tes gains hors-ligne sont justifiés sans une ligne d\'explication.',
    mondes: ['Le grenier', 'La cave', 'La bibliothèque', 'La crypte', 'Le nid', 'La reine'],
    dessiner: 'Des surfaces semi-transparentes et un balai. L\'obscurité pardonne énormément de défauts visuels.',
    risque: 'Très saisonnier : sorti après Halloween, il perd la moitié de son intérêt.',
    urgence: 'Halloween est dans 7 semaines. C\'est la fenêtre.',
  },
  {
    nom: 'Le givre', titre: '+1 Scrape Ice', rang: 3,
    pitch: 'Un tunnel de glace. Tu grattes, la paroi se fissure et cède. Au fond, des objets pris dans le gel depuis des siècles.',
    notes: [3,3,3,3,2,3],
    pourquoi: 'Le tunnel se referme par le gel pendant la nuit, et la glace épaissit naturellement à mesure qu\'on descend. Une défense de mammouth prise dans la glace, ça se rapporte à deux mains.',
    mondes: ['Le pare-brise', 'La cabane', 'Le lac gelé', 'La grotte', 'Le glacier', 'La bête gelée'],
    dessiner: 'Des cubes blancs translucides. Le son du grattage porte le jeu à lui seul.',
    risque: 'Saisonnier aussi, mais la fenêtre d\'hiver dure plus longtemps que celle d\'Halloween.',
    urgence: 'À viser pour décembre.',
  },
  {
    nom: 'Les ronces', titre: '+1 Cut Thorns', rang: 4,
    pitch: 'Un château envahi par les épines. Tu tailles pour progresser de salle en salle, en récupérant ce que la végétation a englouti.',
    notes: [3,3,3,2,2,3],
    pourquoi: 'Mécaniquement identique aux lianes, avec un habillage de conte plutôt que d\'aventure. Les épines peuvent blesser, ce qui ouvre une variable que le modèle de base n\'a pas.',
    mondes: ['La grille', 'La cour', 'Le hall', 'L\'escalier', 'La tour', 'La chambre'],
    dessiner: 'Des cylindres bruns hérissés de piques. Même charge de travail que les lianes.',
    risque: 'Le butin est moins évident à justifier qu\'un temple rempli d\'idoles.',
  },
  {
    nom: 'Les champignons géants', titre: '+1 Cut Shrooms', rang: 5,
    pitch: 'Une caverne où les champignons ont tout envahi. Tu tranches les pieds pour ouvrir la galerie et tu ramasses les spores rares.',
    notes: [3,3,3,2,3,3],
    pourquoi: 'Les champignons repoussent vite et l\'univers permet des couleurs vives, ce qui aide beaucoup quand on ne sait pas modéliser : la palette fait le travail.',
    mondes: ['L\'entrée', 'La galerie', 'Le lac souterrain', 'La forêt de spores', 'Le nid', 'Le champignon-mère'],
    dessiner: 'Des cylindres surmontés de demi-sphères. C\'est le thème le plus simple à dessiner des cinq.',
    risque: 'Moins immédiatement lisible qu\'une jungle ou un manoir dans une vignette.',
  },
];

const RETROGRADES = [
  ['La tonte', 'Un mouton n\'est pas un couloir. Il faudrait tunneliser dans la fourrure d\'une créature géante, ce qui devient bizarre — et le butin au bout n\'a plus de sens.'],
  ['Le rasage', 'Même problème : une tête, c\'est une surface, pas un chemin. Rien à rapporter au vendeur.'],
  ['La rouille', 'La rouille ne repousse pas. La règle « l\'herbe repousse quand tu sors » tombe, et c\'est justement elle qui fait tenir la boucle.'],
];

const PRIS = [
  ['Les feuilles', 'Clean all the leaves', '150 M de visites, 36 000 joueurs. Intouchable.'],
  ['Le creusage, le sable', 'Dig & Clean, Dig to Escape', 'Trois jeux solides se partagent le terrain.'],
  ['La récolte', 'Grow a Garden', 'Occupé, et sur une mécanique différente.'],
  ['La neige', 'Clean all the Snow!', 'Occupé mais petit — un concurrent, pas un mur.'],
  ['L\'herbe', '+1 Cut Grass Adventure', 'Ton point de départ. N\'y reste pas.'],
];

const point = n => `<i class="p p${n}" title="${n === 3 ? 'évident' : n === 2 ? 'correct' : 'à forcer'}"></i>`;

const html = `<title>Cinq reskins pour Cut Grass</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,500;12..96,700&family=Public+Sans:ital,wght@0,400;0,600;1,400&family=JetBrains+Mono:wght@500;700&display=swap">
<style>
:root{--fond:#eef1f0;--carte:#fdfdfc;--encre:#14191a;--doux:#5d6a6c;--trait:#d8dedd;
 --acc:#0f6e5c;--chaud:#a8502c;--or:#7a6a1f}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){
 --fond:#0e1214;--carte:#161d1f;--encre:#e4eae9;--doux:#8a9698;--trait:#283234;
 --acc:#43bfa2;--chaud:#e08a5f;--or:#c8b25e}}
:root[data-theme="dark"]{--fond:#0e1214;--carte:#161d1f;--encre:#e4eae9;--doux:#8a9698;
 --trait:#283234;--acc:#43bfa2;--chaud:#e08a5f;--or:#c8b25e}
*{box-sizing:border-box}
body{background:var(--fond);color:var(--encre);margin:0;font-size:15px;line-height:1.62;
 font-family:"Public Sans",ui-sans-serif,system-ui,sans-serif}
.page{max-width:900px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}a:focus-visible{outline:2px solid var(--acc);outline-offset:3px}
h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:clamp(30px,5.4vw,45px);
 line-height:1.05;margin:0 0 12px;letter-spacing:-.025em;text-wrap:balance}
.chapeau{margin:0;max-width:60ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:34px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:52px 0 8px;letter-spacing:-.015em}
.intro{margin:0 0 22px;color:var(--doux);max-width:62ch}
h3{font-family:"JetBrains Mono",monospace;font-size:10.5px;font-weight:700;text-transform:uppercase;
 letter-spacing:.11em;color:var(--doux);margin:0 0 6px}

.moteur{background:var(--carte);border:1px solid var(--trait);border-radius:4px;padding:22px 26px}
.moteur>p{margin:0 0 16px}
.pieces{display:grid;grid-template-columns:repeat(auto-fit,minmax(228px,1fr));gap:1px;
 background:var(--trait);border:1px solid var(--trait)}
.piece{background:var(--carte);padding:13px 15px}
.piece b{display:block;font-size:13.5px;margin-bottom:2px}
.piece span{font-size:12.5px;color:var(--doux)}

.idee{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:24px 26px;margin-bottom:18px}
.idee.fort{border-color:var(--acc);border-width:2px}
.idee>header{display:flex;align-items:baseline;gap:11px;flex-wrap:wrap;margin-bottom:8px}
.rg{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:26px;
 color:var(--trait);line-height:1;letter-spacing:-.03em}
.idee h4{font-family:"Bricolage Grotesque",sans-serif;font-size:23px;margin:0;letter-spacing:-.015em}
.nomjeu{font-family:"JetBrains Mono",monospace;font-size:12px;color:var(--acc);
 border:1px solid var(--acc);border-radius:3px;padding:2px 8px}
.recommande{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;background:var(--acc);color:var(--carte);padding:3px 9px;border-radius:3px}
.pitch{margin:0 0 15px;font-size:15.5px}
.urgence{font-family:"JetBrains Mono",monospace;font-size:11px;color:var(--chaud);
 border-left:2px solid var(--chaud);padding-left:10px;margin:0 0 14px}

.crit{display:grid;grid-template-columns:repeat(auto-fit,minmax(132px,1fr));gap:7px;
 margin:0 0 16px;padding:13px 0;border-block:1px solid var(--trait)}
.crit div{display:flex;align-items:center;gap:7px;font-size:11.5px;color:var(--doux)}
.p{width:9px;height:9px;border-radius:50%;flex:none;display:inline-block}
.p3{background:var(--acc)}
.p2{background:var(--acc);opacity:.42}
.p1{background:var(--trait);border:1px solid var(--doux)}

.grille{display:grid;grid-template-columns:1fr 1fr;gap:16px 26px}
@media(max-width:640px){.grille{grid-template-columns:1fr}}
.bloc p{margin:0;font-size:13.5px;color:var(--doux)}
.bloc.risque h3{color:var(--chaud)}
.bloc.cle p{color:var(--encre);font-size:14px}
.mondes{display:flex;flex-wrap:wrap;gap:6px;list-style:none;padding:0;margin:0;counter-reset:m}
.mondes li{font-size:12px;background:var(--fond);border:1px solid var(--trait);
 border-radius:3px;padding:3px 9px}
.mondes li::before{content:counter(m) " ";counter-increment:m;
 font-family:"JetBrains Mono",monospace;font-size:9px;color:var(--doux)}
.refs{display:flex;flex-wrap:wrap;gap:13px;margin-top:8px}
.ref{display:flex;gap:7px;align-items:center;text-decoration:none;color:inherit}
.ref img{border-radius:3px;flex:none;background:var(--trait)}
.ref span{display:flex;flex-direction:column}
.ref strong{font-size:11.5px;line-height:1.2}
.ref em{font-style:normal;font-family:"JetBrains Mono",monospace;font-size:9.5px;color:var(--doux)}

.retro{display:grid;gap:9px}
.rt{background:var(--carte);border-left:3px solid var(--or);padding:13px 17px}
.rt b{font-family:"Bricolage Grotesque",sans-serif;font-size:15px}
.rt p{margin:3px 0 0;font-size:13.5px;color:var(--doux)}

table{width:100%;border-collapse:collapse;font-size:13.5px;background:var(--carte);border:1px solid var(--trait)}
th{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;letter-spacing:.08em;
 color:var(--doux);text-align:left;padding:9px 12px;border-bottom:1px solid var(--trait)}
td{padding:8px 12px;border-bottom:1px solid var(--trait)}
.tw{overflow-x:auto}
.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Cinq reskins pour Cut Grass</h1>
  <p class="chapeau">Tu gardes le moteur, tu changes le décor. Classement revu après description précise de la boucle : ce n'est pas un champ ouvert, c'est un couloir à paliers avec un butin à rapporter.</p>
</header>

<h2>Ce que le moteur exige vraiment</h2>
<div class="moteur">
  <p>La boucle repose sur six pièces. Un thème qui n'en tient qu'une partie oblige à retoucher le code — c'est-à-dire à payer un développeur pour défaire ce que tu viens d'acheter.</p>
  <div class="pieces">
    <div class="piece"><b>Un couloir, pas un champ</b><span>La matière barre le passage. On avance en la retirant.</span></div>
    <div class="piece"><b>Elle repousse</b><span>Tu sors, elle revient. C'est ce qui justifie les gains hors-ligne.</span></div>
    <div class="piece"><b>Elle durcit en profondeur</b><span>Le mur est doux : tu peux entrer sous-équipé, ça prend juste des minutes.</span></div>
    <div class="piece"><b>Du butin au bout</b><span>Des objets posés au fond de chaque section, à rapporter au vendeur.</span></div>
    <div class="piece"><b>Deux objets en main</b><span>La limite d'inventaire est la vraie caisse enregistreuse du jeu.</span></div>
    <div class="piece"><b>Deux jauges qui montent</b><span>La force à chaque coup, l'outil à chaque vente.</span></div>
  </div>
</div>

<h2>Le classement</h2>
<p class="intro">Chaque thème est noté sur les six exigences ci-dessus. Un point plein veut dire que ça coule de source, un point pâle qu'il faut un peu d'habillage, un point vide qu'il faut forcer.</p>

${IDEES.map(i => `<article class="idee${i.fort ? ' fort' : ''}">
  <header><span class="rg">${String(i.rang).padStart(2, '0')}</span><h4>${esc(i.nom)}</h4>
    <span class="nomjeu">${esc(i.titre)}</span>
    ${i.fort ? '<span class="recommande">mon choix</span>' : ''}</header>
  <p class="pitch">${esc(i.pitch)}</p>
  ${i.urgence ? `<p class="urgence">${esc(i.urgence)}</p>` : ''}
  <div class="crit">${CRIT.map((c, k) => `<div>${point(i.notes[k])}${esc(c)}</div>`).join('')}</div>
  <div class="grille">
    <div class="bloc cle" style="grid-column:1/-1"><h3>Pourquoi ça tient</h3><p>${esc(i.pourquoi)}</p></div>
    <div class="bloc"><h3>Les six mondes</h3>
      <ul class="mondes">${i.mondes.map(m => `<li>${esc(m)}</li>`).join('')}</ul></div>
    <div class="bloc"><h3>Ce qu'il faut dessiner</h3><p>${esc(i.dessiner)}</p></div>
    <div class="bloc risque" style="grid-column:1/-1"><h3>Le risque</h3><p>${esc(i.risque)}</p></div>
  </div>
</article>`).join('')}

<h2>Ce que ta description a fait tomber</h2>
<p class="intro">Ces trois-là étaient dans ma première liste. Ils marchent pour « un champ dense qui repousse », mais pas pour « un couloir avec du butin au bout ». Je les retire.</p>
<div class="retro">
${RETROGRADES.map(([n, p]) => `<div class="rt"><b>${esc(n)}</b><p>${esc(p)}</p></div>`).join('')}
</div>

<h2>Les thèmes déjà occupés</h2>
<div class="tw"><table>
<thead><tr><th>Thème</th><th>Qui l'occupe</th><th>État</th></tr></thead>
<tbody>${PRIS.map(([t, q, e]) => `<tr><td><strong>${esc(t)}</strong></td><td>${esc(q)}</td><td>${esc(e)}</td></tr>`).join('')}</tbody>
</table></div>
<div class="refs" style="margin-top:14px">
  ${ref('Clean all the leaves', 'le mur du genre')}
  ${ref('Cut Grass Adventure', 'ton point de départ')}
  ${ref('Dig & Clean', 'le creusage est pris')}
</div>

<h2>Ce que je ferais</h2>
<div class="fin">
  <p><strong>Les lianes.</strong> C'est le seul thème qui coche les six cases sans qu'on ait à tordre quoi que ce soit. Et il règle même un point que l'herbe laisse bancal : ta limite de deux objets. Ramener deux poignées d'herbe, ça n'a aucun sens ; ramener deux idoles en or, ça en a. Le joueur ne subit plus une règle, il comprend pourquoi il ne peut pas en prendre trois.</p>
  <p><strong>Tes trois leviers de réglage</strong>, dans l'ordre d'importance : la courbe de dureté entre les étapes — c'est elle qui décide si le joueur s'acharne ou abandonne ; le temps du trajet retour — trop court il n'y a plus de tension, trop long c'est une corvée ; et le moment exact où le jeu te propose la troisième place d'inventaire. Ces trois réglages ne demandent aucune ligne de code, seulement des chiffres à bouger et des joueurs à observer.</p>
  <p><strong>Ce que tu ne dois pas espérer du thème.</strong> Il te donne quelques semaines d'avance, pas un fossé. Le modèle a déjà été acheté par d'autres — la version sous-marine existe. Ce sont tes réglages qui feront la différence, pas le mot que tu mets devant « Adventure ».</p>
</div>

<section class="note">
  <p><strong>Méthode.</strong> Une quarantaine de thèmes compatibles avec la boucle ont été cherchés sur Roblox, sous plusieurs formulations chacun, puis recoupés avec les classements du ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}. Aucun des cinq retenus n'est occupé.</p>
  <p><strong>Limite.</strong> La recherche Roblox privilégie les gros jeux plutôt que la correspondance exacte : « personne n'y est » veut dire « aucun jeu notable n'occupe ce terrain ». Avant de te lancer, cherche toi-même le nom exact que tu comptes donner à ton jeu.</p>
</section>
</div>`;

const out = path.join(ROOT, 'reskin-cut-grass.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
