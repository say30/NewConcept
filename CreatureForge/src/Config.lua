-- Creature Forge — configuration centrale.
-- Tout ce qui est « réglage » vit ici, pour ne jamais encombrer l'interface.

local Config = {}

Config.PLUGIN_NAME = "Creature Forge"
Config.VERSION = "1.0.0"

-- Toutes les créations du plugin vont ici (jamais dans le modèle source).
Config.OUTPUT_FOLDER = "CreatureForge_Output"

-- Préfixe des attributs posés par le plugin sur ses propres créations.
Config.ATTR = "CF_"

-- Nom du MaterialVariant « Studs » par défaut (modifiable dans l'UI).
Config.DEFAULT_VARIANT = "Studs"

-- Mapping UV : 1 unité UV = N studs (utile pour les MaterialVariants sur MeshParts).
Config.UV_STUDS_PER_TILE = 4

-- Petite irrégularité « low-poly » appliquée aux sommets (fraction de la taille).
Config.LOWPOLY_JITTER = 0.025

-- Espacement entre l'original, le blueprint et les versions générées (en studs).
Config.LAYOUT_GAP = 6

-- Génération des MeshParts.
Config.MESH = {
	CollisionFidelity = Enum.CollisionFidelity.Hull,
	RenderFidelity = Enum.RenderFidelity.Precise,
	-- Rendre la main à Studio tous les N meshes (UI fluide pendant la génération).
	YieldEvery = 3,
}

-- Publication des meshes.
Config.PUBLISH = {
	MaxRetries = 4, -- tentatives en cas de rate limit / erreur réseau
	Backoff = { 2, 4, 8, 16 }, -- secondes
	Timeout = 90, -- secondes par upload
	DelayBetween = 0.35, -- pause entre deux uploads
	ApplyRetries = 6, -- l'asset peut mettre quelques secondes à être disponible
	ApplyDelay = 2,
	-- Mémorise clé-de-forme -> assetId entre les sessions (évite de republier).
	CacheSetting = "CreatureForge_PublishedMeshes",
	CacheMax = 3000,
}

-- Visualisation.
Config.VIZ = {
	BlueprintTransparency = 0.35,
	BlueprintTransparencyRig = 0.75,
	LabelMaxDistance = 80,
	MaxAttachmentMarkers = 400,
	Colors = {
		Motor6D = Color3.fromRGB(255, 150, 60),
		Weld = Color3.fromRGB(150, 160, 175),
		WeldConstraint = Color3.fromRGB(90, 170, 255),
		Bone = Color3.fromRGB(255, 80, 200),
		Attachment = Color3.fromRGB(60, 230, 220),
	},
}

-- Niveaux de variation (index 1..3 = Faible / Moyenne / Forte).
Config.VARIATION = {
	{ name = "Faible", amount = 0.08, featureFlip = 0.0, keepStyle = 0.85 },
	{ name = "Moyenne", amount = 0.2, featureFlip = 0.15, keepStyle = 0.5 },
	{ name = "Forte", amount = 0.38, featureFlip = 0.35, keepStyle = 0.15 },
}

-- Emplacements de couleur exposés à l'utilisateur.
Config.PALETTE_SLOTS = { "Primary", "Secondary", "Accent", "Eyes", "Special" }

return Config
