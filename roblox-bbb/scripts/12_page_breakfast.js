#!/usr/bin/env node
// Etape 12 — dossier de production du theme petit-dejeuner pour Keyboard Escape.
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));
const num = n => Number(n || 0).toLocaleString('fr-FR');
const V = readData('verif_breakfast.json');

const PAL = [['#F4E7D3','Nappe'],['#FFFFFF','Lait'],['#F2C230','Céréale'],
             ['#D98E3B','Miel'],['#E8623C','Confiture'],['#8B5E3C','Toast'],['#3B2A1E','Café']];

const CASES = [
  ['Le décor mural', 'Des boîtes de céréales géantes posées contre les murs. Ce sont des images plates — tu en dessines vingt dans un éditeur d\'images, avec des marques inventées, et tu as vingt décors uniques sans un seul volume. C\'est le meilleur argument de ce thème pour toi.'],
  ['La vague', 'Un déluge de lait. Blanc, opaque, immédiatement lisible même sur un écran de téléphone — c\'est une meilleure vague que le chocolat, qui se confond avec le décor brun.'],
  ['La zone visqueuse', 'Une flaque de miel. Tu ralentis, tu colles, tu paniques. Le miel est doré et translucide : il se distingue du lait blanc, donc le joueur comprend qu\'il ne joue pas le même danger.'],
  ['Le sol mortel', 'Le sirop d\'érable bouillant, ou l\'huile de la poêle. Surtout pas de chocolat : tu retomberais dans le thème du jeu d\'origine.'],
  ['Ce qui écrase', 'Des piles de pancakes qui s\'effondrent, des boîtes de céréales qui basculent, des tartines éjectées du grille-pain, un pot de confiture qui tombe.'],
  ['Les petits props', 'Céréales éparpillées au sol, miettes, gouttes de lait, morceaux de sucre, rondelles de banane, pépites. Cinq formes simples, dupliquées partout.'],
  ['Les trois monstres', 'La Cuillère, le Grille-pain, la Mascotte. Détaillés plus bas.'],
];

const MONSTRES = [
  ['La Cuillère géante', 'Stage 10',
   'Elle balaie la table d\'un bord à l\'autre et te ramasse. Un cylindre pour le manche, une demi-sphère aplatie pour le creux — deux primitives, aucune modélisation.',
   'C\'est le meilleur des trois : personne n\'a jamais vu une cuillère comme monstre, et le geste de ramassage se comprend sans explication.'],
  ['Le Grille-pain', 'Stage 4',
   'Une boîte qui avance par bonds et qui éjecte des tartines brûlantes vers le haut à intervalles. Un cube, une fente, deux tartines qui montent et retombent.',
   'Le bruit du ressort qui se déclenche fait toute la tension. Tu apprends à compter les secondes entre deux éjections.'],
  ['Monsieur Croustillant', 'Stage 15',
   'La mascotte de la boîte de céréales, descendue du carton. C\'est un avatar Roblox avec une tête cubique aux couleurs de ta marque inventée. Zéro modélisation, et il porte l\'identité du jeu.',
   'Il devient ton logo, ta vignette et ton monstre final d\'un seul coup. C\'est trois problèmes réglés par un seul asset.'],
];

const STAGES = [
  [1,'La table','Ouverture large et sûre. Nappe à carreaux, miettes, apprentissage de la course.','décor'],
  [2,'Le bol','Premier sol mortel : le lait déborde du bol.','sol'],
  [3,'La boîte de céréales','Pure course entre des boîtes géantes. Décor mural uniquement.','décor'],
  [4,'Le grille-pain','Premier monstre. Les tartines éjectées servent aussi de plateformes mouvantes.','monstre'],
  [5,'Le pot de miel','Première zone visqueuse. Tu ralentis, la pression monte.','gelée'],
  [6,'L\'étagère','Sauts précis entre des paquets. Décor mural.','décor'],
  [7,'Le carton de lait','Première vague. Le carton se renverse, le lait envahit le couloir.','vague'],
  [8,'Le plan de travail','Écraseurs : les boîtes basculent depuis le haut.','écrase'],
  [9,'Le réfrigérateur','Ambiance froide, buée, lumière bleue. Décor mural, respiration visuelle.','décor'],
  [10,'Le tiroir à couverts','Deuxième monstre : la Cuillère géante balaie le couloir.','monstre'],
  [11,'La poêle','Sol mortel : huile bouillante. Sauts courts et nerveux.','sol'],
  [12,'La pile de pancakes','Écraseurs : les pancakes s\'effondrent en cascade.','écrase'],
  [13,'Le sirop','Deuxième vague, plus lente et plus mortelle que le lait.','vague'],
  [14,'Le placard','L\'étape difficile. Verticale, précise — c\'est là que les joueurs recommencent en boucle.','décor'],
  [15,'La mascotte','Troisième monstre. Monsieur Croustillant, et fin du monde.','monstre'],
];

const MONDES = [
  ['Les céréales sucrées','Le bol, la boîte, le lait. Ton monde 1.'],
  ['Le brunch salé','Bacon, œufs, poêle, toasts. Palette plus chaude et plus sombre.'],
  ['La pâtisserie du matin','Pancakes, gaufres, sirop. Le monde le plus coloré.'],
  ['Le réfrigérateur','Froid, buée, bleu. Rupture visuelle bienvenue au milieu du jeu.'],
  ['Le café','Espresso, vapeur, comptoir. Le monde le plus sombre et le plus rapide.'],
  ['L\'usine','La chaîne d\'emballage des céréales. Tapis roulants, machines, boucle bouclée.'],
];

const UI = [
  ['Speed','Croustillant','C\'est ta statistique centrale : donne-lui un nom du thème et elle cesse d\'être un chiffre générique.'],
  ['+100 Speed','Une gorgée de café','La caféine accélère. Tout le monde comprend sans qu\'on explique.'],
  ['2x Speed','Double espresso','Le doublon se justifie tout seul.'],
  ['TreadMills','Les tapis du grille-pain','Tes machines à vitesse deviennent des convoyeurs de tartines.'],
  ['Wins / trophée','Cuillères d\'or','Un objet du thème, collectionnable, et qui se dessine en trois formes.'],
  ['Level','Appétit','Monter de niveau, c\'est avoir plus faim.'],
  ['Rebirth','Nouveau jour','Le petit-déjeuner recommence chaque matin : la boucle est déjà écrite dans le thème.'],
  ['Trails','Traînée de lait ou de sirop','Deux variantes qui coûtent une couleur chacune.'],
  ['Auras','Vapeur','La vapeur de café, la buée du frigo. Des particules, pas des modèles.'],
  ['Shop','Le garde-manger','Le placard qu\'on ouvre.'],
  ['Inventory','Le plateau','Ce que tu portes tient sur un plateau.'],
  ['Items Shop','La boutique du chef','Simple et lisible.'],
];

const NOMS = [
  ['+1 Speed Breakfast Escape','25 caractères, contient +1, Speed et Escape. C\'est le plus solide.','fort'],
  ['+1 Speed Cereal Escape','Plus court et plus précis, mais t\'enferme dans les céréales si tu ajoutes d\'autres mondes.',''],
  ['+1 Cereal Keyboard Escape','Garde le mot Keyboard, qui aide à ressortir sur les recherches du genre.',''],
  ['+1 Breakfast Run','Perd Escape, qui est justement le mot sur-représenté chez les survivants. À éviter.','faible'],
];

const html = `<title>Breakfast Escape — dossier de production</title>
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
.chapeau{margin:0;max-width:62ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:22px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:52px 0 8px;letter-spacing:-.015em}
.intro{margin:0 0 20px;color:var(--doux);max-width:64ch}
h3{font-family:"JetBrains Mono",monospace;font-size:10.5px;font-weight:700;text-transform:uppercase;
 letter-spacing:.11em;color:var(--doux);margin:0 0 8px}

.verif{background:var(--carte);border-left:3px solid var(--acc);padding:18px 22px}
.verif p{margin:0 0 10px}.verif p:last-child{margin:0}
.liste{list-style:none;padding:0;margin:8px 0 0}
.liste li{display:flex;justify-content:space-between;gap:12px;align-items:baseline;
 padding:4px 0;border-bottom:1px dotted var(--trait);font-size:13.5px}
.liste li:last-child{border-bottom:0}
.liste a{text-decoration:none;overflow-wrap:anywhere}
.liste a:hover{text-decoration:underline}
.liste span{font-family:"JetBrains Mono",monospace;font-size:11px;color:var(--doux);white-space:nowrap}

.pal{display:flex;border:1px solid var(--trait);border-radius:3px;overflow:hidden;margin:16px 0 0}
.sw{flex:1;text-align:center;padding-bottom:7px;background:var(--carte)}
.sw i{display:block;height:34px}
.sw b{display:block;font-family:"JetBrains Mono",monospace;font-size:9.5px;margin-top:5px}
.sw span{font-size:10px;color:var(--doux)}

.idee{background:var(--carte);border:2px solid var(--acc);border-radius:4px;padding:20px 24px;margin-top:16px}
.idee p{margin:0 0 10px}.idee p:last-child{margin:0}

.cases{display:grid;gap:1px;background:var(--trait);border:1px solid var(--trait)}
.cas{background:var(--carte);padding:13px 16px;display:grid;grid-template-columns:150px 1fr;gap:16px}
@media(max-width:620px){.cas{grid-template-columns:1fr;gap:2px}}
.cas b{font-family:"JetBrains Mono",monospace;font-size:10.5px;text-transform:uppercase;
 letter-spacing:.06em;color:var(--doux);font-weight:700}
.cas span{font-size:13.5px;color:var(--doux)}

.monstres{display:grid;gap:12px}
.mo{background:var(--carte);border:1px solid var(--trait);border-radius:4px;padding:17px 20px}
.mo header{display:flex;align-items:baseline;gap:10px;margin-bottom:7px}
.mo h4{font-family:"Bricolage Grotesque",sans-serif;font-size:19px;margin:0}
.mo .st{font-family:"JetBrains Mono",monospace;font-size:10px;color:var(--acc);
 border:1px solid var(--acc);border-radius:3px;padding:2px 7px}
.mo p{margin:0 0 8px;font-size:13.5px;color:var(--doux)}
.mo p.pourquoi{color:var(--encre);margin:0}

.stages{width:100%;border-collapse:collapse;font-size:13.5px;background:var(--carte);border:1px solid var(--trait)}
.stages th{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;color:var(--doux);text-align:left;padding:9px 12px;border-bottom:1px solid var(--trait)}
.stages td{padding:7px 12px;border-bottom:1px solid var(--trait);vertical-align:top}
.stages td.n{font-family:"JetBrains Mono",monospace;color:var(--doux);width:34px}
.stages td.d{color:var(--doux)}
.tag{font-family:"JetBrains Mono",monospace;font-size:9px;text-transform:uppercase;
 letter-spacing:.06em;padding:2px 7px;border-radius:3px;white-space:nowrap;border:1px solid currentColor}
.tag.monstre{color:var(--chaud)}.tag.vague{color:#3d7d94}.tag.gelée{color:var(--or)}
.tag.sol{color:var(--chaud)}.tag.écrase{color:var(--or)}.tag.décor{color:var(--doux)}
.tw{overflow-x:auto}

.grille2{display:grid;grid-template-columns:repeat(auto-fit,minmax(228px,1fr));gap:10px}
.bl{background:var(--carte);border:1px solid var(--trait);border-radius:3px;padding:13px 15px}
.bl b{display:block;font-family:"Bricolage Grotesque",sans-serif;font-size:15px;margin-bottom:3px}
.bl span{font-size:12.5px;color:var(--doux)}

.noms{display:grid;gap:8px}
.nm{background:var(--carte);border:1px solid var(--trait);border-radius:3px;padding:12px 16px;
 display:grid;grid-template-columns:auto 1fr;gap:4px 14px;align-items:baseline}
.nm.fort{border-color:var(--acc);border-width:2px}
.nm.faible{opacity:.72}
.nm code{font-family:"JetBrains Mono",monospace;font-size:13.5px;font-weight:700;
 background:var(--fond);padding:3px 9px;border-radius:3px;white-space:nowrap}
.nm p{margin:0;font-size:13px;color:var(--doux);grid-column:1/-1}
@media(min-width:620px){.nm p{grid-column:2}}

.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Breakfast Escape</h1>
  <p class="chapeau">Dossier de production du thème petit-déjeuner pour ton Keyboard Escape : les sept cases remplies, les quinze étapes du monde 1, les trois monstres en primitives, et l'habillage de toute ton interface.</p>
</header>

<div class="verif">
  <p><strong>D'abord la vérification, puisque c'est ce que tu demandes désormais.</strong> Aucun dérivé du genre — ni clavier, ni « +1 Speed » — ne porte le thème petit-déjeuner. Ni dans la recherche Roblox sur douze formulations, ni parmi les 245 dérivés que j'ai recensés.</p>
  <p style="font-size:13.5px;margin-bottom:4px"><strong>Les jeux du même thème, tous genres confondus</strong> — clique et juge :</p>
  <ul class="liste">${(V.autres || []).slice(0, 6).map(g =>
    `<li><a href="${esc(g.url)}" target="_blank" rel="noopener">${esc(g.nom)}</a><span>${num(g.joueurs)} joueurs</span></li>`).join('')}</ul>
  <p style="font-size:13px;margin-top:10px">Le plus gros fait 1 082 joueurs et c'est un jeu de rôle. Aucun ne te concurrence, aucun ne bloque ton nom.</p>
</div>

<h2>La palette</h2>
<p class="intro">À recopier directement dans Studio. Le brun toast et le café servent uniquement d'ombres et de contours — ne les étale pas, sinon tu glisses vers le chocolat du jeu d'origine.</p>
<div class="pal">${PAL.map(([h, n]) => `<div class="sw"><i style="background:${h}"></i><b>${esc(h)}</b><span>${esc(n)}</span></div>`).join('')}</div>

<h2>L'idée qui rattache le thème à ta mécanique</h2>
<div class="idee">
  <p><strong>Le café, c'est la vitesse.</strong> Ta statistique centrale s'appelle Speed. Dans ce thème, elle a une justification que tout le monde comprend sans qu'on l'explique : la caféine.</p>
  <p>Tes bonus « +100 Speed » deviennent des gorgées de café. Le « 2x Speed » devient un double espresso. Les auras deviennent de la vapeur qui monte de la tasse. Ce n'est plus un thème peint par-dessus une mécanique, c'est un thème qui la raconte — et c'est exactement ce qui sépare un reskin d'un vrai jeu.</p>
</div>

<h2>Les sept cases</h2>
<div class="cases">
${CASES.map(([n, d]) => `<div class="cas"><b>${esc(n)}</b><span>${esc(d)}</span></div>`).join('')}
</div>

<h2>Les trois monstres</h2>
<p class="intro">Décrits en primitives, puisque tu ne modélises pas.</p>
<div class="monstres">
${MONSTRES.map(([n, st, comment, pourquoi]) => `<div class="mo">
  <header><h4>${esc(n)}</h4><span class="st">${esc(st)}</span></header>
  <p>${esc(comment)}</p><p class="pourquoi">${esc(pourquoi)}</p></div>`).join('')}
</div>

<h2>Les quinze étapes du monde 1</h2>
<p class="intro">Une répartition qui alterne les registres : jamais deux étapes de même nature à la suite, et une respiration visuelle avant chaque pic de difficulté. L'étape 14 reste la marche haute, comme dans le jeu d'origine.</p>
<div class="tw"><table class="stages">
<thead><tr><th></th><th>Lieu</th><th>Ce qui s'y passe</th><th>Nature</th></tr></thead>
<tbody>${STAGES.map(([n, lieu, quoi, type]) => `<tr>
<td class="n">${n}</td><td><strong>${esc(lieu)}</strong></td><td class="d">${esc(quoi)}</td>
<td><span class="tag ${type}">${esc(type)}</span></td></tr>`).join('')}</tbody>
</table></div>

<h2>Les six mondes</h2>
<p class="intro">Si tu appelles ton jeu Breakfast plutôt que Cereal, tu gardes la place pour les cinq suivants.</p>
<div class="grille2">
${MONDES.map(([n, d], i) => `<div class="bl"><b>${i + 1}. ${esc(n)}</b><span>${esc(d)}</span></div>`).join('')}
</div>

<h2>L'habillage de ton interface</h2>
<p class="intro">Relevé sur tes captures d'écran. Chaque bouton renommé coûte trente secondes et fait beaucoup pour la cohérence.</p>
<div class="tw"><table class="stages">
<thead><tr><th>Actuel</th><th>Devient</th><th>Pourquoi</th></tr></thead>
<tbody>${UI.map(([a, b, c]) => `<tr><td class="d">${esc(a)}</td><td><strong>${esc(b)}</strong></td><td class="d">${esc(c)}</td></tr>`).join('')}</tbody>
</table></div>

<h2>Le nom</h2>
<p class="intro">J'ai comparé les noms des 55 dérivés encore vivants aux 245 recensés. Deux signaux ressortent : le mot <strong>Escape</strong> est sur-représenté chez les survivants (69 % contre 60 %), et la <strong>balise entre crochets</strong> aussi (40 % contre 29 %) — c'est le <code>[UPD]</code> ou <code>[X10]</code> qui signale un jeu entretenu. Les emoji, eux, sont légèrement sous-représentés.</p>
<div class="noms">
${NOMS.map(([n, d, cls]) => `<div class="nm ${cls}"><code>${esc(n)}</code><p>${esc(d)}</p></div>`).join('')}
</div>
<p class="intro" style="margin-top:16px">Et dès ta première mise à jour, passe à <code style="font-family:'JetBrains Mono',monospace;background:var(--carte);padding:2px 7px;border-radius:3px">[UPD] +1 Speed Breakfast Escape</code>. La balise n'est pas décorative : c'est le signal que le jeu vit encore.</p>

<h2>Ce qu'il faut éviter</h2>
<div class="fin">
  <p><strong>Le chocolat.</strong> Pain au chocolat, pâte à tartiner, céréales chocolatées — chaque touche de brun sucré te rapproche du jeu d'origine, qui fait 234 000 joueurs et que tu ne battras pas sur son terrain. Garde le brun pour les contours et les toasts, jamais pour une matière principale.</p>
  <p><strong>Le mot Milk dans le titre.</strong> Milk Factory, Milk Farm, Milk Tower Defense existent déjà. Ils sont petits, mais ils encombrent le mot. Breakfast et Cereal sont libres, reste dessus.</p>
  <p><strong>Trop de couleurs.</strong> Le petit-déjeuner autorise tout l'arc-en-ciel, et c'est un piège : ta vague de lait doit rester la chose la plus visible de l'écran. Garde les murs désaturés et réserve la saturation aux dangers.</p>
</div>

<section class="note">
  <p><strong>Vérification.</strong> Douze formulations de recherche envoyées à Roblox le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}, filtrées sur les noms contenant cereal, breakfast, milk, pancake, waffle, toast, syrup, brunch, cornflake ou oatmeal, puis recoupées avec les 245 dérivés du genre. Zéro dérivé du genre trouvé.</p>
  <p>Comme toujours : la recherche Roblox privilégie les gros jeux et ne fait pas de correspondance exacte. Avant de publier, tape toi-même le nom exact que tu auras choisi.</p>
</section>
</div>`;

const out = path.join(ROOT, 'breakfast-escape.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
