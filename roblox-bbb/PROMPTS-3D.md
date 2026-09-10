# +1 Speed Breakfast Escape — le kit de 10 assets

Pour 3D AI Studio, Meshy ou équivalent.

---

## Pourquoi 10 et pas 43

Ma première liste était trop grosse, tu as eu raison de le dire. Un jeu qui pose
un objet différent à chaque endroit paraît chargé et sans style. Un jeu qui
recombine dix objets à des tailles différentes paraît construit.

Le principe :

- **10 assets générés une seule fois**
- **2 à 3 par étape**, jamais les mêmes trois ensemble
- **la taille change tout** : le même bol est un couvert au sol, une plateforme,
  ou l'arène entière

Chaque asset revient 3 à 5 fois sur les quinze étapes, à chaque fois autrement.
Le joueur ne voit pas la répétition, il voit une cuisine.

**Coût : 350 crédits au lieu de 1 505.**

---

## La règle des trois tailles

C'est elle qui empêche l'effet « trop rempli » dont tu parles.

**Sur chaque étape, tu poses exactement :**

| Rôle | Taille | Combien | Ce que c'est |
|---|---|---|---|
| **Le décor** | 40 à 80 studs | 1 seul | Adossé au mur ou au fond. C'est lui qui nomme l'étape. |
| **L'obstacle** | 8 à 15 studs | 1 ou 2 | On monte dessus, on le contourne, il gêne. |
| **Les miettes** | 0,5 à 2 studs | 5 à 15 | Semées au sol. Du détail qui ne gêne jamais. |

**Jamais deux objets de la même taille côte à côte.** C'est la seule règle à
retenir : c'est le contraste des tailles qui fait qu'une scène respire.

---

## Les 10 assets

Suffixe de style à coller à la fin de **chaque** prompt, sans jamais le changer :

```
, low-poly stylized cartoon game asset, flat solid colors, minimal surface detail,
smooth simple shapes, single centered object, no text, no logos, matte finish,
plain background
```

Sans lui, chaque objet sort dans un style différent. C'est très probablement ce
qui rendait tes essais Meshy décevants.

| # | Asset | Prompt (+ suffixe) | En décor | En obstacle | En miette |
|---|---|---|---|---|---|
| **1** | Bol | `an empty round cereal bowl` | L'arène : on court dedans | Une cuvette à traverser | Un bol posé au sol |
| **2** | Cuillère | `a giant metal breakfast spoon` | Le monstre du stage 10 | Une rampe, un pont | Un couvert au sol |
| **3** | Tasse | `a coffee mug with a handle` | Une tour à contourner | Une plateforme ronde | Une tasse renversée |
| **4** | Brique de lait | `a milk carton with a folded triangular top` | Le mur du fond | Un pilier | Une petite brique |
| **5** | Boîte de céréales | `a tall rectangular cereal box, blank front panel` | Le grand mur — ton image dessus | Un bloc à escalader | Une boîte tombée |
| **6** | Pile de pancakes | `a stack of three pancakes with a pat of butter on top` | Une colline | **Des plateformes empilées** | Un pancake au sol |
| **7** | Anneau de céréale | `a single ring-shaped breakfast cereal loop` | Un anneau géant à traverser | Un cerceau à franchir | **Semé partout** |
| **8** | Grille-pain | `a two-slot pop-up toaster` | Le monstre du stage 4 | Une machine qui éjecte | — |
| **9** | Pot de miel | `a squat honey jar with a lid` | La source du sirop | Un obstacle collant | Un pot au sol |
| **10** | Fraise | `a single strawberry` | — | **Un rocher qui roule** | La touche de couleur |

Note la colonne du milieu : **la cuillère en pont**, **les pancakes en
plateformes**, **la fraise en rocher roulant**. C'est là que le kit devient
malin — l'objet ne sert pas qu'à décorer, il fait partie du niveau.

---

## Le plan des 15 étapes

Aucun trio ne revient deux fois. Le gras indique l'asset en taille décor.

| Étape | Lieu | Décor (grand) | Obstacle (moyen) | Miettes (petit) | Nature |
|---|---|---|---|---|---|
| 1 | La table | **1** Bol | — | 7 anneaux | Ouverture calme |
| 2 | Le bol | **1** Bol | 4 Brique | 7 anneaux | Sol mortel : le lait |
| 3 | L'étagère | **5** Boîte | 10 Fraise | 10 fraises | Décor |
| 4 | Le grille-pain | **8** Grille-pain | 2 Cuillère | 7 anneaux | **Monstre 1** |
| 5 | Le pot de miel | **9** Pot | 6 Pancakes | 9 gouttes | Zone visqueuse |
| 6 | Le plan de travail | **3** Tasse | 5 Boîte | 7 anneaux | Sauts |
| 7 | La brique | **4** Brique | 1 Bol | 4 briquettes | **Vague de lait** |
| 8 | La pile | **6** Pancakes | 10 Fraise | 10 fraises | Écraseurs |
| 9 | Le placard | **5** Boîte | 3 Tasse | 7 anneaux | Décor, respiration |
| 10 | Le tiroir | **2** Cuillère | 9 Pot | 2 couverts | **Monstre 2** |
| 11 | La poêle | **6** Pancakes | 8 Grille-pain | 10 fraises | Sol mortel : l'huile |
| 12 | Le comptoir | **3** Tasse | 4 Brique | 4 briquettes | Écraseurs |
| 13 | Le sirop | **9** Pot | 2 Cuillère | 9 gouttes | **Vague de sirop** |
| 14 | L'étagère haute | **5** Boîte | 1 Bol | 10 fraises | L'étape difficile |
| 15 | La grande boîte | **5** Boîte | 8 Grille-pain | 7 anneaux | **Monstre 3** |

**Combien de fois chaque asset revient :** boîte 5 fois, bol et anneau 4 fois,
tous les autres 3 fois. Assez pour qu'on les reconnaisse, pas assez pour lasser.

---

## Quatre variations qui ne coûtent rien

Le même modèle, quatre apparences. À utiliser sans retenue.

**1. Le coucher.** Une brique de lait debout est un pilier. Couchée, c'est un
tunnel. Renversée avec du lait qui coule, c'est un danger. Trois décors, un
modèle.

**2. L'enfouir.** Enfonce un objet à moitié dans le sol ou dans un mur. Une
cuillère plantée dans le décor ne se reconnaît plus comme la cuillère du
stage 10.

**3. La couleur.** Génère tes modèles sans texture, puis change `Color` dans
Studio. La même fraise en rouge, en vert et en jaune fait trois fruits.

**4. La rotation.** Un objet incliné de 30 degrés paraît tombé, accidentel,
vivant. Un objet parfaitement droit paraît posé par un logiciel.

---

## Ce qu'on ne génère surtout pas

Ces éléments se font dans Studio en quelques secondes et un générateur les
rendrait plus lourds et moins nets.

| Élément | À faire à la place |
|---|---|
| Murs, sols, plateformes | Des Parts, toujours |
| La vague de lait | Un gros bloc blanc. Sa force est sa simplicité. |
| Le sol de sirop, la flaque de miel | Des dalles fines translucides |
| Les tranches de pain qui écrasent | Deux gros cubes |
| Le morceau de sucre | Un cube blanc |
| Monsieur Croustillant | Un avatar Roblox à tête cubique |
| Les six marques de céréales | **Le même asset n° 5**, avec six images différentes en Decal sur la face avant |

Cette dernière ligne est importante : tu ne génères **une seule** boîte de
céréales. Les six marques sont six images plates collées dessus.

---

## Les réglages dans 3D AI Studio

| Réglage | Valeur | Pourquoi |
|---|---|---|
| **Smart Low-Poly** | **ON** | C'est exactement ce qu'il te faut |
| **Polygon Count** | **4000** | En `Auto` tu peux recevoir 50 000 faces |
| **Enable Texturing** | **OFF** | Pour pouvoir recolorer dans Studio |
| **Material Type** | `Shaded` | `PBR` ramène vers le rendu réaliste |
| Texture / Mesh Quality | `Standard` | Suffisant pour des props |
| Email When Complete | ON | Tu ne restes pas devant l'écran |

**Le prompt ne doit contenir que l'anglais.** Ne colle pas le nom français ni
le `|` du tableau — le générateur essaierait de les interpréter.

---

## Réglages à l'import dans Studio

Sur **chaque** modèle, sans exception :

1. `Anchored` **coché** — sinon l'objet tombe au lancement. Erreur numéro un.
2. `CanCollide` **décoché** pour tout ce qui est purement décoratif — le joueur
   traverse, et tu gagnes beaucoup de performance.
3. `CollisionFidelity` = **`Box`** — le réglage par défaut coûte très cher.
4. `Material` = `SmoothPlastic` — les matériaux Roblox ajoutent un grain qui
   jure avec des couleurs plates.
5. Fixe une échelle de référence tout de suite. Par exemple : **le bol en taille
   obstacle fait 10 studs de large.** Tout le reste se règle par rapport à lui.

---

## Ordre de production

| Lot | Assets | Crédits | Pourquoi |
|---|---|---|---|
| **1** | 1 Bol, 2 Cuillère, 3 Tasse, 4 Brique | 140 | **Arrête-toi là et regarde dans le jeu.** Si le style ne va pas, c'est le suffixe qu'on corrige — tu n'auras perdu que 140 crédits. |
| 2 | 5 Boîte, 6 Pancakes | 70 | Le grand mur et les plateformes |
| 3 | 7 Anneau, 10 Fraise | 70 | Les miettes, qu'on sème partout |
| 4 | 8 Grille-pain, 9 Pot | 70 | Le monstre et la source du sirop |

**Total : 350 crédits.**

---

## Si le rendu ne va pas

- **Trop chargé** : ajoute `very low poly, chunky shapes, few polygons`
- **Couleurs sales** : ajoute `bright saturated flat colors, no shading`
- **Formes molles** : ajoute `sharp clean edges, geometric`
- **Ne ressemble pas aux autres** : le suffixe a bougé. Vérifie mot pour mot.

Et souviens-toi qu'à trois mètres, sur un écran de téléphone, personne ne verra
le détail. Un objet lisible et cohérent bat un objet joli et isolé.
