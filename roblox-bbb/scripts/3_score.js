#!/usr/bin/env node
// Etape 3 — note chaque annonce et produit le classement.
// Trois blocs : qualite/richesse de l'annonce (50), traction commerciale (20),
// potentiel marche Roblox (30). Chaque sous-score est conserve pour etre affichable.
const { readData, writeData } = require('./lib');

const clamp = (v, max) => Math.max(0, Math.min(max, v));
const text = r => String(r.description || r.message || r.tag_line || '');
const strip = h => h.replace(/<[^>]+>/g, ' ').replace(/\[\/?[^\]]+\]/g, ' ').replace(/\s+/g, ' ').trim();

const GENRES = {
  tycoon: ['tycoon', 'factory', 'empire'], simulator: ['simulator', 'sim ', 'clicker', 'pet'],
  obby: ['obby', 'parkour', 'tower of'], horror: ['horror', 'survive', 'scary', 'nextbot'],
  tdefense: ['tower defense', 'td '], rpg: ['rpg', 'quest', 'dungeon', 'anime fighting'],
  roleplay: ['roleplay', 'rp ', 'city', 'life', 'brookhaven'], racing: ['racing', 'car', 'drift'],
  fps: ['fps', 'shooter', 'gun', 'combat'], sandbox: ['build', 'sandbox', 'craft'],
  social: ['hangout', 'dance', 'club'], battle: ['battlegrounds', 'pvp', 'arena', 'fight'],
};
function genresOf(s) {
  const l = ' ' + s.toLowerCase().replace(/[^a-z0-9]+/g, ' ') + ' ';
  const mot = k => new RegExp(`\\b${k.trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`).test(l);
  return Object.entries(GENRES).filter(([, kw]) => kw.some(mot)).map(([g]) => g);
}

// Idees de variantes proposees quand le marche Roblox est peu occupe.
const VARIANT_IDEAS = {
  tycoon: ['version co-op 2 joueurs par base', 'rebirth/prestige avec multiplicateurs', 'theme saisonnier (Halloween / Noel)', 'PvP raids entre tycoons'],
  simulator: ['pets + fusion de pets', 'zones debloquables avec gates de puissance', 'evenement hebdo avec classement', 'trading entre joueurs'],
  obby: ['mode course chronometree avec leaderboard', 'checkpoints payants en Robux', 'obby genere aleatoirement', 'skins et trails cosmetiques'],
  horror: ['mode 1 vs 4 (tueur/survivants)', 'generation procedurale des salles', 'chat vocal de proximite', 'saisons avec nouveaux monstres'],
  tdefense: ['tours a fusionner', 'mode infini avec classement', 'co-op 4 joueurs', 'banniere gacha pour les tours'],
  rpg: ['systeme de classes + arbre de talents', 'raids de boss a 10', 'donjons hebdomadaires', 'craft et economie joueur'],
  roleplay: ['metiers avec progression', 'systeme de logement personnalisable', 'evenements de ville scriptes', 'vehicules et permis'],
  racing: ['tuning et peintures', 'courses classees par saison', 'circuits communautaires', 'mode poursuite police'],
  fps: ['battle royale reduit (20 joueurs)', 'skins d armes + caisses', 'mode zombie coop', 'classement competitif'],
  sandbox: ['sauvegarde de builds + partage', 'serveurs prives payants', 'concours de build hebdo', 'kits de blocs premium'],
  social: ['systeme d avatars et emotes premium', 'mini-jeux integres', 'scenes DJ / evenements live', 'systeme d amis et de groupes'],
  battle: ['personnages sous licence (style anime)', 'mode ranked avec elo', 'ultimates a debloquer', 'saisons avec pass de combat'],
  _default: ['ajouter une boucle de progression longue (rebirth)', 'monetisation par gamepasses + boutique rotative', 'evenements limites dans le temps', 'mode cooperatif ou PvP additionnel'],
};

// Bareme cale sur la distribution reelle des 1350 annonces collectees :
// mediane 157 mots, 23 images, 3 intertitres, 18 puces, 5 ventes.
// Le suivi des mises a jour n'est pas mesurable depuis la page publique : ecarte.
function scoreListing(r) {
  const m = r._metrics || {};
  const body = strip(text(r));
  const words = m.words ?? body.split(/\s+/).filter(Boolean).length;
  const media = m.media ?? 0;
  const headings = m.headings ?? 0;
  const bullets = m.bullets ?? 0;
  const reviews = Number(r.review_count || 0);
  const rating = Number(r.review_average || 0);
  const features = /feature|include|what you get|contenu|system/i.test(body) ? 1 : 0;

  const q = {
    longueur: clamp((Math.log10(words + 1) - 1.5) * 12, 14),
    structure: clamp(headings * 0.6 + bullets * 0.25, 10),
    medias: clamp((Math.log10(media + 1) - 0.7) * 10, 12),
    contenu_liste: features * 6,
    preuve_sociale: clamp(reviews * 1.5 + rating * 1.2, 8),
  };
  const qualite = Object.values(q).reduce((a, b) => a + b, 0);

  const purchases = Number(r.purchase_count || 0);
  const price = Number(r.price || 0);
  const t = {
    ventes: clamp(Math.log10(purchases + 1) * 9, 14),
    positionnement_prix: price === 0 ? 1 : clamp(3 + Math.min(price, 60) / 20, 6),
  };

  return { qualite, sousScoresQualite: q, traction: t.ventes + t.positionnement_prix,
           sousScoresTraction: t,
           _stats: { words, media, headings, bullets, reviews, rating, purchases, price } };
}

function scoreMarket(match) {
  const v = (match && match.variants) || [];
  // Un concurrent credible : titre suffisamment proche ET audience reelle.
  // Le seuil de 0.35 evite de declarer un genre libre alors que des equivalents
  // evidents existent sous un nom un peu different.
  for (const x of v) x.concurrent = x.similarity >= 0.35 && (x.visits || 0) > 100000;
  const solides = v.filter(x => x.concurrent);
  const top = solides[0] || v[0];
  if (!top) return { marche: 5, detail: { demande: 0, opportunite: 5, fraicheur: 0 }, variantesSolides: 0 };

  // Demande : audience prouvee du meilleur equivalent sur Roblox.
  const demande = clamp(Math.log10((top.visits || 0) + 1) * 2.2, 16);
  // Opportunite : forte demande et peu de concurrents credibles = bon signe.
  // Aucun equivalent du tout n'est un signal incertain, pas un feu vert.
  const n = solides.length;
  const opportunite = n === 0 ? 5 : n <= 2 ? 9 : n <= 4 ? 7 : n <= 7 ? 4 : 2;
  // Fraicheur : un equivalent maintenu recemment prouve que le genre vit encore.
  const days = top.updated ? (Date.now() - new Date(top.updated)) / 864e5 : 9999;
  const fraicheur = days < 30 ? 5 : days < 180 ? 3 : days < 365 ? 1 : 0;

  return { marche: demande + opportunite + fraicheur,
           detail: { demande, opportunite, fraicheur }, variantesSolides: n };
}

(async () => {
  const res = readData('bbb_resources.json');
  let matches = {};
  try { matches = readData('roblox_matches.json'); } catch (_) { console.warn('! roblox_matches.json absent, bloc marche neutralise'); }

  const scored = res.map(r => {
    const title = r.title || r.name || `#${r.resource_id || r.id}`;
    const L = scoreListing(r);
    const M = scoreMarket(matches[title]);
    const genres = genresOf(`${title} ${strip(text(r))}`.slice(0, 4000));
    const idees = M.variantesSolides <= 3
      ? [...new Set(genres.flatMap(g => VARIANT_IDEAS[g] || []))].slice(0, 5)
      : [];
    return {
      id: r.resource_id ?? r.id, titre: title, url: r._url,
      prix: r.price ?? null, devise: r.currency || 'USD',
      auteur: (r.author && r.author.username) || r.author_id || null,
      tagline: r.tag_line || '',
      description: strip(text(r)).slice(0, 4000),
      genres,
      score: +(L.qualite + L.traction + M.marche).toFixed(1),
      blocs: { qualite: +L.qualite.toFixed(1), traction: +L.traction.toFixed(1), marche: +M.marche.toFixed(1) },
      detailScores: { ...L.sousScoresQualite, ...L.sousScoresTraction, ...M.detail },
      stats: L._stats,
      promo: r.promo || null,
      roblox: (matches[title] && matches[title].variants) || [],
      variantesSolides: M.variantesSolides,
      ideesVariantes: idees.length ? idees : VARIANT_IDEAS._default,
    };
  }).sort((a, b) => b.score - a.score);

  scored.forEach((s, i) => { s.rang = i + 1; });
  writeData('classement.json', scored);
  console.log(`> data/classement.json ecrit (${scored.length} annonces)`);
  console.log('  Top 20 :');
  scored.slice(0, 20).forEach(s => console.log(`   ${String(s.rang).padStart(2)}. ${s.score.toFixed(1)}  ${s.titre}`));
})();
