# GuiCreator

Plugin Roblox Studio pour construire des interfaces visuellement, comme dans Webflow ou Figma, puis générer les vrais objets Roblox.

L'architecture validée de la V1 est décrite dans le document « Architecture V1 – Plugin UI Builder Roblox ».

## Ce que fait le plugin

- **Accueil** : deux grands choix, « Assistant » ou « Je crée moi-même », plus un accès direct à chaque type de fenêtre.
- **Assistant** : on choisit un type (boutique, récompenses, animaux, codes, paramètres, renaissance, quêtes, message, HUD), puis on répond à des questions en images (style, titre, icône, nombre de cartes, présentation, couleurs, monnaie…). L'aperçu se met à jour à chaque clic, et « Créer ma fenêtre » construit la page.
- **Éditeur** : galerie « Ajouter » en miniatures (fenêtres, cartes, boutons, textes, icônes, barres, rangements), calques, et inspecteur en images (couleur, effet, motif, coins, contour, ombre, texte, icône, rangement, placement). Les réglages précis restent dans « Réglages avancés ».
- **8 styles** : Studs, Jardin, Cartoon, Bonbon, Océan, Néon, Sombre, Minimal. Changer de style repeint toute la page.
- **Génération** dans StarterGui, avec les mêmes objets que l'aperçu.

## Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | Socle : projet, commandes, undo/redo, GuiCreatorId, sauvegarde dans la place | fait |
| 2 | Éditeur visuel : accueil, assistant, galerie, calques, inspecteur en images | fait (à tester dans Studio) |
| 3 | Génération dans Roblox | fait (à tester dans Studio) |
| 4 | Styles | 8 styles faits |
| 5 | Modèles, icônes et motifs | 9 assistants, 37 icônes, 6 motifs |
| 6 | Pages et actions des boutons | pages faites, actions à faire |
| 7 | Bibliothèque d'assets | à faire |
| 8 | Finitions | à faire |

## Organisation

```
src/
├── init.server.lua   point d'entrée du plugin
├── App/              écrans du plugin : accueil, assistant, éditeur (barre, galerie, calques, canvas, inspecteur), popups
├── Catalog/          Kit (briques : fenêtre, carte, bouton…), Recipes (assistants), Elements (galerie)
├── Core/             projet, commandes, historique, sélection, ids, noms
├── Generator/        construction des objets Roblox (aperçu et génération)
├── Persistence/      sauvegarde du projet dans ServerStorage
├── Schema/           types d'éléments et propriétés modifiables
├── Style/            les 8 styles (Packs) et la résolution des valeurs « $nom »
├── Visual/           icônes et motifs dessinés avec des formes Roblox, sans image
└── Util/             outils partagés
tests/                tests lancés avec Lune
tools/preview/        rendu des fenêtres en images, pour vérifier le visuel sans Studio
archive/              anciens fichiers JSON, sans lien avec le plugin
```

## Compiler le plugin

Il faut [Rojo](https://rojo.space) 7.

```
rojo build -o GuiCreator.rbxm
```

Copier ensuite `GuiCreator.rbxm` dans le dossier des plugins de Studio (Studio, onglet Plugins, bouton « Plugins Folder »), puis redémarrer Studio.

## Lancer les tests

Il faut [Lune](https://lune-org.github.io/docs) 0.10 ou plus récent.

```
lune run tests/run
```

## Voir les fenêtres sans Studio

Les scripts de `tools/preview` construisent les objets avec Lune, les exportent en JSON, puis `render.js` les dessine en HTML et prend une capture avec Playwright (Node). C'est une approximation de Roblox, utile pour vérifier une mise en page.

```
lune run tools/preview/scene.luau out.json shop      # aussi : tall, banner, hud, recipes, recipesGarden, recipesCandy
lune run tools/preview/icons.luau out.json           # toutes les icônes
lune run tools/preview/plugin.luau out.json all      # les écrans du plugin
node tools/preview/render.js out.json out.png [numéro de scène]
```

Les polices peuvent être placées dans `tools/preview/fonts/` (fichier `local.css`), qui n'est pas suivi par git.

## Règles

- Toute modification du projet passe par une commande de `src/Core/Commands`, pour que l'undo/redo fonctionne partout.
- Tout ce qui est dessiné (aperçu, miniatures, génération) passe par `src/Generator/Builder`.
- Le projet est uniquement fait de données simples (texte, nombres, tableaux), pour être sauvegardé en JSON.
- Les assets intégrés doivent être originaux ou sous une licence autorisant l'usage commercial et la redistribution dans un plugin vendu.
