#!/usr/bin/env node
// Etape 11 — dix themes pour Keyboard Escape, chacun accompagne des jeux reellement
// trouves sur Roblox, avec leurs liens, pour verification directe par l'utilisateur.
const fs = require('fs');
const path = require('path');
const { readData, ROOT } = require('./lib');

const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;' }[c]));
const num = n => Number(n || 0).toLocaleString('fr-FR');
const V = readData('verif_themes.json');
const STRICT = /keyboard|keycap|\+ ?1 (speed|jump|backflip)|speed keyboard/i;

const THEMES = [
  { cle:'Chantier', nom:'Le chantier', sous:'Béton frais', fort:true,
    pal:[['#8E8B85','Béton'],['#F2C230','Sécurité'],['#E0621B','Cône'],['#2B2A28','Bitume']],
    pitch:'Un immeuble en construction, la nuit. Bâches, échafaudages, et une coulée de béton qui te course.',
    vague:'Coulée de béton frais qui déferle et durcit derrière elle',
    gel:'Béton à moitié pris : tu ralentis et tu t\'enfonces',
    sol:'Bitume chaud noir et fumant',
    ecrase:'Poutrelles, palettes de parpaings, benne de la grue',
    monstres:'La Bétonnière (cylindre sur deux cubes-roues) · Le Marteau-piqueur (silhouette en blocs) · La Grue (un bras qui balaie)',
    bonus:'Ton fichier contient déjà des rubans de sécurité et des panneaux WARNING : ils passent tels quels.' },
  { cle:'Fonderie', nom:'La fonderie', sous:'Métal en fusion',
    pal:[['#4A4E54','Acier'],['#FF6A00','Fusion'],['#FFC24A','Étincelle'],['#1A1513','Suie']],
    pitch:'Une aciérie en pleine coulée. Tout est sombre, tout est brûlant, et l\'acier liquide monte.',
    vague:'Coulée d\'acier en fusion qui éclaire la scène en avançant',
    gel:'Scorie refroidie, pâteuse, qui colle aux pieds',
    sol:'Le métal en fusion — la lave la plus crédible qui soit',
    ecrase:'Lingots, presse hydraulique, creuset qui bascule',
    monstres:'Le Creuset (sphère émissive) · Le Soudeur (blocs + torche lumineuse) · La Presse (un bloc sur rail)',
    bonus:'Le rendu tient à la lumière, pas aux modèles. Formes pauvres, image forte.' },
  { cle:'Egypte', nom:'Le tombeau', sous:'Sables mouvants',
    pal:[['#D9B382','Sable'],['#8C6A3F','Ocre'],['#E8C55A','Or'],['#2E7D74','Turquoise']],
    pitch:'Une pyramide qu\'on n\'aurait pas dû ouvrir. Hiéroglyphes, torches, et une marée de sable.',
    vague:'Marée de sable qui monte, précédée d\'un nuage de poussière',
    gel:'Sables mouvants : tu t\'enfonces si tu t\'arrêtes',
    sol:'Fosse de sable brûlant',
    ecrase:'Blocs du plafond, sarcophages qui basculent, la boule de pierre',
    monstres:'La Momie (un avatar + bandages du catalogue) · Le Scorpion (cubes et cylindres) · La Boule de pierre',
    bonus:'Les hiéroglyphes sont des images plates : des dizaines d\'étapes couvertes sans un seul volume.' },
  { cle:'Abysses', nom:'Les abysses', sous:'Fosse océanique',
    pal:[['#0B2A3A','Abysse'],['#1B6E8C','Bleu profond'],['#7FE3D4','Bioluminescence'],['#0A0F14','Noir']],
    pitch:'Une station sous-marine qui cède. Tu descends, la pression monte, et l\'eau noire te suit.',
    vague:'Un mur d\'eau noire qui envahit les coursives',
    gel:'Un banc de méduses qui te freine et te colle',
    sol:'Failles volcaniques sous-marines, eau bouillante',
    ecrase:'Cloisons qui s\'effondrent, containers, la coque qui implose',
    monstres:'Le Poisson-lanterne (sphère + une lumière) · Le Requin (cône allongé) · Le Tentacule (une chaîne de cylindres)',
    bonus:'La bioluminescence sur fond noir donne une identité visuelle immédiate, et coûte une couleur.' },
  { cle:'Decharge', nom:'La décharge', sous:'Casse automobile',
    pal:[['#6B6256','Rouille'],['#9AA37A','Vert sale'],['#C4551F','Oxyde'],['#33302A','Cambouis']],
    pitch:'Une casse à ciel ouvert. Montagnes de carcasses, et une coulée d\'huile noire qui dévale.',
    vague:'Vague d\'huile de vidange noire et luisante',
    gel:'Boue mêlée de graisse, tu patines',
    sol:'Mare d\'acide de batterie verte',
    ecrase:'Carcasses de voitures lâchées par la grue-aimant, la presse à ferraille',
    monstres:'Le Golem de ferraille (cubes empilés) · Le Rat (petit modèle bon marché) · La Grue-aimant (un bras + une sphère)',
    bonus:'Tout est fait de cubes cabossés et de couleurs sales. C\'est le thème le plus tolérant aux formes approximatives.' },
  { cle:'Fromagerie', nom:'La fromagerie', sous:'Fondue',
    pal:[['#F2B21A','Cheddar'],['#FFE7A3','Crème'],['#C97B22','Croûte'],['#8B5A2B','Bois']],
    pitch:'Une cave d\'affinage. Meules jusqu\'au plafond, et une vague de fondue brûlante.',
    vague:'Vague de fondue épaisse avec des fils qui pendent',
    gel:'Mozzarella filante : tu restes collé une seconde',
    sol:'Fondue bouillante',
    ecrase:'Meules géantes qui roulent, blocs de beurre',
    monstres:'Le Rat géant · La Meule roulante (un cylindre, littéralement) · Le Blob de fondue',
    bonus:'Le plus drôle des dix, donc le plus partageable — mais attention au nom, voir ci-dessous.' },
  { cle:'Ramen', nom:'Le restaurant', sous:'Ramen',
    pal:[['#C4342A','Rouge lanterne'],['#F0C987','Bouillon'],['#2B2118','Bois sombre'],['#E8E4D9','Papier']],
    pitch:'Un restaurant de ramen la nuit. Lanternes, vapeur, et un raz-de-marée de bouillon.',
    vague:'Vague de bouillon fumant qui déferle entre les tables',
    gel:'Un enchevêtrement de nouilles où tu t\'empêtres',
    sol:'Huile de friture bouillante',
    ecrase:'Bols géants qui tombent, woks, sacs de riz',
    monstres:'Les Baguettes (deux cylindres qui pincent) · Le Wok (un dôme qui roule) · L\'Œuf mollet géant (une sphère)',
    bonus:'La palette rouge et or sur fond sombre ressort très bien en vignette, et les lanternes sont des cylindres.' },
  { cle:'Marais', nom:'Le marais', sous:'Bayou',
    pal:[['#3E4A2E','Vase'],['#6B7F3A','Algue'],['#8FA86B','Brume'],['#241F17','Tourbe']],
    pitch:'Un bayou envahi. Cyprès, brume, pontons pourris, et une crue de boue qui monte.',
    vague:'Crue de boue épaisse chargée de branches',
    gel:'Tourbière : chaque pas coûte',
    sol:'Vase toxique bouillonnante',
    ecrase:'Troncs qui tombent, pontons qui cèdent, rochers moussus',
    monstres:'Le Crocodile (cubes allongés) · La Sangsue (cylindre souple) · Le Nuage de moustiques (des particules, gratuit)',
    bonus:'La brume masque le fond de la scène : tu peux construire beaucoup moins de décor.' },
  { cle:'FarWest', nom:'Le Far West', sous:'Canyon',
    pal:[['#B5651D','Terre rouge'],['#E3C08D','Poussière'],['#5C4033','Bois'],['#2F4858','Ciel d\'orage']],
    pitch:'Une ville fantôme au fond d\'un canyon. Saloon, mine, et une crue soudaine qui balaie la rue.',
    vague:'Crue soudaine boueuse qui dévale le canyon',
    gel:'Sables mouvants du lit de rivière',
    sol:'Sources de goudron bouillant',
    ecrase:'Rochers du canyon, tonneaux de poudre, wagonnets de mine',
    monstres:'Le Serpent à sonnette (cylindres) · Le Vautour (deux plans en V) · Le Wagonnet fou (un cube sur rails)',
    bonus:'Le décor mural est fait de planches et de rochers plats : deux textures suffisent pour tout le jeu.' },
  { cle:'Cirque', nom:'Le cirque', sous:'Chapiteau', occupe:true,
    pal:[['#C4243A','Rouge cirque'],['#F5F0E6','Toile'],['#F2C230','Ampoule'],['#5B2C83','Violet']],
    pitch:'Un cirque abandonné où le spectacle continue. Rayures, ampoules qui grésillent, chapiteau qui s\'effondre.',
    vague:'Vague de barbe à papa rose qui engloutit la piste',
    gel:'Caramel collant',
    sol:'Cerceau enflammé, fosse aux fauves',
    ecrase:'Boulets de canon, massues, la grosse caisse qui roule',
    monstres:'Le Clown (avatar + tête du catalogue) · L\'Homme-canon (une trajectoire) · Le Diable en boîte (un cube et un ressort)',
    bonus:'Le seul des dix qui a déjà un concurrent direct dans le genre — minuscule, mais il existe.' },
];

function verif(cle) {
  const o = V[cle] || { duGenre: [], autres: [] };
  const tous = [...o.duGenre, ...o.autres];
  const vrais = tous.filter(g => STRICT.test(g.nom));
  const autres = tous.filter(g => !STRICT.test(g.nom)).sort((a, b) => b.joueurs - a.joueurs).slice(0, 5);
  const gros = autres[0];
  const collision = !gros ? 'aucune' : gros.joueurs >= 1500 ? 'forte' : gros.joueurs >= 400 ? 'moyenne' : 'faible';
  return { vrais, autres, collision };
}

const lien = g => `<li><a href="${esc(g.url)}" target="_blank" rel="noopener">${esc(g.nom)}</a>
  <span>${num(g.joueurs)} joueurs</span></li>`;

const html = `<title>Dix thèmes vérifiés un par un</title>
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
.chapeau{margin:0;max-width:62ch;color:var(--doux);font-size:16px}
.entete{border-bottom:2px solid var(--encre);padding-bottom:24px;margin-bottom:20px}
h2{font-family:"Bricolage Grotesque",sans-serif;font-size:25px;margin:52px 0 8px;letter-spacing:-.015em}
.intro{margin:0 0 22px;color:var(--doux);max-width:64ch}
h3{font-family:"JetBrains Mono",monospace;font-size:10.5px;font-weight:700;text-transform:uppercase;
 letter-spacing:.11em;color:var(--doux);margin:0 0 7px}

.methode{background:var(--carte);border-left:3px solid var(--acc);padding:16px 20px;margin-bottom:14px}
.methode p{margin:0;font-size:14px}

.recap{width:100%;border-collapse:collapse;font-size:13.5px;background:var(--carte);
 border:1px solid var(--trait);margin-top:14px}
.recap th{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.08em;color:var(--doux);text-align:left;padding:9px 12px;border-bottom:1px solid var(--trait)}
.recap td{padding:8px 12px;border-bottom:1px solid var(--trait)}
.recap td.c{text-align:center;font-family:"JetBrains Mono",monospace}
.tw{overflow-x:auto}
.ok{color:var(--acc);font-weight:700}.no{color:var(--chaud);font-weight:700}

.theme{background:var(--carte);border:1px solid var(--trait);border-radius:4px;
 padding:22px 24px;margin-bottom:16px}
.theme.fort{border-color:var(--acc);border-width:2px}
.theme.occupe{border-color:var(--chaud)}
.theme>header{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin-bottom:8px}
.rg{font-family:"Bricolage Grotesque",sans-serif;font-weight:700;font-size:24px;
 color:var(--trait);line-height:1;letter-spacing:-.03em}
.theme h4{font-family:"Bricolage Grotesque",sans-serif;font-size:21px;margin:0;letter-spacing:-.015em}
.sous{font-family:"JetBrains Mono",monospace;font-size:11px;color:var(--acc);
 border:1px solid var(--acc);border-radius:3px;padding:2px 7px}
.badge{font-family:"JetBrains Mono",monospace;font-size:9.5px;text-transform:uppercase;
 letter-spacing:.07em;padding:3px 8px;border-radius:3px;margin-left:auto}
.badge.libre{background:var(--acc);color:var(--carte)}
.badge.pris{background:var(--chaud);color:var(--carte)}
.pitch{margin:0 0 14px;font-size:15px}
.pal{display:flex;border:1px solid var(--trait);border-radius:3px;overflow:hidden;margin-bottom:14px}
.sw{flex:1;text-align:center;padding-bottom:6px}
.sw i{display:block;height:30px}
.sw b{display:block;font-family:"JetBrains Mono",monospace;font-size:9.5px;margin-top:5px}
.sw span{font-size:10px;color:var(--doux)}
.slots{list-style:none;padding:0;margin:0 0 14px;display:grid;gap:5px}
.slots li{display:grid;grid-template-columns:104px 1fr;gap:12px;font-size:13.5px;align-items:baseline}
@media(max-width:600px){.slots li{grid-template-columns:1fr;gap:0}}
.slots b{font-family:"JetBrains Mono",monospace;font-size:10px;text-transform:uppercase;
 letter-spacing:.06em;color:var(--doux);font-weight:700}
.slots span{color:var(--doux)}
.bonus{font-size:13.5px;background:var(--fond);border-left:2px solid var(--acc);
 padding:9px 13px;margin:0 0 16px}

.check{border-top:1px solid var(--trait);padding-top:14px}
.deux{display:grid;grid-template-columns:1fr 1fr;gap:18px 26px}
@media(max-width:620px){.deux{grid-template-columns:1fr}}
.liste{list-style:none;padding:0;margin:0}
.liste li{display:flex;justify-content:space-between;gap:12px;align-items:baseline;
 padding:5px 0;border-bottom:1px dotted var(--trait);font-size:13.5px}
.liste li:last-child{border-bottom:0}
.liste a{text-decoration:none;overflow-wrap:anywhere}
.liste a:hover{text-decoration:underline}
.liste span{font-family:"JetBrains Mono",monospace;font-size:11px;color:var(--doux);white-space:nowrap}
.rien{font-size:13.5px;color:var(--acc);margin:0}
.coll{font-family:"JetBrains Mono",monospace;font-size:10.5px;color:var(--doux);margin:9px 0 0}
.coll b{color:var(--chaud)}
.fin{background:var(--carte);border-left:3px solid var(--acc);padding:20px 24px;margin-top:16px}
.fin p{margin:0 0 11px}.fin p:last-child{margin:0}
.note{margin-top:52px;padding-top:22px;border-top:1px solid var(--trait);font-size:13px;
 color:var(--doux);max-width:70ch}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
</style>

<div class="page">
<header class="entete">
  <h1>Dix thèmes vérifiés un par un</h1>
  <p class="chapeau">Chaque thème est suivi des jeux réellement trouvés sur Roblox, avec leurs liens et leur nombre de joueurs. Clique, regarde, juge toi-même — ne me crois pas sur parole.</p>
</header>

<div class="methode">
  <p><strong>Comment j'ai cherché.</strong> Cinq formulations par thème envoyées à la recherche Roblox, puis filtrage sur le nom des jeux. Je sépare deux choses très différentes : un <strong>dérivé du genre</strong> (un jeu clavier ou « +1 Speed » avec ce thème, c'est-à-dire ton vrai concurrent) et un <strong>jeu du même thème dans un autre genre</strong> (obby, tycoon, horreur), qui ne te concurrence pas mais occupe le nom. Contre-vérification sur les 245 dérivés du genre que j'avais déjà recensés.</p>
</div>

<div class="tw"><table class="recap">
<thead><tr><th>Thème</th><th>Dérivé du genre</th><th>Jeux du même thème</th><th>Le plus gros voisin</th><th>Collision de nom</th></tr></thead>
<tbody>
${THEMES.map(t => { const v = verif(t.cle); const g = v.autres[0]; return `<tr>
<td><strong>${esc(t.nom)}</strong></td>
<td class="c ${v.vrais.length ? 'no' : 'ok'}">${v.vrais.length || 'aucun'}</td>
<td class="c">${v.autres.length}</td>
<td>${g ? `<a href="${esc(g.url)}" target="_blank" rel="noopener">${esc(g.nom)}</a> <span style="color:var(--doux)">(${num(g.joueurs)})</span>` : '—'}</td>
<td class="c">${v.collision}</td></tr>`; }).join('')}
</tbody></table></div>

<h2>Le détail, thème par thème</h2>
<p class="intro">Pour chacun : ce qui remplit tes cases, la palette à recopier dans Studio, et surtout les liens à vérifier.</p>

${THEMES.map((t, i) => { const v = verif(t.cle); return `<article class="theme${t.fort ? ' fort' : ''}${t.occupe ? ' occupe' : ''}">
  <header><span class="rg">${String(i + 1).padStart(2, '0')}</span><h4>${esc(t.nom)}</h4>
    <span class="sous">${esc(t.sous)}</span>
    <span class="badge ${v.vrais.length ? 'pris' : 'libre'}">${v.vrais.length ? 'déjà pris' : 'libre'}</span></header>
  <p class="pitch">${esc(t.pitch)}</p>
  <div class="pal">${t.pal.map(([h, n]) => `<div class="sw"><i style="background:${h}"></i><b>${esc(h)}</b><span>${esc(n)}</span></div>`).join('')}</div>
  <ul class="slots">
    <li><b>La vague</b><span>${esc(t.vague)}</span></li>
    <li><b>La gelée</b><span>${esc(t.gel)}</span></li>
    <li><b>Le sol mortel</b><span>${esc(t.sol)}</span></li>
    <li><b>Ce qui écrase</b><span>${esc(t.ecrase)}</span></li>
    <li><b>Les 3 monstres</b><span>${esc(t.monstres)}</span></li>
  </ul>
  <p class="bonus">${esc(t.bonus)}</p>
  <div class="check">
    <div class="deux">
      <div><h3>Dérivés du genre — tes vrais concurrents</h3>
        ${v.vrais.length ? `<ul class="liste">${v.vrais.map(lien).join('')}</ul>`
          : '<p class="rien">Aucun. Ni dans la recherche Roblox, ni dans les 245 dérivés recensés.</p>'}</div>
      <div><h3>Même thème, autre genre</h3>
        ${v.autres.length ? `<ul class="liste">${v.autres.map(lien).join('')}</ul>`
          : '<p class="rien">Aucun jeu notable.</p>'}
        <p class="coll">Risque de collision de nom : <b>${v.collision}</b></p></div>
    </div>
  </div>
</article>`; }).join('')}

<h2>Ce que je retiens</h2>
<div class="fin">
  <p><strong>Neuf sur dix sont libres dans ton genre.</strong> Le seul pris est <strong>le cirque</strong> : « +1 Speed Circus Escape » existe, avec 12 joueurs. C'est minuscule, mais c'est exactement le genre de chose qu'on ne voit qu'en cliquant — d'où ta demande, qui était la bonne.</p>
  <p><strong>La collision de nom compte autant que le genre.</strong> Fromagerie et cirque sont libres côté dérivés, mais leurs noms sont déjà occupés par des jeux connus : « Cheese Escape » est un jeu d'horreur en labyrinthe, « Escape The Carnival of Terror » fait 2 000 joueurs. Ton jeu se battrait pour les mêmes mots-clés. À l'inverse, <strong>chantier, fonderie, décharge et marais sont vides même en nom</strong> — tu y serais seul dans les résultats de recherche.</p>
  <p><strong>Mon choix reste le chantier</strong>, pour une raison bête : ton fichier contient déjà des rubans de sécurité et des panneaux WARNING. En thème zombie ils sont là par hasard ; en thème chantier ils sont chez eux. Et le béton te donne les trois états dont tu as besoin — liquide, pâteux, durci — avec une seule matière.</p>
</div>

<section class="note">
  <p><strong>Ce que cette vérification ne garantit pas.</strong> La recherche Roblox privilégie les gros jeux et ne fait pas de correspondance exacte : un jeu minuscule ou au nom très inhabituel peut m'échapper. « Aucun dérivé » veut dire « rien trouvé sur cinq formulations et sur mes 245 dérivés recensés », pas « rien n'existe ». Avant de te lancer, tape toi-même le nom exact que tu comptes donner à ton jeu dans la recherche Roblox.</p>
  <p>Relevé le ${new Date().toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' })}. Les nombres de joueurs sont des instantanés et varient beaucoup selon l'heure.</p>
</section>
</div>`;

const out = path.join(ROOT, 'themes-verifies.html');
fs.writeFileSync(out, html);
console.log(`> ${out} — ${Math.round(html.length/1024)} Ko`);
