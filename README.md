# GuiCreator

Plugin Roblox Studio pour construire des interfaces visuellement, comme dans Webflow ou Figma, puis générer les vrais objets Roblox.

L'architecture validée de la V1 est décrite dans le document « Architecture V1 – Plugin UI Builder Roblox ».

## Avancement

| Étape | Contenu | État |
| --- | --- | --- |
| 1 | Socle : projet, commandes, undo/redo, GuiCreatorId, sauvegarde dans la place | en cours |
| 2 | Éditeur minimal : canvas, calques, inspecteur | à faire |
| 3 | Première génération dans Roblox | à faire |
| 4 | Thèmes | à faire |
| 5 | Composants et variantes | à faire |
| 6 | Pages et actions | à faire |
| 7 | Bibliothèque d'assets et presets | à faire |
| 8 | Finitions | à faire |

## Organisation

```
src/
├── init.server.lua   point d'entrée du plugin
├── Core/             projet, commandes, historique, sélection, ids, noms
├── Persistence/      sauvegarde du projet dans ServerStorage
└── Util/             outils partagés
tests/                tests lancés avec Lune
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

## Règles

- Toute modification du projet passe par une commande de `src/Core/Commands`, pour que l'undo/redo fonctionne partout.
- Le projet est uniquement fait de données simples (texte, nombres, tableaux), pour être sauvegardé en JSON.
- Les assets intégrés doivent être originaux ou sous une licence autorisant l'usage commercial et la redistribution dans un plugin vendu.
