# L'étape qui n'appartient qu'à toi

Tous les acheteurs du modèle ont les mêmes quinze étapes. Celle que tu ajoutes
est ton seul vrai avantage. Autant qu'elle soit mémorable.

---

## Ce que les 15 étapes utilisent déjà

En les listant, on voit ce qui manque :

| Déjà fait | Étapes |
|---|---|
| Monstre qui poursuit | 2, 10, 12 |
| Écrasement | 3, 7, 14 |
| Sauts au-dessus du vide | 4, 5, 9, 13 |
| Vague / liquide qui monte | 6, 8, 11 |
| Montée verticale | 8, 11 |

**Ce qui n'existe nulle part :**

- une salle où il faut **ralentir**
- une salle **sombre**
- une salle où le joueur **choisit** son chemin
- une salle **sans danger**

Et la première est de loin la plus forte.

---

## La salle qui punit la vitesse

### Pourquoi elle

Ton jeu entier dit au joueur : cours plus vite, achète plus de vitesse, monte de
niveau. Une salle qui retourne cette règle est une surprise que personne
n'attend — et elle ne demande aucun nouveau système, juste de la géométrie.

Ce n'est pas une idée en l'air. Dans le direct que tu m'as transmis, la
streameuse échoue en boucle sur l'étape 14 et dit exactement pourquoi :

> « J'ai trop de vitesse et je passe tout droit. »
> « Je saute plus doucement parce que je passe toujours par-dessus. »

Le problème existe déjà dans le jeu, subi et frustrant. Toi, tu en fais une
salle assumée, annoncée, avec les moyens de s'y adapter. La frustration
devient un défi.

### Le décor : le grand bol

Un bol géant rempli de lait. Le joueur doit le traverser en sautant d'un anneau
de céréale à l'autre. Le lait tue au contact — tu réutilises le sol mortel que
tu as déjà.

### Comment ça marche

**Version sans script.** Les anneaux sont petits et espacés court. À pleine
vitesse, le joueur dépasse systématiquement l'anneau visé et tombe dans le lait.
Il doit relâcher, avancer par petites touches, viser. C'est de la géométrie
pure : rien à coder.

| Élément | Dimension |
|---|---|
| Anneau (plateforme) | 5 × 5 studs |
| Écart entre deux anneaux | 7 studs |
| Hauteur au-dessus du lait | 3 studs |
| Nombre d'anneaux | 12 à 15 |

Des écarts **courts**, pas longs. C'est le contre-intuitif : un grand écart
récompense la vitesse, un petit écart la punit.

**Version avec un petit script.** À l'entrée, une flaque de lait que le joueur
traverse et qui plafonne sa vitesse le temps de la salle. Tout le monde franchit
l'étape à la même allure, qu'on soit niveau 50 ou niveau 700.

C'est cinq lignes de code — l'Assistant de Studio te les écrit si tu lui
demandes « limite la WalkSpeed du joueur à 30 tant qu'il est dans cette zone ».

Cette version est meilleure : elle est juste, lisible, et elle donne au joueur
un moyen de s'adapter au lieu de simplement le punir.

### Ce qu'il ne faut surtout pas faire

**Pas de murs qui font rebondir.** La même streameuse s'en plaint :

> « Ça devrait être de la triche. Je rebondis contre le mur et le jeu me sort. »

Un joueur qui échoue doit comprendre pourquoi. Rebondir sur un mur invisible,
il ne comprend pas — il pense que le jeu triche. Tombe dans le lait, il comprend.

### L'annoncer

Un panneau à l'entrée : **RALENTIS**. Et pendant la salle, la jauge de vitesse
passe en rouge quand elle est trop haute.

Une difficulté annoncée est un défi. La même, cachée, est un bug.

---

## Les trois autres, si celle-là ne te plaît pas

**La salle sombre.** Lumières éteintes, seule la résistance du grille-pain
éclaire en rouge. Le joueur avance à tâtons. Coût : zéro asset, juste des murs
noirs et deux `PointLight`. Aucune des quinze n'est sombre — l'effet de rupture
est immédiat.

**La salle à choix.** Deux portes, deux couloirs courts, même sortie. L'un est
rapide et dangereux, l'autre lent et sûr. Ton jeu permet déjà d'aller à droite
ou à gauche en fin d'étape : tu utilises une structure qui existe. Et ça donne
une raison de rejouer.

**La salle sans danger.** Après quinze salles qui tuent, une pièce où il ne se
passe rien : une table de petit-déjeuner tranquille, la radio qui joue, rien qui
poursuit. Trente secondes de calme avant le final. C'est le genre de moment dont
les joueurs parlent — et c'est la salle la moins chère à construire de tout le
jeu.

---

## L'ordre que je te conseille

| Étape | Contenu |
|---|---|
| **15** | La salle qui punit la vitesse — ta signature |
| **16** | Le final XXL, Monsieur Croustillant |

Le twist avant le feu d'artifice. Si tu mets ta salle après le final, le joueur
croit le jeu terminé et s'en va.

Et si tu veux les deux : glisse la salle sans danger entre les deux. Quinze
salles de tension, une pause, puis le boss. C'est le rythme classique, et il
marche.
