#!/usr/bin/env node
// Etape 7 — page d'idees : familles de jeux sans modelisation 3D, creneaux verifies
// absents de Roblox, et distinction entre absence-opportunite et absence-avertissement.
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));
const num = n => Number(n).toLocaleString('fr-FR');
const R = readData('refs.json');

const preuve = (cle, legende) => {
  const r = R[cle]; if (!r) return '';
  return `<a class="preuve" href="https://www.roblox.com/games/${r.place}/" target="_blank" rel="noopener">
    ${r.icone ? `<img src="${r.icone}" alt="" width="40" height="40" loading="lazy">` : ''}
    <span><strong>${esc(r.nom)}</strong><em>${num(r.joueurs)} joueurs · ${esc(legende)}</em></span></a>`;
};

const FAMILLES = [
  ['L\'avatar comme décor', ['Dress To Impress', 'Catalog Avatar Creator'],
   'Les joueurs arrivent avec leurs propres vêtements. Le catalogue Roblox fournit l\'intégralité des assets, gratuitement et à l\'infini. Zéro modélisation.'],
  ['Le nettoyage satisfaisant', ['Clean all the leaves', 'Dig & Clean'],
   'Des primitives, des particules et un bon son. Aucun modèle compliqué : la satisfaction vient du geste, pas du décor.'],
  ['La devinette', ['Guess the character color', 'Guess The Person'],
   'Des images et une interface. Cinq jeux tournent entre 2 500 et 8 000 joueurs sans qu\'aucun ne domine — famille vivante et ouverte.'],
  ['La voix', ['Scream And Run'],
   'Le micro remplace les assets. Rien à dessiner, rien à modéliser, et un format que les streamers adorent filmer.'],
];

// Chaque creneau a ete verifie par une recherche dediee sur Roblox.
const OUI = [
  {
    titre: 'Le jeu de la pastèque',
    quoi: 'Tu lâches des boules dans un bocal. Deux identiques qui se touchent fusionnent en une plus grosse. Ça déborde, tu perds. Sur Roblox : des têtes de personnages, des œufs ou des brainrots à la place des fruits.',
    libre: 'Aucun jeu de fusion par chute sur Roblox. La fusion elle-même est pourtant très demandée.',
    marche: 'Suika Game a été un phénomène mondial en 2023. Sur Roblox, la fusion tourne déjà bien sans que personne n\'ait fait la version physique.',
    refs: ['Merge a Nuke'],
    assets: '10 sphères de tailles croissantes, une image plate collée sur chacune. Le moteur physique fait tout le reste.',
    brief: 'Un bocal, des collisions, une table de fusion, un score, un classement. Deux semaines de travail pour un développeur correct.',
    risque: 'Le concept est copiable en une semaine. Il faut sortir vite et tenir par les mises à jour.',
  },
  {
    titre: 'Reste silencieux',
    quoi: 'L\'inverse de Scream And Run. Une créature dort. Ton micro pilote le jeu : plus tu fais de bruit, plus elle se réveille. Tu dois traverser la salle en retenant ton souffle, avec tes amis qui essaient de te faire rire.',
    libre: 'Aucun jeu ne fait du silence la mécanique centrale. Le cri, si.',
    marche: 'Scream And Run est monté dans les tendances avec ce seul ressort. Le silence est plus drôle à regarder que le cri — c\'est un format taillé pour TikTok.',
    refs: ['Scream And Run'],
    assets: 'Une salle sombre, une créature, une jauge de bruit. C\'est l\'idée qui porte le jeu, pas les graphismes.',
    brief: 'Lire le volume du micro, une jauge, une IA qui se réveille par paliers, du multijoueur pour l\'humiliation collective.',
    risque: 'Tous les joueurs n\'ont pas de micro. Il faut une commande de repli au clavier.',
  },
  {
    titre: 'Combine deux mots',
    quoi: 'Tu commences avec Eau, Feu, Terre, Air. Tu en glisses deux l\'un sur l\'autre, ça donne un troisième mot. De proche en proche on arrive à des absurdités que les joueurs se partagent en capture d\'écran.',
    libre: 'Rien de tel sur Roblox. Le seul jeu de mots notable est un jeu d\'orthographe.',
    marche: 'Infinite Craft a explosé en 2024 sur navigateur. Le moteur du jeu, c\'est la découverte absurde — exactement ce qui se partage.',
    refs: [],
    assets: 'Du texte et des emoji. Rien d\'autre. Littéralement zéro asset graphique.',
    brief: 'Une grille d\'inventaire, du glisser-déposer, et surtout un arbre de combinaisons pré-écrit. Le travail est dans l\'écriture du contenu.',
    risque: 'Le contenu est le jeu : il faut des milliers de combinaisons écrites à la main. C\'est long, mais c\'est justement ce que tu peux faire toi-même.',
  },
  {
    titre: 'Devine le jeu Roblox',
    quoi: 'Un extrait de musique, une icône floutée, une description absurde — devine de quel jeu Roblox il s\'agit. En équipe ou en duel.',
    libre: 'La famille devinette est active, mais personne ne fait deviner les jeux Roblox eux-mêmes.',
    marche: 'C\'est le sujet que ce public connaît le mieux au monde. La reconnaissance est immédiate, donc le partage aussi.',
    refs: ['Guess The Person', 'Guess the character color'],
    assets: 'Des images et une interface de quiz.',
    brief: 'Une base de questions, un minuteur, des manches, un score d\'équipe.',
    risque: 'Attention aux droits : réutiliser les icônes d\'autres jeux peut poser problème. Passer par la musique, des indices textuels ou des icônes redessinées est plus sûr.',
  },
  {
    titre: 'Avale la ville',
    quoi: 'Tu es un trou noir au sol. Tu avales ce qui passe, tu grossis, tu avales plus gros. À la fin il ne reste rien de la carte, et le plus gros trou gagne.',
    libre: 'Aucun équivalent sur Roblox.',
    marche: 'Hole.io a été un des plus gros succès mobile de sa génération. La sensation de tout engloutir est universelle et se comprend en trois secondes.',
    refs: [],
    assets: 'Un disque noir et des objets simples déjà existants. Plus tu casses de choses, mieux c\'est.',
    brief: 'Un trou qui grandit, de la détection de taille, une partie chronométrée en multijoueur, un classement.',
    risque: 'Beaucoup d\'objets simultanés à l\'écran : il faut soigner les performances pour les téléphones.',
  },
];

const NON = [
  ['Papers, Please', 'Contrôler des documents et repérer les faux. Interface pure, aucun asset 3D — et absolument personne sur Roblox.',
   'Le rythme est lent et la lecture exigeante. Ce public joue par sessions de cinq minutes.'],
  ['Backpack Battles', 'Ranger son sac à dos pour qu\'il se batte tout seul. Grille en deux dimensions, icônes plates.',
   'Excellent jeu, mais il demande de comprendre des synergies. La courbe d\'entrée est trop raide ici.'],
  ['Mini Metro', 'Tracer des lignes de métro entre des formes géométriques. Aucun modèle à faire.',
   'Élégant et vide sur Roblox — parce que c\'est un jeu de gestion calme, à l\'opposé de ce que ce public vient chercher.'],
  ['Wordle et les jeux de lettres', 'Une grille, des lettres, une réponse par jour.',
   'Un seul jeu de mots tourne vraiment. Le format quotidien suppose une habitude d\'adulte.'],
];

const html = `<title>Cinq jeux qui manquent à Roblox</title>
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
.page{max-width:940px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}
a:focus-visible{outline:2px solid var(--acc);outline-offset:3px}
h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:clamp(31px,5.5vw,48px);
 line-height:1.04;margin:0 0 12px;letter-spacing:-.025em;text-wrap:balance}
.chapeau{margin:0;max-width:60ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:14px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:26px;margin:54px 0 8px;
 letter-spacing:-.015em;text-wrap:balance}
.intro{margin:0 0 22px;color:var(--doux);max-width:62ch}
h3{font-family:"JetBrains Mono",monospace;font-size:10.5px;font-weight:700;text-transform:uppercase;
 letter-spacing:.11em;color:var(--doux);margin:0 0 7px}

.familles{display:grid;grid-template-columns:repeat(auto-fit,minmax(212px,1fr));gap:12px}
.famille{background:var(--carte);border:1px solid var(--trait);border-radius:4px;padding:15px 17px}
.famille h4{font-family:"Bricolage Grotesque",sans-serif;font-size:17px;margin:0 0 7px}
.famille p{margin:0 0 11px;font-size:13.5px;color:var(--doux)}
.preuve{display:flex;gap:8px;align-items:center;text-decoration:none;color:inherit;margin-top:6px}
.preuve img{border-radius:3px;flex:none;background:var(--trait)}
.preuve span{display:flex;flex-direction:column;min-width:0}
.preuve strong{font-size:12px;line-height:1.2;overflow-wrap:anywhere}
.preuve em{font-style:normal;font-family:"JetBrains Mono",monospace;font-size:10px;color:var(--doux)}
.preuve:hover strong{color:var(--acc)}

.idee{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:24px 26px;margin-bottom:18px}
.idee>header{display:flex;align-items:baseline;gap:13px;margin-bottom:12px}
.idee .no{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:34px;
 color:var(--trait);line-height:.9;letter-spacing:-.04em}
.idee h4{font-family:"Bricolage Grotesque",sans-serif;font-size:23px;margin:0;letter-spacing:-.015em}
.quoi{margin:0 0 18px;font-size:15.5px}
.grille{display:grid;grid-template-columns:1fr 1fr;gap:18px 26px;
 border-top:1px solid var(--trait);padding-top:16px}
@media(max-width:660px){.grille{grid-template-columns:1fr}}
.bloc p{margin:0;font-size:13.5px;color:var(--doux)}
.bloc.risque h3{color:var(--chaud)}
.preuves{display:flex;flex-wrap:wrap;gap:14px;margin-top:9px}

.eviter{display:grid;gap:10px}
.ev{background:var(--carte);border-left:3px solid var(--or);padding:14px 18px}
.ev h4{margin:0 0 4px;font-size:16px;font-family:"Bricolage Grotesque",sans-serif}
.ev p{margin:0 0 6px;font-size:13.5px;color:var(--doux)}
.ev p.mais{color:var(--encre)}
.ev b{color:var(--or);font-family:"JetBrains Mono",monospace;font-size:10px;
 text-transform:uppercase;letter-spacing:.08em}

.pratique{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.pratique p{margin:0 0 11px}.pratique p:last-child{margin:0}
.pratique ol{margin:11px 0;padding-left:20px}
.pratique li{margin-bottom:7px}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Cinq jeux qui manquent à Roblox</h1>
  <p class="chapeau">Des concepts qui ont déjà fait leurs preuves ailleurs, que personne n'a portés sur Roblox, et qui ne demandent aucun modèle 3D — parce que c'est la contrainte qui compte ici.</p>
</header>

<h2>D'abord, ce que ta contrainte élimine</h2>
<p class="intro">Ne pas pouvoir modéliser n'est pas un handicap sur Roblox, c'est un filtre. Quatre familles entières marchent sans qu'on ait jamais à ouvrir un logiciel 3D, et elles comptent parmi les plus jouées du moment.</p>
<div class="familles">
${FAMILLES.map(([nom, refs, txt]) => `<div class="famille">
  <h4>${esc(nom)}</h4><p>${esc(txt)}</p>
  ${refs.map(r => preuve(r, 'en ce moment')).join('')}
</div>`).join('')}
</div>

<h2>Les cinq à faire</h2>
<p class="intro">Chaque créneau a été vérifié par une recherche dédiée sur Roblox : rien ne l'occupe. Et chacun s'appuie sur une preuve de demande, ici ou ailleurs.</p>

${OUI.map((o, i) => `<article class="idee">
  <header><span class="no">${String(i + 1).padStart(2, '0')}</span><h4>${esc(o.titre)}</h4></header>
  <p class="quoi">${esc(o.quoi)}</p>
  <div class="grille">
    <div class="bloc"><h3>Pourquoi c'est libre</h3><p>${esc(o.libre)}</p></div>
    <div class="bloc"><h3>Pourquoi ça marcherait</h3><p>${esc(o.marche)}</p>
      ${o.refs.length ? `<div class="preuves">${o.refs.map(r => preuve(r, 'preuve de demande')).join('')}</div>` : ''}
    </div>
    <div class="bloc"><h3>Ce qu'il faut dessiner</h3><p>${esc(o.assets)}</p></div>
    <div class="bloc"><h3>Ce que tu demandes au développeur</h3><p>${esc(o.brief)}</p></div>
    <div class="bloc risque" style="grid-column:1/-1"><h3>Le risque</h3><p>${esc(o.risque)}</p></div>
  </div>
</article>`).join('')}

<h2>Absents, mais pour une raison</h2>
<p class="intro">Ces quatre-là sont eux aussi vides sur Roblox et tout aussi légers en assets. Je te les signale pour que tu ne perdes pas de temps à les redécouvrir : leur absence est un avertissement, pas une opportunité.</p>
<div class="eviter">
${NON.map(([n, quoi, pourquoi]) => `<div class="ev">
  <h4>${esc(n)}</h4><p>${esc(quoi)}</p>
  <p class="mais"><b>mais</b> ${esc(pourquoi)}</p></div>`).join('')}
</div>

<h2>Comment tu t'y prends concrètement</h2>
<div class="pratique">
  <p>Tu ne codes pas et tu ne modélises pas. Ce n'est pas bloquant : sur ces cinq idées, la valeur n'est presque jamais dans le code, elle est dans le réglage. Combien de boules avant que ça déborde, à quel volume la créature se réveille, quelles combinaisons de mots font rire. C'est exactement ce que tu dis savoir faire.</p>
  <ol>
    <li><strong>Écris le jeu en une page</strong> avant de parler à qui que ce soit : ce que fait le joueur dans les dix premières secondes, ce qui le fait recommencer, ce qui se partage en capture d'écran.</li>
    <li><strong>Fais faire une version minimale</strong> — un développeur sur BuiltByBit ou Fiverr, quelques centaines d'euros. Pas de boutique, pas de progression : juste la boucle centrale.</li>
    <li><strong>Teste-la sur de vrais joueurs</strong> et regarde s'ils relancent une partie sans qu'on leur demande. Si non, l'idée est morte, et tu l'as su pour pas cher.</li>
    <li><strong>Ensuite seulement</strong>, ajoute la progression, la boutique et les événements. C'est là que ton flair pour les ajouts devient rentable.</li>
  </ol>
  <p>Sur les cinq, je commencerais par <strong>le jeu de la pastèque</strong>. C'est le seul où la physique fait le travail à ta place, où dix images plates suffisent comme décor, et où la preuve de demande existe des deux côtés — le succès mondial de Suika d'un côté, l'appétit déjà démontré pour la fusion sur Roblox de l'autre.</p>
</div>

<section class="note">
  <p><strong>Méthode.</strong> Une centaine de concepts issus d'autres plateformes ont été confrontés un par un à la recherche Roblox, puis recoupés avec les classements officiels (tendances, révélations, plus joués) relevés le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}. Les chiffres de joueurs sont des instantanés et varient fortement selon l'heure.</p>
  <p><strong>Limite importante.</strong> La recherche Roblox est approximative : elle privilégie les gros jeux plutôt que la correspondance exacte. « Rien trouvé » veut donc dire « aucun jeu notable n'occupe ce terrain », pas « ce jeu n'existe nulle part ». Avant de lancer quoi que ce soit, cherche toi-même le nom exact de ton concept dans Roblox.</p>
</section>
</div>`;

const out = path.join(ROOT, 'idees-jeux.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
