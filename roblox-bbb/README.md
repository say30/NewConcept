# Analyse des jeux Roblox en vente sur BuiltByBit

Recupere les annonces **Roblox > Game Setups** de BuiltByBit, les note sur la richesse
reelle de leur fiche et leur traction, les croise avec les jeux existants sur Roblox,
puis genere un classeur HTML (une fiche par jeu).

Resultat de la derniere execution : **1350 annonces analysees**, top 20 publie.

## Pourquoi une collecte cote navigateur

Deux voies ont ete essayees et fermees :

- **Scraping serveur** — builtbybit.com est derriere un challenge Cloudflare. curl 403,
  Chromium headless et headed sous Xvfb bloques au challenge, lecteurs tiers bloques,
  robots.txt et sitemap.xml bloques aussi.
- **API officielle** — `api.builtbybit.com/v1` repond, mais un token Private avec la case
  « Allow use with our V1 endpoints » activee obtient `success` sur `/v1/health` et
  `PrivilegeRestrictedError` sur tout le reste (`/resources`, `/members/self`, `/alerts`) ;
  la v2 repond `TokenScopeNotEnabled`. Ces endpoints exigent l'abonnement Ultimate payant.

La collecte se fait donc depuis le navigateur de l'utilisateur, qui dispose deja de la
clearance Cloudflare. `collecte-navigateur.js` se colle dans la console.

## Utilisation

```bash
# 1. Dans la console du navigateur, sur builtbybit.com connecte :
#    coller collecte-navigateur.js  ->  telecharge builtbybit-roblox.json  (~12 min)

node scripts/1b_import_navigateur.js ~/builtbybit-roblox.json  # -> data/bbb_resources.json
node scripts/3_score.js                    # pre-classement (bloc marche neutralise)
TOP_N=150 node scripts/2_roblox_match.js   # croisement Roblox des 150 meilleures
node scripts/3_score.js                    # classement final
TOP=20 node scripts/3b_vignettes.js        # vignettes encodees en data: URI
TOP=20 node scripts/4_build_classeur.js    # -> classeur.html
```

`diagnostic.js` sert a reajuster le collecteur si le theme du site change : il releve
depuis la console les classes CSS reellement utilisees, le HTML d'une annonce et la
forme des URL de pagination.

Aucune dependance npm (Node 18+, `curl` present).
`scripts/1_bbb_fetch.js` est la voie API, conservee au cas ou l'acces s'ouvrirait.

## Notation (100 points)

| Bloc | Points | Mesure |
|---|---|---|
| Annonce | 50 | longueur du texte (14), structure titres/puces (10), captures et videos (12), liste de contenu (6), avis et note (8) |
| Traction | 20 | ventes (14), positionnement prix (6) |
| Marche Roblox | 30 | audience du meilleur equivalent (16), creneau libre (9), genre encore vivant (5) |

Bareme cale sur la distribution reelle du corpus : mediane 157 mots, 23 captures,
18 puces, 5 ventes. Le suivi des mises a jour n'est pas lisible depuis la page publique
et n'est donc pas note.

Un concurrent Roblox n'est compte que si son titre est suffisamment proche (similarite
Dice >= 0.35) **et** qu'il depasse 100 000 visites. Les jeux du meme univers au titre trop
eloigne restent affiches, marques « voisin ».

## Cote Roblox

`2_roblox_match.js` interroge `apis.roblox.com/search-api/omni-search` avec un titre
nettoye, recupere les statistiques via `games.roblox.com/v1/games` (visites, joueurs en
ligne, favoris, ratio de likes) et les vignettes via `thumbnails.roblox.com`, puis classe
les candidats par proximite de titre. Quand un genre compte 3 concurrents ou moins, le
classeur propose des idees de variantes adaptees au genre detecte.
