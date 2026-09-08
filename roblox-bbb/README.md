# Analyse des jeux Roblox en vente sur BuiltByBit

Pipeline qui recupere les annonces **Roblox > Game Setups** de BuiltByBit, les note
selon la richesse de leur fiche et leur traction, les croise avec les jeux reels sur
Roblox, puis genere un classeur HTML (une fiche par jeu).

## Pourquoi l'API et pas le scraping

builtbybit.com est derriere un challenge Cloudflare qui bloque tout acces automatise
depuis un environnement serveur (curl -> 403, Chromium headless **et** headed sous
Xvfb -> challenge jamais resolu, lecteurs tiers -> bloques). En revanche
`api.builtbybit.com/v1` repond normalement : c'est la voie utilisee ici.

Il faut un token : builtbybit.com -> ton compte -> **API Credentials** -> creer un
token en lecture. Format attendu : `Private <token>`.

## Utilisation

```bash
export BBB_TOKEN="Private xxxxxxxx"
node scripts/1_bbb_fetch.js       # -> data/bbb_resources.json
node scripts/2_roblox_match.js    # -> data/roblox_matches.json
node scripts/3_score.js           # -> data/classement.json + top 20 en console
TOP=20 node scripts/4_build_classeur.js   # -> classeur.html
```

Aucune dependance npm (Node 18+, `curl` present).

## Notation (100 points)

| Bloc | Points | Ce qui est mesure |
|---|---|---|
| Qualite de l'annonce | 50 | longueur de description, structure (titres/listes), nombre de medias, liste de fonctionnalites, nombre de mises a jour, avis et note |
| Traction commerciale | 20 | nombre de ventes, positionnement prix |
| Potentiel marche Roblox | 30 | audience prouvee du meilleur equivalent, saturation du genre (peu de concurrents credibles = opportunite), fraicheur des mises a jour |

Les sous-scores sont conserves dans `data/classement.json` et affiches dans chaque fiche.

## Cote Roblox

Pour chaque annonce, `2_roblox_match.js` interroge la recherche Roblox
(`apis.roblox.com/search-api/omni-search`) avec un titre nettoye, recupere les
statistiques (`games.roblox.com/v1/games` : visites, joueurs en ligne, favoris,
ratio de likes) et les vignettes (`thumbnails.roblox.com`), puis classe les
candidats par proximite de titre. Quand un genre compte 3 concurrents credibles ou
moins, le classeur propose des idees de variantes a developper.
