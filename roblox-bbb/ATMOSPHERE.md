# Breakfast Escape — l'ambiance

Aucun asset à créer. Que des valeurs à taper dans Studio.
C'est ce qui fera que ton jeu ne ressemblera plus du tout à l'original vert.

**L'idée :** un matin d'été, le soleil bas entre par la fenêtre de la cuisine,
la lumière est dorée et il y a de la poussière qui flotte dedans.

---

## 1. Lighting

Sélectionne `Lighting` dans l'Explorer et règle ceci :

| Propriété | Valeur | Effet |
|---|---|---|
| `Technology` | `ShadowMap` | De vraies ombres, sans plomber les téléphones |
| `ClockTime` | `7.5` | Soleil bas du matin, ombres longues |
| `GeographicLatitude` | `20` | Le soleil rase au lieu de tomber d'aplomb |
| `Brightness` | `2` | |
| `ExposureCompensation` | `0.2` | Un rien surexposé, comme un matin |
| `Ambient` | `80, 70, 60` | Les ombres tirent vers le brun chaud |
| `OutdoorAmbient` | `130, 118, 100` | |
| `EnvironmentDiffuseScale` | `0.6` | |
| `GlobalShadows` | coché | |

**Ne prends pas `Future`** pour Technology. C'est plus beau mais ton jeu est un
jeu de course : la fluidité sur téléphone compte plus que la qualité des ombres.

---

## 2. Atmosphere

Clic droit sur `Lighting` → `Insert Object` → `Atmosphere`.

| Propriété | Valeur |
|---|---|
| `Density` | `0.3` |
| `Offset` | `0.25` |
| `Color` | `245, 230, 205` |
| `Decay` | `200, 175, 140` |
| `Glare` | `0.4` |
| `Haze` | `1.2` |

C'est ce qui donne la brume dorée dans laquelle la poussière flotte. Le `Haze`
est le réglage le plus visible : monte-le à `2` si tu veux plus de matin, descends
à `0.5` si ça devient laiteux.

---

## 3. Les trois effets

Toujours dans `Lighting`, `Insert Object` :

**Bloom** — le halo autour de ce qui est clair. C'est lui qui fait « lait ».

| Propriété | Valeur |
|---|---|
| `Intensity` | `0.6` |
| `Size` | `24` |
| `Threshold` | `1.2` |

**ColorCorrection** — la teinte générale.

| Propriété | Valeur |
|---|---|
| `Brightness` | `0.02` |
| `Contrast` | `0.08` |
| `Saturation` | `0.15` |
| `TintColor` | `255, 248, 235` |

**SunRays** — les rayons qui percent.

| Propriété | Valeur |
|---|---|
| `Intensity` | `0.12` |
| `Spread` | `0.9` |

Reste bas sur `Intensity` : au-delà de `0.2` on ne voit plus où on saute.

---

## 4. Ce qu'il ne faut pas mettre

**`DepthOfField`.** Ça floute l'arrière-plan. Sur un jeu où on court vite et où
on saute au jugé, c'est une gêne directe — et ça coûte cher en performance.

---

## 5. Faire varier selon l'étape

Le même décor sous une autre lumière devient une autre salle. Pose un
`ColorCorrection` supplémentaire dans la zone concernée, ou change simplement la
couleur des `PointLight` de l'étape.

| Étapes | Ambiance | Comment |
|---|---|---|
| 1 à 6 | Matin doré | Les réglages ci-dessus, tels quels |
| 7 · le lait | Blanc laiteux | `Saturation` à `0`, `Brightness` à `0.06` |
| 9 · le frigo | Froid | `TintColor` sur `225, 240, 255`, `Ambient` sur `60, 70, 85` |
| 11 · la poêle | Chaud | `TintColor` sur `255, 235, 210`, ajoute un `PointLight` orange au sol |
| 13 · le sirop | Ambré | `TintColor` sur `255, 225, 180`, `Contrast` à `0.15` |
| 15 · la fin | Plein jour | `ClockTime` à `12`, tout s'éclaire, on est arrivé |

---

## 6. Le test qui compte

Lance le jeu et regarde une capture d'écran de ton étape 7.

**La vague de lait doit être la chose la plus claire de l'image.** Si un mur ou
une boîte est plus lumineux qu'elle, baisse leur `Color` — pas la lumière. Le
joueur doit repérer le danger avant de le comprendre.

---

## 7. Le son fait la moitié de l'ambiance

C'est gratuit et personne n'y pense.

- **Fond de cuisine** : une radio lointaine, très bas dans le mix
- **Le grille-pain** : le « ding » quand il éjecte — ça devient ta signature sonore
- **La vague** : un glouglou grave et lent, pas un bruit d'eau vif
- **Le miel** : un son collant quand le joueur ralentit
- **Les céréales au sol** : un petit croustillement quand on court dessus
- **Dehors** : des oiseaux, très bas. C'est ce qui dit « c'est le matin ».

Tu as déjà un bouton `Sounds` dans ton interface : c'est là que ça se branche.
