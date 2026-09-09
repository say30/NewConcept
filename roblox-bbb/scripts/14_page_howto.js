#!/usr/bin/env node
// Etape 14 — mode d'emploi pratique : fabriquer les assets et les poser dans le jeu.
const fs = require('fs');
const path = require('path');
const { ROOT } = require('./lib');
const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));

const PARTIES = [
  {
    n: 1, titre: 'Protéger ton fichier', duree: '5 minutes',
    intro: 'À faire avant de toucher quoi que ce soit. Tu vas casser des choses, c\'est normal — l\'important est de pouvoir revenir en arrière.',
    etapes: [
      ['Duplique le fichier', 'Fais une copie de <code>Keyboard Escape.rbxl</code> et renomme-la <code>Breakfast v1.rbxl</code>. Tu travailles sur la copie, jamais sur l\'original.'],
      ['Refais une copie à chaque grande étape', 'v2, v3, v4. Ça ne coûte rien et ça t\'évitera de tout perdre le jour où une manipulation tourne mal.'],
      ['Dans Studio, active l\'enregistrement automatique', 'File → Studio Settings → Studio → AutoSave, mets un intervalle de 5 minutes.'],
    ],
  },
  {
    n: 2, titre: 'Trouver les décors actuels', duree: '20 minutes',
    intro: 'Avant de fabriquer, il faut savoir où ça se pose. Ton template a déjà 5 décors muraux quelque part — on va les repérer pour comprendre comment ils sont montés.',
    etapes: [
      ['Ouvre l\'Explorer', 'Onglet View → Explorer. C\'est l\'arborescence du jeu, à droite de l\'écran.'],
      ['Ouvre aussi Properties', 'Onglet View → Properties. C\'est là qu\'on modifie tout.'],
      ['Clique sur un décor dans le jeu', 'Dans la fenêtre 3D, clique directement sur un panneau WARNING ou une toile d\'araignée. L\'Explorer va se positionner tout seul dessus.'],
      ['Regarde ce que c\'est', 'Sous la Part sélectionnée, tu verras un objet <code>Decal</code> ou <code>Texture</code>. Clique dessus : dans Properties, la ligne <code>Texture</code> contient une adresse du type <code>rbxassetid://123456789</code>. C\'est l\'image.'],
      ['Note le chemin', 'Regarde où cette Part se trouve dans l\'arborescence — Workspace, puis probablement un dossier par étape. C\'est là que tu iras poser les tiennes.'],
    ],
  },
  {
    n: 3, titre: 'Dessiner une boîte de céréales', duree: '1 h pour la première, 15 min pour les suivantes',
    intro: 'On commence par le plus important. Une boîte de céréales, c\'est un rectangle coloré avec un nom et une tête de mascotte. Rien de plus.',
    etapes: [
      ['Ouvre Photopea', 'Va sur photopea.com. C\'est gratuit, ça marche dans le navigateur, rien à installer.'],
      ['Crée une image de 1024 × 1024 pixels', 'File → New. Roblox aime les tailles en puissance de deux : 512 ou 1024. Ne dépasse pas 1024, c\'est inutile.'],
      ['Remplis le fond d\'une couleur franche', 'Un jaune vif pour Croustis, un rose pour Fraise Crunch. Utilise les couleurs de la palette qu\'on a fixée.'],
      ['Écris le nom en gros', 'Outil Texte. Une police épaisse, une couleur qui contraste, un contour blanc autour des lettres pour que ça reste lisible de loin.'],
      ['Ajoute une tête de mascotte', 'Un cercle, deux yeux, une bouche. Vraiment. Sur un mur, à trois mètres de distance, personne ne verra plus de détail.'],
      ['Ajoute un bol en bas', 'Un demi-cercle blanc avec des petits ronds dedans. C\'est le code visuel de toutes les boîtes de céréales du monde.'],
      ['Exporte en PNG', 'File → Export as → PNG. Garde le fichier sous un nom clair : <code>boite-croustis.png</code>.'],
      ['Répète cinq fois', 'Duplique ton fichier, change la couleur de fond, le nom et la couleur de la mascotte. Les cinq suivantes vont beaucoup plus vite.'],
    ],
    piege: 'N\'utilise jamais une vraie marque. Pas de Kellogg\'s, pas de Chocapic, pas de logo existant. C\'est un motif de retrait du jeu, et Roblox modère les images. Invente tes marques — c\'est aussi plus drôle.',
  },
  {
    n: 4, titre: 'Envoyer tes images dans Roblox', duree: '10 minutes, puis de l\'attente',
    intro: 'Une image sur ton ordinateur ne sert à rien. Il faut la téléverser chez Roblox, qui la vérifie avant de la rendre utilisable.',
    etapes: [
      ['Ouvre l\'Asset Manager', 'Dans Studio, onglet View → Asset Manager. Une fenêtre s\'ouvre en bas à gauche.'],
      ['Va dans le dossier Images', 'Double-clique sur <code>Images</code>.'],
      ['Clic droit → Add Images', 'Sélectionne tes six PNG d\'un coup. Ils partent en modération.'],
      ['Attends', 'Roblox vérifie chaque image. Ça prend de quelques minutes à quelques heures. Tant que c\'est en cours, l\'image apparaît grisée.'],
      ['Récupère l\'identifiant', 'Une fois validée, clic droit sur l\'image → <code>Copy Asset ID</code>. Tu obtiens un nombre. Garde-les dans un fichier texte, tu vas t\'y perdre sinon.'],
    ],
    piege: 'Le texte dans les images est ce qui se fait refuser le plus souvent. Si une boîte est rejetée, réduis le texte ou change la police, et renvoie-la. Ce n\'est pas un blocage définitif.',
  },
  {
    n: 5, titre: 'Coller une image sur un mur', duree: '2 minutes par mur',
    intro: 'C\'est l\'opération que tu vas répéter le plus souvent. Deux façons, selon ce que tu poses.',
    etapes: [
      ['Sélectionne le mur', 'Clique sur la Part dans la fenêtre 3D.'],
      ['Ajoute un Decal', 'Dans l\'Explorer, survole la Part, clique sur le <code>+</code> qui apparaît, tape « Decal », valide.'],
      ['Colle ton identifiant', 'Sélectionne le Decal. Dans Properties, ligne <code>Texture</code>, colle <code>rbxassetid://</code> suivi du nombre copié. L\'image apparaît immédiatement.'],
      ['Choisis la face', 'Ligne <code>Face</code> dans Properties : Front, Back, Top, Bottom, Left, Right. Change jusqu\'à ce que l\'image soit du bon côté.'],
      ['Pour un carrelage, utilise Texture au lieu de Decal', 'Même manipulation, mais choisis <code>Texture</code>. Tu obtiens deux réglages en plus, <code>StudsPerTileU</code> et <code>StudsPerTileV</code>, qui font répéter le motif au lieu de l\'étirer. C\'est ce qu\'il te faut pour les murs de fond.'],
    ],
    piege: 'Un Decal s\'étire pour remplir toute la face. Si ta boîte de céréales a l\'air écrasée, ce n\'est pas l\'image qui est mauvaise : c\'est la Part qui n\'a pas les bonnes proportions. Redimensionne le cube, pas l\'image.',
  },
  {
    n: 6, titre: 'Fabriquer la cuillère', duree: '30 minutes',
    intro: 'L\'exemple type de l\'objet en volume. Deux formes, aucun logiciel de modélisation. Une fois que tu sais faire ça, tu sais faire les dix-neuf autres.',
    etapes: [
      ['Insère un cylindre', 'Onglet Home → Part → Cylinder. Il apparaît devant la caméra.'],
      ['Allonge-le', 'Outil Scale (touche R). Tire sur une poignée pour en faire un manche fin et long.'],
      ['Insère une sphère', 'Home → Part → Sphere.'],
      ['Écrase-la', 'Scale à nouveau : aplatis-la fortement sur un axe pour obtenir un ovale plat. C\'est le creux de la cuillère.'],
      ['Place-la au bout du manche', 'Outil Move (touche V pour aimanter les pièces entre elles).'],
      ['Colore les deux', 'Properties → <code>Color</code>. Un gris clair. Puis <code>Material</code> → <code>Metal</code> pour l\'aspect couvert.'],
      ['Groupe le tout', 'Sélectionne les deux Parts, <code>Ctrl+G</code>. Elles deviennent un Model unique que tu peux déplacer d\'un bloc.'],
      ['Ancre-le', 'Sélectionne le Model, coche <code>Anchored</code> dans Properties. Sans ça, ta cuillère tombe au sol au lancement du jeu.'],
    ],
    piege: 'Oublier <code>Anchored</code> est l\'erreur numéro un. Si un objet part en vrille quand tu testes, c\'est presque toujours ça.',
  },
  {
    n: 7, titre: 'Remplacer les décors du template', duree: '2 à 3 heures pour les quinze étapes',
    intro: 'Maintenant que tu sais fabriquer et poser, il reste à faire le tour du jeu.',
    etapes: [
      ['Étape par étape, pas tout en même temps', 'Prends l\'étape 1, remplace tout, teste, passe à la 2. Sinon tu ne sauras plus ce qui a cassé quoi.'],
      ['Remplace plutôt que de supprimer', 'Sur un décor existant, change seulement la ligne <code>Texture</code> du Decal par ton identifiant. Le placement, la taille et l\'orientation sont déjà réglés — tu récupères tout ce travail gratuitement.'],
      ['Recolore les murs de fond', 'Sélectionne toutes les Parts vertes d\'une étape d\'un coup, puis change <code>Color</code> une seule fois pour toutes.'],
      ['Teste après chaque étape', 'Bouton Play en haut. Traverse l\'étape en vrai. Tu verras tout de suite si un décor bloque le passage.'],
      ['Garde les 5 décors d\'origine sous la main', 'Ne les supprime pas tout de suite. Tant que ton jeu n\'est pas fini, ils te servent de repère pour comparer.'],
    ],
  },
];

const ORDRE = [
  ['Jour 1', 'Sauvegarde, repérage des décors existants, et les 6 boîtes de céréales dessinées et envoyées en modération.'],
  ['Jour 2', 'Les 3 fonds de murs et les 8 petits décors. Pendant ce temps les boîtes sont validées.'],
  ['Jour 3', 'Pose de tout ça sur les étapes 1 à 8. C\'est répétitif mais rapide une fois le geste acquis.'],
  ['Jour 4', 'Étapes 9 à 15, plus les objets en volume les plus visibles : la cuillère, le bol, la tasse.'],
  ['Jour 5', 'La vague de lait, le miel, le sirop. Réglage des vitesses et des dégâts.'],
  ['Plus tard', 'Les trois monstres, puis Monsieur Croustillant qui te servira de vignette.'],
];

const html = `<title>Comment fabriquer tout ça</title>
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
body{background:var(--fond);color:var(--encre);margin:0;font-size:15.5px;line-height:1.66;
 font-family:"Public Sans",ui-sans-serif,system-ui,sans-serif}
.page{max-width:820px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}a:focus-visible{outline:2px solid var(--acc);outline-offset:3px}
code{font-family:"JetBrains Mono",monospace;font-size:.86em;background:var(--fond);
 border:1px solid var(--trait);padding:1px 6px;border-radius:3px;white-space:nowrap}
h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:clamp(30px,5.4vw,44px);
 line-height:1.05;margin:0 0 12px;letter-spacing:-.025em;text-wrap:balance}
.chapeau{margin:0;max-width:58ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:26px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:50px 0 8px;letter-spacing:-.015em}
.intro{margin:0 0 20px;color:var(--doux);max-width:62ch}

.avant{background:var(--carte);border-left:3px solid var(--acc);padding:18px 22px;margin-bottom:26px}
.avant p{margin:0 0 10px}.avant p:last-child{margin:0}

.partie{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:22px 26px;margin-bottom:16px}
.partie>header{display:flex;align-items:baseline;gap:12px;flex-wrap:wrap;margin-bottom:7px}
.num{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:25px;
 color:var(--trait);line-height:1;letter-spacing:-.03em}
.partie h3{font-family:"Bricolage Grotesque",sans-serif;font-size:21px;margin:0;letter-spacing:-.01em}
.duree{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.06em;color:var(--doux);border:1px solid var(--trait);border-radius:3px;
 padding:3px 8px;margin-left:auto;white-space:nowrap}
.partie>p.i{margin:0 0 16px;font-size:14.5px;color:var(--doux)}
ol.etapes{margin:0;padding:0;list-style:none;counter-reset:e}
ol.etapes li{counter-increment:e;display:grid;grid-template-columns:26px 1fr;gap:13px;
 padding:9px 0;border-bottom:1px dotted var(--trait);align-items:baseline}
ol.etapes li:last-child{border-bottom:0}
ol.etapes li::before{content:counter(e);font-family:"JetBrains Mono",monospace;font-size:11px;
 font-weight:700;color:var(--acc);text-align:right}
ol.etapes b{display:block;font-weight:600;margin-bottom:1px}
ol.etapes span{font-size:14px;color:var(--doux)}
.piege{margin:16px 0 0;background:var(--fond);border-left:2px solid var(--chaud);
 padding:11px 15px;font-size:13.5px}
.piege b{color:var(--chaud);font-family:"JetBrains Mono",monospace;font-size:10px;
 text-transform:uppercase;letter-spacing:.07em;display:block;margin-bottom:3px}

.planning{width:100%;border-collapse:collapse;background:var(--carte);border:1px solid var(--trait)}
.planning td{padding:11px 14px;border-bottom:1px solid var(--trait);font-size:14.5px}
.planning td.j{font-family:"JetBrains Mono",monospace;font-size:11px;text-transform:uppercase;
 letter-spacing:.07em;color:var(--acc);white-space:nowrap;width:90px;vertical-align:top;
 padding-top:14px;font-weight:700}
.tw{overflow-x:auto}
.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Comment fabriquer tout ça</h1>
  <p class="chapeau">Le mode d'emploi, du fichier de sauvegarde jusqu'au décor posé sur le mur. Aucune étape ne demande de savoir coder ni modéliser.</p>
</header>

<div class="avant">
  <p><strong>Ce que tu vas réellement faire.</strong> Deux gestes, répétés. Le premier : dessiner une image plate dans un éditeur gratuit, l'envoyer chez Roblox, coller son identifiant sur un mur. Le second : empiler deux ou trois formes de base dans Studio pour faire un objet.</p>
  <p>C'est tout. Il n'y a pas de troisième geste, et aucun des deux ne ressemble à ce que tu as essayé avec Meshy.</p>
</div>

${PARTIES.map(p => `<section class="partie">
  <header><span class="num">${String(p.n).padStart(2, '0')}</span><h3>${esc(p.titre)}</h3>
    <span class="duree">${esc(p.duree)}</span></header>
  <p class="i">${esc(p.intro)}</p>
  <ol class="etapes">${p.etapes.map(([t, d]) => `<li><div><b>${esc(t)}</b><span>${d}</span></div></li>`).join('')}</ol>
  ${p.piege ? `<p class="piege"><b>Le piège</b>${p.piege}</p>` : ''}
</section>`).join('')}

<h2>Dans quel ordre</h2>
<p class="intro">Une répartition réaliste si tu y consacres quelques heures par jour. Les temps d\'attente de la modération sont mis à profit pour dessiner la suite.</p>
<div class="tw"><table class="planning">
<tbody>${ORDRE.map(([j, d]) => `<tr><td class="j">${esc(j)}</td><td>${esc(d)}</td></tr>`).join('')}</tbody>
</table></div>

<h2>Si tu bloques</h2>
<div class="fin">
  <p><strong>Le décor n'apparaît pas.</strong> Neuf fois sur dix, c'est la <code>Face</code> du Decal qui pointe du mauvais côté, ou l'image encore en modération. Essaie les six faces avant de chercher ailleurs.</p>
  <p><strong>L'objet tombe ou traverse le sol.</strong> C'est <code>Anchored</code> qui n'est pas coché. Toujours.</p>
  <p><strong>L'image est étirée.</strong> Ce n'est pas l'image, c'est la Part : redimensionne le cube pour qu'il ait les proportions d'une vraie boîte, haute et étroite.</p>
  <p><strong>Une image est refusée.</strong> C'est presque toujours le texte. Réduis-le, change de police, renvoie. Ça n'a rien de définitif.</p>
  <p>Et quand quelque chose te bloque vraiment : envoie-moi une capture de ton écran Studio avec l'Explorer ouvert. C'est comme ça que j'ai pu comprendre ton jeu jusqu'ici, et c'est ce qui marche le mieux.</p>
</div>
</div>`;

const out = path.join(ROOT, 'comment-faire.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
