#!/usr/bin/env node
// Etape 9 — refonte de la boucle : que changer au fonctionnement, plutot qu'au theme,
// pour que le modele achete cesse d'etre une enieme copie.
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

const IDEES = [
  {
    n: 1, nom: 'On peut te voler ton butin', cout: 'faible', fort: true,
    change: 'Le couloir devient commun à tout le serveur. Quand tu remontes avec tes deux idoles dans les bras, n\'importe qui peut te percuter et te les prendre. Toi aussi, tu peux attendre à la sortie plutôt que couper.',
    reutilise: 'Tout. Le portage existe déjà, il suffit d\'autoriser le transfert entre joueurs.',
    ajoute: 'Une détection de contact, une chute d\'objet, et un délai avant de pouvoir revoler. Quelques jours de travail.',
    pourquoi: 'C\'est la formule la plus puissante de Roblox aujourd\'hui, et ton modèle en possède déjà la moitié sans l\'exploiter. Un jeu de vol, c\'est exactement « transporter un objet d\'un point A à un point B pendant que d\'autres essaient de te le prendre ». Ton trajet retour est ce trajet-là, mais personne ne t\'y menace.',
    refs: [['Steal An Egg', 'premier jeu de Roblox'], ['Steal a Brainrot', 'deuxième'], ['Jump To Steal Soccer Players', 'la formule greffée ailleurs']],
    risque: 'Le vol peut dégoûter les joueurs faibles. Il faut une zone sûre près du vendeur et un plafond sur ce qu\'on peut perdre d\'affilée.',
  },
  {
    n: 2, nom: 'Le couloir se referme derrière toi', cout: 'faible',
    change: 'La végétation repousse pendant que tu t\'enfonces. Plus tu vas loin, plus il faudra couper pour ressortir. Tu dois garder de la force en réserve pour le retour.',
    reutilise: 'Le système de repousse existe déjà — il s\'applique quand tu sors. Il suffit de le rendre continu et plus rapide.',
    ajoute: 'Presque rien : un réglage de vitesse de repousse et un indicateur de profondeur.',
    pourquoi: 'Ça transforme une progression linéaire en pari. Chaque pas de plus est une décision : est-ce que je pousse encore, ou est-ce que je rentre pendant que je peux ? C\'est ce qui manque le plus au modèle d\'origine, où avancer n\'a aucun coût.',
    refs: [],
    risque: 'Mal réglé, c\'est punitif. Il faut toujours laisser une sortie de secours, même lente.',
  },
  {
    n: 3, nom: 'Le poids remplace le nombre', cout: 'faible',
    change: 'Fini la limite à deux objets. Chaque butin a un poids : une petite idole se porte vite, la grande te fait marcher au ralenti. Tu choisis entre trois petites prises sûres ou une grosse qui te rend vulnérable.',
    reutilise: 'La limite d\'inventaire existe, on remplace le compteur par une somme de poids.',
    ajoute: 'Un poids par objet et un lien entre charge et vitesse. Une journée.',
    pourquoi: 'La limite à deux est une règle arbitraire que le joueur subit. Le poids est un arbitrage qu\'il décide. Et ça se marie parfaitement avec le vol : le gros butin est celui qu\'on te prendra.',
    refs: [],
    risque: 'Si le ralentissement est trop fort, plus personne ne prend les gros objets. C\'est un équilibrage à surveiller de près.',
  },
  {
    n: 4, nom: 'Chaque coup est un tirage', cout: 'faible',
    change: 'Chaque coup d\'outil a une petite chance de faire tomber une pièce rare, avec une aura et une annonce à tout le serveur. Le reste ne change pas.',
    reutilise: 'La détection de coup existe déjà. On y branche un tirage.',
    ajoute: 'Une table de raretés, des effets visuels, un message de serveur. Quelques jours.',
    pourquoi: 'Le tirage rare est un genre entier sur Roblox et il se greffe sur n\'importe quoi. Ça donne une raison de continuer à couper une matière que tu maîtrises déjà, au lieu de foncer vers l\'étape suivante.',
    refs: [["Sol's RNG", 'le genre du tirage']],
    risque: 'Facile à surdoser. Si tout le monde a du rare en dix minutes, il n\'y a plus de rare.',
  },
  {
    n: 5, nom: 'Un seul couloir pour tout le serveur', cout: 'moyen',
    change: 'Au lieu que chacun ait son couloir, le serveur entier creuse le même. Ce que tu coupes reste coupé pour les autres, et l\'avancée est affichée à tous. Au bout, quelque chose que personne ne peut atteindre seul.',
    reutilise: 'Le couloir et les paliers restent identiques.',
    ajoute: 'Une synchronisation de l\'état du couloir entre joueurs, et un objectif collectif. Plus lourd que les autres.',
    pourquoi: 'Ça règle le problème de fond de ces jeux : on y est seul au milieu d\'autres gens. Un objectif commun donne une raison de parler, et donc de rester.',
    refs: [],
    risque: 'Un joueur qui coupe tout prive les autres de jeu. Il faut que la matière repousse assez vite pour que chacun ait sa part.',
  },
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
.page{max-width:880px;margin:0 auto;padding:44px 22px 90px}
a{color:var(--acc)}a:focus-visible{outline:2px solid var(--acc);outline-offset:3px}
h1{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:clamp(30px,5.4vw,45px);
 line-height:1.05;margin:0 0 12px;letter-spacing:-.025em;text-wrap:balance}
.chapeau{margin:0;max-width:60ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:34px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:52px 0 8px;letter-spacing:-.015em}
.intro{margin:0 0 22px;color:var(--doux);max-width:62ch}
h3{font-family:"JetBrains Mono",monospace;font-size:10.5px;font-weight:700;text-transform:uppercase;
 letter-spacing:.11em;color:var(--doux);margin:0 0 6px}

.constat{background:var(--carte);border-left:3px solid var(--chaud);padding:20px 24px}
.constat p{margin:0 0 11px}.constat p:last-child{margin:0}
.gros{font-family:"JetBrains Mono",monospace;font-size:28px;font-weight:700;color:var(--chaud);
 font-variant-numeric:tabular-nums;letter-spacing:-.02em}

.trajet{display:flex;align-items:center;gap:0;margin:26px 0 8px;flex-wrap:wrap}
.etape{background:var(--carte);border:1px solid var(--trait);border-radius:3px;
 padding:9px 14px;font-size:13px;white-space:nowrap}
.etape.vide{border-style:dashed;border-color:var(--chaud);color:var(--chaud)}
.fleche{color:var(--doux);padding:0 9px;font-family:"JetBrains Mono",monospace;font-size:12px}
.legende-trajet{font-size:12.5px;color:var(--doux);margin:0}

.idee{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:24px 26px;margin-bottom:18px}
.idee.fort{border-color:var(--acc);border-width:2px}
.idee>header{display:flex;align-items:baseline;gap:11px;flex-wrap:wrap;margin-bottom:10px}
.rg{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:26px;
 color:var(--trait);line-height:1;letter-spacing:-.03em}
.idee h4{font-family:"Bricolage Grotesque",sans-serif;font-size:22px;margin:0;letter-spacing:-.015em}
.cout{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.07em;padding:3px 8px;border-radius:3px;border:1px solid currentColor}
.cout.faible{color:var(--acc)}.cout.moyen{color:var(--or)}
.recommande{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;background:var(--acc);color:var(--carte);padding:3px 9px;border-radius:3px}
.change{margin:0 0 16px;font-size:15.5px}
.grille{display:grid;grid-template-columns:1fr 1fr;gap:16px 26px;
 border-top:1px solid var(--trait);padding-top:15px}
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

.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Changer le fonctionnement, pas le décor</h1>
  <p class="chapeau">Cinq façons de modifier la boucle du modèle que tu achètes, classées par ce qu'elles coûtent à développer. Toutes réutilisent le code existant.</p>
</header>

<h2>Ton modèle a un trajet mort</h2>
<div class="constat">
  <p>Regarde ta propre description : tu coupes, tu ramasses deux objets, <strong>tu les rapportes au vendeur</strong>, tu revends. Ce retour, c'est du temps où le joueur ne fait rien. Il marche.</p>
  <p>Or les deux plus gros jeux de Roblox en ce moment sont exactement ça — transporter un objet pendant que d'autres essaient de te le prendre :</p>
  <div class="refs" style="margin:14px 0">
    ${ref('Steal An Egg', 'premier jeu de Roblox')}
    ${ref('Steal a Brainrot', 'deuxième')}
  </div>
  <p><span class="gros">1 988 649</span></p>
  <p>joueurs connectés à eux deux, sur une mécanique dont <strong>tu possèdes déjà la moitié</strong> et dont tu ne fais rien.</p>
</div>

<div class="trajet">
  <span class="etape">Couper</span><span class="fleche">→</span>
  <span class="etape">Ramasser</span><span class="fleche">→</span>
  <span class="etape vide">Rapporter — rien ne se passe</span><span class="fleche">→</span>
  <span class="etape">Vendre</span>
</div>
<p class="legende-trajet">Le maillon en pointillé est le seul moment où tous les joueurs du serveur sont visibles au même endroit, les bras chargés. C'est le meilleur endroit du jeu, et il est vide.</p>

<h2>Les cinq refontes</h2>
<p class="intro">Classées par coût de développement. Les quatre premières se branchent sur du code qui existe déjà dans le modèle.</p>

${IDEES.map(i => `<article class="idee${i.fort ? ' fort' : ''}">
  <header><span class="rg">${String(i.n).padStart(2, '0')}</span><h4>${esc(i.nom)}</h4>
    <span class="cout ${i.cout}">coût ${esc(i.cout)}</span>
    ${i.fort ? '<span class="recommande">mon choix</span>' : ''}</header>
  <p class="change">${esc(i.change)}</p>
  <div class="grille">
    <div class="bloc cle" style="grid-column:1/-1"><h3>Pourquoi ça marche</h3><p>${esc(i.pourquoi)}</p>
      ${i.refs.length ? `<div class="refs">${i.refs.map(([c, n]) => ref(c, n)).join('')}</div>` : ''}</div>
    <div class="bloc"><h3>Ce que tu réutilises</h3><p>${esc(i.reutilise)}</p></div>
    <div class="bloc"><h3>Ce qu'il faut ajouter</h3><p>${esc(i.ajoute)}</p></div>
    <div class="bloc risque" style="grid-column:1/-1"><h3>Le risque</h3><p>${esc(i.risque)}</p></div>
  </div>
</article>`).join('')}

<h2>Ce que je ferais</h2>
<div class="fin">
  <p><strong>Les trois premières ensemble, pas séparément.</strong> Le vol donne un enjeu au trajet retour. Le poids te fait choisir ce que tu risques. Le couloir qui se referme t'oblige à garder des forces pour rentrer. Prises isolées, ce sont trois ajouts sympathiques ; prises ensemble, elles déplacent le cœur du jeu : <strong>couper n'est plus le jeu, c'est la préparation. Le jeu, c'est rentrer.</strong></p>
  <p>Et c'est ça qui te sort de la copie. Les cinquante autres acheteurs du modèle sortiront un jeu où on coupe de l'herbe verte, jaune ou bleue. Toi, tu sors un jeu où on se fait braquer à la sortie du couloir avec une idole trop lourde dans les bras. Ce n'est plus le même jeu.</p>
  <p><strong>Une précaution.</strong> Ajoute le vol en dernier, et seulement une fois que couper est déjà agréable. Si la boucle de base n'est pas bonne, le vol ne fera qu'accélérer le départ des joueurs — ils partiront frustrés au lieu de partir ennuyés.</p>
</div>

<section class="note">
  <p><strong>Sur les chiffres.</strong> Les joueurs connectés sont un instantané relevé le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })} et varient fortement selon l'heure. Les estimations de temps de développement sont des ordres de grandeur pour un développeur Roblox expérimenté travaillant sur un modèle qu'il découvre.</p>
  <p><strong>Une limite.</strong> Je décris ces refontes à partir de la boucle telle que tu me l'as racontée, sans avoir vu le code du modèle. Avant de commander quoi que ce soit, fais confirmer par le développeur que le couloir peut être partagé entre joueurs — c'est l'hypothèse sur laquelle repose la première idée, et la plus structurante.</p>
</section>
</div>`;

const out = path.join(ROOT, 'refonte-mecanique.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
