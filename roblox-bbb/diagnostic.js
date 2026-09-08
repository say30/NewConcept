/* ============================================================================
   Diagnostic — a coller dans la console, sur la page de recherche BuiltByBit
   deja ouverte et connectee. Ne collecte rien : il decrit ce que la page contient
   vraiment, pour que le collecteur puisse etre corrige.
   Telecharge un petit fichier diagnostic.json.
   ============================================================================ */
(async () => {
  const out = { url: location.href, titre: document.title };

  /* --- A. Ce que voit le DOM vivant (JS deja execute) --- */
  const liensVivants = [...document.querySelectorAll('a[href*="/resources/"]')]
    .map(a => a.getAttribute('href'));
  out.dom = {
    total_liens_resources: liensVivants.length,
    echantillon: liensVivants.slice(0, 25),
    // Quels conteneurs repetitifs existent ? Utile pour cibler chaque annonce.
    classes_repetees: (() => {
      const compte = {};
      for (const el of document.querySelectorAll('div,li,article')) {
        for (const c of el.classList) compte[c] = (compte[c] || 0) + 1;
      }
      return Object.entries(compte)
        .filter(([, n]) => n >= 5 && n <= 60)
        .sort((a, b) => b[1] - a[1]).slice(0, 30);
    })(),
  };

  // Le bloc HTML complet d'une annonce : c'est ce qui me permet d'ecrire le parseur.
  const premier = document.querySelector('a[href*="/resources/"]');
  if (premier) {
    let bloc = premier;
    for (let i = 0; i < 6 && bloc.parentElement; i++) bloc = bloc.parentElement;
    out.dom.exemple_bloc_html = bloc.outerHTML.slice(0, 4000);
  }

  /* --- B. Ce que renvoie un fetch (HTML brut, sans JS) --- */
  try {
    const r = await fetch(location.href, { credentials: 'include' });
    const h = await r.text();
    out.fetch = {
      statut: r.status,
      taille: h.length,
      cloudflare: /just a moment|challenge-platform|cf-chl/i.test(h),
      occurrences_resources: (h.match(/\/resources\//g) || []).length,
      // Les hrefs presents dans le HTML brut : si vide alors que le DOM en a, c'est du rendu JS.
      echantillon_hrefs: (h.match(/href="[^"]*\/resources\/[^"]*"/g) || []).slice(0, 15),
    };
  } catch (e) { out.fetch = { erreur: e.message }; }

  /* --- C. La pagination : quelle forme d'URL le site utilise-t-il ? --- */
  out.pagination = [...document.querySelectorAll('a[href*="page"]')]
    .map(a => a.getAttribute('href')).slice(0, 12);

  const b = new Blob([JSON.stringify(out, null, 2)], { type: 'application/json' });
  const l = document.createElement('a');
  l.href = URL.createObjectURL(b); l.download = 'diagnostic.json'; l.click();
  console.log('diagnostic.json telecharge');
  console.log('liens dans le DOM :', out.dom.total_liens_resources,
              '| dans le HTML brut :', out.fetch && out.fetch.occurrences_resources,
              '| cloudflare :', out.fetch && out.fetch.cloudflare);
})();
