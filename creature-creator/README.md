# 🦎 Créateur de Créatures (façon Spore) → Roblox

Un éditeur de créatures inspiré du *Spore Creature Creator*, pensé pour **exporter vers Roblox Studio** des modèles propres :

- **chaque élément est un objet séparé** (un MeshPart par pièce dans Roblox) : un œil = blanc + iris + pupille + reflet, une bouche = intérieur + dents, une oreille = oreille + intérieur… Tu peux donc **changer la couleur et le matériau de chaque pièce** dans Roblox ;
- **chaque objet est un maillage fermé** : aucun trou, aucune face cachée ;
- la taille est exportée **directement en studs**, avec un **squelette (os)** en option pour l'animation.

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
| **🦴 Construire** | Colonne vertébrale sculptable (glisser les vertèbres jaunes, molette = épaisseur, ajouter/insérer/retirer des vertèbres). **9 types de membres** : jambe, patte digitigrade, jambe massive, bras, long bras, patte d'insecte, tentacule, bras-aile, cou/tige. **122 pièces** : formes libres (10 : sphère, dôme, cube arrondi, cylindre, cône, capsule, tore, pyramide, lame, étoile), yeux (14), bouches & nez (18), cornes & antennes (12), oreilles (9), poils & crêtes (7), ailes & nageoires (9), bouts de queue (10), détails & armures (15), mains (9), pieds (9). Presque toutes ont des réglages propres (longueur, courbure, nombre de dents / piques / doigts, ouverture…). |
| **🎨 Peindre** | Une couleur par rôle : peau, secondaire, détail, griffes/os, blanc des yeux, iris, pupille, reflet, intérieur de bouche, langue, dents, nez/sombre. Chaque pièce peut aussi prendre une **teinte personnalisée**. Option **motif + ventre** peints sur le corps (8 motifs), exportés en texture si tu le souhaites. |
| **▶️ Tester** | Animation de test (marche, course, repos, danse) avec le **vrai squelette qui sera exporté** ; les pièces suivent leurs os. |

Et aussi : **9 modèles de départ** (quadrupède, humanoïde, dragon, insecte, oiseau, créature marine, petit mignon, araignée, golem), **générateur aléatoire**,
symétrie automatique (désactivable par pièce), option « fondre dans le corps » par pièce, annuler/rétablir (100 étapes), **collection** sauvegardée dans le navigateur, import/export `.json`.

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
- **Triangles du corps** : 2 000 à 20 000 (limite Roblox ≈ 20 000 par MeshPart). Le corps est calculé très finement puis **simplifié intelligemment** : les formes restent nettes et les zones plates perdent leurs triangles inutiles.
- **Détail des pièces** : léger / standard / élevé / maximum. Les pointes (crocs, cornes, griffes) restent pointues.
- **Texture du corps** (option) : motif + ventre peints. Sans cette option, chaque objet est d'une **couleur unie**, idéal pour les matériaux Roblox.
- **Squelette** : os nommés (`Root`, `Head`, `Spine2`, `Leg1_1_R`, `Arm1_2_L`…). Le corps est « skinné » (4 influences max par sommet) ; chaque pièce est attachée rigidement à son os.

Fichiers proposés :

1. **`.glb`** (recommandé) : tous les objets + couleurs + squelette dans un seul fichier.
2. **`.zip` OBJ** : un `.obj` avec un objet et un matériau par pièce (+ la texture du corps si activée).

Un rapport s'affiche après génération : nombre d'objets, triangles, **maillages avec trous = 0**, arêtes non-manifold, taille en studs, nombre d'os, liste des pièces.

Noms des objets : `Corps`, puis `<Pièce>_<côté>_<élément>`, par exemple `OeilRond_R_Iris`, `OeilRond_L_Pupille`, `MachoireADents_Dents`, `Leg1PatteACoussinets_R_Griffes`.

### Import dans Roblox Studio

1. Onglet **Accueil** (ou Avatar) → **Importer 3D** → choisis le `.glb`.
2. Réglages d'import : **File Geometry → Scale Unit : Studs** (le fichier est déjà en studs ; c'est aussi ce qui évite le bug de mise à l'échelle des os des meshes riggés).
3. **Import** : tu obtiens un Model avec un MeshPart par pièce. Change la **Color** et le **Material** de chacune librement.
4. Modèle riggé : les **Bones** sont inclus ; ajoute un `AnimationController` + `Animator`, ou anime-le avec l'éditeur d'animation.
5. Modèle statique : soude les pièces (`WeldConstraint`) ou ancre le modèle (**Anchored**). Pour la collision, `CollisionFidelity = Hull` ou `Box` suffit généralement.

L'avant de la créature regarde vers **−Z**, c'est-à-dire la direction `LookVector` de Roblox.

## 🔧 Pourquoi il n'y a pas de trous et pourquoi c'est net

1. Chaque forme est décrite mathématiquement (distance signée, « SDF ») : union lisse, creusement (bouche, narines), intersection (iris et pupilles découpés proprement sur l'œil).
2. Chaque objet est converti en maillage par un **Surface Nets « manifold »** (dual marching cubes) : chaque arête de la grille qui traverse la surface produit exactement un quad, donc **la surface est toujours fermée**. Les cas ambigus sont résolus de façon cohérente ; les rares « tunnels » sont réparés en dédoublant le sommet concerné.
3. **Chaque pièce a sa propre grille**, dimensionnée à sa taille : une pupille ou un croc est calculé aussi finement que le corps entier. C'est pour ça que les pointes sont pointues et les petites pièces nettes.
4. Les maillages sont ensuite **simplifiés par erreur quadrique** (Garland-Heckbert) avec vérification de la topologie à chaque étape : ils restent fermés et 2-manifold, et les détails saillants sont conservés.
5. Chaque export est **vérifié** : chaque arête est partagée par exactement 2 triangles, pour chaque objet.

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
│  ├─ sdf.js              ← primitives à distance signée (sphère, cône arrondi, ellipsoïde, boîte, triangle, tore, plan, groupe)
│  ├─ creature.js         ← modèle de données, colonne, membres, ancrages, squelette
│  ├─ parts.js            ← catalogue des pièces et membres
│  ├─ mesher.js           ← grille, Surface Nets manifold, lissage, couleurs, poids des os
│  ├─ pipeline.js         ← maillage du corps et de chaque pièce (aperçu / export)
│  ├─ decimate.js         ← simplification par erreur quadrique (reste étanche)
│  ├─ bake.js             ← texture atlas optionnelle du corps
│  ├─ paint.js            ← motifs procéduraux, yeux
│  ├─ presets.js, random.js, edit.js, validate.js
├─ src/export/            ← écriture GLB (glTF 2.0 binaire), OBJ/MTL, ZIP
└─ tests/                 ← tests Node + test navigateur (Playwright)
```

Ajouter une pièce : une entrée dans `src/core/parts.js` avec une fonction `build(c, p)` qui assemble des formes (`c.sphere`, `c.cone`, `c.chain`, `c.ell`, `c.box`, `c.tri`, `c.torus`, `c.eye`, `c.keep` pour couper). `c.piece('Nom', 'slot')` crée une nouvelle pièce séparée ; `{ op: 'sub' }` creuse, `{ body: true }` agit sur le corps.

## Limites connues

- Les animations de l'onglet « Tester » ne sont pas exportées : seul le squelette l'est. Les animations se font ensuite dans Roblox.
- L'ancien format `.fbx` n'est pas généré ; Roblox importe très bien le `.glb`.
- Les membres font partie du corps (une seule couleur « Peau ») pour que les articulations restent sans couture quand la créature est animée.
- Le maillage est organique et lisse par nature. Pour un style low-poly, baisse le budget de triangles.

## Inspirations

- Spore Creature Creator (Maxis / EA)
- [Creature Creator](https://github.com/daniellochner/creature-creator-game) de Daniel Lochner (Unity, GPL-3.0). Aucun code n'en est repris ; cette application est écrite de zéro en JavaScript.
