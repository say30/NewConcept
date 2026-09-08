#!/usr/bin/env node
// Etape 8 — dossier de reskin : partant d'un modele achete, quels themes reprennent
// la meme mecanique et ne sont occupes par personne.
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

const IDEES = [
  {
    nom: 'La tonte',
    titre: '+1 Shear',
    champ: 'La laine sur le dos d\'une créature. Tu passes la tondeuse, la toison tombe par touffes, tu la ramasses et tu la vends.',
    repousse: 'La laine repousse toute seule — c\'est la seule justification vraiment naturelle d\'un champ qui se régénère. Pas besoin d\'inventer une excuse.',
    mondes: ['Mouton', 'Alpaga', 'Yak', 'Mammouth laineux', 'Yéti', 'Dragon à fourrure'],
    dessiner: 'La créature est un corps simple ; la toison, ce sont des dizaines de petites sphères blanches. Un pack d\'animaux à bas polygones coûte une dizaine d\'euros et t\'évite toute modélisation.',
    refs: [['Animal Hospital', 'les animaux marchent très fort'], ['Jump for Animals', 'dans les révélations du moment']],
    absence: 'Aucun jeu de tonte sur Roblox. Ni mouton, ni laine, ni toison.',
    risque: 'Il faut que la tondeuse soit agréable au son et au toucher. Si le geste n\'est pas satisfaisant, rien ne rattrape.',
    fort: true,
  },
  {
    nom: 'Le rasage',
    titre: '+1 Shave',
    champ: 'Une barbe, des cheveux, une tignasse. Tu passes le rasoir, ça tombe, tu vends les mèches.',
    repousse: 'Les poils repoussent : la boucle se justifie toute seule, et l\'attente entre deux rasages devient un levier de monétisation évident.',
    mondes: ['Client de barbier', 'Bûcheron', 'Homme des cavernes', 'Père Noël', 'Yéti', 'Géant endormi'],
    dessiner: 'Rien à modéliser du tout. La tête peut être un avatar Roblox agrandi, les poils sont de fins cylindres. C\'est le plus léger des cinq en travail graphique.',
    refs: [],
    absence: 'Rien. Les salons existants sont des tycoons de gestion, pas des jeux de coupe.',
    risque: 'Une seule tête, ça peut lasser vite. Il faut que chaque monde change vraiment de silhouette.',
    fort: false,
  },
  {
    nom: 'La rouille',
    titre: '+1 Scrape',
    champ: 'Une surface métallique rongée. Tu grattes, les plaques de rouille sautent, le métal brille dessous.',
    repousse: 'C\'est le seul des cinq où le champ ne repousse pas naturellement — il faut passer à l\'objet suivant. Ça colle mieux à une progression par niveaux qu\'à un champ infini.',
    mondes: ['Plaque de tôle', 'Vieille voiture', 'Bateau échoué', 'Sous-marin', 'Épave engloutie', 'Robot géant'],
    dessiner: 'Zéro modélisation : des surfaces planes et des petits cubes bruns. Le contraste avant/après fait tout le travail.',
    refs: [['Dig & Clean', 'le nettoyage satisfaisant marche'], ['Clean all the leaves', 'le plus gros du genre']],
    absence: 'Rien sur la rouille ni la restauration à gratter.',
    risque: 'La restauration attire un public un peu plus âgé que la moyenne Roblox. C\'est le pari le plus incertain des cinq.',
    fort: false,
  },
  {
    nom: 'Les toiles d\'araignée',
    titre: '+1 Sweep',
    champ: 'Un manoir abandonné, couvert de toiles. Tu balaies, elles se déchirent, tu récupères ce qu\'elles cachaient.',
    repousse: 'Les araignées retissent pendant que tu es parti — la justification des gains hors-ligne est déjà écrite.',
    mondes: ['Le grenier', 'La cave', 'La bibliothèque', 'La crypte', 'Le nid', 'La reine araignée'],
    dessiner: 'Des surfaces semi-transparentes et un balai. Rien de compliqué, et l\'ambiance sombre pardonne beaucoup de défauts visuels.',
    refs: [],
    absence: 'Des jeux d\'araignées existent, aucun jeu de nettoyage de toiles.',
    risque: 'Très saisonnier. Sorti après Halloween, il perd la moitié de son intérêt.',
    fort: false,
    urgence: 'Halloween est dans 7 semaines. C\'est la fenêtre.',
  },
  {
    nom: 'Le givre',
    titre: '+1 Scrape Ice',
    champ: 'Une couche de glace sur une vitre, un pare-brise, un lac gelé. Tu grattes, ça se fissure et tombe en éclats.',
    repousse: 'Le gel revient la nuit. Là encore, le champ se régénère sans qu\'on ait à l\'expliquer.',
    mondes: ['Pare-brise', 'Vitrine', 'Cabane gelée', 'Lac', 'Grotte de glace', 'Créature prise dans la glace'],
    dessiner: 'Des cubes blancs translucides. Le son du grattage porte tout le jeu.',
    refs: [],
    absence: 'Rien. Il existe un jeu de déneigement, très petit, mais aucun jeu de grattage de givre.',
    risque: 'Saisonnier lui aussi, mais la fenêtre d\'hiver est plus longue que celle d\'Halloween.',
    fort: false,
    urgence: 'À viser pour décembre.',
  },
];

const PRIS = [
  ['Les feuilles', 'Clean all the leaves', '150 M de visites, 36 000 joueurs. Intouchable.'],
  ['La neige', '❄️ Clean all the Snow!', 'Occupé, mais petit — un concurrent, pas un mur.'],
  ['Le creusage et le sable', 'Dig & Clean, Dig to Escape', 'Trois jeux solides se partagent le terrain.'],
  ['La récolte et les cultures', 'Grow a Garden', 'Très occupé, et sur une mécanique différente.'],
  ['Le lavage de maison', 'Wash The House', 'Occupé, moyen.'],
  ['L\'herbe et les haies', '+1 Cut Grass Adventure', 'C\'est ton point de départ. Ne reste pas dessus.'],
];

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

.moteur{background:var(--carte);border:1px solid var(--trait);border-radius:4px;padding:20px 24px}
.etapes{display:flex;flex-wrap:wrap;gap:8px;margin:14px 0 0;list-style:none;padding:0}
.etapes li{font-family:"JetBrains Mono",monospace;font-size:11px;background:var(--fond);
 border:1px solid var(--trait);border-radius:3px;padding:5px 10px}
.etapes li b{color:var(--acc)}

.idee{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:24px 26px;margin-bottom:18px}
.idee.fort{border-color:var(--acc);border-width:2px}
.idee>header{display:flex;align-items:baseline;gap:12px;flex-wrap:wrap;margin-bottom:5px}
.idee h4{font-family:"Bricolage Grotesque",sans-serif;font-size:24px;margin:0;letter-spacing:-.015em}
.nomjeu{font-family:"JetBrains Mono",monospace;font-size:12px;color:var(--acc);
 border:1px solid var(--acc);border-radius:3px;padding:2px 8px}
.recommande{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;background:var(--acc);color:var(--carte);padding:3px 9px;border-radius:3px}
.champ{margin:0 0 16px;font-size:15.5px}
.urgence{font-family:"JetBrains Mono",monospace;font-size:11px;color:var(--chaud);
 border-left:2px solid var(--chaud);padding-left:10px;margin:0 0 14px}
.grille{display:grid;grid-template-columns:1fr 1fr;gap:16px 26px;border-top:1px solid var(--trait);padding-top:15px}
@media(max-width:640px){.grille{grid-template-columns:1fr}}
.bloc p{margin:0;font-size:13.5px;color:var(--doux)}
.bloc.risque h3{color:var(--chaud)}
.mondes{display:flex;flex-wrap:wrap;gap:6px;list-style:none;padding:0;margin:0}
.mondes li{font-size:12px;background:var(--fond);border:1px solid var(--trait);
 border-radius:3px;padding:3px 9px}
.mondes li::before{content:counter(m) " ";counter-increment:m;
 font-family:"JetBrains Mono",monospace;font-size:9px;color:var(--doux)}
.mondes{counter-reset:m}
.refs{display:flex;flex-wrap:wrap;gap:13px;margin-top:8px}
.ref{display:flex;gap:7px;align-items:center;text-decoration:none;color:inherit}
.ref img{border-radius:3px;flex:none;background:var(--trait)}
.ref span{display:flex;flex-direction:column;min-width:0}
.ref strong{font-size:11.5px;line-height:1.2}
.ref em{font-style:normal;font-family:"JetBrains Mono",monospace;font-size:9.5px;color:var(--doux)}
.ref:hover strong{color:var(--acc)}

table{width:100%;border-collapse:collapse;font-size:13.5px;background:var(--carte);
 border:1px solid var(--trait)}
th{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;color:var(--doux);text-align:left;padding:9px 12px;border-bottom:1px solid var(--trait)}
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
  <p class="chapeau">Tu gardes le moteur, tu changes le décor. Voici les thèmes qui rentrent exactement dans la même mécanique — et que personne n'occupe sur Roblox.</p>
</header>

<h2>Le moteur que tu achètes</h2>
<div class="moteur">
  <p style="margin:0">Débarrassé de son herbe, le jeu est une boucle très réutilisable : <strong>un outil qu'on balaie sur un champ dense de petits objets qui repoussent.</strong> Tout thème qui remplit cette phrase fonctionne sans toucher au code.</p>
  <ul class="etapes">
    <li><b>1</b> Entraîner la force</li><li><b>2</b> Balayer le champ</li><li><b>3</b> Ramasser</li>
    <li><b>4</b> Vendre</li><li><b>5</b> Améliorer l'outil</li><li><b>6</b> Rebirth</li>
    <li><b>7</b> Monde suivant</li><li><b>8</b> Gains hors-ligne</li>
  </ul>
</div>

<h2>Les cinq thèmes libres</h2>
<p class="intro">Chacun a été cherché sur Roblox sous plusieurs formulations. Aucun n'est occupé. Les six mondes proposés reprennent la structure que le modèle a déjà.</p>

${IDEES.map(i => `<article class="idee${i.fort ? ' fort' : ''}">
  <header><h4>${esc(i.nom)}</h4><span class="nomjeu">${esc(i.titre)}</span>
    ${i.fort ? '<span class="recommande">mon choix</span>' : ''}</header>
  <p class="champ">${esc(i.champ)}</p>
  ${i.urgence ? `<p class="urgence">${esc(i.urgence)}</p>` : ''}
  <div class="grille">
    <div class="bloc"><h3>Pourquoi le champ repousse</h3><p>${esc(i.repousse)}</p></div>
    <div class="bloc"><h3>Ce qu'il faut dessiner</h3><p>${esc(i.dessiner)}</p></div>
    <div class="bloc" style="grid-column:1/-1"><h3>Les six mondes</h3>
      <ul class="mondes">${i.mondes.map(m => `<li>${esc(m)}</li>`).join('')}</ul></div>
    <div class="bloc"><h3>Personne n'y est</h3><p>${esc(i.absence)}</p></div>
    <div class="bloc"><h3>La demande existe</h3>
      ${i.refs.length ? `<div class="refs">${i.refs.map(([c, n]) => ref(c, n)).join('')}</div>`
        : '<p>Pas de voisin direct sur Roblox — la demande vient du format lui-même, très répandu ailleurs.</p>'}</div>
    <div class="bloc risque" style="grid-column:1/-1"><h3>Le risque</h3><p>${esc(i.risque)}</p></div>
  </div>
</article>`).join('')}

<h2>Les thèmes à ne pas prendre</h2>
<p class="intro">Ils rentrent dans la même mécanique, mais quelqu'un les occupe déjà.</p>
<div class="tw"><table>
<thead><tr><th>Thème</th><th>Qui l'occupe</th><th>État</th></tr></thead>
<tbody>${PRIS.map(([t, q, e]) => `<tr><td><strong>${esc(t)}</strong></td><td>${esc(q)}</td><td>${esc(e)}</td></tr>`).join('')}</tbody>
</table></div>

<h2>Ce que je ferais</h2>
<div class="fin">
  <p><strong>La tonte.</strong> C'est le seul des cinq où tout s'aligne : la laine repousse pour de vrai, donc la boucle n'a besoin d'aucune excuse ; les six mondes s'écrivent tout seuls du mouton au dragon ; et les animaux sont le vecteur le plus chaud de Roblox en ce moment, entre Animal Hospital et Jump for Animals dans les révélations.</p>
  <p><strong>Ton vrai travail est ailleurs que dans le thème.</strong> Le modèle te donne la mécanique, et cinquante personnes peuvent acheter le même. Ce qui te distinguera, c'est le son de la tondeuse, la façon dont la toison tombe, le rythme des paliers. C'est du réglage, pas du code — exactement ce que tu dis savoir faire.</p>
  <p><strong>Et si tu veux jouer une saison</strong>, les toiles d'araignée pour Halloween et le givre pour décembre sont des paris à date. La fenêtre d'Halloween se ferme dans sept semaines.</p>
</div>

<section class="note">
  <p><strong>Méthode.</strong> Une trentaine de thèmes compatibles avec la mécanique ont été cherchés un par un sur Roblox, sous plusieurs formulations chacun, puis recoupés avec les classements du ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}. Les chiffres de joueurs sont des instantanés.</p>
  <p><strong>Limite.</strong> La recherche Roblox privilégie les gros jeux plutôt que la correspondance exacte : « personne n'y est » veut dire « aucun jeu notable n'occupe ce terrain ». Avant de te lancer, cherche toi-même le nom exact que tu comptes donner à ton jeu.</p>
</section>
</div>`;

const out = path.join(ROOT, 'reskin-cut-grass.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
