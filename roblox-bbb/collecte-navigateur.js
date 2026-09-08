/* ============================================================================
   BuiltByBit -> collecte des annonces Roblox / Game Setups
   A COLLER DANS LA CONSOLE DU NAVIGATEUR, sur builtbybit.com, connecte.
   Le navigateur passe Cloudflare : c'est lui qui recupere les pages.
   Duree : ~8 minutes pour 65 pages + le detail de chaque annonce.
   A la fin, un fichier builtbybit-roblox.json est telecharge automatiquement.
   ============================================================================ */
(async () => {
  const PAGES   = 65;    // nombre de pages du listing
  const DELAI   = 400;   // ms entre deux requetes (ne pas descendre plus bas)
  const DETAILS = true;  // false = listing seul, beaucoup plus rapide

  const base = 'https://builtbybit.com/resources/roblox/game-setups/search/?sort=date_published';
  const pause = ms => new Promise(r => setTimeout(r, ms));
  const html2doc = h => new DOMParser().parseFromString(h, 'text/html');

  async function get(url) {
    const r = await fetch(url, { credentials: 'include' });
    if (!r.ok) throw new Error(`HTTP ${r.status} sur ${url}`);
    return r.text();
  }

  /* ---- Phase 1 : listing ------------------------------------------------ */
  const trouves = new Map();
  for (let p = 1; p <= PAGES; p++) {
    let doc;
    try { doc = html2doc(await get(`${base}&page=${p}`)); }
    catch (e) { console.warn(`page ${p} ignoree : ${e.message}`); continue; }

    // On ratisse large : tout lien vers une ressource, quel que soit le theme.
    for (const a of doc.querySelectorAll('a[href*="/resources/"]')) {
      const m = a.getAttribute('href').match(/\/resources\/([\w-]*\.)?(\d+)\/?$/);
      if (!m) continue;
      const id = m[2];
      if (trouves.has(id)) continue;
      const titre = (a.textContent || '').trim();
      if (titre.length < 3) continue;                 // vignettes sans texte
      const bloc = a.closest('li, .structItem, .resourceListItem, div') || a.parentElement;
      trouves.set(id, {
        id,
        titre,
        url: `https://builtbybit.com/resources/${id}/`,
        contexte: (bloc ? bloc.textContent : '').replace(/\s+/g, ' ').trim().slice(0, 300),
      });
    }
    console.log(`listing ${p}/${PAGES} — ${trouves.size} annonces`);
    await pause(DELAI);
  }

  const annonces = [...trouves.values()];
  console.log(`${annonces.length} annonces trouvees.`);

  /* ---- Phase 2 : detail de chaque annonce -------------------------------- */
  if (DETAILS) {
    for (let i = 0; i < annonces.length; i++) {
      const a = annonces[i];
      try {
        const brut = await get(a.url);
        const doc = html2doc(brut);

        // Corps de la description : on prend le plus gros bloc de texte.
        const blocs = [...doc.querySelectorAll('.bbWrapper, .message-body, article, .resourceBody')];
        const corps = blocs.sort((x, y) => y.textContent.length - x.textContent.length)[0];
        const zone  = corps || doc.body;
        const texte = (zone.textContent || '').replace(/\s+/g, ' ').trim();

        a.titrePage = (doc.querySelector('h1') || {}).textContent?.trim() || a.titre;
        // Metriques de richesse : c'est la-dessus que repose la notation.
        a.mots      = texte.split(' ').filter(Boolean).length;
        a.images    = zone.querySelectorAll('img').length;
        a.videos    = zone.querySelectorAll('iframe, video').length;
        a.titres    = zone.querySelectorAll('h1,h2,h3,h4,b,strong').length;
        a.puces     = zone.querySelectorAll('li').length;
        a.liens     = zone.querySelectorAll('a').length;
        a.extrait   = texte.slice(0, 700);

        // Prix, note, avis, telechargements : on lit ce que la page expose.
        const t = doc.body.textContent.replace(/\s+/g, ' ');
        a.prix    = (t.match(/\$\s?\d+(?:[.,]\d{2})?/) || [null])[0];
        a.note    = (t.match(/([0-5][.,]\d)\s*(?:\/\s*5|stars?|etoiles?)/i) || [null, null])[1];
        a.avis    = (t.match(/(\d+)\s*(?:ratings?|reviews?|avis)/i) || [null, null])[1];
        a.dl      = (t.match(/(\d[\d,. ]*)\s*(?:downloads?|purchases?|sales?)/i) || [null, null])[1];
        a.maj     = (doc.querySelector('time') || {}).getAttribute?.('datetime') || null;
      } catch (e) {
        a.erreur = e.message;
      }
      if ((i + 1) % 25 === 0) console.log(`detail ${i + 1}/${annonces.length}`);
      await pause(DELAI);
    }
  }

  /* ---- Telechargement ---------------------------------------------------- */
  const blob = new Blob([JSON.stringify(annonces)], { type: 'application/json' });
  const lien = document.createElement('a');
  lien.href = URL.createObjectURL(blob);
  lien.download = 'builtbybit-roblox.json';
  lien.click();
  console.log(`TERMINE — ${annonces.length} annonces, fichier builtbybit-roblox.json telecharge.`);
})();
