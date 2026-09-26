--[[
	Config
	Toutes les constantes du moteur sont centralisées ici. Aucun "magic number"
	ne doit apparaître ailleurs dans le code : les modules lisent ces valeurs.
	Les paramètres réglables par l'utilisateur (densité, seed...) vivent dans
	Settings ; ici se trouvent les constantes techniques.
]]

local Config = {}

Config.PLUGIN_ID = "ProceduralComposer"
Config.PLUGIN_DISPLAY_NAME = "Procedural Composer"
Config.VERSION = "1.0.0"
Config.SETTINGS_KEY = "ProceduralComposer_Settings_v1"
Config.WINDOW_SETTINGS_KEY = "ProceduralComposer_Window_v1"

-- Organisation de la sortie ------------------------------------------------
Config.Output = {
	ROOT_NAME = "ProceduralAssetPlacement_Generated",
	PREVIEW_NAME = "Generation_Preview",
	GENERATION_PREFIX = "Generation_",
	GENERATION_DIGITS = 3,
	ITEM_DIGITS = 3,
	HIDDEN_WALLS_FOLDER = "_HiddenOriginalWalls",
	GENERATED_BY = "ProceduralComposer",
	Subfolders = {
		Floor = "FloorDecor",
		Wall = "WallDecor",
		Architecture = "Architecture",
		Ceiling = "CeilingDecor",
		Corner = "CornerDecor",
	},
	SUBFOLDER_ORDER = { "Architecture", "Corner", "Wall", "Floor", "Ceiling" },
}

-- Zones d'exclusion créées par le plugin (dossier séparé : "Clear Generated" ne les supprime pas).
Config.ExclusionZone = {
	FOLDER_NAME = "ProceduralExclusionZones",
	PART_NAME = "CenterExclusionZone",
	HEIGHT = 12,
	TRANSPARENCY = 0.75,
	COLOR = Color3.fromRGB(255, 70, 70),
}

-- Attributs posés sur les objets générés / dossiers ------------------------
Config.Attr = {
	IsPreview = "PCP_IsPreview",
	GenerationIndex = "PCP_GenerationIndex",
	GenerationId = "GenerationId",
	GeneratedBy = "GeneratedBy",
	Seed = "Seed",
	SourceAsset = "SourceAsset",
	PlacementType = "PlacementType",
	TargetSurface = "TargetSurface",
	SizeClass = "SizeClass",
	Scale = "PlacementScale",
	Layer = "Layer",
	OriginalTransparency = "PCP_OriginalTransparency",
	Settings = "PCP_SettingsSnapshot",
	-- Attribut optionnel qu'un utilisateur peut poser sur une Part cible pour forcer son rôle.
	SurfaceRole = "SurfaceRole",
}

-- Tags CollectionService ----------------------------------------------------
Config.Tags = {
	EXCLUDE = "ProceduralPlacementExclude",
	PROTECTED = "ProceduralPlacementProtected",
	IGNORE = "ProceduralPlacementIgnore",
	-- Préfixe des tags de rôle d'asset : "ProceduralPlacement_Floor", "ProceduralPlacement_Wall"...
	ROLE_PREFIX = "ProceduralPlacement_",
}

-- Précision géométrique -----------------------------------------------------
Config.Precision = {
	-- Valeur par défaut de SURFACE_EPSILON (modifiable dans Settings).
	DEFAULT_SURFACE_EPSILON = 0.02,
	MIN_SURFACE_EPSILON = 0.001,
	MAX_SURFACE_EPSILON = 0.25,
	-- Tolérance de contact : deux boîtes qui se touchent exactement ne sont pas en collision.
	CONTACT_TOLERANCE = 0.015,
	-- Epsilon numérique pour les comparaisons flottantes.
	NUMERIC_EPSILON = 1e-6,
	-- Seuil sous lequel un objet est considéré "plat" (risque de z-fighting au sol).
	FLAT_ASSET_THICKNESS = 0.35,
	-- Longueur minimale pour qu'un vecteur soit normalisable.
	MIN_VECTOR_LENGTH = 1e-5,
}

-- Analyse de la géométrie cible --------------------------------------------
Config.Geometry = {
	-- Une normale est "sol" si son angle avec la verticale est inférieur à ce seuil.
	FLOOR_MAX_ANGLE_DEG = 30,
	-- Une normale est "mur" si elle est à moins de ce seuil de l'horizontale.
	WALL_MAX_TILT_DEG = 15,
	-- Une Part est une "dalle" si (plus petite dimension / dimension médiane) <= ce ratio.
	SLAB_THIN_RATIO = 0.45,
	-- Taille minimale (studs) d'une surface exploitable.
	MIN_SURFACE_EXTENT = 0.5,
	-- Tolérance de contact entre un mur et un sol pour les considérer adjacents.
	WALL_FLOOR_CONTACT_TOLERANCE = 1.5,
	-- Distance max horizontale entre le pied d'un mur et le bord d'un sol.
	WALL_FLOOR_PLAN_TOLERANCE = 2.0,
	-- Tolérance pour la détection de coins (en plus de l'épaisseur des murs).
	CORNER_TOLERANCE = 2.0,
	-- |dot(N1, N2)| au-delà duquel deux murs sont considérés parallèles.
	PARALLEL_DOT = 0.96,
	-- |dot(N1, N2)| en dessous duquel deux murs peuvent former un coin (angle 30°..150°).
	CORNER_MAX_ABS_DOT = 0.866,
	-- Hauteur minimale entre un sol et une dalle au-dessus pour la considérer plafond.
	MIN_ROOM_HEIGHT = 4,
	-- Recouvrement minimal (fraction d'aire) sol/plafond.
	CEILING_MIN_OVERLAP = 0.3,
	-- Hauteur d'analyse au-dessus d'un sol pour projeter les obstacles.
	OBSTACLE_PROBE_HEIGHT = 64,
	-- Profondeur de projection des zones d'exclusion devant une surface.
	EXCLUSION_PROBE_DEPTH = 64,
	EXCLUSION_PROBE_BACK = 4,
	-- Mur "séparateur" (les deux faces décorées) : chaque côté doit offrir au moins
	-- cette fraction de la profondeur du sol et cette distance minimale.
	DIVIDER_MIN_SIDE_FRACTION = 0.25,
	DIVIDER_MIN_SIDE_DISTANCE = 6,
	-- Parts non-boîtes (MeshPart, Union...) : on sonde la surface réelle par raycast.
	RAYCAST_PROBE_HEIGHT = 4,
	RAYCAST_MAX_SINK = 2,
}

-- Analyse des assets ---------------------------------------------------------
Config.Assets = {
	-- Ignorer les parts totalement invisibles pour calculer la boîte visuelle.
	IGNORE_INVISIBLE_PARTS_IN_BOUNDS = true,
	-- Au-delà de ce nombre de parts, la collision précise utilise une grille d'occupation.
	MAX_EXACT_SUB_BOXES = 24,
	OCCUPANCY_GRID = 4,
	-- Classes de taille : seuils absolus (studs) utilisés pour les petites bibliothèques.
	ABSOLUTE_SIZE_THRESHOLDS = { Small = 3.0, Medium = 8.0, Large = 18.0 },
	-- Seuils percentiles pour les bibliothèques d'au moins PERCENTILE_MIN_ASSETS assets.
	PERCENTILE_THRESHOLDS = { Small = 0.40, Medium = 0.78, Large = 0.94 },
	PERCENTILE_MIN_ASSETS = 8,
	-- Classification automatique par forme.
	-- Les rapports de profondeur sont mesurés par rapport à la largeur ET à la hauteur :
	-- un objet aussi profond que large (arbre, rocher) n'est jamais un objet mural.
	RELIEF_MAX_DEPTH_RATIO = 0.25,
	RELIEF_MIN_HEIGHT_RATIO = 0.25,
	WALL_PROP_MAX_DEPTH_RATIO = 0.6,
	PANEL_MAX_DEPTH_RATIO = 0.4,
	PANEL_MIN_HEIGHT_RATIO = 0.5,
	PANEL_MAX_HEIGHT_RATIO = 3.0,
	PILLAR_MIN_SLENDERNESS = 2.2,
	PILLAR_MIN_SECTION_RATIO = 0.35,
	TRIM_MIN_ELONGATION = 3.0,
	FLAT_FLOOR_MAX_RATIO = 0.12,
	ARCH_MAX_FILL_RATIO = 0.4,
	ROLE_SCORE_THRESHOLD = 0.35,
	-- Poids / valeurs par défaut des métadonnées.
	DEFAULT_WEIGHT = 1,
	DEFAULT_IMPORTANCE = 1,
	SIZE_CLASS_ORDER = { "Small", "Medium", "Large", "Hero" },
	SIZE_CLASS_IMPORTANCE = { Small = 0.6, Medium = 1.0, Large = 1.6, Hero = 2.4 },
}

-- Liste des rôles d'assets reconnus (PlacementType).
Config.Roles = {
	"Floor", "Wall", "Corner", "Ceiling", "LargeStructure",
	"WallModule", "Pillar", "Arch", "WallTop", "WallBase", "Relief", "Filler",
}

-- Collision -------------------------------------------------------------------
Config.Collision = {
	MIN_CELL_SIZE = 4,
	MAX_CELL_SIZE = 64,
	CELL_SIZE_FACTOR = 2,
	-- Index 2D (voisinage) par surface.
	NEIGHBOR_CELL_SIZE = 8,
	-- Nombre max de cellules parcourues par une requête (évite les boîtes géantes).
	MAX_QUERY_CELLS = 4096,
	-- Pas de lancer de rayon dans la grille (fraction de la taille de cellule).
	RAY_STEP_FACTOR = 0.5,
	-- Les parts de la scène invisibles et non collidables sont ignorées.
	IGNORE_INVISIBLE_SCENE_PARTS = true,
}

-- Composition -----------------------------------------------------------------
Config.Composition = {
	-- Plafond de sécurité de couverture du sol (fraction d'aire) à densité 0.5.
	MAX_FLOOR_COVERAGE = 0.34,
	-- Budget des petits éléments de remplissage : une "cellule" de dispersion
	-- par élément (au moins SCATTER_CELL_MIN studs, ou SCATTER_CELL_RADII rayons).
	SCATTER_CELL_MIN = 10,
	SCATTER_CELL_RADII = 8,
	-- Espacement minimal (studs) entre deux beats de bord.
	EDGE_BEAT_MIN_SPACING = 5,
	-- Nombre max d'échecs consécutifs avant d'arrêter une passe.
	MAX_CONSECUTIVE_FAILURES = 30,
	-- Nombre de candidats par tentative (valeur par défaut, réglable).
	DEFAULT_CANDIDATES = 18,
	-- Parmi combien des meilleurs candidats on tire (selon Randomness).
	MIN_TOP_CHOICES = 1,
	MAX_TOP_CHOICES = 5,
	-- Surface (studs²) par "héros" potentiel.
	HERO_AREA = 1400,
	CLUSTER_AREA = 420,
	-- Taille des groupes.
	MIN_CLUSTER_MEMBERS = 1,
	MAX_CLUSTER_MEMBERS = 6,
	-- Espacement entre groupes (multiplié par le rayon du groupe).
	CLUSTER_BREATHING = 1.6,
	-- Palette : fraction des assets utilisés par surface selon Variation.
	PALETTE_MIN_FRACTION = 0.35,
	PALETTE_MIN_COUNT = 3,
	-- Pénalités de répétition.
	REPEAT_LAST_FACTOR = 0.3,
	REPEAT_RECENT_FACTOR = 0.65,
	RECENT_HISTORY = 4,
	-- Rythme visuel : nombre de "vagues" le long de la grande dimension.
	RHYTHM_MIN_WAVES = 1.5,
	RHYTHM_MAX_WAVES = 5,
	-- Bruit de densité (zones respirantes cohérentes).
	NOISE_SCALE = 22,
	-- Beats (séquences 1D pour bords, murs, plafonds).
	BEAT_BASE_SPACING = 1.0,
	BEAT_MAX = 400,
	-- Surface trop petite : en dessous de cette aire on ne place qu'un seul point focal.
	TINY_AREA = 16,
	-- Profondeur de bande de bord par défaut quand EdgeDepth vaut 0.
	MIN_EDGE_DEPTH = 1.5,
	-- Ratio d'allongement au-delà duquel un sol est un couloir.
	CORRIDOR_ASPECT = 3,
	-- Rotation : jitter max (degrés) à Randomness = 1 pour les modes orientés.
	MAX_ROTATION_JITTER_DEG = 14,
	-- Symétrie : décalage max (studs) accepté pour un élément miroir.
	MIRROR_SEARCH_RADIUS = 1.5,
	-- Plafond : fraction max de la hauteur de pièce occupée par un élément suspendu.
	CEILING_MAX_DROP_RATIO = 0.45,
	-- Mur : marges.
	WALL_EDGE_MARGIN = 0.25,
	WALL_PROP_DEFAULT_HEIGHT = 0.6,
	WALL_RELIEF_DEFAULT_HEIGHT = 0.5,
	WALL_HANGING_TOP_MARGIN = 0.1,
}

-- Score des positions candidates -------------------------------------------------
-- Chaque terme est normalisé dans [-1, 1] puis multiplié par son poids.
Config.Scoring = {
	Weights = {
		Crowding = 2.5,
		ClusterCohesion = 2.2,
		LargeSeparation = 3.0,
		Repetition = 1.2,
		Edge = 1.6,
		Wall = 0.9,
		Center = 1.6,
		Balance = 0.9,
		Rhythm = 1.1,
		Empty = 1.9,
		Thirds = 1.3,
		ClusterSeparation = 2.0,
		Noise = 1.0,
	},
	-- Rayon de recherche de voisins (multiple du rayon d'empreinte).
	NEIGHBOR_RADIUS_FACTOR = 4,
	-- Espacement souhaité entre éléments non groupés (multiple de la somme des rayons).
	DESIRED_GAP_FACTOR = 0.6,
	-- Deux grands éléments doivent être séparés de ce multiple de leurs rayons.
	LARGE_SEPARATION_FACTOR = 2.5,
	-- Rayon de pénalité de répétition du même asset.
	REPEAT_RADIUS_FACTOR = 5,
	-- Écart idéal entre membres d'un groupe (multiple du rayon du satellite).
	CLUSTER_GAP_FACTOR = 0.35,
	-- Taille de zone par groupe / par héros, en rayons d'empreinte typiques.
	CLUSTER_SPACING_RADII = 9,
	HERO_SPACING_RADII = 7,
	-- Zone (en rayons de l'asset) par élément de classe Hero.
	HERO_CLASS_ZONE_RADII = 12,
	-- Nombre max de tests de collision par placement (après tri des candidats).
	MAX_COLLISION_TESTS = 8,
	-- Tentatives de choix d'asset avant d'abandonner un placement.
	MAX_ASSET_RETRIES = 3,
}

-- Assemblage modulaire ----------------------------------------------------------
Config.Fitting = {
	QUANTUM = 0.05,
	MAX_UNITS = 12000,
	DEFAULT_MAX_SCALE_DEVIATION = 0.08,
	MAX_STRETCH = 1.6,
	MIN_STRETCH = 0.7,
	-- Reste (studs) toléré en marge centrée quand aucune autre solution n'existe.
	END_MARGIN_TOLERANCE = 0.3,
	-- Largeur minimale d'une pièce de remplissage.
	MIN_FILLER_WIDTH = 0.75,
	-- Écart max entre modules quand les espacements sont autorisés (fraction de largeur).
	MAX_GAP_FRACTION = 0.35,
	-- Coûts de l'optimiseur.
	MODULE_COST = 1.0,
	FILLER_COST = 3.0,
	DEFORMATION_COST = 60.0,
	NOISE_COST = 0.35,
	-- Regroupement des modules par hauteur (fraction).
	HEIGHT_BUCKET_TOLERANCE = 0.12,
	-- Tolérance d'exactitude finale.
	LENGTH_TOLERANCE = 1e-4,
}

-- Architecture --------------------------------------------------------------------
Config.Architecture = {
	-- Couches de profondeur : chaque couche est avancée de n * SURFACE_EPSILON.
	LAYER_MODULE = 1,
	LAYER_PILLAR = 2,
	LAYER_TRIM = 3,
	LAYER_DETAIL = 4,
	LAYER_PROP = 5,
	-- Un pilier est "posé sur le mur" s'il est plus profond que les modules de cette marge.
	PILLAR_DEPTH_MARGIN = 0.1,
	-- Hauteur par défaut des reliefs dans une travée (fraction de hauteur).
	DETAIL_HEIGHT = 0.55,
	-- Écart minimal pour empiler plusieurs rangées de modules.
	MIN_ROW_FILL = 0.35,
	-- Portion de travées remplacées par des arches (modulée par VisualRhythm).
	ARCH_BAY_RATIO = 0.34,
	-- Distance devant la façade pour les rayons de projection des détails.
	DETAIL_RAY_START = 50,
}

-- Performance ----------------------------------------------------------------------
Config.Performance = {
	-- Budget (secondes) avant de rendre la main à Studio pendant la planification.
	YIELD_BUDGET = 0.012,
	-- Nombre de clones instanciés entre deux yields.
	INSTANTIATE_BATCH = 120,
	-- Limites de sécurité.
	HARD_MAX_ASSETS = 5000,
	MAX_SURFACES = 400,
	MAX_LIBRARY_ASSETS = 2000,
	MAX_ANALYZE_PARTS_PER_ASSET = 20000,
}

-- Debug visuel ---------------------------------------------------------------------
Config.Debug = {
	FOLDER_NAME = "ProceduralComposer_Debug",
	MAX_CANDIDATES = 1500,
	MAX_REJECTED = 1500,
	POINT_RADIUS = 0.35,
	NORMAL_LENGTH = 6,
	LINE_THICKNESS = 3,
	BOX_TRANSPARENCY = 0.82,
	ZONE_TRANSPARENCY = 0.7,
	Colors = {
		Bounds = Color3.fromRGB(80, 170, 255),
		Architecture = Color3.fromRGB(255, 170, 60),
		Normal = Color3.fromRGB(80, 255, 120),
		Exclusion = Color3.fromRGB(255, 60, 60),
		CenterClear = Color3.fromRGB(255, 220, 40),
		Candidate = Color3.fromRGB(90, 255, 90),
		Rejected = Color3.fromRGB(255, 70, 70),
		Snap = Color3.fromRGB(40, 240, 255),
		Segment = Color3.fromRGB(230, 70, 255),
		Corner = Color3.fromRGB(255, 140, 0),
		Surface = Color3.fromRGB(255, 255, 255),
	},
}

-- Interface -----------------------------------------------------------------------
Config.UI = {
	WIDGET_ID = "ProceduralComposerWidget",
	DEFAULT_WIDTH = 380,
	DEFAULT_HEIGHT = 760,
	MIN_WIDTH = 300,
	MIN_HEIGHT = 360,
	ROW_HEIGHT = 24,
	PADDING = 6,
	FONT = Enum.Font.SourceSans,
	FONT_BOLD = Enum.Font.SourceSansBold,
	TEXT_SIZE = 14,
	HEADER_TEXT_SIZE = 15,
	SETTINGS_SAVE_DELAY = 0.6,
	MAX_SURFACE_ROWS = 60,
}

return Config
