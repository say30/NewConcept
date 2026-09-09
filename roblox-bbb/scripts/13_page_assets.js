#!/usr/bin/env node
// Etape 13 — liste de courses des assets pour +1 Speed Breakfast Escape.
// Objectif : dire combien il en faut, lesquels, et lesquels sont des images plates.
const fs = require('fs');
const path = require('path');
const { ROOT } = require('./lib');
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));

// type : image = dessin plat colle sur un mur | forme = assemblage de blocs Roblox
const LOTS = [
  { nom: 'Le fond des murs', n: 3, type: 'image',
    intro: 'La surface de base, répétée à l\'infini derrière tout le reste. Trois suffisent pour les quinze étapes.',
    items: [
      ['Carrelage de cuisine', 'Blanc cassé, joints beiges. Le fond par défaut.'],
      ['Papier peint à motifs', 'Petits fruits ou petits pois sur fond crème. Pour les étapes calmes.'],
      ['Porte de placard', 'Planches de bois clair. Pour les étapes 6, 9 et 14.'],
    ] },
  { nom: 'Les grands décors plats', n: 12, type: 'image',
    intro: 'C\'est le cœur du travail, et c\'est du dessin, pas de la 3D. Chacun est une image collée sur un simple cube.',
    items: [
      ['6 boîtes de céréales', 'Six marques inventées : Croustis, Miel Pops, Fraise Crunch, Banana Loops, Milk Stars, Coco Crisp. Même cube, six images différentes.'],
      ['2 briques de lait', 'Une entière debout, une renversée qui coule.'],
      ['1 bouteille de jus d\'orange', 'Orange vif, la seule tache de cette couleur.'],
      ['1 pot de confiture', 'Rouge fraise, avec l\'étiquette.'],
      ['1 pot de miel', 'Doré, forme trapue.'],
      ['1 paquet de café', 'Brun foncé. Sert aussi d\'icône pour tes bonus de vitesse.'],
    ] },
  { nom: 'Les petits décors plats', n: 8, type: 'image',
    intro: 'De la saleté et du détail, à disperser partout. C\'est ce qui manque au jeu d\'origine et qui fait qu\'un mur a l\'air habité.',
    items: [
      ['Éclaboussure de lait', 'Trois tailles à partir du même dessin.'],
      ['Miettes', 'Semées au pied des murs.'],
      ['Tache de café', 'Ronde, marron, comme un fond de tasse.'],
      ['Post-it', 'Jaune, avec un mot griffonné.'],
      ['Magnet de frigo', 'Lettres colorées, comme sur un vrai frigo.'],
      ['Carte de recette', 'Fiche cartonnée épinglée.'],
      ['Calendrier', 'Une page, un mois, un jour entouré.'],
      ['Horloge murale', 'Aiguilles sur 7 h du matin. Détail qui raconte l\'heure du jeu.'],
    ] },
  { nom: 'Les objets en volume', n: 10, type: 'forme',
    intro: 'Ceux-là ont une épaisseur, mais tous sont des cubes, des cylindres ou des sphères assemblés dans Studio. Aucun logiciel de modélisation.',
    items: [
      ['Cuillère', 'Un cylindre + une demi-sphère aplatie.'],
      ['Fourchette', 'Un cylindre + trois petits cubes.'],
      ['Céréale en anneau', 'Un tore. Roblox en fournit un.'],
      ['Morceau de sucre', 'Un cube blanc. Littéralement.'],
      ['Rondelle de banane', 'Un cylindre très plat, jaune.'],
      ['Toast', 'Un cube aplati, coins arrondis.'],
      ['Pile de pancakes', 'Trois cylindres plats empilés.'],
      ['Tasse de café', 'Un cylindre creux + une anse en tore coupé.'],
      ['Bol', 'Une demi-sphère creuse.'],
      ['Boîte de céréales en volume', 'Le cube qui reçoit tes six images. Un seul objet, six apparences.'],
    ] },
  { nom: 'Les dangers', n: 6, type: 'forme',
    intro: 'Les pièces qui tuent ou qui gênent. Elles bougent, donc elles demandent un peu de script — mais leur forme reste simple.',
    items: [
      ['La vague de lait', 'Un gros bloc blanc opaque qui avance. Le plus important du jeu : il doit être visible de loin.'],
      ['La flaque de miel', 'Une dalle dorée translucide qui ralentit.'],
      ['Le sol de sirop', 'Une dalle brune brillante qui tue au contact.'],
      ['Les pancakes qui tombent', 'Tes cylindres plats, lâchés du plafond.'],
      ['Les tranches de pain qui se resserrent', 'Deux gros cubes qui se rapprochent. Le joueur est pris en sandwich — c\'est ton équivalent des murs de gâteau.'],
      ['Le grille-pain', 'Un cube avec une fente et deux toasts qui jaillissent.'],
    ] },
  { nom: 'Les effets à l\'écran', n: 3, type: 'image',
    intro: 'Pas du décor, mais des petites images qui apparaissent pendant la course. Ce sont elles qui portent l\'idée du café — il n\'y a rien à ramasser au sol dans ton jeu, la vitesse monte toute seule quand tu cours.',
    items: [
      ['Le « +1 » qui monte', 'Le chiffre existe déjà. Ajoute derrière lui un petit grain de café ou un nuage de vapeur qui s\'envole. C\'est ça, l\'idée du café : un détail visuel sur un chiffre qui était déjà là.'],
      ['La vapeur', 'Pour les auras. Un panache blanc qui monte, comme au-dessus d\'une tasse.'],
      ['La traînée de lait', 'Pour les trails. Une bande blanche crémeuse derrière le joueur. Une deuxième version dorée pour le sirop.'],
    ] },
  { nom: 'Les monstres', n: 3, type: 'forme',
    intro: 'Les seules pièces qui demandent un peu de soin. Deux sur trois sont des assemblages, le troisième est un avatar.',
    items: [
      ['La Cuillère géante', 'La cuillère de la liste précédente, agrandie. Tu la fabriques une fois, tu l\'utilises deux fois.'],
      ['Le Grille-pain', 'Le même que dans les dangers, en plus gros et qui se déplace.'],
      ['Monsieur Croustillant', 'Un avatar Roblox avec une tête cubique aux couleurs de ta marque. Il sert aussi de logo et de vignette.'],
    ] },
];

const ASTUCES = [
  ['Un cube, six boîtes',
   'Tu fabriques UN cube aux proportions d\'une boîte de céréales. Ensuite tu colles une image différente sur la face avant de chaque copie. Six boîtes différentes, un seul objet fabriqué. C\'est ce multiplicateur qui te permet d\'avoir vingt décors alors que le jeu d\'origine en a cinq.'],
  ['La même image en trois tailles',
   'Une éclaboussure de lait posée en grand sur un mur, en moyen au sol, en petit sur une boîte : ça fait trois décors avec un seul dessin.'],
  ['Tourner et retourner',
   'La même image retournée horizontalement ne se reconnaît pas. Tes huit petits décors deviennent seize placements différents sans rien redessiner.'],
  ['Deux couleurs, deux ambiances',
   'Le même carrelage en beige chaud pour la table, en bleu froid pour le réfrigérateur. Le joueur croit changer de monde, tu n\'as changé qu\'une teinte.'],
];

const total = LOTS.reduce((a, l) => a + l.n, 0);
const images = LOTS.filter(l => l.type === 'image').reduce((a, l) => a + l.n, 0);
const formes = total - images;

const html = `<title>La liste des assets</title>
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
body{background:var(--fond);color:var(--encre);margin:0;font-size:15.5px;line-height:1.65;
 font-family:"Public Sans",ui-sans-serif,system-ui,sans-serif}
.page{max-width:860px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}a:focus-visible{outline:2px solid var(--acc);outline-offset:3px}
h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:clamp(30px,5.4vw,44px);
 line-height:1.05;margin:0 0 12px;letter-spacing:-.025em;text-wrap:balance}
.chapeau{margin:0;max-width:58ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:26px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:50px 0 8px;letter-spacing:-.015em}
.intro{margin:0 0 20px;color:var(--doux);max-width:62ch}

.compte{display:grid;grid-template-columns:repeat(auto-fit,minmax(158px,1fr));gap:1px;
 background:var(--trait);border:1px solid var(--trait)}
.c{background:var(--carte);padding:16px 18px}
.c b{display:block;font-family:"JetBrains Mono",monospace;font-size:32px;font-weight:700;
 line-height:1;letter-spacing:-.02em}
.c span{display:block;font-size:13px;color:var(--doux);margin-top:5px}
.c.vert b{color:var(--acc)}

.explique{background:var(--carte);border-left:3px solid var(--acc);padding:18px 22px;margin-top:18px}
.explique p{margin:0 0 10px}.explique p:last-child{margin:0}

.lot{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:20px 24px;margin-bottom:14px}
.lot>header{display:flex;align-items:baseline;gap:11px;flex-wrap:wrap;margin-bottom:6px}
.lot h3{font-family:"Bricolage Grotesque",sans-serif;font-size:20px;margin:0;letter-spacing:-.01em}
.nb{font-family:"JetBrains Mono",monospace;font-size:13px;font-weight:700;color:var(--acc)}
.type{font-family:"JetBrains Mono",monospace;font-size:9.5px;text-transform:uppercase;
 letter-spacing:.07em;padding:3px 8px;border-radius:3px;margin-left:auto;border:1px solid currentColor}
.type.image{color:var(--acc)}
.type.forme{color:var(--or)}
.lot>p{margin:0 0 14px;font-size:14px;color:var(--doux)}
.items{list-style:none;padding:0;margin:0;display:grid;gap:6px}
.items li{display:grid;grid-template-columns:210px 1fr;gap:16px;font-size:14px;align-items:baseline;
 padding:5px 0;border-bottom:1px dotted var(--trait)}
.items li:last-child{border-bottom:0}
@media(max-width:620px){.items li{grid-template-columns:1fr;gap:1px}}
.items b{font-weight:600}
.items span{color:var(--doux);font-size:13.5px}

.astuce{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:16px 20px;margin-bottom:10px}
.astuce b{display:block;font-family:"Bricolage Grotesque",sans-serif;font-size:17px;margin-bottom:5px}
.astuce span{font-size:14px;color:var(--doux)}

.outils{display:grid;grid-template-columns:repeat(auto-fit,minmax(215px,1fr));gap:10px}
.ou{background:var(--carte);border:1px solid var(--trait);border-radius:3px;padding:14px 16px}
.ou b{display:block;font-size:15px;margin-bottom:3px}
.ou span{font-size:13px;color:var(--doux)}

.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
.note{margin-top:50px;padding-top:22px;border-top:1px solid var(--trait);font-size:13.5px;
 color:var(--doux);max-width:68ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>La liste des assets</h1>
  <p class="chapeau">Tout ce qu'il faut fabriquer pour habiller <strong>+1 Speed Breakfast Escape</strong>, compté pièce par pièce. Le jeu d'origine se contente de 5 décors muraux. On monte à 23.</p>
</header>

<div class="compte">
  <div class="c"><b>${total}</b><span>pièces en tout</span></div>
  <div class="c vert"><b>${images}</b><span>sont des images plates</span></div>
  <div class="c"><b>${formes}</b><span>sont des assemblages de blocs</span></div>
  <div class="c vert"><b>0</b><span>demandent de la modélisation</span></div>
</div>

<div class="explique">
  <p><strong>La différence entre les deux colonnes est ce qui compte pour toi.</strong></p>
  <p>Une <strong>image plate</strong>, c'est un dessin que tu colles sur un mur ou sur la face d'un cube. Tu le fais dans un éditeur d'images, comme une affiche. Ce n'est pas de la 3D, c'est du dessin — et c'est là qu'on met les deux tiers du décor.</p>
  <p>Un <strong>assemblage de blocs</strong>, c'est un objet fait de cubes, cylindres et sphères empilés directement dans Roblox Studio. Une cuillère, c'est un cylindre plus une demi-sphère écrasée. Tu ne quittes jamais Studio, tu n'ouvres jamais Blender ni Meshy.</p>
</div>

<h2>Le détail, lot par lot</h2>

${LOTS.map(l => `<section class="lot">
  <header><h3>${esc(l.nom)}</h3><span class="nb">${l.n} pièces</span>
    <span class="type ${l.type}">${l.type === 'image' ? 'image plate' : 'blocs'}</span></header>
  <p>${esc(l.intro)}</p>
  <ul class="items">${l.items.map(([n, d]) => `<li><b>${esc(n)}</b><span>${esc(d)}</span></li>`).join('')}</ul>
</section>`).join('')}

<h2>Comment 23 décors coûtent moins cher que 5</h2>
<p class="intro">Le jeu d'origine a peu de décors parce qu'il a fabriqué chaque décor séparément. Toi, tu multiplies.</p>
${ASTUCES.map(([n, d]) => `<div class="astuce"><b>${esc(n)}</b><span>${esc(d)}</span></div>`).join('')}

<h2>Avec quoi fabriquer les images</h2>
<p class="intro">Aucun de ces outils ne demande de savoir modéliser. Ce sont des éditeurs d'images.</p>
<div class="outils">
  <div class="ou"><b>Photopea</b><span>Gratuit, dans le navigateur, fonctionne comme Photoshop. Le plus complet pour des boîtes de céréales.</span></div>
  <div class="ou"><b>Canva</b><span>Gratuit, plus simple. Parfait pour les post-it, calendriers et étiquettes.</span></div>
  <div class="ou"><b>Figma</b><span>Gratuit, très bon pour les formes nettes et les logos de tes marques inventées.</span></div>
  <div class="ou"><b>Roblox Studio</b><span>Pour tout le reste. Les 19 objets en volume s'y fabriquent sans rien installer.</span></div>
</div>

<h2>Par où commencer</h2>
<div class="fin">
  <p><strong>Fais les six boîtes de céréales en premier.</strong> Ce sont elles qui donneront son identité au jeu, et une fois le premier gabarit dessiné, les cinq autres se font en changeant les couleurs et le nom. Compte une demi-journée pour les six.</p>
  <p><strong>Ensuite la vague de lait.</strong> C'est la pièce la plus vue du jeu et la plus simple : un gros bloc blanc. Ne passe pas trois jours dessus, passe-les à régler sa vitesse.</p>
  <p><strong>Garde Monsieur Croustillant pour la fin.</strong> Il te servira de logo et de vignette, donc tu le dessineras mieux une fois que tu auras vu le reste du jeu monté.</p>
  <p>Et si tu n'as le temps que pour la moitié : les <strong>3 fonds de murs</strong> plus les <strong>6 boîtes</strong> plus les <strong>8 petits décors</strong> suffisent à habiller les quinze étapes. Ça fait 17 dessins, et zéro modélisation.</p>
</div>

<section class="note">
  <p>Les 5 décors muraux du jeu d'origine que tu as comptés ne sont effectivement que les décors : la vague, les remontées, les murs qui se resserrent et le sol mortel sont des pièces de jeu, comptées ici dans la catégorie « dangers ».</p>
</section>
</div>`;

const out = path.join(ROOT, 'assets-breakfast.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${total} pieces (${images} images, ${formes} formes)`);
