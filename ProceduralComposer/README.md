# Procedural Composer — plugin Roblox Studio

Outil de **composition procédurale de décors** : vous sélectionnez une géométrie existante (sol, murs, façade, plafond, plusieurs Parts...) et une bibliothèque d'assets, le plugin analyse la zone et compose un décor cohérent — hiérarchie visuelle, groupes, zones respirantes, rythme, symétrie, façades architecturales modulaires sans trou — avec preview, seed déterministe et Ctrl+Z.

Totalement générique : aucun nom de Part, de biome ou d'asset n'est codé en dur. Les rôles des surfaces viennent de leur **orientation réelle**, ceux des assets de leurs **métadonnées optionnelles** ou de leur **forme**.

---

## 1. Installation

**Option A — fichier prêt à l'emploi**
1. Copier `dist/ProceduralComposer.rbxmx` dans le dossier Plugins de Studio
   (Studio : onglet *Plugins* → *Plugins Folder*).
2. Redémarrer Studio. Un bouton **Composer** apparaît dans l'onglet *Plugins*.

**Option B — depuis les sources (Rojo)**
```bash
rojo build default.project.json -o ProceduralComposer.rbxmx
```
puis copier le fichier dans le dossier Plugins.

## 2. Démarrage rapide

1. Sélectionner la zone dans l'Explorer (ex. `Sol` + `MurGauche` + `MurDroit`, ou le Model/Folder qui les contient) → **TARGET › Use Current Selection**. La liste *Target Surfaces* affiche le rôle détecté de chaque Part (modifiable : AUTO / FLOOR / WALL / CEILING / IGNORE).
2. Sélectionner le(s) dossier(s) d'assets → **ASSET LIBRARY › Use Current Selection as Library**.
3. Choisir un preset (en haut) ou régler les paramètres.
4. **Generate Preview** → inspecter → **Regenerate** (nouvelle variante), **Accept** ou **Cancel**.

Le résultat est rangé dans :
```
Workspace
└─ ProceduralAssetPlacement_Generated
   ├─ Generation_Preview        (preview en cours)
   └─ Generation_001
      ├─ Architecture / CornerDecor / WallDecor / FloorDecor / CeilingDecor
      │  └─ NomAsset_001, NomAsset_002...
```
Chaque objet porte les attributs `GeneratedBy`, `Seed`, `SourceAsset`, `PlacementType`, `TargetSurface`, `GenerationId`, `SizeClass`, `PlacementScale`, `Layer`.

## 3. Garder le centre vide / zones d'exclusion

Trois mécanismes, cumulables :

| Mécanisme | Utilisation |
|---|---|
| **Keep Center Clear** (FLOOR OPTIONS) | Bande centrale interdite entre `Clear zone start` et `Clear zone end` (ex. 0.2 → 0.8 : décor dans les 20 % de chaque côté). L'axe est automatique (perpendiculaire aux murs) ou forcé (Width / Length / Both). Le preset **EdgesOnly** l'active directement. |
| **Create Center Exclusion Zone** (COLLISION) | Crée une vraie Part visible et redimensionnable au centre de chaque sol analysé, taguée `ProceduralPlacementExclude`, dans `Workspace.ProceduralExclusionZones`. Elle reste active pour toutes les générations suivantes (et n'est jamais supprimée par *Clear Generated*). |
| **Zones manuelles** | Sélectionner des Parts (spawn, chemin, porte, PNJ, coffre...) → *Use Selection as Zones*, ou leur ajouter le tag CollectionService `ProceduralPlacementExclude`. |

*Protected geometry* (ou tag `ProceduralPlacementProtected`) : des objets qui ne doivent jamais être chevauchés, sans pour autant interdire leur voisinage.

## 4. Métadonnées des assets (toutes optionnelles)

Attributs posés sur l'asset **ou sur un dossier parent** (hérités par tout son contenu).

| Attribut | Type | Effet |
|---|---|---|
| `PlacementType` | string | `Floor`, `Wall`, `Corner`, `Ceiling`, `LargeStructure`, `WallModule`, `Pillar`, `Arch`, `WallTop`, `WallBase`, `Relief`, `Filler` — plusieurs séparés par des virgules. Remplace l'analyse automatique. |
| `Weight` | number | Probabilité relative (0 = jamais utilisé). |
| `MinScale` / `MaxScale` | number | Bornes d'échelle. |
| `AllowScale` | bool | `false` interdit toute mise à l'échelle. |
| `AllowRotation` / `AllowMirror` | bool | Rotation autorisée / retournement à 180°. |
| `WallOffset` / `FloorOffset` | number | Décalage depuis le mur / le sol (négatif = enfoncé). |
| `Category` | string | Catégorie (défaut : premier sous-dossier). |
| `Importance` | number | Poids visuel (équilibre gauche/droite). |
| `RepeatLimit` / `UniqueAsset` | number / bool | Limite d'utilisation par génération. |
| `MinSpacing` | number | Espace libre minimal autour de l'asset. |
| `PreferredHeight` | number | Hauteur sur un mur : fraction si ≤ 1, sinon studs. |
| `CanTouchWall` | bool | Peut toucher les murs. |
| `CanOverlapDecoration` | bool | Peut chevaucher d'autres décorations (herbe...). |
| `SizeClass` | string | `Small`, `Medium`, `Large`, `Hero`. |
| `Stretchable` | bool | Module d'une seule Part pouvant être étiré en longueur (corniches...). |
| `CeilingFlip` | bool | Retourne l'asset au plafond. |
| `FacingYaw` / `WallYaw` | number (°) | Corrige l'avant de l'asset / sa face côté mur. |
| `AlignToSurface` | bool | Suit l'inclinaison des pentes. |
| `UsePivotOrientation` | bool | Utilise l'orientation du pivot au lieu du haut du monde. |

Tags équivalents : `ProceduralPlacement_Floor`, `ProceduralPlacement_Wall`, ... ; `ProceduralPlacementIgnore` exclut un asset ou une Part cible.

Sur une Part cible, l'attribut `SurfaceRole` (`Floor`, `Wall`, `Ceiling`, `Ignore`) force son rôle de façon persistante.

**Attachments optionnels** (prioritaires sur la boîte englobante) : `Placement_Base` (point posé sur le sol), `Placement_Back` (point contre le mur), `Snap_Left` / `Snap_Right` (assemblage bord à bord exact), `Snap_Top` / `Snap_Bottom` (empilement), `Facing` (avant de l'asset).

Sans métadonnées, la classification automatique déduit : relief mural (très plat), module mural (panneau), pilier (haut et fin), corniche/soubassement (long et bas), élément de sol, décor de plafond, et la classe de taille (percentiles de la bibliothèque).

## 5. Fonctionnement

- **Analyse géométrique** : chaque Part est découpée en faces dans son repère local ; rôle selon la normale (sol, mur, plafond, pente). Murs découpés au niveau du sol/plafond et aux coins, face intérieure choisie automatiquement, coins et murs parallèles détectés. Tout est exprimé dans le repère des surfaces : une zone tournée de 37° donne exactement la même composition.
- **Mesure des assets** : boîte réelle calculée dans un repère « position du pivot + haut du monde » : un pivot décalé ou basculé n'a aucun effet.
- **Pose exacte** : la face la plus basse touche le sol ; l'arrière d'un objet mural est à `SURFACE_EPSILON` du mur ; les couches architecturales sont avancées de n × epsilon (pas de z-fighting).
- **Composition** : points focaux (tiers), groupes leader + satellites séparés par des zones respirantes (champ de bruit), séquences rythmiques le long des bords (gros / petit groupe / vide), symétrie miroir, équilibre gauche/droite, palette cohérente par surface, score multi-critères des positions candidates.
- **Murs modulaires** : programmation dynamique + micro-mise à l'échelle pour remplir **exactement** la longueur (ex. 211.507 studs = 15 modules de 14 × 1.00718), sinon étirement / remplissage / marge centrée ; jamais de dépassement du haut du mur.
- **Collision** : hash spatial 3D + SAT sur les boîtes orientées + sous-boîtes par Part (grille d'occupation pour les assets de centaines de Parts) + `GetPartBoundsInBox` sur la scène.
- **Historique** : preview et variantes forment un seul point d'annulation ; après *Accept*, **un seul Ctrl+Z** annule toute la génération.
- **Sécurité** : les assets sources sont toujours clonés, les cibles jamais déplacées ni supprimées. Le masquage des murs (Rebuild + *Hide original walls*) est réversible (Cancel, Clear Generated, Ctrl+Z).

## 6. Architecture du code

```
src/
  init.server.luau              Point d'entrée : toolbar, DockWidget
  Core/        Config (toutes les constantes), Settings (schéma + persistance),
               Presets, Logger, Utilities, MathUtil (OBB, SAT, polygones), RandomGenerator
  Analysis/    SelectionAnalyzer, GeometryAnalyzer, AssetAnalyzer, AssetRegistry
  Placement/   PlacementMath, CollisionEngine, ExclusionZones, SnapEngine, ModularFitter,
               CandidateScoring, CompositionPlanner, AssetSelector, PlacementContext,
               FloorPlacementEngine, WallPlacementEngine, ArchitectureEngine,
               CornerEngine, CeilingPlacementEngine
  Generation/  AppController, GenerationManager, OutputBuilder, PreviewManager,
               HistoryManager, DebugVisualizer, Diagnostics
  UI/          Theme, Widgets, UIController
tests/         Mock de l'API Roblox + 35 tests exécutés hors Studio
```

## 7. Tests

```bash
tests/run.sh      # nécessite la CLI luau
```
Les 20 cas du cahier des charges sont dans `tests/specs/cases.luau` (sol + 20 assets, murs parallèles, rotation de 35°, mur de 211.507 studs, tailles extrêmes, Model sans PrimaryPart, pivot bizarre, exclusion au milieu d'un mur, centre libre à 60 %, sous-dossiers, 10 régénérations + déterminisme, Cancel, Accept + historique, collision de gros assets, longueur non multiple, surface minuscule, asset trop grand, murs en angle 90°/60°, mur de 200 studs, sol long et étroit). `tests/specs/engines.luau` et `ui.luau` couvrent l'architecture, les plafonds, tous les algorithmes et modes de rotation, les pentes, les attachments, les tags, les métadonnées, le flux complet et l'interface.

Chaque génération testée est validée automatiquement : contact exact au sol, aucun objet dans les murs, dans les limites des surfaces, aucune interpénétration, aucun doublon.

## 8. Limites connues (pistes V2)

- Les MeshParts/Unions cibles sont sondées par raycast mais leurs obstacles sont approximés par leur boîte.
- Roblox n'autorisant pas l'échelle négative, `AllowMirror` correspond à un retournement de 180°, pas à un vrai miroir géométrique.
- Le mode *FollowPath* suit la grande dimension de la surface (pas encore de chemin dessiné).
- Les coins extérieurs (angles saillants) ne reçoivent pas encore de pièce dédiée.
