# Creature Forge — plugin Roblox Studio (V1)

Étudier des créatures existantes (proportions, découpage, rig, palette) puis générer
**vos propres créatures** : géométrie 100 % procédurale (EditableMesh), nouveaux
MeshIds publiés sur **votre** compte, nouveau rig, nouvelles couleurs.

Aucun sommet d'un mesh source n'est lu, aucun MeshId source n'est réutilisé ni
uploadé. Le modèle source n'est jamais modifié : tout est créé dans
`Workspace/CreatureForge_Output`, et chaque opération est annulable (Ctrl+Z).

## Installation (2 minutes)

1. Téléchargez **`CreatureForge.rbxmx`** (dans ce dossier).
2. Studio → onglet **Plugins** → **Plugins Folder** → copiez le fichier dedans.
3. Redémarrez Studio → bouton **Creature Forge** dans l'onglet Plugins.

Le plugin doit être chargé **localement** (dossier Plugins) : c'est la condition
imposée par Roblox pour `AssetService:CreateAssetAsync` (publication sans prompt).

> Avec Rojo : `rojo build default.project.json -o CreatureForge.rbxmx`
> ou `python3 tools/build_plugin.py` (aucune dépendance).

## Utilisation

**Onglet STUDY / REBUILD**

| Action | Résultat |
|---|---|
| Sélectionner une créature | « Créature sélectionnée : Sunshine Dragon ✓ » (cliquer une pièce suffit) |
| **ANALYSER LA CRÉATURE** | Résumé : pièces, MeshParts, couleurs, Motor6D, bones + morphologie |
| **BLUEPRINT** | Copie d'étude à côté : une boîte exacte (taille / position / rotation / couleur / nom) par pièce |
| **VUE ÉCLATÉE** + slider | Écarte les pièces autour du centre, orientation conservée |
| **AFFICHER RIG** | Motor6D (orange), welds, bones (rose), attachments (cyan) : lignes + marqueurs |
| **FANTÔME (forme réelle)** | Superpose l'original en transparence sur le blueprint (suit la vue éclatée) — étude uniquement, jamais publié |
| **CRÉER MA CRÉATURE** | Nouvelle créature stylisée low-poly : meshes neufs, couleurs, rig, matériau |
| **RECONSTRUIRE FIDÈLE** | Même disposition, tailles, rotations, couleurs, matières et Motor6D que l'original, chaque pièce refaite par une forme générée qui remplit sa boîte |
| **NOUVELLES COULEURS** | Palette cohérente Primary / Secondary / Accent / Eyes / Special |
| Pastille de couleur | Sélectionne la couleur → modifiez-la dans Propriétés, la créature suit |
| Material | Original / Studs (votre MaterialVariant, nom modifiable) / SmoothPlastic |
| **CRÉER RIG** | Reconstruit le rig (utile après vos retouches) |
| **PUBLIER MES MESHES** | Upload des nouveaux meshes sur votre compte + remplacement automatique des IDs |

Raccourci : **CRÉER MA CRÉATURE** analyse automatiquement si besoin.
`Variation` : Faible (proche des proportions) · Moyenne · Forte (simple inspiration
structurelle). `Seed` vide = aléatoire ; une seed fixe régénère la même créature.

**Onglet CREATURE MIXER** : prévu pour l'étape suivante (V2).

## Étudier une créature « de l'intérieur »

Les sommets d'un mesh qui ne vous appartient pas sont illisibles (règle Roblox).
Pour comprendre la construction : **BLUEPRINT** + **FANTÔME** + **VUE ÉCLATÉE**
(chaque pièce et sa vraie forme, écartées), **AFFICHER RIG**, et dans Studio
l'onglet *Affichage* › rendu **fil de fer** (wireframe) pour voir le découpage des
triangles. Si le créateur du pack vous **partage** ses assets (permissions Roblox)
ou vend les fichiers sources (.fbx/.blend), vous aurez un accès complet et légal.

## Limitations réellement bloquantes

1. **Meshes non publiés = temporaires.** Un EditableMesh vit en mémoire : il n'est
   pas sauvegardé avec la place. Cliquez **PUBLIER** pour rendre la créature
   permanente. (Si vous rouvrez Studio avant, sélectionnez la créature : le plugin
   reconstruit ses meshes à l'identique depuis leur « recette » stockée en attributs.)
2. **Publication = plugin local + compte autorisé.** Si Roblox refuse (permission,
   vérification de compte), le statut l'indique et **RÉESSAYER** apparaît. Les
   erreurs 429 et les délais sont gérés automatiquement (backoff 2/4/8/16 s).
3. **Studs sur MeshParts** : la texture suit les UV générés (1 UV = 4 studs,
   réglable via `Config.UV_STUDS_PER_TILE`, puis recréer la créature).

## Rig généré

`Root` (ancré, invisible, PrimaryPart) → `Body` / `Pelvis` → `Neck` → `Head` → `Jaw`,
`Leg_FR` → `Leg_FR_Lower` → `Foot_FR`, `Tail01` → `Tail02`…, `Wing_L/R`,
`Ear_L/R`, `Tentacle01`… en **Motor6D** ; yeux, cornes, pics, museau en
**WeldConstraint**. `AnimationController` + `Animator` inclus. Morphologies :
bipède, quadrupède, hexapode/insecte, flottante, rampante, ailée — jamais
supposée humanoïde.

## Architecture

```
src/
  Main.server.lua            barre d'outils + fenêtre
  Config.lua                 tous les réglages
  Core/        Controller (actions, état, Undo, sélection) · Util
  UI/          MainWindow (2 onglets) · Components (thème sombre)
  Analysis/    CreatureAnalyzer · MorphologyAnalyzer · RigAnalyzer · PaletteAnalyzer
  Geometry/    MeshBuilder · MeshUtils · ShapeLibrary (32 formes) · EditableMeshFactory · MeshRegistry
  Generation/  ProportionGenerator · BodyPlanner · PaletteGenerator · CreatureGenerator
  Rigging/     RigBuilder
  Materials/   MaterialManager
  Publishing/  AssetPublisher
  Study/       BlueprintBuilder · ExplodedView · RigVisualizer
```

Pipeline : pièces source (noms, tailles, CFrames uniquement) → **traits** généraux
(proportions relatives, nombre de membres, ailes, queue, cornes, palette) →
**proportions** variées selon seed/variation → **plan corporel** → formes
procédurales → EditableMesh → MeshParts → rig → matériau → publication.
Le format « traits » est conçu pour être mélangé : c'est la base du futur Mixer.

## Tests hors Studio

`tools/run_tests.sh` (CLI `luau` requis) exécute la logique réelle avec des
services Roblox simulés : 32 formes fermées et bien orientées, analyse de
5 morphologies, parcours complet (analyse → blueprint → vue éclatée → rig →
création → couleurs → matériau → publication avec 429 / permission refusée →
restauration), intégrité du modèle source, et câblage de chaque bouton de l'UI.
