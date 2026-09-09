# +1 Speed Breakfast Escape — liste des assets 3D à générer

Pour 3D AI Studio, Meshy ou tout générateur équivalent.

---

## 1. La règle la plus importante : le suffixe de style

**Colle ce texte à la fin de CHAQUE prompt, sans jamais le changer :**

```
, low-poly stylized cartoon game asset, flat solid colors, minimal surface detail,
smooth simple shapes, single centered object, no text, no logos, matte finish,
plain background
```

C'est ce qui fait que tes trente objets auront l'air de venir du même jeu.
Sans ce suffixe, chaque modèle sort dans un style différent — c'est très
probablement ce qui rendait tes essais précédents décevants, bien plus que
la qualité du générateur.

**Trois mots à ne jamais mettre :** `realistic`, `detailed`, `photorealistic`.
Ils produisent des maillages lourds et impossibles à assortir.

---

## 2. Ce qu'il NE faut PAS générer

Ces objets se font en dix secondes dans Studio et un générateur 3D les rendrait
plus lourds et moins nets. Ne gaspille pas tes crédits dessus.

| Objet | À faire à la place |
|---|---|
| Morceau de sucre | Un cube blanc, Material `SmoothPlastic` |
| Rondelle de banane | Un cylindre très plat, jaune |
| Toast (simple) | Un cube aplati, coins arrondis |
| Boîte de céréales | Un cube + ton image en Decal sur la face avant |
| Céréale en anneau | La forme `Torus` fournie par Roblox |
| Murs, sols, plateformes | Des Parts, toujours |
| Vague de lait | Un gros bloc blanc — sa force est sa simplicité |
| Flaque de miel, sol de sirop | Des dalles fines et translucides |
| Tranches de pain qui écrasent | Deux gros cubes |
| Monsieur Croustillant | Un avatar Roblox avec une tête cubique |

---

## 3. Les objets de table — le cœur du décor

Ce sont eux qui feront comprendre en une seconde qu'on est sur une table de
petit-déjeuner géante.

| # | Objet | Prompt (+ suffixe) |
|---|---|---|
| 01 | Cuillère | `a giant metal breakfast spoon` |
| 02 | Fourchette | `a giant metal breakfast fork` |
| 03 | Couteau à beurre | `a rounded butter knife` |
| 04 | Bol de céréales vide | `an empty round cereal bowl` |
| 05 | Bol plein de lait | `a cereal bowl filled with milk and floating cereal loops` |
| 06 | Tasse de café | `a coffee mug with a handle, seen from the side` |
| 07 | Verre de jus | `a tall glass of orange juice` |
| 08 | Assiette | `a round white breakfast plate` |
| 09 | Serviette pliée | `a folded paper napkin` |
| 10 | Salière et poivrière | `a salt shaker and a pepper shaker pair` |

---

## 4. La nourriture

À semer partout : sur les murs, au sol, sur les plateformes.

| # | Objet | Prompt (+ suffixe) |
|---|---|---|
| 11 | Pile de pancakes | `a stack of three pancakes with a pat of butter on top` |
| 12 | Gaufre | `a single square waffle` |
| 13 | Croissant | `a crescent-shaped croissant pastry` |
| 14 | Œuf au plat | `a fried egg, sunny side up` |
| 15 | Œuf dans son coquetier | `a boiled egg in an egg cup` |
| 16 | Tranche de bacon | `a wavy strip of cooked bacon` |
| 17 | Toast avec confiture | `a slice of toast with red jam spread on it` |
| 18 | Grappe de céréales | `a small cluster of colorful ring cereal pieces` |
| 19 | Fraise | `a single strawberry` |
| 20 | Régime de bananes | `a bunch of three bananas` |

---

## 5. Les contenants — les grands décors muraux

Ce sont les plus gros, ceux qu'on adosse aux murs. Génère-les en volume,
mais colle quand même tes images dessinées sur leur face avant : le modèle
donne le relief, ton image donne la marque.

| # | Objet | Prompt (+ suffixe) |
|---|---|---|
| 21 | Boîte de céréales (relief) | `a tall rectangular cereal box, blank front panel` |
| 22 | Brique de lait | `a milk carton with a folded triangular top` |
| 23 | Brique renversée | `a milk carton lying on its side, tipped over` |
| 24 | Pot de miel | `a squat honey jar with a lid` |
| 25 | Pot de confiture | `a glass jam jar with a cloth lid cover` |
| 26 | Bouteille de sirop | `a maple syrup bottle with a handle` |
| 27 | Bouteille de jus | `a juice carton with a screw cap` |
| 28 | Paquet de café | `a coffee bean bag, folded top` |
| 29 | Beurrier | `a rectangular butter dish with a lid` |
| 30 | Sucrier | `a small sugar bowl with a lid` |

---

## 6. Les appareils — les décors de fond

Un par étape suffit à donner son identité à la salle.

| # | Objet | Prompt (+ suffixe) | Étape |
|---|---|---|---|
| 31 | Grille-pain | `a two-slot pop-up toaster` | 4 et monstre |
| 32 | Cafetière | `a drip coffee maker with a glass pot` | 5 |
| 33 | Bouilloire | `a whistling kettle with a spout` | 11 |
| 34 | Réfrigérateur | `a tall two-door refrigerator, closed` | 9 |
| 35 | Micro-ondes | `a small microwave oven with a door window` | 8 |
| 36 | Mixeur | `a kitchen blender with a jug` | 12 |
| 37 | Poêle | `a round frying pan with a handle` | 11 |
| 38 | Boîte à œufs | `an open egg carton holding six eggs` | 15 |
| 39 | Horloge murale | `a round wall clock` | tous |
| 40 | Torchon suspendu | `a hanging kitchen towel` | tous |

---

## 7. Les monstres

Les seuls où il vaut la peine d'insister et de relancer plusieurs fois.

| # | Objet | Prompt (+ suffixe) |
|---|---|---|
| 41 | Cuillère géante | Reprends le n° 01, agrandi. Ne le régénère pas. |
| 42 | Grille-pain vivant | `a toaster with two large cartoon eyes on its front` |
| 43 | Monsieur Croustillant | À ne pas générer : un avatar Roblox avec une tête cubique aux couleurs de ta marque. |

---

## 8. Réglages à l'import dans Studio

À faire sur **chaque** modèle importé, sans exception.

1. **Vérifie le nombre de triangles.** Sélectionne le MeshPart, regarde ses
   propriétés. Au-delà de 5 000 triangles pour un objet décoratif, régénère
   en simplifiant le prompt. Un jeu de course doit rester fluide sur téléphone.

2. **Mets l'échelle tout de suite.** Un modèle importé arrive à une taille
   arbitraire. Décide d'une règle simple — par exemple une cuillère fait
   4 studs de long — et applique-la avant de dupliquer.

3. **`Anchored` = coché.** Sinon l'objet tombe au lancement. C'est l'erreur
   numéro un.

4. **`CanCollide` = décoché** pour tout ce qui est purement décoratif.
   Le joueur traverse, et tu gagnes énormément de performance.

5. **`CollisionFidelity` = `Box`** pour les props. `PreciseConvexDecomposition`
   est le réglage par défaut sur certains imports et il coûte très cher.

6. **`Material` = `SmoothPlastic`.** Les matériaux Roblox ajoutent un grain qui
   jure avec un modèle aux couleurs plates.

7. **Recolore dans Studio plutôt que dans le prompt.** Génère tes objets en gris
   ou en blanc et donne-leur leur couleur avec la propriété `Color`. Tu gardes
   la main, et tu peux faire six variantes d'un même modèle.

---

## 9. Ordre de production conseillé

| Lot | Objets | Pourquoi en premier |
|---|---|---|
| 1 | 01, 04, 06, 22 (cuillère, bol, tasse, lait) | Ce sont les quatre qu'on verra le plus. Ils valident ton style. |
| 2 | 31, 21 (grille-pain, boîte) | Le premier monstre et le décor mural principal. |
| 3 | 11 à 20 (la nourriture) | Beaucoup d'objets, petits, rapides à placer. |
| 4 | 24 à 30 (les contenants) | Le remplissage des murs. |
| 5 | 32 à 40 (les appareils) | Un par étape, pour différencier les salles. |

**Arrête-toi après le lot 1** et regarde le résultat dans le jeu avant de
continuer. Si ces quatre-là ne te plaisent pas, ce n'est pas la peine d'en
générer trente-six autres — il faut d'abord corriger le suffixe de style.

---

## 10. Si le rendu ne te plaît toujours pas

- **Objet trop chargé** : ajoute `very low poly, chunky shapes, few polygons`.
- **Couleurs sales** : ajoute `bright saturated flat colors, no shading`.
- **Formes molles** : ajoute `sharp clean edges, geometric`.
- **Ne ressemble pas aux autres** : c'est le suffixe qui a bougé. Vérifie que
  tu l'as collé mot pour mot.

Et rappelle-toi que sur un mur, à trois mètres, personne ne verra le détail.
Un objet lisible et cohérent bat un objet joli et isolé.
