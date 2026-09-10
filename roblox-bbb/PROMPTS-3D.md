# Breakfast Escape — la déco

10 assets à générer, à poser sur des étapes qui existent déjà.
On ne touche à rien d'autre.

---

## Le suffixe de style

À coller à la fin de **chaque** prompt, sans jamais le changer :

```
, low-poly stylized cartoon game asset, flat solid colors, minimal surface detail,
smooth simple shapes, single centered object, no text, no logos, matte finish,
plain background
```

C'est lui qui fait que les dix objets ont l'air de venir du même jeu.
Sans lui, chacun sort dans un style différent.

Ne colle que l'anglais dans le champ : pas le nom français, pas le `|`.

---

## Les 10 assets

| # | Asset | Prompt (+ suffixe) |
|---|---|---|
| 1 | Bol | `an empty round cereal bowl` |
| 2 | Cuillère | `a giant metal breakfast spoon` |
| 3 | Tasse | `a coffee mug with a handle` |
| 4 | Brique de lait | `a milk carton with a folded triangular top` |
| 5 | Boîte de céréales | `a tall rectangular cereal box, blank front panel` |
| 6 | Pile de pancakes | `a stack of three pancakes with a pat of butter on top` |
| 7 | Anneau de céréale | `a single ring-shaped breakfast cereal loop` |
| 8 | Grille-pain | `a two-slot pop-up toaster` |
| 9 | Pot de miel | `a squat honey jar with a lid` |
| 10 | Fraise | `a single strawberry` |

---

## Deux tailles, jamais trois

C'est la seule règle pour que ça ne fasse pas surchargé.

- **Le grand** — adossé au mur du fond, 40 à 80 studs. **Un seul par étape.**
- **Les petits** — semés au sol le long du chemin, 0,5 à 2 studs. 5 à 15 par étape.

Rien entre les deux. C'est l'écart de taille qui fait respirer la scène.

---

## Quoi mettre sur chaque étape

| Étape | Le grand au fond | Les petits au sol |
|---|---|---|
| 1 | Bol | anneaux |
| 2 | Brique de lait | anneaux + fraises |
| 3 | Boîte de céréales | fraises |
| 4 | Grille-pain | anneaux |
| 5 | Pot de miel | pancakes |
| 6 | Tasse | anneaux + cuillères |
| 7 | Brique de lait | briquettes |
| 8 | Pile de pancakes | fraises |
| 9 | Boîte de céréales | anneaux + tasses |
| 10 | Cuillère | cuillères |
| 11 | Pile de pancakes | fraises |
| 12 | Tasse | briquettes |
| 13 | Pot de miel | gouttes de miel |
| 14 | Boîte de céréales | fraises + anneaux |
| 15 | Boîte de céréales | anneaux |

La boîte revient 4 fois, mais avec une **marque différente à chaque fois** —
voir plus bas. Personne ne remarque que c'est le même modèle.

---

## Quatre façons de ne pas répéter

Le même objet, quatre apparences.

1. **Couche-le.** Une brique de lait debout est un pilier. Couchée, c'est autre chose.
2. **Enfonce-le.** À moitié dans le mur ou le sol, il ne se reconnaît plus.
3. **Recolore-le.** Génère sans texture, puis change `Color` dans Studio.
   La même fraise en rouge, vert et jaune fait trois fruits.
4. **Incline-le.** 30 degrés, et l'objet paraît tombé plutôt que posé par un logiciel.

---

## Les six marques de céréales

Tu ne génères **qu'une seule** boîte. Les six marques sont six images plates
collées sur sa face avant avec un `Decal`. Un asset, six apparences.

---

## Réglages dans 3D AI Studio

| Réglage | Valeur |
|---|---|
| Smart Low-Poly | **ON** |
| Polygon Count | **4000** |
| Enable Texturing | **OFF** (pour recolorer dans Studio) |
| Material Type | `Shaded` |
| Texture / Mesh Quality | `Standard` |
| Email When Complete | ON |

---

## Réglages à l'import dans Studio

Sur chaque modèle, sans exception :

1. `Anchored` **coché** — sinon l'objet tombe au lancement.
2. `CanCollide` **décoché** — c'est de la déco, le joueur doit la traverser.
3. `CollisionFidelity` = **`Box`**.
4. `Material` = `SmoothPlastic`.

---

## Ordre et coût

| Lot | Assets | Crédits |
|---|---|---|
| **1** | Bol, Cuillère, Tasse, Brique | 140 |
| 2 | Boîte, Pancakes | 70 |
| 3 | Anneau, Fraise | 70 |
| 4 | Grille-pain, Pot de miel | 70 |

**Total : 350 crédits.**

**Arrête-toi après le lot 1.** Pose les quatre dans le jeu, regarde. Si le style
ne va pas, on corrige le suffixe et tu n'as perdu que 140 crédits.

---

## Si le rendu ne va pas

- **Trop chargé** → ajoute `very low poly, chunky shapes, few polygons`
- **Couleurs sales** → ajoute `bright saturated flat colors, no shading`
- **Formes molles** → ajoute `sharp clean edges, geometric`
- **Ne ressemble pas aux autres** → le suffixe a bougé, vérifie mot pour mot
