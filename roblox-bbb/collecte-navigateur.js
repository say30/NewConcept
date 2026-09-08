/* ============================================================================
   BuiltByBit -> collecte des annonces Roblox / Game Setups  (v2)
   A COLLER DANS LA CONSOLE DU NAVIGATEUR, sur builtbybit.com, connecte.

   Structure reelle du site (XenForo), confirmee par diagnostic.js :
     - chaque annonce  = .structItem--resource   (21 par page, 65 pages)
     - titre           = .structItem-title a
     - accroche        = .structItem-resourceTagLine
     - note            = .structItem-metaItem--rating
     - pagination      = /resources/result?category_id=54&sort=date_published&page=N

   Duree : ~12 min pour les ~1365 annonces avec leur detail.
   Resultat : fichier builtbybit-roblox.json telecharge, plus une copie dans le
   presse-papier si le telechargement est bloque par le navigateur.
   ============================================================================ */
(async () => {
  const PAGES   = 65;
  const DELAI   = 350;   // ms entre deux requetes
  const DETAILS = true;  // false = listing seul (~1 min)

  const LISTE = n => `https://builtbybit.com/resources/result?category_id=54&sort=date_published&page=${n}`;
  const pause = ms => new Promise(r => setTimeout(r, ms));
  const doc_de = h => new DOMParser().parseFromString(h, 'text/html');
  const propre = s => (s || '').replace(/\s+/g, ' ').trim();

  async function get(url) {
    const r = await fetch(url, { credentials: 'include' });
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return r.text();
  }

  /* ---- Phase 1 : listing ------------------------------------------------ */
  const trouves = new Map();
  for (let p = 1; p <= PAGES; p++) {
    let doc;
    try { doc = doc_de(await get(LISTE(p))); }
    catch (e) { console.warn(`page ${p} ignoree : ${e.message}`); await pause(DELAI); continue; }

    const items = doc.querySelectorAll('.structItem--resource');
    for (const it of items) {
      const a = it.querySelector('.structItem-title a[href*="/resources/"]')
             || it.querySelector('a[href*="/resources/"]');
      if (!a) continue;
      const href = a.getAttribute('href');
      const id = (href.match(/(\d+)\/?(?:$|\?)/) || [])[1];   // .../slug.12345/
      if (!id || trouves.has(id)) continue;

      const texte = propre(it.textContent);
      trouves.set(id, {
        id,
        titre: propre(a.textContent),
        url: new URL(href, location.origin).href,
        accroche: propre((it.querySelector('.structItem-resourceTagLine') || {}).textContent),
        note: (it.querySelector('.structItem-metaItem--rating') || {}).title || null,
        // Le prix apparait dans le bloc de l'annonce sous forme $xx.xx ou "Free".
        prix: (texte.match(/\$\s?\d+(?:[.,]\d{1,2})?/) || [/free/i.test(texte) ? '$0' : null])[0],
        listing: texte.slice(0, 300),
      });
    }
    console.log(`listing ${p}/${PAGES} — ${items.length} sur la page, ${trouves.size} au total`);

    if (p === 1 && trouves.size === 0) {
      console.error('ARRET : aucune annonce sur la page 1. Es-tu bien connecte sur builtbybit.com ?');
      return;
    }
    await pause(DELAI);
  }

  const annonces = [...trouves.values()];
  console.log(`${annonces.length} annonces collectees.`);

  /* ---- Phase 2 : detail de chaque annonce -------------------------------- */
  if (DETAILS) {
    for (let i = 0; i < annonces.length; i++) {
      const a = annonces[i];
      try {
        const doc = doc_de(await get(a.url));

        // Corps de la description : .bbWrapper est le conteneur XenForo standard.
        const blocs = [...doc.querySelectorAll('.bbWrapper, .message-body, .resourceBody')];
        const zone = blocs.sort((x, y) => y.textContent.length - x.textContent.length)[0] || doc.body;
        const texte = propre(zone.textContent);

        // Metriques de richesse : c'est sur elles que repose la notation.
        a.mots   = texte.split(' ').filter(Boolean).length;
        a.images = zone.querySelectorAll('img').length;
        a.videos = zone.querySelectorAll('iframe, video').length;
        a.titres = zone.querySelectorAll('h1,h2,h3,h4,b,strong').length;
        a.puces  = zone.querySelectorAll('li').length;
        a.spoilers = zone.querySelectorAll('.bbCodeSpoiler, .bbCodeBlock').length;
        a.extrait = texte.slice(0, 500);

        const t = propre(doc.body.textContent);
        a.auteur = propre((doc.querySelector('.username, .u-concealed a') || {}).textContent) || null;
        a.avis   = (t.match(/(\d+)\s*(?:ratings?|reviews?)/i) || [])[1] || null;
        a.ventes = (t.match(/(\d[\d,. ]*)\s*(?:purchases?|downloads?|sales?)/i) || [])[1] || null;
        a.maj    = (doc.querySelector('time') || {}).getAttribute?.('datetime') || null;
        a.majs   = doc.querySelectorAll('.block--messages .message, .resourceUpdate').length;
      } catch (e) { a.erreur = e.message; }

      if ((i + 1) % 25 === 0) console.log(`detail ${i + 1}/${annonces.length}`);
      await pause(DELAI);
    }
  }

  /* ---- Sortie ------------------------------------------------------------ */
  const json = JSON.stringify(annonces);
  try {
    const l = document.createElement('a');
    l.href = URL.createObjectURL(new Blob([json], { type: 'application/json' }));
    l.download = 'builtbybit-roblox.json';
    document.body.appendChild(l); l.click(); l.remove();
  } catch (e) { console.warn('telechargement bloque :', e.message); }
  try { copy(json); console.log('(copie aussi dans le presse-papier)'); } catch (e) {}
  console.log(`TERMINE — ${annonces.length} annonces. Fichier builtbybit-roblox.json.`);
  window.RESULTAT = annonces;   // dispo dans la console si besoin
})();
