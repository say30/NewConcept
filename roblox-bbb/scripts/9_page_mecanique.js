#!/usr/bin/env node
// Etape 9 — meme moteur, autre verbe. Le modele achete est une equation
// (puissance contre resistance, butin rapporte, zones qui s'ouvrent) qui ne dit
// nulle part "couper". Voici les activites qui rentrent dedans sans toucher au code.
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));
const num = n => Number(n).toLocaleString('fr-FR');
const R = readData('refs.json');

const ref = (cle, note) => {
  const r = R[cle]; if (!r) return '';
  return `<a class="ref" href="https://www.roblox.com/games/${r.place}/" target="_blank" rel="noopener">
    ${r.icone ? `<img src="${r.icone}" alt="" width="36" height="36" loading="lazy">` : ''}
    <span><strong>${esc(r.nom)}</strong><em>${num(r.joueurs)} joueurs · ${esc(note)}</em></span></a>`;
};

// Les six rouages du modele, exprimes sans jamais dire "herbe" ni "couper".
const ROUAGES = ['La résistance', 'Ton outil', 'Ta force', 'Le butin', 'Pourquoi ça revient', 'Les zones'];

const IDEES = [
  {
    n: 1, nom: 'Pompier', titre: 'Le feu et les gens', fort: true,
    pitch: 'Tu entres dans un bâtiment en flammes avec une lance. Le feu recule quand tu l\'arroses. Au fond, des gens inconscients : tu en charges deux, un sur chaque épaule, et tu ressors les mettre en sécurité.',
    map: [
      'Le feu a des points de vie, comme l\'herbe. Un gros brasier avec une lance faible, ça prend des minutes — le mur reste doux.',
      'La lance, puis le canon, puis l\'hélicoptère largueur. Achetés avec l\'argent des sauvetages.',
      'L\'endurance. Elle monte à chaque seconde d\'arrosage, exactement comme la force montait à chaque coup.',
      'Les victimes. Deux à la fois, une par épaule — et pour une fois la limite se comprend toute seule.',
      'Le feu se propage à nouveau dès que tu sors. La régénération est déjà écrite dans le thème.',
      'Maison, immeuble, école, hôpital, gratte-ciel, raffinerie.',
    ],
    pourquoi: 'C\'est le seul des cinq où le trajet retour arrête d\'être une corvée. Tu ne rapportes pas une matière première à revendre, tu rapportes quelqu\'un. Le même code, mais le joueur ressent autre chose — et c\'est ce que tu cherches : garder le moteur sans refaire le même jeu.',
    refs: [['Firefighters', 'personne n\'occupe le terrain'], ['Rescue Animals', 'le sauvetage plaît, en petit']],
    dessiner: 'Le feu, ce sont des particules — Roblox les fournit. Les victimes sont des mannequins d\'avatar. Les bâtiments, des boîtes. Tu n\'as rien à modéliser.',
    risque: 'Il faut rester sobre sur la représentation du danger : des gens évanouis, pas blessés. Roblox est strict là-dessus.',
  },
  {
    n: 2, nom: 'Chasseur de fantômes', titre: 'L\'aspirateur',
    pitch: 'Un manoir hanté, un aspirateur sur le dos. Tu vises un fantôme, tu tires, il résiste et tu dois tenir. Ton réservoir contient deux spectres : tu remontes les vider chez le client.',
    map: [
      'La résistance du fantôme remplace la dureté de l\'herbe. Un spectre ancien avec un aspirateur d\'entrée de gamme, tu tires pendant des minutes.',
      'La puissance d\'aspiration : aspirateur de poche, puis dorsal, puis camion.',
      'La poigne. Elle monte à chaque capture réussie.',
      'Les fantômes eux-mêmes, deux par réservoir.',
      'Le manoir se repeuple la nuit. Aucune explication à inventer.',
      'Le grenier, la cave, la bibliothèque, la chapelle, le cimetière, le manoir d\'à côté.',
    ],
    pourquoi: 'Le geste change complètement : au lieu de frapper en boucle, tu maintiens une pression contre quelque chose qui résiste et qui tire dans l\'autre sens. C\'est le même calcul, mais ça ne se joue pas pareil du tout.',
    refs: [],
    dessiner: 'Un fantôme, c\'est une sphère blanche translucide avec deux yeux. C\'est l\'idée la moins coûteuse en dessin des cinq.',
    risque: 'Fort à Halloween, plus tiède ensuite. À sortir maintenant ou à assumer comme saisonnier.',
  },
  {
    n: 3, nom: 'Démolisseur', titre: 'La masse',
    pitch: 'Un bâtiment condamné. Tu tapes les murs, ils se fissurent puis s\'écroulent. Dans les gravats, du cuivre et des câbles que tu revends à la casse.',
    map: [
      'Le béton a des points de vie. Le mur porteur en a beaucoup plus que la cloison.',
      'Masse, marteau-piqueur, boule de démolition, explosifs.',
      'La force brute, montant à chaque impact.',
      'Les matériaux récupérés, deux charges à la fois.',
      'Bâtiment suivant : le chantier se réinitialise plutôt que de repousser.',
      'Cabane, pavillon, entrepôt, usine, tour, barrage.',
    ],
    pourquoi: 'La destruction est immédiatement lisible et satisfaisante, et l\'effet avant/après est bien plus spectaculaire qu\'un carré d\'herbe rasé. C\'est le meilleur des cinq pour faire une vignette qui donne envie de cliquer.',
    refs: [],
    dessiner: 'Des blocs. Littéralement. Roblox est né pour ça, et tu peux t\'en tirer sans une seule texture.',
    risque: 'C\'est le seul où la ressource ne repousse pas : il faut enchaîner les chantiers, donc en produire beaucoup.',
  },
  {
    n: 4, nom: 'Dépanneur', titre: 'Le remorquage',
    pitch: 'Des épaves sont plantées un peu partout. Tu accroches un câble et tu tires. Plus c\'est lourd, plus tu avances lentement — et le trajet retour devient l\'épreuve elle-même.',
    map: [
      'Le poids remplace les points de vie. Une voiture se traîne, un camion à peine, un avion pas du tout sans treuil.',
      'Le câble, le treuil, la dépanneuse, le tracteur.',
      'La traction, qui monte à chaque mètre parcouru sous charge.',
      'L\'épave elle-même. Une seule, mais énorme — la limite devient physique.',
      'De nouvelles épaves apparaissent pendant ton absence.',
      'Le parking, la route, la falaise, le port, la casse, le désert.',
    ],
    pourquoi: 'C\'est le plus malin des cinq sur le plan de la structure : il fusionne l\'action et le trajet retour, qui ne sont plus deux moments séparés mais un seul. Le temps mort du modèle disparaît au lieu d\'être meublé.',
    refs: [['Pull An Egg', 'tirer marche déjà, sous une autre forme']],
    dessiner: 'Des véhicules simples, ou des formes cubiques assumées. Un pack de voitures à bas polygones coûte une dizaine d\'euros.',
    risque: 'Un objet lourd traîné trop lentement devient pénible. Le réglage de la vitesse sous charge décide de tout.',
  },
  {
    n: 5, nom: 'Perceur de coffres', titre: 'La chambre forte',
    pitch: 'Une banque, une succession de portes blindées. Chaque serrure résiste selon sa qualité. Tu forces, tu ouvres, tu prends deux lingots et tu ressors avant que ça se referme.',
    map: [
      'La solidité de la serrure, exactement comme la dureté de l\'herbe.',
      'Crochets, perceuse, chalumeau, explosifs.',
      'La dextérité, qui monte à chaque serrure ouverte.',
      'Les lingots, deux dans les bras.',
      'La banque réarme ses portes quand tu es parti.',
      'Bureau de tabac, banque de quartier, banque centrale, musée, casino, réserve d\'or.',
    ],
    pourquoi: 'Le casse est un fantasme universel et l\'univers autorise une esthétique très propre, faite de couloirs et de métal — donc peu de choses à dessiner.',
    refs: [],
    dessiner: 'Des couloirs, des portes, des lingots dorés. Aucun modèle organique, que des formes droites.',
    risque: 'Tu arrives sur le terrain des jeux de vol, qui sont énormes et féroces. C\'est le pari le plus exposé des cinq.',
  },
];

const GREFFES = [
  ['On peut te prendre ce que tu portes', 'Le trajet retour devient l\'enjeu du jeu. Les deux plus gros jeux de Roblox reposent là-dessus, et ton moteur a déjà le portage.'],
  ['La sortie se referme', 'Le feu se propage derrière toi, la serrure se réarme, les fantômes reviennent. Il faut garder des ressources pour ressortir.'],
  ['Le poids plutôt que le nombre', 'Trois petites prises sûres, ou une grosse qui te ralentit. Un arbitrage plutôt qu\'une règle subie.'],
];

const html = `<title>Changer le fonctionnement, pas le décor</title>
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

.equation{background:var(--carte);border:1px solid var(--trait);border-radius:4px;padding:22px 26px}
.equation>p{margin:0 0 15px}
.rouages{display:grid;grid-template-columns:repeat(auto-fit,minmax(158px,1fr));gap:1px;
 background:var(--trait);border:1px solid var(--trait)}
.rouage{background:var(--carte);padding:12px 14px}
.rouage b{display:block;font-size:13px;margin-bottom:2px}
.rouage span{font-size:12px;color:var(--doux)}
.souligne{color:var(--chaud);font-weight:600}

.idee{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:24px 26px;margin-bottom:18px}
.idee.fort{border-color:var(--acc);border-width:2px}
.idee>header{display:flex;align-items:baseline;gap:11px;flex-wrap:wrap;margin-bottom:9px}
.rg{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:26px;
 color:var(--trait);line-height:1;letter-spacing:-.03em}
.idee h4{font-family:"Bricolage Grotesque",sans-serif;font-size:22px;margin:0;letter-spacing:-.015em}
.verbe{font-family:"JetBrains Mono",monospace;font-size:11.5px;color:var(--acc);
 border:1px solid var(--acc);border-radius:3px;padding:2px 8px}
.recommande{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;background:var(--acc);color:var(--carte);padding:3px 9px;border-radius:3px}
.pitch{margin:0 0 17px;font-size:15.5px}

.corresp{border-top:1px solid var(--trait);padding-top:14px;margin-bottom:16px}
.corresp ul{list-style:none;padding:0;margin:0;display:grid;gap:7px}
.corresp li{display:grid;grid-template-columns:132px 1fr;gap:14px;font-size:13.5px;align-items:baseline}
@media(max-width:600px){.corresp li{grid-template-columns:1fr;gap:1px}}
.corresp b{font-family:"JetBrains Mono",monospace;font-size:10.5px;text-transform:uppercase;
 letter-spacing:.06em;color:var(--doux);font-weight:700}
.corresp span{color:var(--doux)}

.grille{display:grid;grid-template-columns:1fr 1fr;gap:16px 26px}
@media(max-width:640px){.grille{grid-template-columns:1fr}}
.bloc p{margin:0;font-size:13.5px;color:var(--doux)}
.bloc.cle p{color:var(--encre);font-size:14px}
.bloc.risque h3{color:var(--chaud)}
.refs{display:flex;flex-wrap:wrap;gap:14px;margin-top:9px}
.ref{display:flex;gap:8px;align-items:center;text-decoration:none;color:inherit}
.ref img{border-radius:3px;flex:none;background:var(--trait)}
.ref span{display:flex;flex-direction:column}
.ref strong{font-size:12px;line-height:1.2}
.ref em{font-style:normal;font-family:"JetBrains Mono",monospace;font-size:9.5px;color:var(--doux)}
.ref:hover strong{color:var(--acc)}

.greffes{display:grid;gap:9px}
.gr{background:var(--carte);border-left:3px solid var(--or);padding:13px 17px}
.gr b{font-family:"Bricolage Grotesque",sans-serif;font-size:15px}
.gr p{margin:3px 0 0;font-size:13.5px;color:var(--doux)}
.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Changer le fonctionnement, pas le décor</h1>
  <p class="chapeau">Cinq jeux qui n'ont plus rien à voir avec la coupe d'herbe, et qui tournent pourtant sur exactement le même moteur que celui que tu achètes.</p>
</header>

<h2>Ce que tu achètes vraiment</h2>
<div class="equation">
  <p>Écris la boucle du modèle sans jamais prononcer le mot « herbe ». Il reste six rouages — et <span class="souligne">aucun d'eux ne dit « couper »</span>. C'est là que tu as de la place.</p>
  <div class="rouages">
    <div class="rouage"><b>Une résistance</b><span>Elle a des points de vie et monte par paliers.</span></div>
    <div class="rouage"><b>Un outil</b><span>Acheté avec l'argent, il augmente ta production.</span></div>
    <div class="rouage"><b>Une force</b><span>Elle monte toute seule à chaque geste répété.</span></div>
    <div class="rouage"><b>Un butin</b><span>Deux unités en main, à convertir en argent.</span></div>
    <div class="rouage"><b>Un aller-retour</b><span>Le butin se ramène à un vendeur fixe.</span></div>
    <div class="rouage"><b>Des zones</b><span>Elles s'ouvrent selon ta puissance, jamais brutalement.</span></div>
  </div>
</div>

<h2>Cinq autres verbes</h2>
<p class="intro">Pour chacun, la correspondance rouage par rouage : c'est ce qui prouve que ton développeur n'a pas à réécrire la logique, seulement à renommer et rhabiller. Aucun des cinq n'est occupé sur Roblox.</p>

${IDEES.map(i => `<article class="idee${i.fort ? ' fort' : ''}">
  <header><span class="rg">${String(i.n).padStart(2, '0')}</span><h4>${esc(i.nom)}</h4>
    <span class="verbe">${esc(i.titre)}</span>
    ${i.fort ? '<span class="recommande">mon choix</span>' : ''}</header>
  <p class="pitch">${esc(i.pitch)}</p>
  <div class="corresp"><h3>Rouage par rouage</h3>
    <ul>${ROUAGES.map((r, k) => `<li><b>${esc(r)}</b><span>${esc(i.map[k])}</span></li>`).join('')}</ul>
  </div>
  <div class="grille">
    <div class="bloc cle" style="grid-column:1/-1"><h3>Pourquoi ce n'est plus le même jeu</h3><p>${esc(i.pourquoi)}</p>
      ${i.refs.length ? `<div class="refs">${i.refs.map(([c, n]) => ref(c, n)).join('')}</div>` : ''}</div>
    <div class="bloc"><h3>Ce qu'il faut dessiner</h3><p>${esc(i.dessiner)}</p></div>
    <div class="bloc risque"><h3>Le risque</h3><p>${esc(i.risque)}</p></div>
  </div>
</article>`).join('')}

<h2>Trois ajouts qui marchent sur n'importe lequel</h2>
<p class="intro">Quel que soit le verbe que tu choisis, ces trois greffes se posent par-dessus et coûtent peu.</p>
<div class="greffes">
${GREFFES.map(([n, p]) => `<div class="gr"><b>${esc(n)}</b><p>${esc(p)}</p></div>`).join('')}
</div>
<div class="refs" style="margin-top:14px">
  ${ref('Steal An Egg', 'le portage disputé, premier jeu de Roblox')}
  ${ref('Steal a Brainrot', 'même principe, deuxième')}
</div>

<h2>Ce que je ferais</h2>
<div class="fin">
  <p><strong>Le pompier.</strong> C'est celui qui s'éloigne le plus de la coupe d'herbe tout en gardant le moteur intact. Le feu a des points de vie comme l'herbe, la lance remplace la faucille, l'endurance remplace la force, les zones sont des bâtiments de plus en plus grands, et le feu se propage à nouveau dès que tu sors — la régénération n'a même pas besoin d'être justifiée.</p>
  <p>Mais surtout, il règle le vrai défaut du modèle : <strong>ce que tu ramènes n'est plus une marchandise, c'est quelqu'un.</strong> Deux victimes, une par épaule — ta limite d'inventaire arrête d'être une règle arbitraire. Personne ne dira que tu as copié un jeu de coupe d'herbe.</p>
  <p><strong>Si tu veux le moins de dessin possible</strong>, prends le chasseur de fantômes : un spectre est une sphère blanche avec deux yeux. Et si tu veux la vignette la plus vendeuse, prends le démolisseur — l'avant/après d'un immeuble qui s'écroule bat n'importe quel carré d'herbe rasé.</p>
</div>

<section class="note">
  <p><strong>Vérification.</strong> Chacun de ces cinq verbes a été cherché sur Roblox sous plusieurs formulations le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}. Les jeux les plus proches trouvés sont très petits : Firefighters! à ${num((R['Firefighters'] || {}).joueurs || 0)} joueurs, Rescue Animals! à ${num((R['Rescue Animals'] || {}).joueurs || 0)}. Aucun ne fait tourner cette boucle.</p>
  <p><strong>Limite.</strong> Je décris ces correspondances à partir de la boucle telle que tu me l'as racontée, sans avoir vu le code. Fais confirmer par le développeur avant de commander : selon la façon dont le modèle est écrit, remplacer les points de vie de l'herbe par ceux d'un feu peut être une ligne à changer, ou un système entier à reprendre.</p>
</section>
</div>`;

const out = path.join(ROOT, 'refonte-mecanique.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
