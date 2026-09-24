# 🦎 Créateur de Créatures (façon Spore) → Roblox

Un éditeur de créatures inspiré du *Spore Creature Creator*, pensé pour **exporter vers Roblox Studio** des modèles propres :
un **seul maillage fermé** (aucun trou, aucune face cachée à l'intérieur), **texturé**, avec un **squelette (os)** optionnel pour l'animation.

Usage personnel, gratuit, sans serveur : tout tourne dans le navigateur.

## ▶️ Lancer l'application

**Le plus simple :** ouvre `dist/index.html` en double-cliquant dessus (Chrome, Edge ou Firefox récent).
C'est un fichier unique et autonome : il marche hors-ligne et peut être copié n'importe où.

**Pour modifier le code :**

```bash
cd creature-creator
npm install
npm run dev      # serveur de développement (http://localhost:5173)
npm run build    # régénère dist/index.html
npm test         # tests du maillage (étanchéité, non-manifold) + export GLB validé
```

## 🧬 Ce que tu peux faire

| Mode | Contenu |
|---|---|
| **🦴 Construire** | Colonne vertébrale sculptable (glisser les vertèbres jaunes, molette = épaisseur, ajouter/insérer/retirer des vertèbres), membres articulés (jambe, patte digitigrade, bras, patte d'insecte, tentacule, bras-aile, cou/tige), **67 pièces** : yeux (8), bouches & nez (12), cornes & antennes (8), oreilles (5), ailes & nageoires (6), bouts de queue (6), détails & armures (9), mains (6), pieds (7). |
| **🎨 Peindre** | 6 couleurs (principale, secondaire, détail, griffes/os, ventre, yeux), uni + 8 motifs procéduraux (taches, léopard, rayures, tigre, girafe, écailles, dos foncé, camouflage…), 14 palettes, grain de peau, couleur par pièce ou teinte personnalisée. |
| **▶️ Tester** | Animation de test (marche, course, repos, danse) avec le **vrai squelette qui sera exporté**, pour vérifier que la peau suit bien les os. |

Et aussi : **9 modèles de départ** (quadrupède, humanoïde, dragon, insecte, oiseau, créature marine, petit mignon, araignée, golem), **générateur aléatoire**,
symétrie automatique (désactivable par pièce), annuler/rétablir (100 étapes), **collection** sauvegardée dans le navigateur, import/export `.json`.

### Contrôles

- **Clic** sur une pièce / un membre : le sélectionner (réglages à droite : taille, rotation, enfoncement, paramètres propres à la pièce, couleur, symétrie).
- **Glisser** une pièce : elle glisse sur la peau. **Molette** sur une pièce, une vertèbre ou une articulation : taille / épaisseur.
- **Clic-glisser dans le vide** : tourner la caméra · clic droit : déplacer · molette : zoom.
- Catalogue : clique une pièce puis clique sur la créature (ou glisse-la directement). `Maj`+clic pour en poser plusieurs.
- Mains/pieds : sélectionne un membre puis clique une main/un pied (ou glisse-le près du bout du membre).
- Raccourcis : `Suppr` supprimer · `D` dupliquer · `M` symétrie on/off · `Ctrl+Z` / `Ctrl+Y` · `Échap`.

## ⬇️ Export pour Roblox

Bouton **« Exporter pour Roblox »** :

- **Hauteur en studs** : le modèle est mis à l'échelle, posé au sol (y = 0) et centré.
- **Triangles max** : 1 000 à 20 000 (limite Roblox par MeshPart ≈ 20 000). La résolution est ajustée automatiquement pour rester sous ce budget.
- **Texture** 512 ou 1024 px, intégrée au fichier.
- **Squelette** : os nommés (`Root`, `Head`, `Spine2`, `Leg1_1_R`, `Arm1_2_L`…), 4 influences max par sommet.

Fichiers proposés :

1. **`.glb`** (recommandé) : maillage + texture + squelette dans un seul fichier.
2. **`.zip` OBJ** : `.obj` + `.mtl` + `.png` (statique, sans os).
3. **Texture seule** (`.png`).

Un rapport s'affiche après génération : nombre de triangles, **trous = 0**, arêtes non-manifold, taille en studs, nombre d'os.

### Import dans Roblox Studio

1. Onglet **Accueil** (ou Avatar) → **Importer 3D** → choisis le `.glb`.
2. Réglages d'import : **File Geometry → Scale Unit : Studs** (le fichier est déjà en studs ; c'est aussi ce qui évite le bug de mise à l'échelle des os des meshes riggés).
3. Garde la texture activée → **Import**.
4. Modèle riggé : il arrive avec ses **Bones** ; ajoute un `AnimationController` + `Animator`, ou anime-le avec l'éditeur d'animation.
5. Modèle statique : pense à cocher **Anchored** si c'est un décor. Pour la collision, `CollisionFidelity = Hull` ou `Box` suffit généralement.

L'avant de la créature regarde vers **−Z**, c'est-à-dire la direction `LookVector` de Roblox.

## 🔧 Pourquoi il n'y a pas de trous

L'approche classique (coller des morceaux de maillage) laisse des fentes et des faces internes. Ici :

1. La créature est décrite comme une **union lisse de formes mathématiques** (distance signée, « SDF ») : vertèbres, membres et pièces fusionnent en douceur, et les bouches / creux d'oreilles sont **soustraits**.
2. Cette forme est convertie en maillage par un **Surface Nets « manifold »** (dual marching cubes). Chaque arête de la grille qui traverse la surface produit exactement un quad, donc **la surface est toujours fermée**. Les faces ambiguës sont résolues de la même façon des deux côtés.
3. Les rares cas de « tunnel » (deux feuilles fines dans le même voxel) sont réparés en dédoublant le sommet concerné, et chaque export est **vérifié** : chaque arête est partagée par exactement 2 triangles.
4. Les parties trop fines (antennes, membranes) sont automatiquement épaissies à la taille d'un voxel pour ne jamais se fragmenter.
5. Les couleurs (motifs, yeux, ombrage d'occlusion) sont **cuites dans une texture** : atlas par triangle, ordonné selon une courbe de Morton pour limiter les bavures de mip-map.

Les tests automatiques (`npm test`) vérifient tout ça sur les 9 modèles et 15 créatures aléatoires, et font passer chaque `.glb` dans le **validateur glTF officiel de Khronos** (0 erreur, 0 avertissement).

## 📁 Organisation du code

```
creature-creator/
├─ dist/index.html        ← l'application prête à l'emploi (fichier unique)
├─ index.html, src/style.css
├─ src/main.js            ← interface, interactions, historique, export
├─ src/viewport.js        ← rendu three.js, poignées, animation de test
├─ src/worker.js          ← maillage en arrière-plan (Web Worker)
├─ src/core/
│  ├─ sdf.js              ← primitives à distance signée (sphère, cône arrondi, ellipsoïde, boîte, triangle)
│  ├─ creature.js         ← modèle de données, colonne, membres, ancrages, squelette
│  ├─ parts.js            ← catalogue des pièces et membres
│  ├─ mesher.js           ← grille, Surface Nets manifold, lissage, couleurs, poids des os
│  ├─ bake.js             ← budget de triangles, cuisson de la texture atlas
│  ├─ paint.js            ← motifs procéduraux, yeux
│  ├─ presets.js, random.js, edit.js, validate.js
├─ src/export/            ← écriture GLB (glTF 2.0 binaire), OBJ/MTL, ZIP
└─ tests/                 ← tests Node + test navigateur (Playwright)
```

Ajouter une pièce : une entrée dans `src/core/parts.js` avec une fonction `build(c, p)` qui assemble des formes (`c.sphere`, `c.cone`, `c.ell`, `c.box`, `c.tri`, `c.eye`, `{ sub: true }` pour creuser).

## Limites connues

- Les animations de l'onglet « Tester » ne sont pas exportées : seul le squelette l'est. Les animations se font ensuite dans Roblox.
- L'ancien format `.fbx` n'est pas généré ; Roblox importe très bien le `.glb`.
- Le maillage est organique et lisse par nature. Pour un style low-poly, baisse le budget de triangles.

## Inspirations

- Spore Creature Creator (Maxis / EA)
- [Creature Creator](https://github.com/daniellochner/creature-creator-game) de Daniel Lochner (Unity, GPL-3.0). Aucun code n'en est repris ; cette application est écrite de zéro en JavaScript.
