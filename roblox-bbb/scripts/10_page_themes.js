#!/usr/bin/env node
// Etape 10 — dossier de theme pour le modele Keyboard Escape : cinq univers qui
// remplissent les sept cases de la structure existante, sans modelisation 3D.
const fs = require('fs');
const path = require('path');
const { ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));

// Les sept elements que le modele impose, releves sur la version bonbons/chocolat.
const CASES = [
  ['Le décor mural', 'La majorité des étapes ne sont que des murs habillés. C\'est plat, c\'est le gros du travail, et ça ne demande aucun volume.'],
  ['La vague qui poursuit', 'Le raz-de-marée de chocolat. Un grand bloc qui avance et tue au contact.'],
  ['La zone visqueuse', 'La gélatine. Une matière qui ralentit ou colle au lieu de tuer.'],
  ['Ce qui écrase', 'Les gâteaux qui tombent sur les joueurs. Des blocs lourds à trajectoire verticale.'],
  ['Les petits props', 'Les bonbons de pâtisserie éparpillés. Du détail bon marché, posé en nombre.'],
  ['Le sol mortel', 'Le chocolat au sol qui sert de lave. Contact, mort.'],
  ['Les trois monstres', 'Trois poursuivants sur trois étapes distinctes. C\'est le seul endroit où il faut une silhouette.'],
];

const THEMES = [
  {
    n: 1, nom: 'Le chantier', titre: 'Béton frais', fort: true,
    palette: [['#8E8B85','Béton'],['#F2C230','Jaune sécurité'],['#E0621B','Cône'],['#2B2A28','Bitume'],['#B9C4CC','Acier']],
    accroche: 'Un immeuble en construction, la nuit. Bâches qui claquent, échafaudages, et une coulée de béton qui te course dans les couloirs.',
    remplit: [
      'Échafaudages, bâches plastiques, panneaux DANGER, tuyaux, plaques de tôle ondulée. Tout est plat ou cubique.',
      'Une coulée de béton frais, gris clair, qui déferle et durcit derrière elle.',
      'Du béton à moitié pris : tu ralentis, tu t\'enfonces, tu paniques.',
      'Poutrelles d\'acier et palettes de parpaings lâchées du plafond, plus la benne de la grue qui balaie.',
      'Cônes, casques, brouettes, sacs de ciment, briques éparses. Cinq objets recyclés partout.',
      'Bitume chaud noir et fumant, ou béton liquide. Contact, mort.',
      'La Bétonnière, le Marteau-piqueur, la Grue.',
    ],
    monstres: [
      ['La Bétonnière', 'Un cylindre couché sur deux cubes-roues, qui tourne sur lui-même en roulant vers toi. Zéro modélisation.'],
      ['Le Marteau-piqueur', 'Une silhouette d\'ouvrier en blocs qui avance par à-coups, avec un bruit de percussion. Le son fait la peur.'],
      ['La Grue', 'Pas de corps : juste un bras horizontal qui balaie l\'étage à hauteur de torse. Le plus simple des trois.'],
    ],
    pourquoi: 'C\'est le thème qui te demande le moins de retouches : ton template contient déjà des rubans de sécurité et des panneaux WARNING sur les murs. Ils passent tels quels d\'un décor zombie à un décor de chantier — tu récupères du décor au lieu de le jeter.',
    dur: 'Le gris peut vite être terne. Compense avec l\'éclairage : lampes de chantier orange, gyrophares, et du jaune partout.',
  },
  {
    n: 2, nom: 'La fonderie', titre: 'Métal en fusion',
    palette: [['#4A4E54','Acier'],['#FF6A00','Fusion'],['#FFC24A','Étincelle'],['#1A1513','Suie'],['#C4342A','Néon rouge']],
    accroche: 'Une aciérie en pleine coulée. Tout est sombre, tout est brûlant, et l\'acier liquide monte dans les couloirs.',
    remplit: [
      'Plaques d\'acier rivetées, tuyaux, jauges, passerelles grillagées, néons rouges. Des cubes et des cylindres.',
      'Une coulée d\'acier en fusion, orange incandescent. Elle éclaire toute la scène en avançant.',
      'De la scorie refroidie, pâteuse, qui colle aux pieds.',
      'Lingots lâchés d\'en haut, presse hydraulique qui descend, creuset qui bascule.',
      'Enclumes, pinces, moules, gerbes d\'étincelles. Les étincelles sont des particules, gratuites.',
      'Le métal en fusion lui-même. C\'est la lave la plus crédible qui existe.',
      'Le Creuset, le Soudeur, la Presse.',
    ],
    monstres: [
      ['Le Creuset vivant', 'Une masse orange lumineuse qui se déplace en tremblant. Une sphère émissive suffit — pas de forme à sculpter.'],
      ['Le Soudeur', 'Une silhouette en blocs avec une torche qui projette une lumière bleue. La lumière fait le personnage.'],
      ['La Presse', 'Un bloc énorme qui tombe et se relève en te suivant le long d\'un rail. Une seule pièce animée.'],
    ],
    pourquoi: 'C\'est le thème où le rendu ne dépend presque pas des modèles mais de la lumière. Un décor sombre plus des surfaces incandescentes donne une image forte avec des formes très pauvres — exactement ce qu\'il te faut.',
    dur: 'Trop sombre, on ne voit plus où sauter. Éclaire systématiquement les plateformes par en dessous.',
  },
  {
    n: 3, nom: 'La fromagerie', titre: 'Fondue',
    palette: [['#F2B21A','Cheddar'],['#FFE7A3','Crème'],['#C97B22','Croûte'],['#8B5A2B','Bois'],['#E8E2D0','Carrelage']],
    accroche: 'Une cave d\'affinage. Meules empilées jusqu\'au plafond, et une vague de fondue brûlante qui dévale les couloirs.',
    remplit: [
      'Carrelage jaune, planches, tonneaux, meules empilées contre les murs. Des cylindres et des cubes, rien d\'autre.',
      'Une vague de fondue orange, épaisse, avec des fils qui pendent.',
      'De la mozzarella filante : tu restes collé une seconde, le temps de te faire rattraper.',
      'Des meules géantes qui roulent dans les couloirs et des blocs de beurre qui tombent.',
      'Souris, râpes, couteaux, croûtes, trous de gruyère découpés dans les murs.',
      'La fondue bouillante au sol.',
      'Le Rat, la Meule, le Blob de fondue.',
    ],
    monstres: [
      ['Le Rat géant', 'Le seul qui demande un vrai modèle — et un pack de rats bas polygones coûte quelques euros.'],
      ['La Meule roulante', 'Un cylindre jaune qui roule vers toi. C\'est une primitive, littéralement.'],
      ['Le Blob de fondue', 'Une masse orange qui coule. Même astuce que le creuset : une sphère molle et brillante.'],
    ],
    pourquoi: 'C\'est le plus drôle des cinq, et donc le plus partageable. Un thème comestible fonctionne déjà très bien dans ce genre — le jeu de tête fait des milliards de visites avec des bonbons — mais personne n\'a pris le fromage.',
    dur: 'Le jaune omniprésent fatigue l\'œil. Alterne des salles en cave sombre et des salles en cuisine claire.',
  },
  {
    n: 4, nom: 'Le tombeau', titre: 'Sables mouvants',
    palette: [['#D9B382','Sable'],['#8C6A3F','Ocre'],['#E8C55A','Or'],['#2E7D74','Turquoise'],['#241C15','Ombre']],
    accroche: 'Une pyramide qu\'on n\'aurait pas dû ouvrir. Hiéroglyphes, torches, et une marée de sable qui remplit les couloirs derrière toi.',
    remplit: [
      'Hiéroglyphes — des images plates collées sur les murs, le décor mural idéal — colonnes, torches, fresques.',
      'Une marée de sable qui monte et engloutit tout, avec un nuage de poussière devant.',
      'Des sables mouvants : tu t\'enfonces lentement si tu t\'arrêtes.',
      'Des blocs de pierre lâchés du plafond, des sarcophages qui basculent, et la boule de pierre roulante.',
      'Scarabées, vases, torches, ossements, pièces d\'or éparpillées.',
      'Une fosse de sable brûlant, ou du sable noir qui aspire.',
      'La Momie, le Scorpion, la Boule.',
    ],
    monstres: [
      ['La Momie', 'Un avatar Roblox habillé de bandages du catalogue. Tu n\'as rien à modéliser du tout.'],
      ['Le Scorpion géant', 'Des cubes allongés pour le corps, des cylindres pour les pattes, une pince en deux blocs. Assemblable dans Studio.'],
      ['La Boule de pierre', 'Une sphère grise qui roule dans un couloir. La référence est universelle, tout le monde comprend en une seconde.'],
    ],
    pourquoi: 'Les hiéroglyphes sont le meilleur décor mural possible pour ta contrainte : ce sont des images plates, donc tu peux couvrir des dizaines d\'étapes avec quelques textures et zéro volume.',
    dur: 'L\'Égypte est très vue. Il faut que ta vignette sorte du lot par la couleur — pousse le turquoise, que personne n\'utilise.',
  },
  {
    n: 5, nom: 'Le cirque', titre: 'Chapiteau',
    palette: [['#C4243A','Rouge cirque'],['#F5F0E6','Toile'],['#F2C230','Ampoule'],['#5B2C83','Violet'],['#1C1A26','Coulisses']],
    accroche: 'Un cirque abandonné où le spectacle continue quand même. Rayures rouges, ampoules qui grésillent, et un chapiteau qui s\'effondre derrière toi.',
    remplit: [
      'Rayures rouge et blanc, affiches, guirlandes d\'ampoules, rideaux de velours. Des plans et des couleurs franches.',
      'Une vague de barbe à papa rose qui déferle et engloutit la piste.',
      'Du caramel collant qui te retient au sol.',
      'Boulets de canon, massues de jonglage, la grosse caisse qui roule, les gradins qui s\'effondrent.',
      'Ballons, quilles, tickets, pop-corn, cerceaux.',
      'La fosse aux fauves, ou un cerceau enflammé au sol.',
      'Le Clown, l\'Homme-canon, le Diable en boîte.',
    ],
    monstres: [
      ['Le Clown', 'Un avatar Roblox avec une tête de clown du catalogue. Le plus efficace pour l\'effet, le moins cher à produire.'],
      ['L\'Homme-canon', 'Il ne marche pas : il est tiré et retombe en travers de ton chemin. Une trajectoire, pas un personnage.'],
      ['Le Diable en boîte', 'Un cube qui s\'ouvre et un ressort qui jaillit. Deux primitives et une animation de ressort.'],
    ],
    pourquoi: 'Le clown est une valeur sûre chez ce public, et la palette rouge-blanc-or donne une vignette qui se repère instantanément dans une grille de jeux — c\'est un avantage concret sur un thème gris.',
    dur: 'Le cirque effrayant est très exploité ailleurs sur Roblox, même s\'il est libre dans ce genre-ci. Assume le côté festif plutôt que l\'horreur.',
  },
];

const LIBRES = ['Les abysses', 'La décharge', 'La raffinerie', 'Le marais', 'Le restaurant de ramen'];
const PRIS = [
  ['Bonbons et chocolat', 'le jeu d\'origine, 234 000 joueurs'],
  ['Peinture', 'sept jeux, dont Paint My Keyboard'],
  ['Gelée, miel, beurre, glace', 'tous pris, et par de gros jeux'],
  ['Zombie et slime', 'c\'est le thème de ton fichier actuel'],
  ['Neige, sable de plage, eau', 'occupés, en petit'],
];

const swatch = p => `<div class="pal">${p.map(([h, n]) =>
  `<div class="sw"><i style="background:${h}"></i><b>${esc(h)}</b><span>${esc(n)}</span></div>`).join('')}</div>`;

const html = `<title>Cinq thèmes pour Keyboard Escape</title>
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
.page{max-width:920px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}a:focus-visible{outline:2px solid var(--acc);outline-offset:3px}
h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:clamp(30px,5.4vw,45px);
 line-height:1.05;margin:0 0 12px;letter-spacing:-.025em;text-wrap:balance}
.chapeau{margin:0;max-width:60ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:34px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:52px 0 8px;letter-spacing:-.015em}
.intro{margin:0 0 22px;color:var(--doux);max-width:62ch}
h3{font-family:"JetBrains Mono",monospace;font-size:10.5px;font-weight:700;text-transform:uppercase;
 letter-spacing:.11em;color:var(--doux);margin:0 0 7px}

.cases{display:grid;grid-template-columns:repeat(auto-fit,minmax(232px,1fr));gap:1px;
 background:var(--trait);border:1px solid var(--trait)}
.cas{background:var(--carte);padding:13px 15px}
.cas b{display:block;font-size:13.5px;margin-bottom:2px}
.cas span{font-size:12.5px;color:var(--doux)}

.theme{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:24px 26px;margin-bottom:18px}
.theme.fort{border-color:var(--acc);border-width:2px}
.theme>header{display:flex;align-items:baseline;gap:11px;flex-wrap:wrap;margin-bottom:9px}
.rg{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:26px;
 color:var(--trait);line-height:1;letter-spacing:-.03em}
.theme h4{font-family:"Bricolage Grotesque",sans-serif;font-size:23px;margin:0;letter-spacing:-.015em}
.sous{font-family:"JetBrains Mono",monospace;font-size:11.5px;color:var(--acc);
 border:1px solid var(--acc);border-radius:3px;padding:2px 8px}
.recommande{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;background:var(--acc);color:var(--carte);padding:3px 9px;border-radius:3px}
.accroche{margin:0 0 16px;font-size:15.5px}

.pal{display:flex;flex-wrap:wrap;gap:0;margin:0 0 18px;border:1px solid var(--trait);
 border-radius:3px;overflow:hidden}
.sw{flex:1 1 92px;padding:0 0 8px;text-align:center;background:var(--carte);
 border-right:1px solid var(--trait)}
.sw:last-child{border-right:0}
.sw i{display:block;height:38px}
.sw b{display:block;font-family:"JetBrains Mono",monospace;font-size:10px;margin-top:6px;
 font-weight:700;letter-spacing:.02em}
.sw span{font-size:10.5px;color:var(--doux)}

.remplit{border-top:1px solid var(--trait);padding-top:15px;margin-bottom:16px}
.remplit ul{list-style:none;padding:0;margin:0;display:grid;gap:7px}
.remplit li{display:grid;grid-template-columns:152px 1fr;gap:14px;font-size:13.5px;align-items:baseline}
@media(max-width:620px){.remplit li{grid-template-columns:1fr;gap:1px}}
.remplit b{font-family:"JetBrains Mono",monospace;font-size:10.5px;text-transform:uppercase;
 letter-spacing:.06em;color:var(--doux);font-weight:700}
.remplit span{color:var(--doux)}

.monstres{display:grid;grid-template-columns:repeat(auto-fit,minmax(216px,1fr));gap:10px;margin-bottom:16px}
.mo{background:var(--fond);border:1px solid var(--trait);border-radius:3px;padding:12px 14px}
.mo b{display:block;font-size:14px;font-family:"Bricolage Grotesque",sans-serif;margin-bottom:3px}
.mo span{font-size:12.5px;color:var(--doux)}

.grille{display:grid;grid-template-columns:1fr 1fr;gap:16px 26px}
@media(max-width:640px){.grille{grid-template-columns:1fr}}
.bloc p{margin:0;font-size:13.5px;color:var(--doux)}
.bloc.cle p{color:var(--encre);font-size:14px}
.bloc.risque h3{color:var(--chaud)}

table{width:100%;border-collapse:collapse;font-size:13.5px;background:var(--carte);border:1px solid var(--trait)}
th{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;letter-spacing:.08em;
 color:var(--doux);text-align:left;padding:9px 12px;border-bottom:1px solid var(--trait)}
td{padding:8px 12px;border-bottom:1px solid var(--trait)}
.tw{overflow-x:auto}
.autres{display:flex;flex-wrap:wrap;gap:7px;margin-top:12px;list-style:none;padding:0}
.autres li{font-size:12.5px;background:var(--carte);border:1px solid var(--trait);
 border-radius:3px;padding:4px 11px}
.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Cinq thèmes pour Keyboard Escape</h1>
  <p class="chapeau">Cinq univers qui remplissent exactement la structure de ton modèle — vague, gelée, écraseurs, sol mortel, trois monstres — sans qu'aucun ne demande de modélisation. Tous vérifiés absents des 245 dérivés du genre.</p>
</header>

<h2>Les sept cases à remplir</h2>
<p class="intro">Relevées sur la version bonbons et chocolat. Un thème n'est bon que s'il les remplit toutes les sept de façon évidente — sinon il faudra inventer, et inventer coûte cher.</p>
<div class="cases">
${CASES.map(([n, d]) => `<div class="cas"><b>${esc(n)}</b><span>${esc(d)}</span></div>`).join('')}
</div>

<h2>Les cinq thèmes</h2>
<p class="intro">Chaque palette est donnée en codes hexadécimaux, à recopier directement dans Studio. Chaque monstre est décrit par les primitives qui le composent.</p>

${THEMES.map(t => `<article class="theme${t.fort ? ' fort' : ''}">
  <header><span class="rg">${String(t.n).padStart(2, '0')}</span><h4>${esc(t.nom)}</h4>
    <span class="sous">${esc(t.titre)}</span>
    ${t.fort ? '<span class="recommande">mon choix</span>' : ''}</header>
  <p class="accroche">${esc(t.accroche)}</p>
  ${swatch(t.palette)}
  <div class="remplit"><h3>Les sept cases</h3>
    <ul>${CASES.map(([n], k) => `<li><b>${esc(n)}</b><span>${esc(t.remplit[k])}</span></li>`).join('')}</ul>
  </div>
  <h3>Les trois monstres, en pièces détachées</h3>
  <div class="monstres">${t.monstres.map(([n, d]) => `<div class="mo"><b>${esc(n)}</b><span>${esc(d)}</span></div>`).join('')}</div>
  <div class="grille">
    <div class="bloc cle"><h3>Pourquoi celui-là</h3><p>${esc(t.pourquoi)}</p></div>
    <div class="bloc risque"><h3>Le piège</h3><p>${esc(t.dur)}</p></div>
  </div>
</article>`).join('')}

<h2>Ce qui est déjà pris</h2>
<p class="intro">Relevé sur les 245 dérivés du genre que j'ai recensés.</p>
<div class="tw"><table>
<thead><tr><th>Thème</th><th>Qui l'occupe</th></tr></thead>
<tbody>${PRIS.map(([t, q]) => `<tr><td><strong>${esc(t)}</strong></td><td>${esc(q)}</td></tr>`).join('')}</tbody>
</table></div>
<p class="intro" style="margin-top:20px">Libres également, si aucun des cinq ne te parle :</p>
<ul class="autres">${LIBRES.map(l => `<li>${esc(l)}</li>`).join('')}</ul>

<h2>Ce que je ferais</h2>
<div class="fin">
  <p><strong>Le chantier.</strong> Pas parce qu'il est le plus joli — la fonderie et le cirque le battent là-dessus — mais parce qu'il est le moins cher à produire à partir de ce que tu as déjà. Regarde tes captures : il y a des <strong>rubans de sécurité et des panneaux WARNING sur les murs</strong>. En thème zombie ils sont du décor de hasard ; en thème chantier ils sont exactement à leur place. Tu récupères du décor au lieu de le jeter.</p>
  <p>Et le béton frais est une des rares matières qui remplit les trois états dont tu as besoin sans effort : liquide qui déferle, pâteux qui ralentit, durci qui construit le décor. Une seule matière, trois usages, une seule couleur à régler.</p>
  <p><strong>Si tu veux le plus fort visuellement</strong>, prends la fonderie : là, ce n'est pas la modélisation qui fait l'image, c'est la lumière. Un couloir noir et une coulée orange incandescente donnent une capture spectaculaire avec des formes très pauvres.</p>
</div>

<section class="note">
  <p><strong>Vérification.</strong> Les cinq thèmes ont été cherchés dans les 245 dérivés du genre que j'ai recensés, puis sur la recherche Roblox le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}. Aucun n'est occupé. Seule la peinture, que j'avais envisagée, s'est révélée prise par sept jeux.</p>
  <p><strong>Ce qui va vite.</strong> Le jeu de tête du genre est passé de 148 000 à 234 000 joueurs en vingt-quatre heures, et une cinquantaine de dérivés sortent chaque mois. Ces thèmes sont libres aujourd'hui — pas nécessairement dans deux mois.</p>
</section>
</div>`;

const out = path.join(ROOT, 'themes-keyboard.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
